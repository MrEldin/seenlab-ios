//
//  Components.swift
//  seenlab
//
//  The building blocks every channel uses, drawn like the web app: white cards on warm paper with a 1px
//  line, Caveat eyebrows, tinted chips, KPI tiles. Keep new screens made of these.
//

import SwiftUI

/// A white card (the web's `rounded-3xl border border-sl-line bg-white`).
struct SLCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.slLine, lineWidth: 1))
            .shadow(color: Color.slInk.opacity(0.04), radius: 1, y: 1)
    }
}

/// The handwritten note above a title ("šta danas da uradiš").
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.hand(21)).foregroundStyle(Color.slAccent600) }
}

/// Title + subtitle of a card, with an optional "Kako ovo radi?" link to the knowledge base.
struct CardTitle: View {
    var eyebrow: String? = nil
    let title: String
    var subtitle: String? = nil
    var kb: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let eyebrow { Eyebrow(text: eyebrow) }
            Text(title).font(.dm(16, .semibold)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
            if subtitle != nil || kb != nil {
                (Text(subtitle.map { $0 + " " } ?? "").foregroundStyle(Color.slInkMuted)
                 + Text(kb == nil ? "" : t("kb.how")).foregroundStyle(Color.slAccent700).fontWeight(.semibold))
                    .font(.dm(12.5))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onTapGesture { kb?() }
            }
        }
    }
}

/// A small rounded label (severity, kind, engine…).
struct Chip: View {
    let text: String
    var tone: Tone = .neutral
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(.dm(11.5, .semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .foregroundStyle(tone.fg)
        .background(tone.bg, in: Capsule())
    }
}

/// A number with its label, like the web KPI tiles.
struct KpiTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var tone: Tone? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.dm(12)).foregroundStyle(Color.slInkMuted).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value).font(.dm(22, .semibold)).foregroundStyle(tone?.fg ?? Color.slInk).monospacedDigit()
                if let sub { Text(sub).font(.dm(11.5)).foregroundStyle(Color.slInkMuted).lineLimit(1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A grid of KPI tiles, two per row.
struct KpiGrid: View {
    let items: [KpiTile]
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 14) {
            ForEach(items.indices, id: \.self) { items[$0] }
        }
    }
}

/// Up or down, green or red, the way the web shows a position change (positive = better).
struct DeltaText: View {
    let delta: Double?
    var suffix: String = ""
    var body: some View {
        if let delta, delta != 0 {
            HStack(spacing: 2) {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down").font(.system(size: 9, weight: .bold))
                Text(Fmt.num(abs(delta), digits: 1) + suffix).font(.dm(11.5, .semibold)).monospacedDigit()
            }
            .foregroundStyle(delta > 0 ? Color.slGood : Color.slBad)
        }
    }
}

/// App or site icon from a URL, with a quiet placeholder.
struct RemoteIcon: View {
    let url: String?
    var size: CGFloat = 40
    var fallback: String = "app.fill"

    var body: some View {
        AsyncImage(url: url.flatMap(URL.init(string:))) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else { ZStack { Color.slTint100; Image(systemName: fallback).foregroundStyle(Color.slAccent600).font(.system(size: size * 0.42)) } }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous).stroke(Color.slLine, lineWidth: 0.5))
    }
}

/// A 0–100 score in a ring (audit health, listing score).
struct ScoreRing: View {
    let score: Double?
    var size: CGFloat = 64
    var label: String? = nil

    private var tone: Tone { guard let score else { return .neutral }; return score >= 80 ? .good : score >= 50 ? .warn : .bad }

    var body: some View {
        ZStack {
            Circle().stroke(Color.slLine, lineWidth: size * 0.1)
            Circle().trim(from: 0, to: CGFloat((score ?? 0) / 100)).stroke(tone.fg, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)).rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(score.map { Fmt.int($0) } ?? "—").font(.dm(size * 0.3, .semibold)).foregroundStyle(Color.slInk).monospacedDigit()
                if let label { Text(label).font(.dm(size * 0.13)).foregroundStyle(Color.slInkMuted) }
            }
        }
        .frame(width: size, height: size)
    }
}

/// A row with a leading title/sub and a trailing value; the list cell of every table.
struct InfoRow<Trailing: View>: View {
    let title: String
    var sub: String? = nil
    var mono: Bool = false
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(mono ? .system(size: 13.5, design: .monospaced) : .dm(14, .medium)).foregroundStyle(Color.slInk).lineLimit(2)
                if let sub, !sub.isEmpty { Text(sub).font(.dm(12)).foregroundStyle(Color.slInkMuted).lineLimit(2) }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 10)
    }
}

