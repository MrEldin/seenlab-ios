//
//  ProjectPickerSheet.swift
//  seenlab
//
//  The project picker, drawn like the web's app rail: deep petrol glass with slow rising bubbles, every
//  project as a card (icon, where it lives, which channels it has), the one being viewed ringed in white
//  with the rail's edge marker. Picking one switches the whole app to it and closes the sheet.
//

import SwiftUI

struct ProjectPickerSheet: View {
    @EnvironmentObject private var projects: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var picked: Int?

    private var apps: [Project] { projects.projects.filter(\.hasStore) }
    private var sites: [Project] { projects.projects.filter { !$0.hasStore } }

    var body: some View {
        ZStack {
            RailBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if !apps.isEmpty { group(t("ios.projects.apps"), apps) }
                    if !sites.isEmpty { group(t("ios.projects.sites"), sites) }
                    addOnWeb
                }
                .padding(.horizontal, 20)
                .padding(.top, 26)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.selection, trigger: picked)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground(Color.slAccent900)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("MarkLight").resizable().scaledToFit().frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 0) {
                Text(t("ios.projects.hand")).font(.hand(20)).foregroundStyle(Color.slTint300)
                Text(t("sl.rail.label")).font(.dm(24, .bold)).tracking(-0.5).foregroundStyle(.white)
            }
            Spacer()
            Text("\(projects.projects.count)").font(.dm(13, .semibold)).monospacedDigit().foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
    }

    private func group(_ title: String, _ list: [Project]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.dm(12.5, .semibold)).foregroundStyle(.white.opacity(0.55)).padding(.leading, 4)
            VStack(spacing: 8) {
                ForEach(list) { p in
                    ProjectCard(project: p, active: p.id == projects.currentId) { pick(p) }
                }
            }
        }
    }

    /// New projects are added on the web — the rail's dashed "+" button.
    private var addOnWeb: some View {
        Button { openURL(URL(string: "https://seenlab.io/app")!) } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 17, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).foregroundStyle(.white.opacity(0.4)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("sl.rail.add")).font(.dm(15, .semibold))
                    Text(t("ios.projects.onWeb")).font(.dm(12.5)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private func pick(_ p: Project) {
        picked = p.id
        if p.id != projects.currentId { withAnimation(.snappy) { projects.select(p.id) } }
        Task { try? await Task.sleep(for: .milliseconds(220)); dismiss() }
    }
}

/// One project on the rail: icon (ringed when active), name, where it lives, its channels.
private struct ProjectCard: View {
    let project: Project
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomLeading) {
                    RemoteIcon(url: project.iconUrl, size: 50, fallback: project.platformIcon)
                        .clipShape(RoundedRectangle(cornerRadius: active ? 14 : 25, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: active ? 14 : 25, style: .continuous).stroke(.white.opacity(active ? 0.95 : 0), lineWidth: 2.5))
                    if project.platform != "ios" {
                        Image(systemName: project.platformIcon).font(.system(size: 9.5, weight: .bold)).foregroundStyle(Color.slAccent800)
                            .frame(width: 19, height: 19).background(.white, in: Circle())
                            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                            .offset(x: -3, y: 3)
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name).font(.dm(15.5, .semibold)).foregroundStyle(.white).lineLimit(1)
                    HStack(spacing: 5) {
                        Image(systemName: project.platformIcon).font(.system(size: 10.5))
                        Text(project.hasStore ? project.storeName + " · " + project.byline : project.byline).lineLimit(1)
                    }
                    .font(.dm(12.5)).foregroundStyle(.white.opacity(0.62))
                    HStack(spacing: 4) {
                        channel("ASO", on: project.hasStore)
                        channel("SEO", on: true)
                        channel("AIO", on: true)
                    }
                }
                Spacer(minLength: 6)
                if active {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.slAccent800)
                        .frame(width: 26, height: 26).background(.white, in: Circle())
                }
            }
            .padding(12)
            // opaque glass: the bubbles rise between the cards, never across the text
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.slAccent800)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(active ? 0.13 : 0.05)))
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(active ? 0.28 : 0.08), lineWidth: 1))
            // the rail's active marker on the edge
            .overlay(alignment: .leading) {
                Capsule().fill(.white).frame(width: 4, height: active ? 30 : 0).offset(x: -10).opacity(active ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(RailPress())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func channel(_ name: String, on: Bool) -> some View {
        Text(name).font(.dm(10, .bold)).tracking(0.3)
            .strikethrough(!on, color: .white.opacity(0.4))
            .foregroundStyle(.white.opacity(on ? 0.85 : 0.35))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.white.opacity(on ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 5))
    }
}

private struct RailPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Deep petrol, like tinted lab glass, with slow bubbles rising through it (the web rail).
struct RailBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LinearGradient(colors: [.slAccent700, .slAccent800, .slAccent900], startPoint: .top, endPoint: .bottom)
            TimelineView(.animation(paused: reduceMotion)) { tl in
                Canvas { ctx, size in
                    let now = tl.date.timeIntervalSinceReferenceDate
                    for n in 1...14 {
                        let d = 9.0 + Double(n % 4) * 3                      // seconds to rise
                        let p = ((now / d) + Double(n) * 0.137).truncatingRemainder(dividingBy: 1)
                        let r = 2.0 + Double(n % 3) * 1.6
                        let x = size.width * (0.06 + Double((n * 37) % 88) / 100) + sin(now * 0.6 + Double(n)) * 6
                        let y = size.height * (1.05 - p * 1.15)
                        let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                        ctx.stroke(Circle().path(in: rect), with: .color(.white.opacity(0.32 * sin(.pi * p))), lineWidth: 1.2)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
