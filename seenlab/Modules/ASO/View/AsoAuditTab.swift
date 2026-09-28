//
//  AsoAuditTab.swift
//  seenlab
//
//  Audit listinga, as the web's AsoAudit: the listing score with its issues, the fields the store indexes
//  (length against the limit), the indexed words, keyword coverage, duplicates and unused words.
//  Google Play has no keyword field; its full description is indexed instead.
//

import SwiftUI

struct AsoAuditTab: View {
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel

    var body: some View {
        if let a = store.audit {
            score(a)
            fields(a)
            coverage(a)
            duplicates(a)
            unused(a)
        } else {
            EmptyCard(icon: "checklist", title: t("aso.overview.noOwnTitle"), text: t("aso.overview.noOwnHint"))
        }
        AsoWebOnlyNote()
    }

    // MARK: Score

    private func score(_ a: AsoAudit) -> some View {
        SLCard {
            CardTitle(title: t("aso.audit.scoreTitle"), subtitle: t("aso.audit.scoreSubtitle"), kb: { channel.kb("audit") })
            HStack(alignment: .center, spacing: 18) {
                ScoreRing(score: a.score, size: 96, label: "/ 100")
                VStack(alignment: .leading, spacing: 8) {
                    let issues = a.issues ?? []
                    if issues.isEmpty {
                        Label(t("aso.audit.noIssues"), systemImage: "checkmark.circle.fill").font(.dm(12.5)).foregroundStyle(Color.slGood)
                    }
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, i in
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: i.level == "error" ? "exclamationmark.octagon.fill" : i.level == "warn" ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(i.level == "error" ? Color.slBad : i.level == "warn" ? Color.slWarn : Color.slInkMuted)
                                .padding(.top, 1)
                            Text(t("aso.audit.issues.\(i.key)", ["count": i.count ?? 0], count: i.count))
                                .font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 16)
        }
    }

    // MARK: Fields

    private func fields(_ a: AsoAudit) -> some View {
        let f = a.fields
        return SLCard {
            CardTitle(title: t("aso.audit.fieldsTitle"), subtitle: a.isAndroid ? t("aso.audit.fieldsSubtitleAndroid") : t("aso.audit.fieldsSubtitle"), kb: { channel.kb("audit") })
            VStack(alignment: .leading, spacing: 16) {
                meter(t("aso.audit.fieldTitle"), f?.title, max: 30)
                meter(a.isAndroid ? t("aso.audit.fieldShortDescription") : t("aso.audit.fieldSubtitle"), f?.subtitle, max: a.isAndroid ? 80 : 30)
                if a.isAndroid {
                    VStack(alignment: .leading, spacing: 6) {
                        meter(t("aso.audit.fieldDescription"), f?.description, max: 4000, clamp: true)
                        Text(t("aso.audit.descriptionHint")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        meter(t("aso.audit.fieldKeywords"), f?.keywordField, max: 100, mono: true)
                        Text(t("aso.audit.keywordsHint")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                }
                let words = a.indexedWords ?? []
                VStack(alignment: .leading, spacing: 8) {
                    RowDivider()
                    Text(t("aso.audit.indexed", ["count": words.count], count: words.count)).font(.dm(11.5, .medium)).foregroundStyle(Color.slInkFaint)
                    AsoFlow(spacing: 5) { ForEach(words, id: \.self) { AsoWordChip(text: $0) } }
                }
            }
            .padding(.top, 16)
        }
    }

    private func meter(_ label: String, _ field: AsoAuditField?, max: Int, mono: Bool = false, clamp: Bool = false) -> some View {
        let text = field?.text ?? ""
        return AsoFieldMeter(label: label, text: text, length: field?.length ?? text.count, max: field?.max ?? max, mono: mono, clamp: clamp)
    }

    // MARK: Coverage

    private func coverage(_ a: AsoAudit) -> some View {
        let rows = (a.coverage ?? []).sorted { x, y in
            let cx = x.covered == true ? 1 : 0, cy = y.covered == true ? 1 : 0
            return cx != cy ? cx < cy : (x.traffic ?? 0) > (y.traffic ?? 0)
        }
        return SLCard(padding: 0) {
            CardTitle(title: t("aso.audit.coverageTitle"), subtitle: t("aso.audit.coverageSubtitle"), kb: { channel.kb("keyword-strategy") })
                .padding(18)
            if rows.isEmpty {
                AsoInlineEmpty(title: t("aso.kw.empty"), icon: "checklist").padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.term) { c in
                        RowDivider()
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(c.term).font(.dm(14, .medium)).foregroundStyle(Color.slInk).lineLimit(2)
                                Spacer(minLength: 8)
                                AsoPositionPill(position: c.position)
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                if c.covered == true {
                                    Label(t("aso.audit.covered"), systemImage: "checkmark.circle.fill").font(.dm(12)).foregroundStyle(Color.slGood)
                                } else {
                                    (Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(" " + t("aso.audit.missing") + ": ") + Text((c.missingWords ?? []).joined(separator: ", ")).font(.system(size: 12, design: .monospaced)))
                                        .font(.dm(12)).foregroundStyle(Color.slWarn).lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                AsoScoreBadge(value: c.traffic, kind: .traffic)
                                AsoScoreBadge(value: c.difficulty, kind: .difficulty)
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 11)
                    }
                }
            }
        }
    }

    // MARK: Duplicates / unused

    private func duplicates(_ a: AsoAudit) -> some View {
        SLCard {
            CardTitle(title: t("aso.audit.dupesTitle"), subtitle: t("aso.audit.dupesSubtitle"))
            Group {
                if let d = a.duplicates, !d.isEmpty {
                    AsoFlow(spacing: 6) {
                        ForEach(Array(d.enumerated()), id: \.offset) { _, x in
                            (Text(x.word ?? "").fontWeight(.semibold) + Text(" · " + (x.where ?? "")))
                                .font(.dm(12)).foregroundStyle(Color.slWarn)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.slWarnSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                } else {
                    Label(t("aso.audit.noDupes"), systemImage: "checkmark.circle.fill").font(.dm(12.5)).foregroundStyle(Color.slGood)
                }
            }
            .padding(.top, 12)
        }
    }

    private func unused(_ a: AsoAudit) -> some View {
        SLCard {
            CardTitle(title: t("aso.audit.unusedTitle"), subtitle: t("aso.audit.unusedSubtitle"))
            Group {
                if let w = a.unusedFieldWords, !w.isEmpty {
                    AsoFlow(spacing: 6) { ForEach(w, id: \.self) { AsoWordChip(text: $0, fg: .slInkSoft, bg: .slTint50, mono: true) } }
                } else {
                    Text(t("aso.audit.noUnused")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted)
                }
            }
            .padding(.top, 12)
        }
    }
}
