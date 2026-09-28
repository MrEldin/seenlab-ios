//
//  AioSourcesView.swift
//  seenlab
//
//  Sources tab (web: OutreachPanel.vue + SourcesPanel.vue): the pages the AI cites when it recommends
//  others ("where to be"), each with the latest pitch written on the web (email, reply, listing), and
//  every cited site with how often it was cited.
//

import SwiftUI

struct AioSourcesView: View {
    let data: AioOverview
    let drafts: [String: AioOutreachResult]
    @Environment(\.channel) private var channel

    private var outreach: [AioOutreach] { data.outreach ?? [] }
    private var sources: [AioSource] { data.sources ?? [] }
    private var hasWebEngine: Bool { data.enabledEngines.contains { $0.web == true } }

    var body: some View {
        SLCard(padding: 0) {
            AioCardHead(eyebrow: t("aio.outreach.eyebrow"), title: t("aio.outreach.title"), subtitle: t("aio.outreach.subtitle"), kb: { channel.kb("outreach") })
            RowDivider()
            if outreach.isEmpty {
                Text(hasWebEngine ? t("aio.outreach.empty") : t("aio.outreach.needsWeb"))
                    .font(.dm(13.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                    .padding(18)
            } else {
                RowList(items: outreach) { o in
                    AioOutreachRow(item: o, draft: o.urls?.first.flatMap { drafts[$0] }, label: data.label)
                }
            }
        }

        SLCard(padding: 0) {
            AioCardHead(title: t("aio.sources.title"), subtitle: t("aio.sources.subtitle"), kb: { channel.kb("engines") })
            RowDivider()
            if sources.isEmpty {
                VStack(spacing: 6) {
                    Text(t("aio.sources.empty")).font(.dm(15, .semibold)).foregroundStyle(Color.slInk)
                    Text(t("aio.sources.emptyHint")).font(.dm(13)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(24)
            } else {
                HStack {
                    Text(t("aio.sources.col.domain"))
                    Spacer()
                    Text(t("aio.sources.col.citations")).frame(width: 52, alignment: .trailing)
                    Text(t("aio.sources.col.prompts")).frame(width: 60, alignment: .trailing)
                }
                .font(.dm(11, .semibold)).foregroundStyle(Color.slInkMuted)
                .padding(.horizontal, 18).padding(.vertical, 9)
                .background(Color.slPaper)
                RowDivider()
                RowList(items: sources) { s in sourceRow(s) }
            }
            AioCardTip(text: t("aio.sources.tip"))
        }
    }

    private func sourceRow(_ s: AioSource) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let url = URL(string: "https://" + s.domain) {
                        Link(destination: url) { Text(s.domain).font(.dm(14, .medium)).foregroundStyle(Color.slInk).lineLimit(1) }
                    }
                    if s.own == true {
                        Text(t("aio.sources.yours")).font(.dm(10, .bold)).foregroundStyle(Color.slGood)
                            .padding(.horizontal, 6).padding(.vertical, 1).background(Color.slGoodSoft, in: Capsule())
                    }
                }
                AioEngineMarks(engines: s.engines ?? [], label: data.label, size: 18)
            }
            Spacer(minLength: 6)
            Text(AioFmt.n(s.citations)).frame(width: 52, alignment: .trailing)
            Text(AioFmt.n(s.prompts)).frame(width: 60, alignment: .trailing)
        }
        .font(.dm(13.5)).monospacedDigit().foregroundStyle(Color.slInk)
        .padding(.horizontal, 18).padding(.vertical, 11)
    }
}

private struct AioOutreachRow: View {
    let item: AioOutreach
    let draft: AioOutreachResult?
    let label: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        if let url = URL(string: "https://" + item.domain) {
                            Link(destination: url) { Text(item.domain).font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk).lineLimit(1) }
                        }
                        AioEngineMarks(engines: item.engines ?? [], label: label, size: 18)
                    }
                    if let rivals = item.rivals, !rivals.isEmpty {
                        Text(t("aio.outreach.recommends", ["rivals": rivals.joined(separator: ", ")]))
                            .font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    count(item.prompts, "aio.outreach.prompts", bold: true)
                    count(item.citations, "aio.outreach.citations", bold: false)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(item.urls ?? [], id: \.self) { u in
                    if let url = URL(string: u) {
                        Link(destination: url) {
                            Text(AioFmt.hostPath(u)).font(.dm(12)).foregroundStyle(Color.slAccent700).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
            }
            if let d = draft?.draft { pitch(d) }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private func count(_ n: Int?, _ key: String, bold: Bool) -> some View {
        let v = n ?? 0
        return (Text(AioFmt.n(v)).font(.dm(bold ? 14 : 12, .semibold)).foregroundStyle(Color.slInk)
                + Text(" " + t(key, count: v)).font(.dm(12)).foregroundStyle(Color.slInkMuted))
            .monospacedDigit()
    }

    /// The pitch written for this page on the web.
    private func pitch(_ d: AioOutreachResult.Draft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = d.summary, !summary.isEmpty {
                Text(summary).font(.dm(13)).foregroundStyle(Color.slInkSoft).fixedSize(horizontal: false, vertical: true)
            }
            if let steps = d.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\(i + 1).").font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                            Text(s).font(.dm(13)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let email = d.email, (email.subject ?? "").isEmpty == false || (email.body ?? "").isEmpty == false {
                box(title: t("aio.outreach.email"), copy: (email.subject ?? "") + "\n\n" + (email.body ?? "")) {
                    if let subject = email.subject { Text(subject).font(.dm(13.5, .semibold)).foregroundStyle(Color.slInk) }
                    if let body = email.body { Text(body).font(.dm(13)).foregroundStyle(Color.slInkSoft) }
                }
            }
            if let reply = d.reply, !reply.isEmpty {
                box(title: t("aio.outreach.reply"), copy: reply) { Text(reply).font(.dm(13)).foregroundStyle(Color.slInkSoft) }
            }
            if let listing = d.listing, !listing.isEmpty {
                box(title: t("aio.outreach.listing"), copy: listing) { Text(listing).font(.dm(13)).foregroundStyle(Color.slInkSoft) }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
        .padding(.top, 4)
    }

    private func box<C: View>(title: String, copy: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
                Spacer()
                CopyButton(text: copy)
            }
            VStack(alignment: .leading, spacing: 4) { content() }
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
