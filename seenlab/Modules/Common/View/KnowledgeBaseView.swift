//
//  KnowledgeBaseView.swift
//  seenlab
//
//  The ASO, SEO and AIO knowledge bases — the web's chapters (Resources/KB/<channel>.<lang>.json, exported
//  from the client) with the same block types: p, h, list, steps, tip, warn, table, kpi. Read chapters are
//  remembered on this device.
//

import SwiftUI

struct KBChapter: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let minutes: Int?
    let blocks: [KBBlock]
}

struct KBBlock: Decodable, Hashable {
    let type: String
    let text: String?
    let items: [JSONValue]?
    let head: [String]?
    let rows: [[String]]?
}

enum KnowledgeBase {
    static func chapters(_ channel: String) -> [KBChapter] {
        for lang in [L10n.shared.locale, "en"] {
            if let url = Bundle.main.url(forResource: "\(channel).\(lang)", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let list = try? JSONDecoder().decode([KBChapter].self, from: data) { return list }
        }
        return []
    }

    static func title(_ channel: String) -> String {
        switch channel { case "seo": t("kb.seoTitle"); case "aio": t("kb.aioTitle"); default: t("aso.kb.title") }
    }
}

/// The sheet: chapter list, then a chapter. `start` opens a chapter directly (from "Kako ovo radi?").
struct KnowledgeBaseSheet: View {
    let channel: String
    var start: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var path: [KBChapter] = []
    @AppStorage("kb.read") private var readRaw = ""

    private var chapters: [KBChapter] { KnowledgeBase.chapters(channel) }
    private var read: Set<String> { Set(readRaw.split(separator: ",").map(String.init)) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let done = chapters.filter { read.contains(channel + ":" + $0.id) }.count
                    Text("\(done) / \(chapters.count) · " + t("ios.kb.done").lowercased()).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                    ProgressView(value: Double(done), total: Double(max(chapters.count, 1))).tint(Color.slAccent600).padding(.bottom, 6)
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { i, ch in
                        NavigationLink(value: ch) {
                            HStack(spacing: 12) {
                                let isRead = read.contains(channel + ":" + ch.id)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9).fill(isRead ? Color.slAccent600 : Color.slTint100).frame(width: 30, height: 30)
                                    if isRead { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) }
                                    else { Text("\(i + 1)").font(.dm(13, .semibold)).foregroundStyle(Color.slAccent800) }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ch.title).font(.dm(14.5, .medium)).foregroundStyle(Color.slInk).multilineTextAlignment(.leading)
                                    if let m = ch.minutes { Text(t("ios.kb.minutes", ["n": m])).font(.dm(11.5)).foregroundStyle(Color.slInkMuted) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.slInkFaint)
                            }
                            .padding(12)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.slBg)
            .navigationTitle(KnowledgeBase.title(channel))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(t("ios.close")) { dismiss() } } }
            .navigationDestination(for: KBChapter.self) { ch in
                KBChapterView(chapter: ch).onAppear { markRead(ch) }
            }
            .onAppear {
                if let start, path.isEmpty, let ch = chapters.first(where: { $0.id == start }) { path = [ch] }
            }
        }
    }

    private func markRead(_ ch: KBChapter) {
        var r = read; r.insert(channel + ":" + ch.id); readRaw = r.sorted().joined(separator: ",")
    }
}

struct KBChapterView: View {
    let chapter: KBChapter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let m = chapter.minutes { Text(t("ios.kb.minutes", ["n": m])).font(.dm(12)).foregroundStyle(Color.slInkMuted) }
                Text(chapter.title).font(.dm(26, .bold)).tracking(-0.5).foregroundStyle(Color.slInk)
                ForEach(Array(chapter.blocks.enumerated()), id: \.offset) { _, b in KBBlockView(block: b) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.slBg)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct KBBlockView: View {
    let block: KBBlock

    var body: some View {
        switch block.type {
        case "h":
            Text(block.text ?? "").font(.dm(18, .semibold)).foregroundStyle(Color.slInk).padding(.top, 6)
        case "list":
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, it in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(Color.slAccent500).frame(width: 6, height: 6).padding(.top, 7)
                        Text(it.string ?? "").font(.dm(15)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case "steps":
            VStack(spacing: 10) {
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { i, it in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)").font(.dm(13, .semibold)).foregroundStyle(.white).frame(width: 26, height: 26).background(Color.slAccent800, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(it["title"]?.string ?? "").font(.dm(15, .semibold)).foregroundStyle(Color.slInk)
                            Text(it["text"]?.string ?? "").font(.dm(14)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.slLine))
                }
            }
        case "tip", "warn":
            let warn = block.type == "warn"
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: warn ? "exclamationmark.triangle" : "lightbulb").foregroundStyle(warn ? Color.slWarn : Color.slAccent700)
                Text(block.text ?? "").font(.dm(14)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(warn ? Color.slWarnSoft : Color.slTint50, in: RoundedRectangle(cornerRadius: 14))
        case "kpi":
            VStack(spacing: 8) {
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, it in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(it["label"]?.string ?? "").font(.dm(14, .semibold)).foregroundStyle(Color.slAccent800)
                        Text(it["text"]?.string ?? "").font(.dm(14)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slLine))
                }
            }
        case "table":
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    GridRow { ForEach(block.head ?? [], id: \.self) { Text($0).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted) } }
                    ForEach(Array((block.rows ?? []).enumerated()), id: \.offset) { _, row in
                        Divider().gridCellColumns(max(1, block.head?.count ?? row.count))
                        GridRow { ForEach(Array(row.enumerated()), id: \.offset) { i, c in Text(c).font(.dm(13, i == 0 ? .semibold : .regular)).foregroundStyle(i == 0 ? Color.slInk : Color.slInkSoft).frame(maxWidth: 220, alignment: .leading) } }
                    }
                }
                .padding(14)
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.slLine))
        default:
            Text(block.text ?? "").font(.dm(15)).foregroundStyle(Color.slInkSoft).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
}
