//
//  AioPagesView.swift
//  seenlab
//
//  Pages for AI tab (web: PagesPanel.vue): the pages worth writing (vs the rivals the AI recommends,
//  alternatives, best-of), and the pages already written on the web — title, address, meta, the page
//  itself and its schema, ready to copy.
//

import SwiftUI

struct AioPagesView: View {
    let data: AioOverview
    let pages: [Job<AioPageResult>]
    @Environment(\.channel) private var channel
    @State private var selected: Int?

    private var ideas: [AioPageIdea] { data.pageIdeas ?? [] }
    private var current: Job<AioPageResult>? { pages.first { $0.id == selected } ?? pages.first }

    private func icon(_ kind: String?) -> String {
        switch kind { case "comparison": "scalemass"; case "alternatives": "shuffle"; default: "trophy" }
    }

    var body: some View {
        SLCard {
            CardTitle(eyebrow: t("aio.pages.eyebrow"), title: t("aio.pages.title"), subtitle: t("aio.pages.subtitle"), kb: { channel.kb("pages") })
            if !ideas.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(ideas.enumerated()), id: \.offset) { _, i in
                        HStack(spacing: 10) {
                            Image(systemName: icon(i.kind)).font(.system(size: 14)).foregroundStyle(Color.slAccent700).frame(width: 20)
                            Text(i.title ?? i.target ?? "").font(.dm(13.5, .medium)).foregroundStyle(Color.slInk).lineLimit(2)
                            Spacer(minLength: 6)
                            if let kind = i.kind { Text(t("aio.pages.kinds." + kind)).font(.dm(11)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                    }
                }
                .padding(.top, 14)
            }
        }

        if pages.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("aio.pages.earlier")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.horizontal, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pages, id: \.id) { job in
                            let on = job.id == current?.id
                            Button { withAnimation(.snappy(duration: 0.2)) { selected = job.id } } label: {
                                Text(job.result?.page?.title ?? job.input?["target"]?.string ?? "—")
                                    .font(.dm(12.5, on ? .semibold : .regular)).lineLimit(1)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .foregroundStyle(on ? Color.slInk : Color.slInkSoft)
                                    .background(on ? Color.slTint50 : Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? Color.slAccent600 : Color.slLine, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            }
        }

        if let page = current?.result?.page {
            SLCard(padding: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    if let slug = page.slug { Text("/" + slug).font(.system(size: 12, design: .monospaced)).foregroundStyle(Color.slInkMuted).textSelection(.enabled) }
                    Text(page.title ?? "").font(.dm(18, .semibold)).tracking(-0.3).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                    if let meta = page.metaDescription { Text(meta).font(.dm(13)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true).textSelection(.enabled) }
                    HStack(spacing: 8) {
                        if let md = page.markdown { CopyButton(text: md, label: t("aio.pages.copyPage")) }
                        if let schema = page.schemaCode, !schema.isEmpty { CopyButton(text: schema, label: t("aio.pages.copySchema")) }
                    }
                    .padding(.top, 6)
                }
                .padding(18)
                RowDivider()
                AioAnswerText(text: page.markdown ?? "", size: 14)
                    .padding(18)
                AioCardTip(text: t("aio.pages.tip"))
            }
        } else {
            AioWebNote()
        }
    }
}
