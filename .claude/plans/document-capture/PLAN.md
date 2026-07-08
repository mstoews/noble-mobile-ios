# Document Capture (iOS port) — Plan

Owner: senior-dev session (running in Desktop/nbledger). Port of the completed
Desktop feature into this App Store-bound app. Status: pending / in-progress /
blocked / review / done.

## Binding references (read all three)

- Server contract (identical backend, verified live):
  /Users/murraytoews/Desktop/nbledger/.claude/plans/document-capture/CONTRACT.md
- Desktop rulings D1–D11 (all apply here):
  /Users/murraytoews/Desktop/nbledger/.claude/plans/document-capture/DECISIONS.md
- Mobile rulings M-D1…: ./DECISIONS.md (this directory)
- Desktop verification findings (F1–F4, all must be honored in the port):
  /Users/murraytoews/Desktop/nbledger/.claude/plans/document-capture/VERIFICATION.md

## Repo facts (recon-verified 2026-07-08)

- Build = `nbledger.xcodeproj` compiling `nbledger/`; the `Package.swift` /
  `Sources/NBLMobile` SPM tree is vestigial (not in the pbxproj) — ignore it.
- `nbledger/APIService.swift` (2351 LOC, @Observable, @Environment DI):
  single tenant-aware `baseURL = host + "/" + slug + "/v1"` — all-v1 already;
  Firebase securetoken refresh; `request`/`decoder` are PRIVATE; no `session`
  member (URLSession.shared hardcoded); `analyzeInvoice(imageData:)` (no
  mediaType); NO asset/bill client exists.
- `nbledger/InvoicesView.swift` (811 LOC): VisionKit `VNDocumentCameraViewController`
  scanner + PhotosPicker → analyze → INLINE form; never uploads/attaches.
- Tests: Swift Testing, one placeholder test, no URLProtocol stub seam yet.
- No Anthropic/direct-AI usage anywhere (clean).

## Source files to port (Desktop, post-fix-round versions)

/Users/murraytoews/Desktop/nbledger/nbledger/{AssetService,BillService,
BillFormView,BillDocumentsView}.swift, InvoicesView.swift (as flow reference),
and tests nbledgerTests/{APIServiceAssetTests,APIServiceBillTests}.swift.

## Tasks

### M1 — API layer port — done (verified: independent rerun 17/17 unit tests green)
In this repo's APIService.swift: widen `request` and `decoder` from private to
internal; add an injectable `session` property (`init(session: URLSession = .shared)`
or equivalent that preserves the @Observable/@Environment construction sites);
add `mediaType` param to `analyzeInvoice` (default "image/jpeg", body field
`media_type`). Then port AssetService.swift and BillService.swift as
extension files, ADAPTED: drop Desktop's `base: v1BaseURL` argument — this
repo's `request` already targets the tenant-aware v1 base (ruling M-D2); keep
model names and method signatures otherwise identical to Desktop (post-F1:
`uploadAsset` returns the confirmed `AssetRecord`, no UploadedAsset type).
Port both Desktop test files, adjusted for the target's session injection.
- Acceptance: build green; ported test suites fully green on this repo's
  scheme; no `/public/api`-style hardcoding — tenant flows from `slug`;
  no behavior change to existing APIService callers.
- Touches: nbledger/APIService.swift, new nbledger/AssetService.swift,
  new nbledger/BillService.swift, nbledgerTests/.
- Depends on: none (Desktop sources for these files are final).

### M2 — UI port: capture flow + bill form + documents — done (verified: independent rerun 24/24 unit tests green)
Port BillFormView.swift and BillDocumentsView.swift (post-F2/F4 versions:
onDone reset wired, QuickLook temp files deleted on dismiss + file protection).
Refactor THIS repo's InvoicesView to the Desktop flow shape — capture →
auto-upload(kind:"receipts") → analyze → BillFormView prefill → create_bill
(booked:false) → attach → Documents section — while KEEPING the VisionKit
document scanner as the camera path (ruling M-D1; do not regress to
UIImagePickerController) and keeping PhotosPicker. Add fileImporter per
Desktop F3: imported images analyze; PDFs upload+attach only (no analysis,
CONTRACT §3.1). Preserve Desktop failure-state semantics (upload retry keeps
image; analysis failure → manual entry with asset still attached; ""/0.0 →
empty fields). Remove the now-redundant inline form paths.
- Acceptance: build + full test suite green; VisionKit scanner still the
  camera entry; all four Desktop verification findings honored here.
- Touches: nbledger/InvoicesView.swift, new BillFormView.swift,
  BillDocumentsView.swift.
- Depends on: M1, and Desktop fix round F2–F4 completion (port final files).

### M3 — Verification pass — done (SHIP-WITH-NOTES, see VERIFICATION.md)
Independent verify, Desktop-T4 style: static contract check of the port, build
+ tests, security sweep (no secrets, no signed-URL logging, tenant never
hardcoded), and a live READ-ONLY walk (analyze-invoice 200 shape; list/download
endpoints). No live writes — the identical server chain was already
write-verified within Desktop T4's D11 boundary except upload_url/create_bill
which require a user login; note that gap the same way.
- Depends on: M1, M2.

## Status log
- 2026-07-08: plan created after recon; M1 ready to dispatch.

## FEATURE COMPLETE (iOS port) — 2026-07-09
M1–M3 done and verified (24/24 tests, SHIP-WITH-NOTES). Not committed.
