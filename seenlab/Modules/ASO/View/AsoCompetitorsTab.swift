//
//  AsoCompetitorsTab.swift
//  seenlab
//
//  Konkurenti, as the web's tracked-apps table: each app with its rating, how many tracked keywords it
//  ranks for, top 10 count, average rank and its last listing change. Own app first, tinted.
//

import SwiftUI

struct AsoCompetitorsTab: View {
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel

    var body: some View {
        SLCard(padding: 0, span: .full) {
            CardTitle(title: t("aso.comp.listTitle"), subtitle: t("aso.comp.listSubtitle"), kb: { channel.kb("competitors") })
                .padding(18)
            if store.apps.isEmpty {
                AsoInlineEmpty(title: t("aso.comp.empty"), hint: t("aso.comp.emptyHint"), icon: "person.2").padding(.bottom, 10)
            } else {
                // one column on a phone, two on an iPad
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 0, alignment: .top)], spacing: 0) {
                    ForEach(store.apps) { app in
                        VStack(spacing: 0) { RowDivider(); AsoAppRow(app: app) }
                    }
                }
            }
        }
        AsoWebOnlyNote()
    }
}

/// One tracked app.
struct AsoAppRow: View {
    let app: AsoApp

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RemoteIcon(url: app.iconUrl, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name ?? "—").font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk).lineLimit(2)
                        if app.isOwn == true { AsoYouTag() }
                    }
                    Text(byline).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1)
                    Text((app.subtitle ?? "").isEmpty ? "—" : app.subtitle!)
                        .font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineLimit(2).padding(.top, 2)
                }
            }

            HStack(spacing: 0) {
                metric(t("aso.comp.colRatings"), value: "★ " + (app.rating.map { $0 > 0 ? Fmt.num($0, digits: 2) : "—" } ?? "—"), sub: Fmt.int(app.ratingCount ?? 0))
                metric(t("aso.comp.colRanked"), value: "\(app.keywordsRanked ?? 0)", sub: "/ \(app.keywordsTotal ?? 0)")
                metric(t("aso.comp.colTop10"), value: "\(app.top10 ?? 0)", accent: true)
                metric(t("aso.comp.colAvg"), value: app.avgPosition.map { "#" + Fmt.num($0, digits: 1) } ?? "—")
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t("aso.comp.colLastChange")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
                if let change = app.lastChange {
                    Text(AsoFmt.day(change.date) + " · " + (change.changes ?? []).map { AsoFmt.field($0.field) }.joined(separator: ", "))
                        .font(.dm(12)).foregroundStyle(Color.slInkSoft).lineLimit(2)
                } else {
                    Text("—").font(.dm(12)).foregroundStyle(Color.slInkFaint)
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(app.isOwn == true ? Color.slTint50.opacity(0.5) : Color.clear)
    }

    private var byline: String {
        [app.developer, app.version.map { "v" + $0.display }, app.versionReleasedAt.map { Fmt.relative($0) }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func metric(_ label: String, value: String, sub: String? = nil, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.dm(10.5)).foregroundStyle(Color.slInkMuted).lineLimit(1).minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.dm(14, .semibold)).foregroundStyle(accent ? Color.slAccent800 : Color.slInk).monospacedDigit().lineLimit(1)
                if let sub { Text(sub).font(.dm(10.5)).foregroundStyle(Color.slInkMuted).monospacedDigit().lineLimit(1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
