//
//  SeoLabView.swift
//  seenlab
//
//  The lab (web: LabPanel), on Search Console data: pages seen but not clicked, searches almost on page 1,
//  pages losing clicks, and page experiments with clicks, CTR and position before and after.
//

import SwiftUI

struct SeoLabView: View {
    let lab: SeoLabReport?
    let go: (String) -> Void

    var body: some View {
        if let lab, lab.connected != true { needsGsc }
        if let lab, lab.connected == true {
            lowCtr(lab.lowCtr ?? [])
            striking(lab.striking ?? [])
            decaying(lab.decaying ?? [])
        }
        experiments(lab?.experiments ?? [])
        SeoWebOnly()
    }

    private var needsGsc: some View {
        SLCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 28, weight: .light)).foregroundStyle(Color.slAccent600)
                Text(t("seo.lab.needsGsc")).font(.dm(16, .semibold)).foregroundStyle(Color.slInk)
                Text(t("seo.lab.needsGscSub")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                Button { go("console") } label: { Text(t("seo.lab.connect")) }
                    .buttonStyle(SLButtonStyle(kind: .primary)).padding(.top, 6)
            }
        }
    }

    // MARK: - Seen but not clicked

    private func lowCtr(_ rows: [SeoLabReport.LowCtr]) -> some View {
        SeoSection(title: t("seo.lab.ctrTitle"), subtitle: t("seo.lab.ctrSub"), kb: "ctr") {
            if rows.isEmpty {
                SeoNote(text: t("seo.lab.ctrEmpty"))
            } else {
                SeoRows(items: rows) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        SeoLinkText(url: p.url, text: SeoFmt.path(p.url), color: .slInk, weight: .semibold)
                        Text(t("seo.lab.ctrLine", ["imp": Fmt.int(p.impressions), "pos": Fmt.num(p.position), "ctr": Fmt.num(p.ctr, digits: 2), "exp": Fmt.num(p.expectedCtr, digits: 2)]))
                            .font(.dm(12)).foregroundStyle(Color.slInkMuted).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                        Chip(text: t("seo.lab.gain", ["n": Fmt.int(p.gain)]), tone: .good)
                    }
                }
            }
        }
    }

    // MARK: - Almost on page 1

    private func striking(_ rows: [SeoLabReport.Striking]) -> some View {
        SeoSection(title: t("seo.lab.strikingTitle"), subtitle: t("seo.lab.strikingSub"), kb: "striking") {
            if rows.isEmpty {
                SeoNote(text: t("seo.lab.strikingEmpty"))
            } else {
                SeoRows(items: rows) { q in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(q.query ?? "").font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                            Text(Fmt.pos(q.position) + " · " + Fmt.int(q.impressions) + " " + t("seo.lab.impr") + " · " + SeoFmt.path(q.url))
                                .font(.dm(11.5)).foregroundStyle(Color.slInkMuted).monospacedDigit().lineLimit(1).truncationMode(.middle)
                        }
                        Spacer(minLength: 6)
                        Text("+" + Fmt.int(q.gain)).font(.dm(12, .semibold)).foregroundStyle(Color.slGood).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Losing clicks

    private func decaying(_ rows: [SeoLabReport.Decaying]) -> some View {
        SeoSection(title: t("seo.lab.decayTitle"), subtitle: t("seo.lab.decaySub"), kb: "decay") {
            if rows.isEmpty {
                SeoNote(text: t("seo.lab.decayEmpty"))
            } else {
                SeoRows(items: rows) { d in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            SeoLinkText(url: d.url, text: SeoFmt.path(d.url), color: .slInk, weight: .medium)
                            Text(t("seo.lab.decayLine", ["from": Fmt.int(d.prevClicks), "to": Fmt.int(d.clicks),
                                                         "p1": d.prevPosition.map { Fmt.num($0) } ?? "—", "p2": d.position.map { Fmt.num($0) } ?? "—"]))
                                .font(.dm(11.5)).foregroundStyle(Color.slInkMuted).monospacedDigit()
                        }
                        Spacer(minLength: 6)
                        Text(Fmt.int(d.change) + "%").font(.dm(12, .semibold)).foregroundStyle(Color.slBad).monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Experiments

    private func experiments(_ rows: [SeoLabReport.Experiment]) -> some View {
        SeoSection(title: t("seo.lab.expTitle"), subtitle: t("seo.lab.expSub"), kb: "experiments") {
            if rows.isEmpty {
                SeoNote(text: t("ios.nothing"))
            } else {
                SeoRows(items: rows) { e in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.note ?? "").font(.dm(14, .medium)).foregroundStyle(Color.slInk)
                            Text((e.startedOn.map { Fmt.short($0) } ?? "") + " · " + SeoFmt.path(e.url))
                                .font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1).truncationMode(.middle)
                        }
                        if e.ready == true, let b = e.before, let a = e.after {
                            HStack(spacing: 0) {
                                compare(t("seo.lab.clicksDay"), Fmt.num(b.clicksPerDay), Fmt.num(a.clicksPerDay), better: (a.clicksPerDay ?? 0) > (b.clicksPerDay ?? 0))
                                compare("CTR", Fmt.pct(b.ctr, digits: 2), Fmt.pct(a.ctr, digits: 2), better: (a.ctr ?? 0) > (b.ctr ?? 0))
                                compare(t("seo.rank.col.position"), Fmt.pos(b.position), Fmt.pos(a.position), better: (a.position ?? 99) < (b.position ?? 99))
                            }
                            .padding(10)
                            .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            Text(t("seo.lab.measuring", ["days": e.after?.days ?? 0])).font(.dm(12)).foregroundStyle(Color.slInkMuted)
                        }
                    }
                }
            }
        }
    }

    private func compare(_ label: String, _ before: String, _ after: String, better: Bool) -> some View {
        SeoMini(label: label,
                value: Text(before + " → ").foregroundStyle(Color.slInkSoft) + Text(after).fontWeight(.bold).foregroundStyle(better ? Color.slGood : Color.slBad),
                alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
