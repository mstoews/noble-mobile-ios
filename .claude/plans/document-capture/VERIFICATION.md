# Document Capture (iOS port) — M3 Independent Verification

Date: 2026-07-09. Verifier: M3 (wrote none of the ported code).
Repo: noble-mobile-ios working tree (uncommitted M1+M2 changes);
reference server: noble-go-server (read-only); reference impl:
Desktop nbledger CONTRACT.md / DECISIONS.md D1–D11 / VERIFICATION.md F1–F4.

## Overall verdict: SHIP-WITH-NOTES

Every static contract check, all four Desktop fixes, both rulings M-D1/M-D2,
the build, 24/24 unit tests, the security sweep, and the live read-only walk
PASS. M2's claim that the Payments tab "rides the known-broken legacy base
per D8" is **wrong** — adjudicated below with live evidence. Remaining notes
are minor and listed in §7; the known write-chain verification gap (user-bound
credential required) carries over from Desktop T4 unchanged.

---

## 1. Static contract conformance — PASS

Files reviewed: modified `nbledger/APIService.swift`, `nbledger/InvoicesView.swift`;
new `nbledger/AssetService.swift`, `nbledger/BillService.swift`,
`nbledger/BillFormView.swift`, `nbledger/BillDocumentsView.swift`,
`nbledgerTests/APIServiceAssetTests.swift`, `nbledgerTests/APIServiceBillTests.swift`.
(Also new `nbledgerUITests/LoginFlowTests.swift` — a UI login probe, see §7.4.)
Project uses file-system-synchronized groups (8 refs in pbxproj), so new files
are in the build — confirmed by the build itself.

- **Paths**: every new call goes through `APIService.request`, which targets
  the existing tenant-aware `baseURL = {host}/{slug}/v1` (APIService.swift:1522).
  Routes used — `assets/upload_url`, `assets/{id}/confirm`,
  `assets/{id}/download_url`, `assets[?kind=]`, DELETE `assets/{id}`,
  `attach_bill_asset`, `list_bill_assets/{journal_id}`, `agent/analyze-invoice`,
  `create_bill`, `list_ap_vendors`, `funds_list`, `account_list` — all match
  noble-go-server api/routes.go registrations under the `/:company/v1` group.
- **snake_case fields**: CodingKeys checked one-by-one against CONTRACT.md
  (upload ticket, asset row, attach req/resp, create_bill req/resp §4,
  analyze req). All correct; also asserted in unit tests.
- **amount-as-string**: `CreateBillExpenseLine.amount: String`
  (BillService.swift:103); test asserts `line["amount"] as? String == "1250.00"`.
- **RFC3339**: `BillFormView.rfc3339DateOnly` emits `yyyy-MM-dd` + `T00:00:00Z`
  with en_US_POSIX; unit-tested (`2026-06-28T00:00:00Z`).
- **booked:false**: hardcoded literal in `BillFormView.save()` (line 368);
  test asserts `json["booked"] as? Bool == false`.
- **Attach only after confirm**: `uploadAsset` = upload_url → PUT → confirm;
  `InvoicesView.uploadedAssetId` set only after `uploadAsset` returns (i.e.
  post-confirm); `BillFormView.attachDocumentIfNeeded` runs only with a
  server-returned `savedJournalId` and non-nil `assetId`. Confirm never
  attempted after failed PUT (unit-tested: methods == ["POST","PUT"]).
- **Failure semantics preserved**: failed upload keeps `capturePayload` in
  memory with Retry Upload; failed analysis keeps `uploadedAssetId` with
  Retry Analysis + manual-entry hint (asset still attached on save); failed
  attach keeps the saved bill and offers Retry Attach; ""/0 extraction → nil
  prefill (`makePrefill`, unit-tested both directions).
- **D9/D10 parity**: vendor default account applied only when the exact
  account/child pair exists in the chart (`applyVendorDefaults`); fund never
  defaulted; Save gated on vendor+fund+account+invoice_no+amount>0
  (`canSubmit`); manual tab uses the same BillFormView/create_bill path; the
  old `submitInvoice` inline-form path is gone from InvoicesView.

## 2. Desktop fixes F1–F4 present — PASS

- **F1** — `uploadAsset` ends at confirm and returns the confirmed
  `AssetRecord`; no download_url step, no `UploadedAsset` type
  (AssetService.swift:171-180). Test `uploadAssetRunsThreeStepFlow` asserts
  exactly 3 requests.
- **F2** — `startNewBill()` resets every field + save state and calls
  `onDone?()`; the manual tab works without onDone because the reset is
  in-place (BillFormView.swift:405-420). Capture flow wires
  `onDone: { resetCapture() }` and re-identities the form via
  `.id(uploadedAssetId ?? "no-asset")`.
- **F3** — `.fileImporter(allowedContentTypes: [.image, .pdf])` present;
  `makeCapturePayload` routes PDFs (extension or %PDF magic) through
  unchanged as `application/pdf` with `isAnalyzable == false`;
  `uploadAndAnalyze` gates analysis on `isAnalyzable`; UI explains PDFs are
  attach-only. Four unit tests cover the routing.
- **F4** — QuickLook temp file written with
  `[.atomic, .completeFileProtection]` and deleted in the sheet's
  `onDismiss` via the tracked `lastPreviewFileURL`
  (BillDocumentsView.swift:81-87, 172).

## 3. Mobile rulings — PASS

- **M-D1**: VisionKit `VNDocumentCameraViewController` is the camera path
  (DocumentScannerView, InvoicesView.swift:757-798); zero occurrences of
  `UIImagePickerController` in the working tree. Multi-page scans upload
  page 1 with an explicit user-facing note.
