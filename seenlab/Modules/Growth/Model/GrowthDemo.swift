//
//  GrowthDemo.swift
//  seenlab
//
//  The sample board a Free account sees (the web's demo.js): a fictional app, Habitly, in the visitor's language.
//  Built as the API's JSON so the board, the cards and the drawer show it exactly like a real one.
//

import Foundation

extension GrowthStore {
    func loadSample() {
        func n(_ id: String, _ channel: String, _ cost: Int, _ h: Int, _ week: Int, _ copy: [[String: String]] = []) -> [String: Any] {
            ["id": id, "channel": channel, "title": t("growth.demo.cards." + id), "why": t("growth.demo.why." + id), "steps": [], "copy": copy, "cost": cost, "effort_hours": h, "week": week, "expect": ""]
        }
        let plan: [String: Any] = [
            "stage": "new", "summary": t("growth.demo.summary"), "budget": 1000,
            "phases": [
                ["id": "fix", "kind": "fix", "title": t("growth.demo.phases.fix"), "note": t("growth.demo.notes.fix"), "nodes": [n("ratings", "fix_ratings", 0, 3, 1), n("listing", "fix_listing", 0, 4, 1)]],
                ["id": "free", "kind": "free", "title": t("growth.demo.phases.free"), "note": t("growth.demo.notes.free"), "nodes": [
                    n("ph", "product_hunt", 0, 6, 2, [["kind": "tagline", "label": "Tagline", "text": "Habits that stick, one streak at a time"]]),
                    n("hn", "show_hn", 0, 3, 2, [["kind": "title", "label": "Title", "text": "Show HN: Habitly – a habit tracker that never asks you to sign up"]]), n("alt", "alternativeto", 0, 1, 3)]],
                ["id": "paid", "kind": "paid", "title": t("growth.demo.phases.paid"), "note": t("growth.demo.notes.paid"), "nodes": [n("idm", "indie_dev_monday", 300, 1, 5), n("asa", "apple_search_ads", 350, 2, 6)]],
                ["id": "scale", "kind": "scale", "title": t("growth.demo.phases.scale"), "note": "", "nodes": [n("creator", "niche_creator", 800, 4, 9)]],
            ],
            "suggestions": [], "conditions": [],
        ]
        let channels: [[String: Any]] = [("fix_ratings", "Ratings", "fix"), ("fix_listing", "Store listing", "fix"), ("product_hunt", "Product Hunt", "launch"), ("show_hn", "Show HN", "launch"),
                                         ("alternativeto", "AlternativeTo", "directory"), ("indie_dev_monday", "Indie Dev Monday", "newsletter"), ("apple_search_ads", "Apple Search Ads", "ads"), ("niche_creator", "Niche creator", "creator")]
            .map { ["id": $0.0, "name": $0.1, "kind": $0.2, "cost": [0, 0], "effort_hours": 1, "how": ""] }
        let json: [String: Any] = [
            "plan": plan, "directory": channels, "maps": [], "evidence": [:], "inbox": [], "rivals": [], "experiments": [:],
            "state": ["steps": ["ratings": ["status": "done"], "listing": ["status": "done"], "ph": ["status": "done", "visitors": 1240, "signups": 86], "hn": ["status": "doing"]], "rev": 0, "comments": [], "budget": 1000],
            "results": ["ph": ["at": "2026-09-15", "d7": ["days": 7, "elapsed": 7, "complete": true, "clicks": [4.4, 21.7], "ratings": [34, 61], "ai": [11, 19]]],
                        "ratings": ["at": "2026-09-02", "d7": ["days": 7, "elapsed": 7, "complete": true, "ratings": [12, 34]]]],
        ]
        if let data = try? JSONSerialization.data(withJSONObject: json), let d = try? JSONDecoder().decode(GrowthData.self, from: data) { setSample(d) }
    }
}
