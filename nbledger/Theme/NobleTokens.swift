//
//  NobleTokens.swift
//  nbledger
//
//  NobleLedger design tokens (docs/design_handoff_noble_mobile/README.md).
//  Single source for brand color, radius, and the tabular money style —
//  views should not carry ad-hoc hex values.
//

import SwiftUI

// MARK: - Color

extension Color {
    /// Emerald 700 — primary actions, active tab, accents.
    static let nobleEmerald = Color(red: 4 / 255, green: 120 / 255, blue: 87 / 255)         // #047857
    /// Emerald 600 — bright CTA on dark surfaces (login).
    static let nobleEmeraldBright = Color(red: 5 / 255, green: 150 / 255, blue: 105 / 255)  // #059669
    /// Emerald 800 — pressed/hover primary, gradient end.
    static let nobleEmeraldHighlight = Color(red: 6 / 255, green: 95 / 255, blue: 70 / 255) // #065f46
    /// Deep emerald — hero gradient base.
    static let nobleEmeraldDeep = Color(red: 6 / 255, green: 78 / 255, blue: 59 / 255)      // #064e3b
    /// Emerald 50 — tinted icon chips, success banners, draft tags.
    static let nobleEmeraldSoft = Color(red: 236 / 255, green: 253 / 255, blue: 245 / 255)  // #ecfdf5
    /// Emerald 300 — accent text on dark surfaces.
    static let nobleEmeraldOnDark = Color(red: 110 / 255, green: 231 / 255, blue: 183 / 255) // #6ee7b7
    /// Slate 900 — dark profile/login surfaces.
    static let nobleSlateInk = Color(red: 15 / 255, green: 23 / 255, blue: 42 / 255)        // #0f172a
    /// Slate 600 — secondary icon strokes.
    static let nobleSlate = Color(red: 71 / 255, green: 85 / 255, blue: 105 / 255)          // #475569
    /// Slate 400 — muted text on dark surfaces.
    static let nobleSlateMuted = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)   // #94a3b8

    /// Overdue / destructive / unbalanced.
    static let nobleWarn = Color(red: 220 / 255, green: 38 / 255, blue: 38 / 255)           // #dc2626
    /// Text on warn-soft backgrounds.
    static let nobleWarnText = Color(red: 153 / 255, green: 27 / 255, blue: 27 / 255)       // #991b1b
    /// Overdue pill background.
    static let nobleWarnSoft = Color(red: 254 / 255, green: 226 / 255, blue: 226 / 255)     // #fee2e2

    /// Open / pending status.
    static let nobleAmber = Color(red: 217 / 255, green: 119 / 255, blue: 6 / 255)          // #d97706
    /// Text on amber-soft backgrounds.
    static let nobleAmberText = Color(red: 146 / 255, green: 64 / 255, blue: 14 / 255)      // #92400e
    /// Open/pending pill background.
    static let nobleAmberSoft = Color(red: 254 / 255, green: 243 / 255, blue: 199 / 255)    // #fef3c7

    /// Receivables accent, "open receipts".
    static let nobleBlue = Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255)           // #2563eb
    /// Special-assessment fund.
    static let noblePurple = Color(red: 147 / 255, green: 51 / 255, blue: 234 / 255)        // #9333ea

    /// Fund accent by gl_funds code (OPER/RES/SPE per the seeded server data).
    static func nobleFund(_ code: String) -> Color {
        switch code.uppercased() {
        case "OPER", "OPERATING": return .nobleEmerald
        case "RES", "RESERVE": return .nobleBlue
        case "SPE", "SPECIAL": return .noblePurple
        default: return .nobleSlate
        }
    }
}

// MARK: - Gradient

extension LinearGradient {
    /// Emerald hero-card gradient (#064e3b → #047857, 155°).
    static let nobleHero = LinearGradient(
        colors: [.nobleEmeraldDeep, .nobleEmerald],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Radius

enum NobleRadius {
    /// Cards and grouped surfaces.
    static let card: CGFloat = 16
    /// Hero and profile cards.
    static let hero: CGFloat = 18
    /// Icon chips.
    static let chip: CGFloat = 8
    /// Transaction avatars.
    static let avatar: CGFloat = 11
}

// MARK: - Money

extension Text {
    /// Currency text with tabular figures — every amount in the app
    /// renders through this so columns align.
    static func money(_ value: Double, code: String = "USD") -> Text {
        Text(value, format: .currency(code: code))
            .monospacedDigit()
    }
}
