//
//  AuthStore.swift
//  seenlab
//
//  Signs in with email and password (POST /api/login → JWT), keeps the token in the keychain and ends
//  the session when the API says so (401, suspended account).
//

import Foundation
import Combine

final class AuthStore: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var user: User?
    @Published var busy = false
    @Published var error: String?

    init() {
        isSignedIn = KeyChainManager.shared.token != nil
        NetworkManager.shared.onSessionEnded = { [weak self] reason in
            Task { @MainActor in self?.endSession(reason == .suspended ? t("admin.login.suspended") : nil) }
        }
    }

    func login(email: String, password: String) async {
        busy = true; error = nil
        defer { busy = false }
        do {
            let res: LoginResponse = try await NetworkManager.shared.requestPlain(SeenlabAPI.login(email: email.trimmingCharacters(in: .whitespaces), password: password))
            KeyChainManager.shared.token = res.accessToken
            isSignedIn = true
            await loadUser()
        } catch let e as APIError {
            KeyChainManager.shared.token = nil
            switch e {
            case .wrongCredentials, .unauthorized: error = t("admin.login.wrongCredentials")
            case .validation: error = t("admin.login.invalidData")
            case .suspended: error = t("admin.login.suspended")
            case .offline: error = t("ios.offline")
            default: error = t("admin.login.loginFailed")
            }
        } catch {
            self.error = t("admin.login.loginFailed")
        }
    }

    func loadUser() async {
        guard let u: User = try? await NetworkManager.shared.request(SeenlabAPI.user) else { return }
        user = u
        L10n.shared.adoptAccountLocale(u.locale)
    }

    /// Saves the language on the account too, so the web and the morning emails follow it.
    func setLanguage(_ code: String) {
        L10n.shared.set(code)
        Task { _ = try? await NetworkManager.shared.request(SeenlabAPI.profile(locale: code), as: JSONValue.self) }
    }

    func logout() async {
        _ = try? await NetworkManager.shared.request(SeenlabAPI.logout, as: JSONValue.self)
        endSession(nil)
    }

    private func endSession(_ message: String?) {
        KeyChainManager.shared.token = nil
        user = nil
        isSignedIn = false
        error = message
    }
}

extension APIError: Equatable {
    static func == (a: APIError, b: APIError) -> Bool { a.localizedDescription == b.localizedDescription }
}
