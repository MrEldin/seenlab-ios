//
//  PlanView.swift
//  seenlab
//
//  The morning action plan (web: seo/components/PlanPanel.vue). The same plan feeds the SEO and AIO pages;
//  each shows the actions of its own channel.
//

import SwiftUI

struct PlanView: View {
    let plan: ActionPlan?
    let channel: String
    var go: ((String) -> Void)? = nil
    var kb: ((String) -> Void)? = nil

    @State private var open: String?

    private var actions: [ActionPlan.Action] { (plan?.actions ?? []).filter { $0.channel == channel } }

    var body: some View {
        SLCard {
            CardTitle(eyebrow: t("plan.eyebrow"), title: t("plan.title"), subtitle: t("plan.subtitle"), kb: kb.map { k in { k("plan") } })
            if let at = plan?.generatedAt {
                Text(t("plan.made", ["time": Fmt.relative(at)])).font(.dm(11)).foregroundStyle(Color.slInkFaint).padding(.top, 6)
            }
        }
        if actions.isEmpty {
            EmptyCard(icon: "checklist", title: t("plan.empty"))
        } else {
            ForEach(Array(actions.enumerated()), id: \.element.id) { i, a in
                ActionCard(index: i + 1, action: a, open: open == a.id, go: go) {
                    withAnimation(.snappy) { open = open == a.id ? nil : a.id }
                }
            }
        }
    }
}

private struct ActionCard: View {
    let index: Int
    let action: ActionPlan.Action
    let open: Bool
    var go: ((String) -> Void)?
    let toggle: () -> Void

    var body: some View {
        SLCard(padding: 0) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index)").font(.dm(13, .semibold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(Color.slAccent800, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title ?? "").font(.dm(15, .semibold)).foregroundStyle(Color.slInk).multilineTextAlignment(.leading)
                        if let why = action.why { Text(why).font(.dm(13)).foregroundStyle(Color.slInkSoft).multilineTextAlignment(.leading) }
                        HStack(spacing: 8) {
                            if let kind = action.kind { Chip(text: t("plan.kinds." + kind), tone: .accent) }
                            if let impact = action.impact { Text(t("plan.impact", ["n": Fmt.int(impact)])).font(.dm(11)).foregroundStyle(Color.slInkFaint) }
                        }
                        .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.slInkFaint).rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("action-" + action.id)

            if open {
                VStack(alignment: .leading, spacing: 12) {
                    if let steps = action.steps, !steps.isEmpty {
                        Text(t("plan.steps")).font(.dm(12, .semibold)).foregroundStyle(Color.slInkMuted)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(i + 1).").font(.dm(13, .semibold)).foregroundStyle(Color.slInkMuted)
                                    Text(s).font(.dm(13.5)).foregroundStyle(Color.slInk).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    if let draft = action.draft, !draft.isEmpty { DraftBox(title: t("plan.draft"), text: draft) }
                    if let tab = action.link?.tab, let go {
                        Button { go(tab) } label: { Text(t("plan.open") + " →").font(.dm(13, .semibold)).foregroundStyle(Color.slAccent700) }.buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.slPaper)
                .overlay(alignment: .top) { RowDivider() }
            }
        }
    }
}
