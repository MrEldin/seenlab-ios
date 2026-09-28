//
//  AioPromptSheet.swift
//  seenlab
//
//  What each assistant answered to one prompt (web: PromptModal.vue): pick the assistant, read the full
//  answer with the product's names on the marker, then the products named in order, the sources cited,
//  the claims about the product and 90 days of history.
//

import SwiftUI

struct AioPromptSheet: View {
    let prompt: AioPromptRow
    let engines: [AioEngine]
    let load: (Int) async throws -> AioPromptDetail?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: AioPromptDetail?
    @State private var error: String?
    @State private var tab: String?

    private func label(_ key: String) -> String { engines.first { $0.key == key }?.name ?? key }
    private var answers: [AioAnswer] { detail?.answers ?? [] }
    private var current: AioAnswer? { answers.first { $0.id == tab } }
    private func multi(_ engine: String) -> Bool { answers.filter { $0.engine == engine }.count > 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: t("aio.prompt.answers"))
                        Text("“" + (prompt.text ?? "") + "”").font(.dm(19, .semibold)).tracking(-0.3).foregroundStyle(Color.slInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 4)

                    if let detail {
                        if answers.isEmpty {
                            EmptyCard(icon: "hourglass", title: t("aio.prompt.noAnswer"))
                        } else {
                            picker
                            if let a = current { answerCard(a, names: detail.names ?? []) } else { EmptyCard(icon: "hourglass", title: t("aio.prompt.noAnswer")) }
                        }
                    } else if let error {
                        ErrorCard(message: error) { Task { await fetch() } }
                    } else {
                        LoadingCard()
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 32)
            }
            .background(Color.slBg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .semibold)) }
                        .accessibilityLabel(t("ios.close"))
                }
            }
            .toolbarBackground(Color.slBg, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(Color.slAccent600)
        .task { await fetch() }
    }

    private func fetch() async {
        error = nil
        do {
            let d = try await load(prompt.id)
            detail = d
            let first = (d?.answers ?? []).first { $0.mentioned == true } ?? d?.answers?.first
            tab = first?.id
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? t("ios.loadFailed")
        }
    }

    // One pill per answer.
    private var picker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(answers) { a in
                    let on = a.id == tab
                    Button { withAnimation(.snappy(duration: 0.2)) { tab = a.id } } label: {
                        HStack(spacing: 7) {
                            AioEngineMark(engine: a.engine, label: label(a.engine), size: 20)
                            Text(label(a.engine)).font(.dm(13.5, .medium))
                            if multi(a.engine) { Text(t("aio.prompt.sample", ["n": a.sample ?? 1])).font(.dm(11)).opacity(0.6) }
                            if a.mentioned == true {
                                Text(AioFmt.place(a.position)).font(.dm(11, .bold)).monospacedDigit()
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .foregroundStyle(on ? Color.white : Color.slGood)
                                    .background(on ? Color.white.opacity(0.2) : Color.slGoodSoft, in: Capsule())
                            }
                        }
                        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
                        .foregroundStyle(on ? Color.white : Color.slInkSoft)
                        .background(on ? Color.slInk : Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(on ? Color.clear : Color.slLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
    }

    @ViewBuilder private func answerCard(_ a: AioAnswer, names: [String]) -> some View {
        let rivals = (a.brands ?? []).filter { $0.own != true }.map(\.name)

        SLCard {
            AioFlow(spacing: 6) {
                if a.mentioned == true {
                    Chip(text: (a.position ?? 0) > 0 ? t("aio.prompt.mentionedAt", ["pos": Fmt.num(a.position, digits: 1)]) : t("aio.prompt.mentioned"), tone: .good)
                } else {
                    Chip(text: t("aio.prompt.notMentioned"))
                }
                if let s = a.sentiment {
                    Chip(text: t("aio.prompt.sentiment." + s), tone: s == "positive" ? .good : s == "negative" ? .bad : .neutral)
                }
                Text([a.model, a.capturedOn.map { t("aio.prompt.on", ["date": Fmt.short($0)]) }].compactMap { $0 }.joined(separator: " · "))
                    .font(.dm(11.5)).foregroundStyle(Color.slInkMuted)
                    .padding(.vertical, 3)
            }
            .padding(.bottom, 14)

            if let err = a.errorText {
                Text(t("aio.prompt.failed", ["error": err])).font(.dm(13.5)).foregroundStyle(Color.slBad)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.slBadSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                AioAnswerText(text: a.answer ?? "", own: names, rivals: rivals)
            }
        }

        if let claims = a.claims, !claims.isEmpty {
            SLCard {
                Text(t("aio.prompt.claims")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(claims.enumerated()), id: \.offset) { _, c in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: c.verdict == "correct" ? "checkmark.circle.fill" : c.verdict == "wrong" ? "xmark.circle.fill" : "questionmark.circle")
                                .font(.system(size: 15))
                                .foregroundStyle(c.verdict == "correct" ? Color.slGood : c.verdict == "wrong" ? Color.slBad : Color.slWarn)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.claim ?? "").font(.dm(13.5)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                                if let fix = c.fix, !fix.isEmpty {
                                    Text(t("aio.accuracy.truth") + ": " + fix).font(.dm(12)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
        }

        if let brands = a.brands, !brands.isEmpty {
            SLCard {
                Text(t("aio.prompt.brands")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.bottom, 10)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(brands.prefix(12).enumerated()), id: \.offset) { i, b in
                        HStack(spacing: 10) {
                            Text(Fmt.int(b.rank ?? Double(i + 1))).font(.dm(11.5)).monospacedDigit().foregroundStyle(Color.slInkFaint).frame(width: 20, alignment: .trailing)
                            if b.own == true {
                                Text(b.name).font(.dm(13.5, .bold)).foregroundStyle(Color.slInk)
                                    .padding(.horizontal, 4).background(Color.slMarker.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                            } else {
                                Text(b.name).font(.dm(13.5, b.competitor == true ? .medium : .regular)).foregroundStyle(b.competitor == true ? Color.slInk : Color.slInkSoft)
                            }
                            Spacer(minLength: 0)
                        }
                        .lineLimit(1)
                    }
                }
            }
        }

        SLCard {
            Text(t("aio.prompt.citations")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.bottom, 10)
            if let cites = a.citations, !cites.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(cites.prefix(15).enumerated()), id: \.offset) { _, u in
                        if let url = URL(string: u), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                                    Text(AioFmt.hostPath(u)).font(.dm(13)).lineLimit(1).truncationMode(.middle)
                                }
                                .foregroundStyle(Color.slAccent700)
                            }
                        } else {
                            Text(u).font(.dm(13)).foregroundStyle(Color.slInkSoft).lineLimit(1)
                        }
                    }
                }
            } else {
                Text(t("aio.prompt.noCitations")).font(.dm(12.5)).foregroundStyle(Color.slInkMuted).fixedSize(horizontal: false, vertical: true)
            }
        }

        if let history = detail?.history?[a.engine], !history.isEmpty {
            SLCard {
                Text(t("aio.prompt.history")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted).padding(.bottom, 10)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 12, maximum: 12), spacing: 3)], alignment: .leading, spacing: 3) {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, h in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(h.error == true ? Color.slBad.opacity(0.4) : h.mentioned == true ? Color.slAccent600 : Color.slBg)
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(h.error != true && h.mentioned != true ? Color.slLine : .clear, lineWidth: 1))
                            .frame(width: 12, height: 12)
                            .accessibilityLabel(Fmt.short(h.date) + (h.mentioned == true ? " · " + AioFmt.place(h.position) : ""))
                    }
                }
            }
        }
    }
}
