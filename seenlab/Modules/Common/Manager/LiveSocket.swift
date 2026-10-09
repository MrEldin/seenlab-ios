//
//  LiveSocket.swift
//  seenlab
//
//  A socket to Seenlab's Reverb server (the Pusher protocol over URLSessionWebSocketTask, no library): joins one
//  presence channel — a growth board — and reports who is on it and the board's events ("changed"). Reconnects
//  with a growing pause when the line drops; stop() when the board is closed or the app goes to the background.
//  Best effort: without it the board still refreshes on its own, only slower.
//

import Foundation

@MainActor
final class LiveSocket {
    /// Where the socket is (sent by the API with the board): Reverb's public key, host, port, TLS.
    struct Config: Decodable, Equatable { var key: String; var host: String; var port: Int; var tls: Bool }

    var onEvent: ((String, [String: Any]) -> Void)?
    var onMembers: ((Set<Int>) -> Void)?
    var onState: ((Bool) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var config: Config?
    private var channel = ""
    private var members = Set<Int>()
    private var retry = 0
    private var stopped = true
    private var pinger: Task<Void, Never>?
    private var reconnect: Task<Void, Never>?

    func start(_ config: Config, channel: String) {
        if !stopped, self.channel == channel, self.config == config { return }
        stop()
        self.config = config
        self.channel = channel
        stopped = false
        retry = 0
        open()
    }

    func stop() {
        stopped = true
        reconnect?.cancel(); pinger?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        members = []
        onState?(false)
    }

    private func open() {
        guard let c = config, !stopped else { return }
        var comps = URLComponents()
        comps.scheme = c.tls ? "wss" : "ws"; comps.host = c.host; comps.port = c.port; comps.path = "/app/\(c.key)"
        comps.queryItems = [URLQueryItem(name: "protocol", value: "7"), URLQueryItem(name: "client", value: "seenlab-ios"), URLQueryItem(name: "version", value: "1.0")]
        guard let url = comps.url else { return }
        var req = URLRequest(url: url)
        req.setValue("https://seenlab.io", forHTTPHeaderField: "Origin")   // Reverb checks the origin
        let t = URLSession.shared.webSocketTask(with: req)
        task = t
        t.resume()
        receive(t)
        pinger?.cancel()
        // the server drops a quiet connection after 30 s
        pinger = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(25))
                self?.send(["event": "pusher:ping", "data": [String: Any]()])
            }
        }
    }

    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self, t === self.task else { return }
                switch result {
                case .success(let msg):
                    if case .string(let s) = msg { await self.handle(s) }
                    self.receive(t)
                case .failure:
                    self.dropped()
                }
            }
        }
    }

    private func handle(_ text: String) async {
        guard let msg = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any], let event = msg["event"] as? String else { return }
        // Pusher sends `data` as a JSON string
        let data: [String: Any] = (msg["data"] as? String).flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] } ?? (msg["data"] as? [String: Any]) ?? [:]
        switch event {
        case "pusher:connection_established":
            retry = 0
            if let id = data["socket_id"] as? String { await subscribe(socketId: id) }
        case "pusher_internal:subscription_succeeded":
            let ids = ((data["presence"] as? [String: Any])?["ids"] as? [Any]) ?? []
            members = Set(ids.compactMap { Int("\($0)") })
            onMembers?(members)
            onState?(true)
        case "pusher_internal:member_added":
            if let id = Int("\(data["user_id"] ?? "")") { members.insert(id); onMembers?(members) }
        case "pusher_internal:member_removed":
            if let id = Int("\(data["user_id"] ?? "")") { members.remove(id); onMembers?(members) }
        case "pusher:ping":
            send(["event": "pusher:pong", "data": [String: Any]()])
        case "pusher:error":
            let code = (data["code"] as? Int) ?? 0
            if (4000...4099).contains(code) { stop() }   // refused for good (wrong key, origin): stay off
        default:
            if (msg["channel"] as? String) == "presence-" + channel, !event.hasPrefix("pusher") { onEvent?(event, data) }
        }
    }

    /// The board's channel is private: the API signs the subscription with the session's token.
    private func subscribe(socketId: String) async {
        guard let token = KeyChainManager.shared.token, let url = URL(string: NetworkManager.shared.baseURL + "/broadcasting/auth") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["socket_id": socketId, "channel_name": "presence-" + channel])
        guard let (body, resp) = try? await URLSession.shared.data(for: req), (resp as? HTTPURLResponse)?.statusCode == 200,
              let auth = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let signature = auth["auth"] as? String else { dropped(); return }
        var sub: [String: Any] = ["channel": "presence-" + channel, "auth": signature]
        if let cd = auth["channel_data"] as? String { sub["channel_data"] = cd }
        send(["event": "pusher:subscribe", "data": sub])
    }

    private func send(_ obj: [String: Any]) {
        guard let task, let d = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: d, encoding: .utf8) else { return }
        task.send(.string(s)) { _ in }
    }

    private func dropped() {
        task = nil
        pinger?.cancel()
        members = []
        onState?(false)
        guard !stopped else { return }
        retry += 1
        let wait = min(30.0, pow(2.0, Double(min(retry, 5))))
        reconnect = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            self?.open()
        }
    }
}
