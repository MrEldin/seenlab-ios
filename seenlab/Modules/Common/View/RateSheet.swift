//
//  RateSheet.swift
//  seenlab
//
//  The rating ask, in the lab's own hand: a paper card that rises over the tab bar with the good news
//  that opened it on a marker strip, five stars that light up one by one, and three honest answers —
//  yes (Apple's prompt follows), something's off (a mail to us), not now.
//

import SwiftUI

struct RateSheet: View {
    let moment: ReviewAsk.Moment
    @ObservedObject private var ask = ReviewAsk.shared
    @State private var lit = 0
    @State private var up = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.slInk.opacity(up ? 0.38 : 0)
                .ignoresSafeArea()
                .onTapGesture { ask.later() }
            card
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .offset(y: up ? 0 : 520)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.22)) { up = true }
            for i in 1...5 {
                withAnimation(.spring(duration: 0.4, bounce: 0.45).delay(0.45 + Double(i) * 0.11)) { lit = i }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image("Mark").resizable().scaledToFit().frame(width: 26, height: 26)
                    .frame(width: 44, height: 44).background(Color.slTint100, in: RoundedRectangle(cornerRadius: 14))
                Text(t("ios.rate.hand")).font(.hand(21)).foregroundStyle(Color.slAccent600).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button { ask.later() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.slInkMuted)
                        .frame(width: 32, height: 32).background(Color.slBg, in: Circle())
                }
                .accessibilityLabel(t("ios.rate.later"))
            }

            Text(t("ios.rate.title")).font(.dm(25, .bold)).tracking(-0.5).foregroundStyle(Color.slInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)

            // the good news, as a strip of marker on the page
            Text(moment.line).font(.dm(14.5, .semibold)).foregroundStyle(Color.slInk)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.slMarker.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                .rotationEffect(.degrees(-1.2))
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)

            stars.padding(.top, 20)

            Text(t("ios.rate.text")).font(.dm(14.5)).foregroundStyle(Color.slInkSoft).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 16)

            Button { ask.rate() } label: { HStack { Spacer(); Text(t("ios.rate.yes")); Spacer() } }
                .buttonStyle(SLButtonStyle(kind: .primary))
                .padding(.top, 22)
                .accessibilityIdentifier("rate-yes")
            Button { ask.feedback() } label: { HStack { Spacer(); Text(t("ios.rate.no")); Spacer() } }
                .buttonStyle(SLButtonStyle(kind: .secondary))
                .padding(.top, 8)
            Button(t("ios.rate.later")) { ask.later() }
                .font(.dm(13.5, .semibold)).foregroundStyle(Color.slInkMuted)
                .frame(maxWidth: .infinity).padding(.top, 14).padding(.bottom, 2)
        }
        .padding(22)
        .background(Color.slPaper, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.slLine))
        .shadow(color: Color.slInk.opacity(0.18), radius: 30, y: 12)
    }

    /// Five stars that light up one after another; the marker-yellow of the board, petrol outline.
    private var stars: some View {
        HStack(spacing: 7) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= lit ? "star.fill" : "star")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(i <= lit ? Color.slMarker : Color.slLineStrong)
                    .overlay {
                        if i <= lit { Image(systemName: "star").font(.system(size: 26, weight: .semibold)).foregroundStyle(Color.slAccent700) }
                    }
                    .scaleEffect(i <= lit ? 1 : 0.86)
            }
        }
        .accessibilityHidden(true)
    }
}
