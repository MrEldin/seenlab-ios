//
//  SeoAiView.swift
//  seenlab
//
//  AI readiness (web: ReadinessPanel + IndexingPanel): which crawlers robots.txt lets in, llms.txt and its
//  draft, schema.org types, pages that are empty without JavaScript, then IndexNow / Bing and the latest
//  schema markup draft. Read-only: verifying, sending pages and writing drafts happen on the web.
//

import SwiftUI

struct SeoAiView: View {
    let report: SeoAuditReport?
    let llms: Job<SeoLlmsDraft>?
    let extras: SeoSlot<SeoAiExtras>
    let retry: () -> Void

    var body: some View {
        if let ai = report?.ai {
            bots(ai.bots ?? [])
            llmsCard(ai)
            schemaCard(ai)
        } else {
            EmptyCard(icon: "testtube.2", title: t("seo.ai.needAudit"))
        }
        SeoSlotView(slot: extras, retry: retry) { x in
            SeoIndexNowCard(info: x?.indexNow, bing: x?.bing)
            if let blocks = x?.schema?.blocks, !blocks.isEmpty { SeoSchemaCard(blocks: blocks) }
        }
        SeoWebOnly()
    }

    // MARK: - Crawlers

    private func bots(_ bots: [SeoAiReport.Bot]) -> some View {
        SeoSection(title: t("seo.ai.botsTitle"), subtitle: t("seo.ai.botsSub"), kb: "ai-readiness") {
            SeoRows(items: bots) { b in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(b.bot).font(.system(size: 12.5, design: .monospaced)).foregroundStyle(Color.slInk)
                        (Text(b.owner ?? "").foregroundStyle(Color.slInkSoft) + Text(b.kind.map { " · " + t("seo.ai.kind." + $0) } ?? "").foregroundStyle(Color.slInkFaint))
                            .font(.dm(12)).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    let allowed = b.allowed == true
                    Chip(text: allowed ? t("seo.ai.allowed") : t("seo.ai.blocked"), tone: allowed ? .good : b.kind == "training" ? .warn : .bad)
                }
            }
            SeoNote(text: t("seo.ai.trainingNote"), paper: true)
        }
    }

    // MARK: - llms.txt

    private func llmsCard(_ ai: SeoAiReport) -> some View {
        let found = ai.llmsTxt?.found == true
        let draft = llms?.isDone == true ? llms?.result : nil
        return SLCard {
            HStack(alignment: .center, spacing: 8) {
                Text(t("seo.ai.llmsTitle")).font(.dm(16, .semibold)).foregroundStyle(Color.slInk)
                Chip(text: found ? t("seo.ai.llmsFound") : t("seo.ai.llmsMissing"), tone: found ? .good : .warn)
            }
            Text(t("seo.ai.llmsSub")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).lineSpacing(2).fixedSize(horizontal: false, vertical: true).padding(.top, 4)
            if llms?.isRunning == true {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(Color.slAccent600)
                    Text(t("seo.ai.llmsDrafting")).font(.dm(12, .semibold)).foregroundStyle(Color.slAccent800)
                }
                .padding(.top, 10)
            }
            if let text = draft?.llmsTxt, !text.isEmpty {
                DraftBox(title: t("seo.ai.llmsReady"), text: text, mono: true).padding(.top, 12)
                if let notes = draft?.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("seo.ai.notes")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
                        ForEach(notes, id: \.self) { n in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").foregroundStyle(Color.slInkFaint)
                                Text(n).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
                            }
                            .font(.dm(12))
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    // MARK: - Schema types and JS

    private func schemaCard(_ ai: SeoAiReport) -> some View {
        let types = ai.schemaTypes
        let js = ai.jsOnlyPages ?? 0
        return SLCard {
            CardTitle(title: t("seo.ai.schemaTitle"), subtitle: t("seo.ai.schemaSub"))
            if types.isEmpty {
                Text(t("seo.ai.schemaNone")).font(.dm(12.5)).foregroundStyle(Color.slWarn).fixedSize(horizontal: false, vertical: true).padding(.top, 10)
            } else {
                SeoFlow(spacing: 6) {
                    ForEach(types, id: \.type) { s in
                        (Text(s.type).foregroundStyle(Color.slAccent800) + Text("  × \(s.count)").foregroundStyle(Color.slAccent700.opacity(0.7)))
                            .font(.dm(12, .medium)).monospacedDigit()
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.slTint100, in: Capsule())
                    }
                }
                .padding(.top, 10)
            }
            Text(t("seo.ai.jsTitle")).font(.dm(16, .semibold)).foregroundStyle(Color.slInk).padding(.top, 20)
            Text(js > 0 ? t("seo.ai.jsBad", ["n": js], count: js) : t("seo.ai.jsOk"))
                .font(.dm(12.5, js > 0 ? .semibold : .regular)).foregroundStyle(js > 0 ? Color.slBad : Color.slGood)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 4)
        }
    }
}

// MARK: - IndexNow and Bing

private struct SeoIndexNowCard: View {
    let info: SeoIndexNow?
    let bing: SeoBing?

    private var host: String { URL(string: info?.keyUrl ?? "")?.host ?? "" }

    var body: some View {
        SeoSection(title: t("seo.indexnow.title"), subtitle: t("seo.indexnow.subtitle"), kb: "bing") {
            if let info, let key = info.key {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("1").font(.dm(12, .semibold)).foregroundStyle(Color.slAccent800)
                            .frame(width: 24, height: 24).background(Color.slTint100, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("seo.indexnow.step1")).font(.dm(13)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                Text(key + ".txt").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.slInk).lineLimit(1).truncationMode(.middle)
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color.slBg, in: RoundedRectangle(cornerRadius: 8))
                                CopyButton(text: key, label: t("seo.indexnow.copyKey"))
                            }
                            if let url = info.keyUrl {
                                Text(t("seo.indexnow.fileHint", ["url": url])).font(.dm(11)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                            }
                            if let at = info.submittedAt {
                                Text(t("seo.indexnow.last", ["time": Fmt.relative(at)])).font(.dm(11.5, .medium)).foregroundStyle(Color.slInkSoft)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        RowDivider().padding(.bottom, 10)
                        Text(t("seo.indexnow.bing")).font(.dm(13.5, .semibold)).foregroundStyle(Color.slInk)
                        if bing?.configured == true {
                            Text(t("seo.indexnow.bingIndexed", ["n": Fmt.int(bing?.indexed)])).font(.dm(13)).foregroundStyle(Color.slInkSoft)
                        } else if !host.isEmpty, let url = URL(string: "https://www.bing.com/search?q=site%3A" + host) {
                            HStack(spacing: 4) {
                                Text(t("seo.indexnow.bingManual")).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                                Link(destination: url) { Text("site:\(host) ↗").font(.dm(12, .semibold)).foregroundStyle(Color.slAccent700) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 18).padding(.bottom, 18)
            } else {
                SeoNote(text: t("ios.nothing"))
            }
        }
    }
}

// MARK: - Schema markup draft

private struct SeoSchemaCard: View {
    let blocks: [SeoSchemaDraft.Block]

    var body: some View {
        SeoSection(title: t("seo.schema.title"), subtitle: t("seo.schema.subtitle"), kb: "schema") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                    VStack(alignment: .leading, spacing: 6) {
                        if let why = b.why, !why.isEmpty { Text(why).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true) }
                        DraftBox(title: [b.type, b.where].compactMap { $0 }.joined(separator: " · "), text: b.code ?? "", mono: true)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 18)
        }
    }
}