extension InfoRow where Trailing == EmptyView {
    init(title: String, sub: String? = nil, mono: Bool = false) { self.init(title: title, sub: sub, mono: mono) { EmptyView() } }
}

/// Hairline between rows inside a card.
struct RowDivider: View {
    var body: some View { Rectangle().fill(Color.slLine).frame(height: 1) }
}

/// Rows separated by hairlines.
struct RowList<Item, Row: View>: View {
    let items: [Item]
    @ViewBuilder var row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                if i > 0 { RowDivider() }
                row(item)
            }
        }
    }
}

/// Empty, loading and failed states inside a card.
struct EmptyCard: View {
    var icon: String = "testtube.2"
    let title: String
    var text: String? = nil

    var body: some View {
        SLCard {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 28, weight: .light)).foregroundStyle(Color.slAccent600)
                Text(title).font(.dm(15, .semibold)).foregroundStyle(Color.slInk).multilineTextAlignment(.center)
                if let text { Text(text).font(.dm(13)).foregroundStyle(Color.slInkMuted).multilineTextAlignment(.center) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }
}

struct LoadingCard: View {
    var body: some View {
        SLCard { HStack { Spacer(); ProgressView().tint(Color.slAccent600); Spacer() }.padding(.vertical, 30) }
    }
}

struct ErrorCard: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        SLCard {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 24)).foregroundStyle(Color.slWarn)
                Text(message).font(.dm(13.5)).foregroundStyle(Color.slInkSoft).multilineTextAlignment(.center)
                Button(t("ios.retry"), action: retry).buttonStyle(SLButtonStyle(kind: .secondary))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
        }
    }
}

/// Buttons: primary = ink pill (the web's black "Izmeri pozicije"), secondary = outlined.
struct SLButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, accent }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dm(14, .semibold))
            .padding(.horizontal, 16).padding(.vertical, 10)
            .foregroundStyle(kind == .secondary ? Color.slInk : .white)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(kind == .secondary ? Color.slLineStrong : .clear, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }

    private var background: Color {
        switch kind { case .primary: .slInk; case .secondary: .white; case .accent: .slAccent600 }
    }
}

/// Copies text and says so for a moment (drafts, schema code, titles).
struct CopyButton: View {
    let text: String
    var label: String? = nil
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.6)); copied = false }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.system(size: 11, weight: .semibold))
                Text(copied ? t("aso.ai.copied") : (label ?? t("aso.ai.copy"))).font(.dm(12, .semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(Color.slAccent800)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.slLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// A block of text that can be selected and copied (drafts, code).
struct DraftBox: View {
    var title: String? = nil
    let text: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let title { Text(title).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted) }
                Spacer()
                CopyButton(text: text)
            }
            Text(text)
                .font(mono ? .system(size: 12, design: .monospaced) : .dm(13.5))
                .foregroundStyle(Color.slInkSoft)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.slLine, lineWidth: 1))
    }
}

/// Horizontal tab pills under a channel header (the web's header nav).
struct TabItem: Identifiable, Hashable {
    let key: String
    let label: String
    var icon: String
    var count: Int? = nil
    var id: String { key }
}

struct ChannelTabs: View {
    let tabs: [TabItem]
    @Binding var selection: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(tabs) { tab in
                        let on = tab.key == selection
                        Button {
                            withAnimation(.snappy(duration: 0.25)) { selection = tab.key }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon).font(.system(size: 13, weight: .medium)).foregroundStyle(on ? Color.slAccent800 : Color.slInk.opacity(0.4))
                                Text(tab.label).font(.dm(13.5, .medium))
                                if let c = tab.count {
                                    Text("\(c)").font(.dm(11)).monospacedDigit().padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(on ? Color.white : Color.slInk.opacity(0.05), in: Capsule())
                                        .foregroundStyle(on ? Color.slAccent800 : Color.slInk.opacity(0.45))
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .foregroundStyle(on ? Color.slInk : Color.slInk.opacity(0.55))
                            .background(on ? Color.slTint100 : .clear, in: Capsule())
                            .overlay(Capsule().stroke(on ? Color.slTint200 : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(tab.key)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selection) { _, v in withAnimation { proxy.scrollTo(v, anchor: .center) } }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
}

/// The yellow marker behind a word, like the web headlines.
extension Text {
    func marker() -> some View {
        self.background(alignment: .bottom) { Color.slMarker.frame(height: 9).offset(y: -2).padding(.horizontal, -2) }
    }
}

/// Screen scaffolding: paper background, scrolling column with the web's spacing, pull to refresh.
struct ChannelScroll<Content: View>: View {
    var refresh: (() async -> Void)? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) { content }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
        }
        .background(Color.slBg)
        .refreshable { await refresh?() }
    }
}