- **M-D2**: grep for `"public"` across all new/changed production files:
  the ONLY hit is APIService.swift:1523 (`tenant.isEmpty ? "public" : tenant`)
  — byte-identical to HEAD, i.e. pre-existing, not introduced by the port.
  Tenant pinning (`service.tenant = "public"`) appears in test files only,
  which M-D2 allows. No `v1BaseURL`, no `/public/api`, no Desktop crutch.

## 4. No regression to existing APIService callers — PASS

- `init()` → `init(session: URLSession = .shared)`: default argument keeps
  all six existing `APIService()` construction sites compiling unchanged
  (nbledgerApp.swift:12 + five preview sites); @Observable/@Environment
  wiring untouched.
- `request`/`decoder` widened private → internal: visibility-only.
- `URLSession.shared.data(for:)` → `session.data(for:)` in `request` and the
  refresh path: identical behavior with the default session.
- `analyzeInvoice` gained `mediaType` with default `"image/jpeg"` — existing
  call shape unchanged (unit-tested).
- Build green; full unit suite green (§5).

## 5. Build + tests — PASS

- `xcodebuild -scheme nbledger -destination 'platform=iOS Simulator,id=C308E43F-9489-44B4-A35C-3B9D07A16276' build`
  → `** BUILD SUCCEEDED **`
- `… -only-testing:nbledgerTests test` → `Test run with 24 tests in 3 suites
  passed` / `** TEST SUCCEEDED **` (24/24: 9 asset/analyze, 14 bill/prefill/
  payload, 1 pre-existing example). The two login-dependent UI screenshot
  failures are known/pre-existing and out of scope (not run).

## 6. Adjudication: M2's Payments-tab claim — CLAIM IS WRONG (no breakage)

M2 reported the Payments tab "still rides the known-broken legacy base per
D8" via `fetchApTransactions`. Verified three ways:

1. **Code**: this repo has a single tenant-aware base — `fetchApTransactions`
   (APIService.swift:1884) calls `request("/read_ap_transactions")`, which
   resolves to `{host}/{tenant}/v1/read_ap_transactions`. There is no legacy
   `/public/api` base anywhere in this repo.
2. **Server**: api/routes.go:210 registers
   `noble.GET("read_ap_transactions", server.ReadAPTransactions)` inside the
   tenant-scoped `/:company/v1` group (server.go:200).
3. **Live**: `GET /public/v1/read_ap_transactions` → **HTTP 200** with real
   AP transaction rows whose fields (transaction_date, vendor_id, status,
   amount, description) match the app's `Payment` model.

D8 is a **Desktop-repo** ruling about Desktop's broken legacy base; it does
not describe this repo. Nothing 404s. The note in M2's report was Desktop
context bleeding into a mobile claim and should be disregarded.

## 7. Security sweep — PASS (with notes)

- `grep -ri "anthropic|x-api-key|sk-ant|nbk_|api.anthropic"` over nbledger/,
  nbledgerTests/, nbledgerUITests/: **zero hits**. No embedded AI keys, no
  direct AI-provider calls (analysis goes to our server's
  `/agent/analyze-invoice`, test-asserted).
- Zero `print`/`NSLog`/`os_log`/`Logger` statements in any new/changed
  production file; signed URLs never logged or persisted —
  BillDocumentsView fetches a fresh URL per preview and stores only the
  downloaded bytes.
- Authorization: `request()` sends `Bearer <token>` on API calls; the GCS
  PUT (`putAssetBytes`) sends no Authorization (unit-test asserted); the
  signed-URL GET uses a bare `URLSession.shared.data(from:)` — no auth
  header added. Correct on all three.
- Temp files: protected (`.completeFileProtection`) and deleted on dismiss.
- Notes (non-blocking):
  1. If the preview sheet is never dismissed normally (app killed mid-
     preview), the temp file survives until OS cleanup — same residual
     behavior class as Desktop's F4 note; acceptable.
  2. `handleImportedFile` reads the imported file synchronously
     (`Data(contentsOf:)`) on the main actor — a very large PDF could hitch
     the UI briefly. Cosmetic; consider a Task offload in a follow-up.
  3. The signed-URL GET in BillDocumentsView uses `URLSession.shared`
     rather than the injectable `apiService.session` — no security or
     behavior issue, just untestable via the URLProtocol seam.
  4. New `nbledgerUITests/LoginFlowTests.swift` (a live-login UI probe with
     a fake credential and `print()` of test state) is riding uncommitted in
     the same tree. Harmless — UI-test target only — but decide whether it
     belongs in this feature's commit.

## 8. Live READ-ONLY walk — PASS (no writes performed)

Auth: the `nbk_` integration key from the Desktop repo config (never printed).
No mutating endpoint was called.

| Check | Result |
|---|---|
| GET `/public/v1/assets` | **200** `[]` (JSON array — key's user scope has no assets, matches Desktop T4) |
| POST `/public/v1/agent/analyze-invoice` (base64 of a 1x1 synthetic JPEG, media_type image/jpeg) | **200** exact six-field shape `{"vendor_name":"","invoice_number":"","amount":0,"date":"","due_date":"","description":""}` |
| GET `/public/v1/read_ap_transactions` | **200** array of AP rows (§6 adjudication) |

Known carried-over gap (same as Desktop T4 / plan M3): `upload_url`,
`create_bill`, and `attach` require a user-bound identity and 401 with this
integration key, so the live write chain remains unexercised by an
independent verifier. Confidence rests on the contract-exact unit tests
(24/24), this static review, and the Go handlers. A one-time simulator walk
with a real Firebase login would close it.
