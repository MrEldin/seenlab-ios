//
//  AsoAiTab.swift
//  seenlab
//
//  AI predlog, as the web's AsoAi: the latest listing proposal for this storefront — the strategy, each
//  proposed field against what is live (length, words entering and leaving the index, the reasoning,
//  copy), alternatives, quick wins, keywords to track or drop, description tips and extra localizations.
//  Generating a new proposal happens on the web.
//

import SwiftUI

struct AsoAiTab: View {
    @EnvironmentObject private var store: AsoStore
    @Environment(\.channel) private var channel

    var body: some View {
        if let job = store.suggestion, job.isRunning {
            SLCard {
                HStack(spacing: 14) {
                    ProgressView().tint(Color.slAccent600)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t("aso.ai.runningTitle")).font(.dm(15, .semibold)).foregroundStyle(Color.slInk)
                        Text(t("aso.ai.thinkingHint")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else if let job = store.suggestion, job.isDone, let result = job.result, let sug = result.suggestion {
            proposal(result, sug)
            legend
            if !sug.quickWins.isEmpty { quickWins(sug.quickWins) }
            if !sug.keywordsToAdd.isEmpty { terms(t("aso.ai.keywordsToAdd"), t("aso.ai.keywordsToAddHint"), sug.keywordsToAdd) }
            terms(t("aso.ai.keywordsToDrop"), t("aso.ai.keywordsToDropHint"), sug.keywordsToDrop)
            if !sug.descriptionTips.isEmpty { tips(sug.descriptionTips, android: isAndroid(result)) }
            if !sug.secondaryLocalizations.isEmpty { localizations(sug.secondaryLocalizations) }
        } else {
            EmptyCard(icon: "wand.and.stars", title: t("aso.ai.title"), text: store.suggestion?.error ?? t("ios.aso.aiEmpty"))
        }
        AsoWebOnlyNote()
    }

    private func isAndroid(_ r: AsoSuggestionResult) -> Bool { (r.platform ?? store.audit?.platform ?? store.overview?.platform) == "android" }

    // MARK: Proposal

    private func proposal(_ r: AsoSuggestionResult, _ s: AsoSuggestion) -> some View {
        let android = isAndroid(r)
        let own = store.overview?.own
        return SLCard {
            CardTitle(eyebrow: t("aso.tabs.ai"), title: t("aso.ai.proposalTitle"),
                      subtitle: t("aso.ai.proposalSubtitle", ["time": Fmt.relative(r.generatedAt), "model": r.ai?.model ?? "—", "tokens": Fmt.int(r.ai?.usage?.totalTokens ?? 0)]),
                      kb: { channel.kb("ai-proposal") })
            VStack(alignment: .leading, spacing: 12) {
                if let summary = s.summary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(t("aso.ai.strategy").uppercased(), systemImage: "arrow.triangle.branch")
                            .font(.dm(11, .semibold)).tracking(0.6).foregroundStyle(Color.slAccent800)
                        Text(summary).font(.dm(14)).foregroundStyle(Color.slInk).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                AsoProposalField(label: t("aso.audit.fieldTitle"), item: s.title, current: own?.name, defaultMax: 30)
                AsoProposalField(label: android ? t("aso.audit.fieldShortDescription") : t("aso.audit.fieldSubtitle"), item: s.subtitle, current: own?.subtitle, defaultMax: android ? 80 : 30)
                if !android {
                    AsoProposalField(label: t("aso.audit.fieldKeywords"), item: s.keywordField, current: store.audit?.fields?.keywordField?.text, defaultMax: 100, mono: true)
                }
                if android, let d = s.description, let text = d.text, !text.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(t("aso.ai.descriptionProposal")).font(.dm(12.5, .medium)).foregroundStyle(Color.slInk)
                            Spacer()
                            Text("\(d.length ?? text.count) / \(d.max ?? 4000)").font(.dm(12)).monospacedDigit()
                                .foregroundStyle(d.ok == false ? Color.slBad : Color.slInkMuted)
                        }
                        DraftBox(text: text)
                        if let why = d.rationale, !why.isEmpty {
                            Text(why).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                }
                if !s.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        AsoSectionLabel(text: t("aso.ai.alternatives"))
                        Text(t("aso.ai.alternativesHint")).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(s.alternatives.enumerated()), id: \.offset) { _, alt in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(alt.title ?? "").font(.dm(14, .semibold)).foregroundStyle(Color.slInk)
                                    Text("\((alt.title ?? "").count)/30").font(.dm(11)).monospacedDigit().foregroundStyle(Color.slInkMuted)
                                    Spacer(minLength: 6)
                                    CopyButton(text: [alt.title, alt.subtitle].compactMap { $0 }.joined(separator: "\n"))
                                }
                                HStack(alignment: .firstTextBaseline) {
                                    Text(alt.subtitle ?? "").font(.dm(13.5)).foregroundStyle(Color.slInkSoft)
                                    Text("\((alt.subtitle ?? "").count)/\(android ? 80 : 30)").font(.dm(11)).monospacedDigit().foregroundStyle(Color.slInkMuted)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.top, 14)
        }
    }

    // MARK: Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsoSectionLabel(text: t("aso.ai.legendTitle"))
            HStack(alignment: .firstTextBaseline, spacing: 8) { AsoPositionPill(position: 12, size: 12); legendText(t("aso.ai.legendPosition")) }
            HStack(alignment: .firstTextBaseline, spacing: 8) { AsoScoreBadge(value: 84, kind: .traffic); legendText(t("aso.ai.legendTraffic")) }
            HStack(alignment: .firstTextBaseline, spacing: 8) { AsoScoreBadge(value: 23, kind: .difficulty); legendText(t("aso.ai.legendDifficulty")) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.slLine, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func legendText(_ s: String) -> some View {
        Text(s).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Lists

    private func quickWins(_ items: [String]) -> some View {
        SLCard {
            CardTitle(title: t("aso.ai.quickWins"), subtitle: t("aso.ai.quickWinsHint"))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, q in AsoNumbered(index: i + 1, text: q) }
            }
            .padding(.top, 14)
        }
    }

    private func terms(_ title: String, _ hint: String, _ items: [AsoSuggestion.Term]) -> some View {
        SLCard {
            CardTitle(title: title, subtitle: hint)
            if items.isEmpty {
                Text("—").font(.dm(12.5)).foregroundStyle(Color.slInkMuted).padding(.top, 10)
            } else {
                RowList(items: items) { AsoKeywordLine(term: $0.term, why: $0.why).padding(.vertical, 10) }.padding(.top, 6)
            }
        }
    }

    private func tips(_ items: [String], android: Bool) -> some View {
        SLCard {
            CardTitle(title: t("aso.ai.descriptionTips"), subtitle: android ? t("aso.ai.descriptionTipsHintAndroid") : t("aso.ai.descriptionTipsHint"))
            VStack(alignment: .leading, spacing: 8) { ForEach(Array(items.enumerated()), id: \.offset) { _, d in AsoBullet(text: d) } }
                .padding(.top, 12)
        }
    }

    private func localizations(_ items: [AsoSuggestion.Localization]) -> some View {
        SLCard {
            CardTitle(title: t("aso.ai.secondaryTitle"), subtitle: t("aso.ai.secondarySubtitle"))
            VStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, loc in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(loc.locale ?? "—").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Color.slAccent800, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Spacer()
                            Text("\((loc.keywordField ?? "").count) / 100").font(.dm(11)).monospacedDigit().foregroundStyle(Color.slInkMuted)
                        }
                        if let why = loc.why, !why.isEmpty {
                            Text(why).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                        }
                        if let sub = loc.subtitle, !sub.isEmpty {
                            (Text(sub).font(.dm(14, .semibold)).foregroundStyle(Color.slInk) + Text("  \(sub.count)/30").font(.dm(11)).foregroundStyle(Color.slInkMuted))
                        }
                        if let kf = loc.keywordField, !kf.isEmpty { DraftBox(text: kf, mono: true) }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
                }
            }
            .padding(.top, 14)
        }
    }
}

