//
//  AioSetupView.swift
//  seenlab
//
//  Names & assistants tab (web: SetupPanel.vue), read-only: the names an answer is matched on, the product
//  facts answers are checked against, the website, and which assistants are connected.
//

import SwiftUI

struct AioSetupView: View {
    let data: AioOverview
    @Environment(\.channel) private var channel

    private var aliases: [String] { data.aliases ?? [] }
    private var autoNames: [String] {
        (data.names ?? []).filter { n in !aliases.contains { $0.lowercased() == n.lowercased() } }
    }

    var body: some View {
        SLCard {
            CardTitle(title: t("aio.setup.names"), subtitle: t("aio.setup.namesSub"), kb: { channel.kb("setup") })
            AioFlow(spacing: 6) {
                ForEach(autoNames, id: \.self) { n in
                    (Text(n).foregroundStyle(Color.slInkSoft) + Text(" · " + t("aio.setup.auto")).font(.dm(10)).foregroundStyle(Color.slInkFaint))
                        .font(.dm(12))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.slBg, in: Capsule())
                        .overlay(Capsule().stroke(Color.slLine, lineWidth: 1))
                }
                ForEach(aliases, id: \.self) { a in
                    Text(a).font(.dm(12, .medium)).foregroundStyle(Color.slAccent800)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.slTint100, in: Capsule())
                }
            }
            .padding(.top, 14)

            RowDivider().padding(.vertical, 16)

            Text(t("aio.setup.facts")).font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
            Text(t("aio.setup.factsSub")).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true).padding(.top, 3)
            if let facts = data.facts, !facts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DraftBox(text: facts).padding(.top, 10)
            } else {
                Text(t("aio.setup.noWebsite")).font(.dm(13, .medium)).foregroundStyle(Color.slInkFaint).padding(.top, 8)
            }

            RowDivider().padding(.vertical, 16)

            Text(t("aio.setup.website")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
            Text(data.websiteUrl.flatMap { $0.isEmpty ? nil : $0 } ?? t("aio.setup.noWebsite"))
                .font(.dm(14, .medium)).foregroundStyle(Color.slInk).textSelection(.enabled).padding(.top, 3)
            (Text(t("aio.setup.websiteSub") + " ").foregroundStyle(Color.slInkMuted) + Text("SEO →").foregroundStyle(Color.slAccent700).fontWeight(.semibold))
                .font(.dm(12))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 3)
                .onTapGesture { channel.open(.seo) }
        }

        SLCard {
            CardTitle(title: t("aio.engines.title"), subtitle: t("aio.setup.enginesSub"), kb: { channel.kb("engines") })
            RowList(items: data.engines ?? []) { e in
                let on = e.enabled == true
                HStack(spacing: 12) {
                    AioEngineMark(engine: e.key, label: e.name, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        (Text(e.name).font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
                         + Text(e.model.map { "  " + $0 } ?? "").font(.dm(12)).foregroundStyle(Color.slInkMuted))
                            .lineLimit(1)
                        Text(on ? (e.web == true ? t("aio.engines.web") : t("aio.engines.noWeb")) : t("aio.engines.offHint"))
                            .font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    if on {
                        Circle().fill(Color.slGood).frame(width: 8, height: 8)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(Color.slGoodSoft, in: Capsule())
                    } else {
                        Chip(text: t("aio.engines.off"))
                    }
                }
                .padding(.vertical, 11)
                .opacity(on ? 1 : 0.6)
            }
            .padding(.top, 8)
        }
        AioWebNote()
    }
}
