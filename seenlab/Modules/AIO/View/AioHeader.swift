//
//  AioHeader.swift
//  seenlab
//
//  The top card (web: AnswersHeader.vue): when the assistants were last asked, the connected assistants,
//  the big headline ("Habitly shows up in 15 of 25 AI answers" with the marker) and the four numbers.
//

import SwiftUI

struct AioHeader: View {
    let data: AioOverview?
    @EnvironmentObject private var projects: ProjectStore

    private var k: AioKpis? { data?.kpis }
    private var appName: String { data?.appName ?? projects.current?.name ?? "" }

    private var status: String? {
        guard let data else { return nil }
        if let at = data.job?.finishedAt { return t("aio.measured", ["time": Fmt.relative(at)]) }
        return t("aio.never")
    }

    /// The best single result, for the line under the headline.
    private var best: (pos: Double, prompt: String, engine: String)? {
        var top: (pos: Double, prompt: String, engine: String)?
        for p in data?.prompts ?? [] {
            for (engine, r) in (p.results?.values ?? [:]).sorted(by: { $0.key < $1.key }) {
                guard r.mentioned == true, let pos = r.position, pos > 0 else { continue }
                if top == nil || pos < top!.pos { top = (pos, p.text ?? "", engine) }
            }
        }
        return top.map { ($0.pos, $0.prompt, data?.label($0.engine) ?? $0.engine) }
    }

    private var headline: (key: String, sub: String?) {
        guard let x = k, (x.prompts ?? 0) > 0 else { return ("aio.headline.empty", t("aio.headline.emptySub")) }
        let answers = x.answers ?? 0
        if answers == 0 { return ("aio.headline.empty", t("aio.headline.waiting")) }
        if (x.mentioned ?? 0) == 0 { return ("aio.headline.none", t("aio.headline.noneSub", ["n": answers], count: answers)) }
        if let b = best {
            return ("aio.headline.some", t("aio.headline.someSub", ["pos": Fmt.num(b.pos, digits: 1), "prompt": b.prompt, "engine": b.engine]))
        }
        return ("aio.headline.some", nil)
    }

    var body: some View {
        ChannelHeader(channel: "aio", status: status) {
            if let data {
                VStack(alignment: .leading, spacing: 0) {
                    if !data.enabledEngines.isEmpty {
                        AioEngineMarks(engines: data.enabledEngines.map(\.key), label: data.label)
                            .padding(.bottom, 14)
                    }
                    Eyebrow(text: t("aio.note"))
                    Text(AioFmt.marked(t(headline.key), [
                        "app": appName,
                        "m": AioFmt.n(k?.mentioned),
                        "n": AioFmt.n(k?.answers),
                    ], marked: ["app", "m"]))
                    .font(.dm(26, .bold))
                    .tracking(-0.6)
                    .lineSpacing(1)
                    .foregroundStyle(Color.slInk)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                    if let sub = headline.sub {
                        Text(sub).font(.dm(14.5)).foregroundStyle(Color.slInkSoft).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 10)
                    }
                    if data.job?.status == "failed" {
                        Text(t("aio.runFailed", ["error": data.job?.error ?? ""])).font(.dm(12)).foregroundStyle(Color.slBad).padding(.top, 8)
                    }

                    stats.padding(.top, 16)
                }
            }
        }
    }

    private var stats: some View {
        let x = k
        let none = t("aio.stats.none")
        return KpiGrid(items: [
            KpiTile(label: t("aio.stats.rate"), value: x?.mentionRate.map { Fmt.num($0, digits: 0) + "%" } ?? none, sub: t("aio.stats.rateSub")),
            KpiTile(label: t("aio.stats.share"), value: x?.shareOfVoice.map { Fmt.num($0, digits: 1) + "%" } ?? none),
            KpiTile(label: t("aio.stats.position"), value: (x?.avgPosition).flatMap { $0 > 0 ? "#" + Fmt.num($0, digits: 1) : nil } ?? none,
                    sub: (x?.avgPosition ?? 0) > 0 ? t("aio.stats.positionSub") : nil),
            KpiTile(label: t("aio.stats.rival"), value: x?.topRival?.name ?? none),
        ])
        .padding(14)
        .background(Color.slTint50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
