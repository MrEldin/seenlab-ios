//
//  seenlabApp.swift
//  seenlab
//
//  Seenlab for iOS: the ASO, SEO and AIO reports of the web app, read-only, on the phone.
//

import SwiftUI

@main
struct seenlabApp: App {
    @StateObject private var auth: AuthStore
    @StateObject private var projects = ProjectStore()
    @StateObject private var l10n = L10n.shared

    init() {
        FontRegistrar.register()
        #if DEBUG
        // `-debugToken <jwt>` signs in without typing (screenshots, UI checks). Debug builds only.
        if let token = UserDefaults.standard.string(forKey: "debugToken") { KeyChainManager.shared.token = token }
        #endif
        _auth = StateObject(wrappedValue: AuthStore())
        #if DEBUG
        // `-apiBase http://localhost:86` on the scheme's launch arguments points the app at the local API.
        if let base = UserDefaults.standard.string(forKey: "apiBase") { print("API", base) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(projects)
                .environmentObject(l10n)
                .preferredColorScheme(.light)
                .tint(Color.slAccent600)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var projects: ProjectStore
    @EnvironmentObject private var l10n: L10n

    var body: some View {
        Group {
            if auth.isSignedIn { MainView() } else { LoginView() }
        }
        .id(l10n.locale)   // strings are read at render time; a new language redraws everything
        .onChange(of: auth.isSignedIn) { _, signedIn in if !signedIn { projects.reset() } }
    }
}
