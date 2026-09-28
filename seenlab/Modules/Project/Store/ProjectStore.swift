//
//  ProjectStore.swift
//  seenlab
//
//  The signed-in person's projects and the one being viewed (remembered like the web's `sl.project`).
//  Switching the project scopes every channel call to it.
//

import Foundation
import Combine

final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var loaded = false
    @Published var error: String?
    @Published var currentId: Int? {
        didSet {
            NetworkManager.shared.projectId = currentId
            if let currentId { UserDefaults.standard.set(currentId, forKey: "sl.project") }
            L10n.shared.platform = current?.platform == "android" ? "android" : "ios"
        }
    }

    var current: Project? { projects.first { $0.id == currentId } }

    func load() async {
        do {
            let list: [Project] = try await NetworkManager.shared.request(SeenlabAPI.projects) ?? []
            projects = list
            error = nil
            let saved = UserDefaults.standard.integer(forKey: "sl.project")
            let keep = list.contains { $0.id == currentId } ? currentId : nil
            currentId = keep ?? (list.contains { $0.id == saved } ? saved : list.first?.id)
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
        loaded = true
    }

    func select(_ id: Int) { currentId = id }

    func reset() { projects = []; loaded = false; currentId = nil }
}
