# Handoff: Noble Ledger Mobile — brand + IA redesign

## Overview
This package specifies a redesign of the **Noble Ledger Mobile** iOS app (`nbledger`, SwiftUI). It moves the app onto the NobleLedger brand (emerald/slate + the crown mark), restructures navigation from a 5-tab shell into a **2-tab companion model with a center Capture FAB and a More hub**, and redesigns each screen for hierarchy and the accounting workflow (sign-off, journal booking, AP/AR, banking, capture).

The task is a **reskin + re-architecture, not a rewrite**: `APIService.swift`, all `Codable` models, auth (Firebase-style + Sign in with Apple), biometric lock, and the Plaid integration stay as they are. This is a presentation-and-navigation effort that reuses the existing networking untouched.

## About the design files
The files in `prototype/` are **design references created in HTML/React (JSX)** — an interactive prototype showing the intended look and behavior. They are **not production code to copy**. The job is to **recreate these designs in the existing SwiftUI codebase** using its established patterns (`@Observable` `APIService` via `@Environment`, `@AppStorage`, `NavigationStack`, `TabView`, `List`, SF Symbols, system materials). Do not port JSX to Swift line-by-line; rebuild the same layouts natively.

Read `prototype/Implementation Plan.dc.html` first — it is the phased build plan (open in any browser). `prototype/Noble Ledger Prototype.dc.html` is the runnable interactive prototype; `prototype/Design Review.dc.html` holds the original critique + the alternative directions that were considered.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and interactions are final. Recreate the UI pixel-accurately using native SwiftUI. Where the prototype and a native iOS convention conflict, prefer the native convention (e.g. system segmented controls, `.searchable`, standard nav transitions).

## How to run the prototype
Open `prototype/Noble Ledger Prototype.dc.html` in a browser. It boots to the login; tap **Log In** (or Face ID) to enter. Bottom tabs are **Home · Activity · [Capture] · More**; the emerald FAB runs Capture → AI review → draft payable. More routes to Payables, Receivables, Banking, Chart of Accounts, Settings, Journal Booking, and Payment Sign-Off.

---

## Design tokens

### Color
| Token | Hex | Use |
|---|---|---|
| Emerald 700 (primary) | `#047857` | Primary actions, active tab, accents, hero gradient base |
| Emerald 800 (highlight) | `#065f46` | Pressed/hover primary, gradient end |
| Emerald 50 (soft) | `#ecfdf5` | Tinted icon chips, success banners, draft tag bg |
| Emerald 300 | `#6ee7b7` | On-dark accent text (login) |
| Slate 900 (ink) | `#1c1c1e` / `#0f172a` | Primary text; `#0f172a` for the dark profile/login surfaces |
| Slate 600 | `#475569` | Secondary icon strokes |
| Slate 500 (secondary) | `rgba(60,60,67,0.6)` | Secondary text (iOS label secondary) |
| Slate 300 (tertiary) | `rgba(60,60,67,0.3)` | Chevrons, disclosure |
| Separator | `rgba(60,60,67,0.12)` | Hairline dividers |
| iOS grouped bg | `#F2F2F7` | Screen background (light) |
| Card | `#FFFFFF` | Surfaces (light) |
| Warn / overdue | `#dc2626` (text `#991b1b`, bg `#fee2e2`) | Overdue, destructive, unbalanced |
| Amber | `#d97706` (text `#92400e`, bg `#fef3c7`) | Open/pending status pills |
| Blue | `#2563eb` | Receivables accent, "open receipts" dot |
| Purple | `#9333ea` | Special-assessment fund |

Dark mode: bg `#000`, card `#1C1C1E`, ink `#fff`, secondary `rgba(235,235,245,0.6)`, separator `rgba(84,84,88,0.55)`. Map to SwiftUI semantic colors (`.systemGroupedBackground`, `.secondarySystemGroupedBackground`, `.secondary`) so dark comes mostly free.

### Fund colors
Operating `#047857` · Reserve `#2563eb` · Special Assessment `#9333ea`.

### Typography
Font: **Inter var** (the shipped DS face) — substitute the system SF stack if not bundled. All currency uses **tabular figures** (`.monospacedDigit()` / `fontVariantNumeric: tabular-nums`).
| Role | Size / weight |
|---|---|
| Large title (screen) | 32–34 / 700 |
| Metric hero | 40–44 / 700, tabular |
| Row title | 16 / 600 |
| Body | 15 / 400 |
| Secondary / sub | 12.5–13 / 400 |
| Section label | 13 / 600, secondary color, letter-spacing 0.3 |
| Overline (KICKER) | 12.5 / 600, emerald, letter-spacing 0.04em |
| Status pill | 11 / 600 (DRAFT tag 10 / 700, 0.4 tracking) |

### Radius / spacing / elevation
Cards 16–18 · icon chips 8–11 · toggles/pills 999 · FAB 20–22. Page gutter 16. Card inner padding 14–16. Shadow (light) `0 1px 3px rgba(0,0,0,0.06)`; hero `0 8px 22px rgba(4,120,87,0.28)`. Dark surfaces use no shadow (borders separate).

