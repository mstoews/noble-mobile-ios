//
//  NobleKit.swift
//  nbledger
//
//  Shared NobleLedger UI primitives — the repeated pieces every reskinned
//  screen uses (docs/design_handoff_noble_mobile/README.md). All colors come
//  from NobleTokens; surfaces use semantic system colors so dark mode is free.
//

import SwiftUI

// MARK: - NobleCard

/// Rounded card surface: white in light mode, elevated gray in dark,
/// hairline-shadowed per the DS elevation spec.
struct NobleCard<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: NobleRadius.card, style: .continuous)
            )
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

// MARK: - SectionLabel

/// Grouped-section header: 13/600, secondary color, slight tracking.
struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .kerning(0.3)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: - StatusPill

/// Small status capsule (Open / Overdue / Paid / DRAFT…).
struct StatusPill: View {
    let text: String
    var color: Color = .nobleAmberText
    var background: Color = .nobleAmberSoft

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .kerning(0.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule())
    }

    static func overdue(_ text: String) -> StatusPill {
        StatusPill(text: text, color: .nobleWarnText, background: .nobleWarnSoft)
    }

    static func open(_ text: String) -> StatusPill {
        StatusPill(text: text, color: .nobleAmberText, background: .nobleAmberSoft)
    }

    static func success(_ text: String) -> StatusPill {
        StatusPill(text: text, color: .nobleEmerald, background: .nobleEmeraldSoft)
    }
}

// MARK: - MetricHero

/// Emerald-gradient hero card: kicker label, large tabular figure, and a
/// caption row underneath.
struct MetricHero<Sub: View>: View {
    let label: String
    let value: Double
    @ViewBuilder var sub: Sub

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .kerning(0.3)
                .foregroundStyle(.white.opacity(0.8))
            Text.money(value)
                .font(.system(size: 40, weight: .bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
            sub
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient.nobleHero,
            in: RoundedRectangle(cornerRadius: NobleRadius.hero, style: .continuous)
        )
        .shadow(color: .nobleEmerald.opacity(0.28), radius: 11, x: 0, y: 8)
    }
}

// MARK: - DetailRow

/// Key/value meta row for detail screens. Empty values render as an em dash.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }
}

// MARK: - Preview gallery

#Preview("Noble Kit — Light") {
    NobleKitGallery()
}

#Preview("Noble Kit — Dark") {
    NobleKitGallery()
        .preferredColorScheme(.dark)
}

private struct NobleKitGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                MetricHero(label: "TOTAL CASH ON HAND", value: 482310) {
                    HStack(spacing: 6) {
                        Text("Across 3 fund accounts")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("▲ 2.1%")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.nobleEmeraldOnDark)
                    }
                }

                SectionLabel("Status pills")
                NobleCard(padding: 14) {
                    HStack(spacing: 8) {
                        StatusPill.open("Open")
                        StatusPill.overdue("Overdue")
                        StatusPill.success("Paid")
                        StatusPill.success("DRAFT")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                SectionLabel("Detail rows")
                NobleCard(padding: 14) {
                    VStack(spacing: 8) {
                        DetailRow(label: "Fund", value: "Operating")
                        Divider()
                        DetailRow(label: "Reference", value: "AP-1918")
                        Divider()
                        DetailRow(label: "Submitted by", value: "jmalik · ACCT")
                    }
                }

                SectionLabel("Money")
                NobleCard(padding: 14) {
                    HStack {
                        Text("Amount")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text.money(10505.22)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }
}
