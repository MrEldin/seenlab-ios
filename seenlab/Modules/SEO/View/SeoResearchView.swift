//
//  SeoResearchView.swift
//  seenlab
//
//  Research (web: ResearchPanel): the latest keyword ideas and the latest AI content plan, read-only.
//  New research is started on the web.
//

import SwiftUI

struct SeoResearchView: View {
    let research: SeoResearch?

    private var ideas: SeoIdeas? { research?.ideas?.result }
    private var brief: SeoBrief? { research?.brief?.result }

    var body: some View {
        ideasCard
        briefCard
        SeoWebOnly()
    }

    // MARK: - Keyword ideas

    private var ideasCard: some View {
        SeoSection(title: t("seo.ideas.title"), subtitle: t("seo.ideas.subtitle"), kb: "research") {
            if research?.ideas?.running != nil { running(t("seo.ideas.running")) }
        } content: {
            if let ideas, let list = ideas.ideas, !list.isEmpty {
                SeoNote(text: t("seo.ideas.for", ["seed": ideas.seed ?? "", "country": (ideas.country ?? "").uppercased()]) + " · "
                        + (ideas.source == "dataforseo" ? t("seo.ideas.sourceData") : t("seo.ideas.sourceAuto")), paper: true)
                SeoRows(items: list) { i in ideaRow(i) }
            } else {
                SeoNote(text: t("ios.nothing"))
            }
        }
    }

    private func ideaRow(_ i: SeoIdeas.Idea) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(i.term).font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                Spacer(minLength: 6)
                if i.tracked == true { Chip(text: t("seo.ideas.tracked")) }
            }
            HStack(alignment: .top, spacing: 16) {
                SeoMini(label: t("seo.ideas.col.volume"), value: Text(i.volume.map { Fmt.int($0) } ?? "—").foregroundStyle(Color.slInk), alignment: .leading)
                SeoMini(label: t("seo.ideas.col.difficulty"), value: difficulty(i.difficulty), alignment: .leading)
                SeoMini(label: t("seo.ideas.col.cpc"), value: Text(i.cpc.map { "$" + Fmt.num($0, digits: 2) } ?? "—").foregroundStyle(Color.slInk), alignment: .leading)
                if let g = i.gsc {
                    SeoMini(label: t("seo.ideas.col.yours"),
                            value: Text(t("seo.ideas.gsc", ["imp": SeoFmt.num(g.impressions), "pos": g.position.map { Fmt.num($0) } ?? "—"])).foregroundStyle(Color.slInkMuted),
                            alignment: .leading)
                }
            }
        }
    }

    private func difficulty(_ d: Double?) -> Text {
        guard let d else { return Text("—").foregroundStyle(Color.slInkFaint) }
        return Text(Fmt.int(d)).foregroundStyle(d >= 60 ? Color.slBad : d >= 30 ? Color.slWarn : Color.slGood)
    }

    // MARK: - Content plan

    private var briefCard: some View {
        SeoSection(eyebrow: t("seo.brief.eyebrow"), title: t("seo.brief.title"), subtitle: t("seo.brief.subtitle"), kb: "brief") {
            if research?.brief?.running != nil { running(t("seo.brief.running")) }
        } content: {
            if let brief, let b = brief.brief {
                VStack(spacing: 0) {
                    RowDivider()
                    SeoBriefBody(brief: brief, content: b).padding(18)
                }
            } else {
                SeoNote(text: t("ios.nothing"))
            }
        }
    }

    private func running(_ text: String) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini).tint(Color.slAccent600)
            Text(text).font(.dm(11.5, .semibold)).foregroundStyle(Color.slAccent800)
        }
    }
}

private struct SeoBriefBody: View {
    let brief: SeoBrief
    let content: SeoBrief.Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // keyword · own position · target length
            SeoFlow(spacing: 6) {
                Text(brief.keyword ?? "").font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
                Text("· " + (brief.ownPosition.map { t("seo.brief.ranksAt", ["n": Fmt.num($0)]) } ?? t("seo.brief.notRanking"))).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                if let w = content.words, !w.isNull, !w.display.isEmpty {
                    Text("· " + t("seo.brief.words", ["n": w.display])).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                }
            }

            if content.intent != nil || content.summary != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let intent = content.intent {
                        (Text(t("seo.brief.intent") + ": ").fontWeight(.semibold) + Text(intent)).font(.dm(14)).foregroundStyle(Color.slInk)
                    }
                    if let summary = content.summary { Text(summary).font(.dm(13.5)).foregroundStyle(Color.slInkSoft) }
                }
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if let missing = content.missing, !missing.isEmpty {
                block(t("seo.brief.missing")) {
                    SeoFlow(spacing: 6) { ForEach(missing, id: \.self) { Chip(text: $0, tone: .bad) } }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                counted(t("seo.brief.pageTitle"), content.title, max: 60, bold: true)
                counted(t("seo.brief.meta"), content.metaDescription, max: 155, bold: false)
            }
            .padding(14)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))

            if let intro = content.intro, !intro.isEmpty { DraftBox(title: t("seo.brief.intro"), text: intro) }

            if let outline = content.outline, !outline.isEmpty {
                block(t("seo.brief.outline")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(outline.enumerated()), id: \.offset) { _, o in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("H2 · " + (o.heading ?? "")).font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
                                ForEach(Array((o.points ?? []).enumerated()), id: \.offset) { _, p in bullet(p) }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                        }
                    }
                }
            }

            if let faq = content.faq, !faq.isEmpty {
                block(t("seo.brief.faq")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(faq.enumerated()), id: \.offset) { _, f in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.q ?? "").font(.dm(13.5, .semibold)).foregroundStyle(Color.slInk)
                                Text(f.a ?? "").font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let links = content.internalLinks, !links.isEmpty {
                block(t("seo.brief.links")) {
                    VStack(alignment: .leading, spacing: 3) { ForEach(Array(links.enumerated()), id: \.offset) { _, l in bullet(l) } }
                }
            }

            if let pages = brief.pages, !pages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    RowDivider()
                    Text(t("seo.brief.pages")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.top, 8)
                    ForEach(Array(pages.enumerated()), id: \.offset) { _, p in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(p.position ?? 0).").font(.dm(11)).foregroundStyle(Color.slInkFaint).monospacedDigit().frame(width: 22, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                SeoLinkText(url: p.url, text: p.title ?? p.domain ?? "")
                                Text(t("seo.brief.pageWords", ["n": Fmt.int(Double(p.words ?? 0))]) + " · " + t("seo.brief.pageHeadings", ["n": (p.headings ?? []).count]))
                                    .font(.dm(11)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private func block<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
            content()
        }
    }

    private func counted(_ label: String, _ text: String?, max: Int, bold: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
                Spacer()
                Text("\((text ?? "").count) / \(max)").font(.dm(11.5)).foregroundStyle((text ?? "").count > max ? Color.slBad : Color.slInkFaint).monospacedDigit()
            }
            HStack(alignment: .top) {
                Text(text ?? "—").font(.dm(bold ? 14 : 13, bold ? .semibold : .regular)).foregroundStyle(bold ? Color.slInk : Color.slInkSoft)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                if let text, !text.isEmpty { CopyButton(text: text) }
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("•").foregroundStyle(Color.slInkFaint)
            Text(text).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
        }
        .font(.dm(13))
    }
}
