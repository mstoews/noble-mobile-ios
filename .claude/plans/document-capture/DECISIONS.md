# Document Capture (iOS port) — Mobile Decisions

Desktop rulings D1–D11 in
/Users/murraytoews/Desktop/nbledger/.claude/plans/document-capture/DECISIONS.md
are binding here too. Mobile-specific rulings:

M-D1: Camera path stays VisionKit.
→ Keep `VNDocumentCameraViewController` as the scanner; do not port Desktop's
UIImagePickerController CameraView.
→ Why: the document scanner (edge detection, multi-page, de-skew) is strictly
better capture UX for receipts and is already shipped in this app.

M-D2: Base URL / tenant handling.
→ Use this repo's existing tenant-aware `baseURL` (host + slug + "/v1") for
all ported calls. Do NOT port Desktop's `v1BaseURL`/hardcoded `company =
"public"` — that was a Desktop-repo crutch (its legacy base was broken).
Nothing tenant-specific may be hardcoded in ported code.
→ Why: this app already runs multi-tenant with the correct scheme.

M-D3: Integration approach for the service layer.
→ Widen APIService `request`/`decoder` to internal, add injectable `session`,
and port AssetService/BillService as separate extension files matching
Desktop's layout (adapted per M-D2).
→ Why: keeps file-level parity between the two repos so future fixes port
1:1, and the session seam is required for the URLProtocol test suites anyway.

M-D4: The port includes the Desktop fix round.
→ F1 (uploadAsset success = confirm, returns AssetRecord), F2 (form reset via
onDone), F3 (fileImporter; PDFs attach-only), F4 (QuickLook temp cleanup +
file protection) are part of the port's acceptance, not optional extras.