// MARK: - A proposed field

/// Proposed vs live: the character meter against the store limit, which words enter and leave the
/// index, the model's reasoning and a copy button.
struct AsoProposalField: View {
    let label: String
    let item: AsoSuggestion.Field?
    let current: String?
    let defaultMax: Int
    var mono = false

    var body: some View {
        let text = item?.text ?? ""
        let len = item?.length ?? text.count
        let max = item?.max ?? defaultMax
        let over = item?.ok == false || len > max
        let before = AsoProposalField.words(current)
        let after = AsoProposalField.words(text)
        let added = after.filter { !before.contains($0) }
        let removed = (current ?? "").isEmpty ? [] : before.filter { !after.contains($0) }

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label).font(.dm(12.5, .medium)).foregroundStyle(Color.slInk)
                Spacer()
                Text("\(len) / \(max)").font(.dm(12, over ? .semibold : .regular)).monospacedDigit().foregroundStyle(over ? Color.slBad : Color.slInkMuted)
            }
            HStack(alignment: .firstTextBaseline) {
                AsoSectionLabel(text: t("aso.ai.proposed"), color: .slAccent700)
                Spacer()
                if !text.isEmpty { CopyButton(text: text) }
            }
            .padding(.top, 12)
            Text(text.isEmpty ? "—" : text)
                .font(mono ? .system(size: 13.5, weight: .semibold, design: .monospaced) : .dm(16, .semibold))
                .foregroundStyle(Color.slAccent800)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            AsoMeterBar(fraction: Double(len) / Double(Swift.max(max, 1)), over: over, tint: Double(len) / Double(Swift.max(max, 1)) > 0.9 ? .slAccent700 : .slAccent400)
                .padding(.top, 8)
            Text(over ? t("aso.ai.charsOver", ["n": len - max]) : t("aso.ai.charsLeft", ["n": max - len]))
                .font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.top, 4)

            if let current, !current.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    AsoSectionLabel(text: t("aso.ai.now"))
                    Text(current).font(mono ? .system(size: 12, design: .monospaced) : .dm(12.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 12)
            }

            if !added.isEmpty || !removed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if !added.isEmpty {
                        AsoFlow(spacing: 4) {
                            Text(t("aso.ai.wordsAdded")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.trailing, 2)
                            ForEach(added, id: \.self) { AsoWordChip(text: $0, fg: .slGood, bg: .slGoodSoft) }
                        }
                    }
                    if !removed.isEmpty {
                        AsoFlow(spacing: 4) {
                            Text(t("aso.ai.wordsRemoved")).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).padding(.trailing, 2)
                            ForEach(removed, id: \.self) { AsoWordChip(text: $0, fg: .slBad, bg: .slBadSoft, strike: true) }
                        }
                    }
                }
                .padding(.top, 12)
            }

            if let why = item?.rationale, !why.isEmpty {
                RowDivider().padding(.top, 12)
                Text(why).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true).padding(.top, 10)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.slLine, lineWidth: 1))
    }

    /// The words a field puts in the index (the web's split on spaces and punctuation).
    static func words(_ text: String?) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",:;&/|()-–—."))
        var seen = Set<String>(), out: [String] = []
        for w in (text ?? "").lowercased().components(separatedBy: separators) where w.count > 1 && !seen.contains(w) {
            seen.insert(w); out.append(w)
        }
        return out
    }
}

/// A keyword the AI mentions, with our numbers when we already track it.
struct AsoKeywordLine: View {
    let term: String
    let why: String?
    @EnvironmentObject private var store: AsoStore

    var body: some View {
        let k = store.keywordsByTerm[term.lowercased()]
        VStack(alignment: .leading, spacing: 5) {
            AsoFlow(spacing: 6) {
                Text(term).font(.dm(14, .medium)).foregroundStyle(Color.slInk).padding(.trailing, 2)
                if let k {
                    AsoPositionPill(position: k.position)
                    AsoScoreBadge(value: k.traffic, kind: .traffic)
                    AsoScoreBadge(value: k.difficulty, kind: .difficulty)
                } else {
                    Text(t("aso.ai.notTracked")).font(.dm(10.5, .medium)).foregroundStyle(Color.slInkFaint)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.slTint50, in: Capsule())
                }
            }
            if let why, !why.isEmpty {
                Text(why).font(.dm(12.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