### Iconography
SF Symbols in-app (the prototype's inline SVGs are placeholders). Tab bar: Home = `house`, Activity = chart/`chart.line.uptrend.xyaxis`, Capture = `doc.viewfinder`, More = `ellipsis`. Reuse the app's existing Heroicons/`e-icons` registry per current convention.

---

## Screens / views

Legend: **NEW** build fresh · **RESKIN** restyle existing · **REFACTOR** restructure + restyle.

### 1. Login — `LoginView.swift` (REFACTOR)
- **Purpose:** authenticate; remembered workspace + Face ID first.
- **Layout:** full-bleed diagonal gradient `#0f172a → #123f33 → #065f46`. Centered framed crown (64×64, 2px `#475569` border, radius 14), "Noble Ledger" 30/700 white, subtitle "Accounting for condominium corporations" `#94a3b8`. Then a **Workspace** card (persisted tenant, "Change" link), email + password fields (translucent `rgba(255,255,255,0.07)`, 1px `rgba(255,255,255,0.13)`, radius 12), emerald **Log In** button `#059669`, "or" divider, white **Sign in with Apple**, **Unlock with Face ID** row (emerald-300). Version `v0.0.4.66` pinned bottom.
- **Behavior changes:** Company ID no longer gates Sign in with Apple; persist tenant in `@AppStorage`/Keychain and show it as the workspace card; offer Face ID unlock when a session exists. Error copy stays short/declarative per DS voice.

### 2. Home / Dashboard — `MainView.swift › DashboardView` (REFACTOR)
- **Purpose:** at-a-glance financial position + what needs attention.
- **Layout:** header kicker "BROOKLINE GROVE" + "Dashboard" + avatar. **Net-position hero** (emerald gradient card, label + 40/700 tabular value + assets/liabilities/MTD trend). Two tiles **Money in · AR** / **Money out · AP** (amount + a red "N overdue" / secondary "due this week"). **NEEDS ATTENTION** grouped list (dot + title + subtitle + chevron). **BUDGET VS ACTUAL · YTD** with two progress bars (emerald = healthy, slate = neutral).
- **Change from today:** collapse the 7 co-equal material widgets into this hierarchy. Numbers are the hero; green/red reserved for variance only — do **not** render raw signed liabilities as red errors (fix in the presentation layer, not the ledger math).

### 3. Activity — `MainView` (NEW tab, reuses txn data)
- Segmented **All / Needs sign-off · N**; transaction rows (colored avatar by direction, payee, memo · when, signed amount; amber dot when awaiting sign-off). Tapping opens the sign-off detail.

### 4. Transaction / sign-off detail — `PaymentSignOffView.swift` (RESKIN)
- Amount hero, status chip, meta rows (Type, Fund, Account, Reference, Date, Submitted by · role), **LEDGER IMPACT** Dr/Cr rows, sticky **Sign off & book** (guarded by confirmation + Face ID). Booked items show "✓ Booked · no action required".

### 5. Payables list + bill detail — `APPayablesView.swift` (RESKIN)
- **List:** back to More, "Payables" title, **Open payables** total card + "N overdue" chip, **Open / Paid / All** segmented control, rows (vendor initial chip, vendor + optional **DRAFT** tag, `AP-#### · due/overdue` with overdue in red, amount). Footer count.
- **Bill detail:** back, status chip (Open/Overdue/Paid), AMOUNT DUE hero, vendor, meta (Invoice #, Vendor, Invoice date, Due, Fund, Account, Submitted by), **LINE ITEMS** + Subtotal / HST (13%) / Total breakdown, sticky **Record payment**.

### 6. Receivables list + invoice detail — `ARReceivablesView.swift` (RESKIN)
- **List:** **Outstanding** total + "N overdue" chip, **Open / Overdue / Paid** filter, rows (unit-owner invoices, `AR-#### · due/overdue`, amount).
- **Detail:** same DocDetail as bill, meta (Invoice #, Customer, Issued, Due, Fund, Account), line items, **Remaining balance** row, sticky **Record payment received**.

### 7. Journal Booking + entry detail — `JournalBookingView.swift` / `GLJournalView.swift` (REFACTOR)
- **Review list:** **Open entries** total + "all balanced / N unbalanced" chip, entry rows (green check / red warning chip, description, `J-#### · type · date` or "Debits ≠ credits" in red, amount, chevron), sticky **Book N balanced entries** (skips unbalanced; Face ID).
- **Entry detail:** `J-#### · TYPE`, description, date; **JOURNAL LINES** table with ACCOUNT / DEBIT / CREDIT columns, Totals row, a "Debits and credits balance" (green) or "Out of balance by $X" (red) line; sticky **Book journal** / **Edit lines** — unbalanced shows disabled **Fix balance to book**.

### 8. Banking — `BankingView.swift` (RESKIN)
- Horizontally scrollable **account cards** (selected card = emerald gradient; name, `···· mask`, current balance, "available"), **RECENT TRANSACTIONS** for the selected account (direction chip, name, when, signed amount). Plaid link flow unchanged; "Connect" in nav.

### 9. Chart of Accounts — `LedgerView.swift` (RESKIN)
- Collapsible GL groups (Assets, Liabilities, Equity, Revenue, Expenses) with a rotating disclosure chevron + section total; indented account rows (emerald account number · name · balance). Keep the existing hierarchy builder; restyle only.

### 10. Settings — `MainView.swift › SettingsView` (RESKIN)
- Grouped list: **ACCOUNT** (Name, Email, Company, Role · ADMIN), **SECURITY** (Face ID/Touch ID toggle, Dark appearance toggle — emerald when on), **BANKING** (Connect a bank account), **Log Out** (red, confirmation dialog → returns to login). Version footer.

### 11. More hub — `MoreView.swift` (REFACTOR)
- Dark profile card (framed crown, company, "Murray Toews · Manager", ADMIN pill). **NEEDS YOUR ACTION** group: **Payment Sign-Off** (emerald check chip, "$X awaiting approval", red count badge) → Activity; **Journal Booking** ("N open entries · $X", amber badge) → booking. **MONEY**: Payables, Receivables, Banking. **ACCOUNT**: Chart of Accounts, Settings. Drop the six arbitrary card tints of the current grid.

### 12. Capture — `InvoicesView.swift` (RESKIN + close the loop)
- FAB → camera viewfinder (document guide frame, shutter) → **Review** screen (captured thumb, "Extracted by AI", editable field rows with confidence chips, duplicate-check line) → **Create draft payable**. On success, land in **Payables** with a green success banner and the new bill tagged **DRAFT** (open total updates). Existing VisionKit scan → `/analyze_invoice` → confirm pipeline stays; this only closes the loop into Payables.

### 13. AI assistant — `AgentChatView.swift` (REFACTOR — safety)
- Empty state: questions as suggestions ("What's overdue right now?", "How are we tracking against budget?"). Move **Book / Close all open journals** out of one-tap suggestions into a **BULK ACTIONS · CONFIRMATION REQUIRED** group with counts, an explicit review step, and Face ID. Never mutate the ledger from a single tap.

---

## Interactions & behavior
- **Navigation:** tab switch (Home/Activity/More) instant; More → detail = `NavigationStack` push with back to source; Capture = full-screen cover; details use system push transition.
- **Capture loop:** camera → review → Create draft → dismiss to Payables + banner + DRAFT row + updated open total.
- **Primary actions** (Sign off, Book, Record payment): confirmation dialog + Face ID; on success clear the item, decrement the relevant badge count, show a brief success state.
- **Filters:** segmented controls filter in place; Journal "Book all" skips unbalanced entries.
- **Log out:** confirmation dialog → clears session → login.
- **Motion:** restrained per brand — no scale-on-press; rely on standard nav/view transitions.

## State management
Reuse the existing `@Observable APIService` (`@Environment(APIService.self)`), `@AppStorage` (tenant, biometric flag, dark pref), and `@State`. New/added state: remembered workspace/tenant; captured-draft list appended to Payables; per-screen loading/empty/error; badge counts derived from journal/payment/AR fetches. Keep the concurrency rule — sequential API calls, avoid `async let` with mixed error handling.

## Assets
- `prototype/assets/logo.svg` — the NobleLedger crown mark (bronze `#916931`), shown inside a framed container per brand. Use the existing app asset catalog version in-app.
- All other glyphs are SF Symbols / the app's existing icon registry — the prototype's inline SVGs are placeholders only.

## Files in this bundle
- `Implementation Plan.dc.html` — phased build plan (read first).
- `Noble Ledger Prototype.dc.html` — runnable interactive prototype (entry point).
- `noble-app.jsx` — prototype state machine (screen routing).
- `ui-kit/noble-ios-app.jsx` — all screen components + sample data (Brookline Grove).
- `ios-frame.jsx` — device bezel (reference only, not shipped).
- `Design Review.dc.html` — original critique + alternative directions.
- `assets/logo.svg` — crown mark.

## Target codebase files to touch
`MainView.swift`, `MoreView.swift`, `LoginView.swift`, `LedgerView.swift`, `GLJournalView.swift`, `JournalBookingView.swift`, `APPayablesView.swift`, `ARReceivablesView.swift`, `BankingView.swift`, `InvoicesView.swift`, `PaymentSignOffView.swift`, `AgentChatView.swift`, plus a new `Theme/NobleTokens.swift` + shared SwiftUI kit (`NobleCard`, `SectionLabel`, `StatusPill`, `MetricHero`, `DetailRow`). Do **not** modify `APIService.swift`, models, or `PlaidLinkFlow.swift` beyond call sites.

## Definition of done (per screen)
Matches prototype layout/hierarchy/tokens with zero hardcoded colors; renders in light + dark at largest Dynamic Type with VoiceOver; loading/empty/error states designed; primary action wired to real data with confirmation where destructive; snapshot test added (extend `AccountsPageScreenshotTests`, `ApprovalScreensScreenshotTests`).
