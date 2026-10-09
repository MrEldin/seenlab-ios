//
//  PushManager.swift
//  seenlab
//
//  Pushes (APNs): asks once for permission after signing in, hands the device token to the API (sandbox for debug
//  builds, production for TestFlight and the App Store), shows a push that arrives while the app is open, and opens
//  the place a tapped push points to. Signing out removes this phone from the account's devices.
//

import UIKit
import UserNotifications

@MainActor
final class PushManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushManager()
    private var token: String?

    func install() { UNUserNotificationCenter.current().delegate = self }

    /// After signing in: the system question once; afterwards just register again (tokens can change).
    func start() async {
        #if DEBUG
        // `-skipPushPrompt YES`: screenshots and UI checks without the system question
        if UserDefaults.standard.bool(forKey: "skipPushPrompt") { return }
        #endif
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        if [.authorized, .provisional, .ephemeral].contains(status) { UIApplication.shared.registerForRemoteNotifications() }
    }

    func status() async -> UNAuthorizationStatus { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }

    func registered(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        token = hex
        #if DEBUG
        let env = "sandbox"
        #else
        let env = "production"
        #endif
        Task { _ = try? await NetworkManager.shared.request(SeenlabAPI.addDevice(token: hex, env: env, label: UIDevice.current.model), as: JSONValue.self) }
    }

    /// Before the session ends (sign out): this phone stops getting the account's pushes.
    func signOut() async {
        guard let token else { return }
        _ = try? await NetworkManager.shared.request(SeenlabAPI.removeDevice(token: token), as: JSONValue.self)
        self.token = nil
    }

    // A push while the app is open: shown as a banner, and the bell's count catches up.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        await NoticeStore.shared.refreshCount()
        return [.banner, .sound, .list, .badge]
    }

    // A tapped push: to the place it points, and marked read.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let url = info["url"] as? String
        let project = info["project_id"] as? Int
        let board = info["board"] as? Int
        let id = info["id"] as? String
        await MainActor.run {
            NoticeStore.shared.route = NoticeTarget.from(url: url, projectId: project, board: board, card: nil)
            if let id { Task { _ = try? await NetworkManager.shared.request(SeenlabAPI.noticeRead(id), as: JSONValue.self); await NoticeStore.shared.refreshCount() } }
        }
    }
}

/// The app delegate: only for the APNs token.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MainActor.assumeIsolated { PushManager.shared.install() }
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MainActor.assumeIsolated { PushManager.shared.registered(deviceToken) }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("APNs registration failed: \(error.localizedDescription)")
        #endif
    }
}
