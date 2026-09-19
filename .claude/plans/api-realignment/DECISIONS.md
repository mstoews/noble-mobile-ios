# API Realignment — Decisions

Rulings for the realignment work. A-D* are settled; A-O* are OPEN and need
the owner's call before the task that depends on them starts. Findings
referenced as F1–F13 live in ./FINDINGS.md.

## Settled

A-D1: The session token replaces the Firebase token wholesale.
→ `POST /v1/auth/login` is the only login path. Store `session_token` where
`authToken` lives today and keep sending it as `Authorization: Bearer`. Delete
the Firebase API key, `performTokenRefresh`'s `securetoken.googleapis.com`
call, and the `refreshToken` storage it fed.
→ Why: F1 — Firebase ID-token acceptance was removed from the middleware, so
there is no migration path that keeps any part of the old flow working.

A-D2: Refresh rides the HttpOnly cookie, not a stored token.
→ `POST /v1/auth/refresh` with no body; let URLSession's shared
`HTTPCookieStorage` carry the cookie. Do not attempt to read, persist or
inspect the refresh cookie — it is HttpOnly by design and rotates.
→ Why: F1. The server reads it from the cookie (`api/auth_login.go:260`);
there is no body-borne refresh token to store.

A-D3: Keep the biometric gate; re-point it at refresh.
→ The existing lock-on-expiry → Face ID → silent-refresh flow stays. Only the
refresh call underneath changes. Biometrics must never be presented as
authentication to the server — it unlocks the app so the refresh can run.
→ Why: preserves the shipped UX and the "no password re-entry" property that
`ContentView` and `BiometricGate` are built around.

A-D4: `expected_updated_at` is threaded through, never faked.
→ Every OCC-guarded write carries the `updated_at` the client last read for
that row. If the app does not have one in hand, it re-reads the row first. Do
not send `now()`, an empty string, or a remembered-from-elsewhere timestamp.
→ Why: F5. The point of the token is to fail a stale write; synthesising one
re-opens the lost-update hole the server just closed.

A-D5: A 409 from an OCC-guarded write is a user-facing conflict, not an error
toast.
→ Surface it as "this record changed on the server — reload?" with a reload
action, distinct from the generic `APIError.serverError` path.
→ Why: the write is expected to fail sometimes by design; a generic failure
message trains the user to retry blindly, which is exactly what OCC is
supposed to prevent.

A-D6: Read `journal_status`, never `booked`, for bill posted-ness.
→ `journal_status == "CLOSED"` means posted; OPEN is draft; CANCELLED is
voided. `create_bill` requests keep sending `booked: false`, which the server
still accepts.
→ Why: F3. `booked` was a redundant mirror and is no longer returned.

A-D7: Spec paths are trusted; spec schemas for the payments family are not.
→ When porting anything in the payments/receipts area, read
`noble-go-server/db/sqlc/models.go` and the handler, not `docs/openapi.json`.
→ Why: F9. `api/openapi_drift_test.go` guarantees paths only, and the payments
schemas still describe the retired `ap_transactions` shape.

A-D8: Server-side defects get filed against noble-go-server, not worked
around here.
→ F9 (stale payments schemas) and F13 (wrong `servers[0]` URL) are server
repo tasks. This plan records them and stops there.
→ Why: a client-side workaround for a stale spec makes the next client
generation wrong in the same way, silently.

A-D9: Dead client code is deleted, not fixed.
→ `fetchPaymentsByDate` (`APIService.swift:2019`) and `fetchPaymentById`
(`:2001`) have no call sites and target changed contracts (F6). Delete them
with the rest of the retired `Payment` surface rather than porting them to
the receipts shape speculatively.
→ Why: keeping a compiled-but-wrong wrapper around invites a future caller to
trust it.

A-D10: Refresh is single-flight.
→ One rotation at a time, with concurrent callers awaiting the same task.
→ Why: the server revokes the refresh token it is handed and treats a second
presentation as theft, burning every session the user has once a 30-second
grace window passes (`api/auth_login.go:292`, `refreshReuseGrace`). Session
tokens last 15 minutes and the dashboard fires six reads at once, so parallel
401s would otherwise rotate in parallel. Covered by
`concurrentUnauthorizedRequestsRotateTheSessionOnce`.

A-D11: No `public` fallback for the tenant slug, ever.
→ Tenant-scoped requests refuse an empty tenant rather than addressing a
default, and login rejects `public`/`information_schema`/`pg_*` client-side.
→ Why: F14. `public` is the template every tenant is cloned from and the
server refuses it on all paths; the old fallback pointed at the seed ledger.

A-D12: The client tracks `refresh_expires_at`, not the refresh token.
→ The refresh credential is an HttpOnly cookie and unreadable by design, so
the expiry handed back at login is what decides lock-and-retry (biometric
unlock → rotate) versus full sign-out. It is extended on rotation, never
cleared by a response that omits it.
→ Why: `handleUnauthorized` used to branch on whether a refresh token string
was held, and there is no longer a string to hold.

A-D13: Sign in with Apple is removed, not disabled. (Owner's call, 2026-09-19;
was A-O1.)
→ The button, `handleAppleCompletion`, `loginWithApple`, the nonce helpers and
the `com.apple.developer.applesignin` entitlement are gone.
→ Why: the server route was removed with Firebase auth (F1) and there is no
Apple → session exchange to call. A visible button that cannot complete a
login also fails App Store review.

A-D14: MFA is detected, not completed — for now. (Was A-O2.)
→ `logIn` returns `.mfaRequired(challengeID:factors:)` and the login screen
says two-factor sign-in must be finished on the web. `/v1/auth/mfa/select`
and `/mfa/verify` are not implemented.
→ Why: MFA only triggers for accounts with *confirmed* factors
(`api/auth_login.go:193`), so this is not on the common path, and detection is
a strict subset of the full flow — adding the factor picker later changes no
existing behaviour. Revisit when a tenant user enrols.

## Open — owner's call required

A-O3: What the Payables tab becomes. **Blocks A2.**
→ The `ap_transactions` model it was built on no longer exists (F2). Options:
(a) rebuild the list on `read_aging_bills_by_period` + the bill detail
endpoints, with `schedule_bill_payment` replacing "record payment";
(b) rebuild on `read_payments_by_date` (the new receipts table) as a receipts
register, which is a different feature; (c) hide the tab until the capture →
approve → pay loop is finished server-side.
→ Recommendation: (a). It matches what the tab is for (money owed by period),
reuses the vendor picker, and the bill surface is complete and documented.
Related: the capture-loop constraint already recorded in memory
(`create_bill` writes journal + approval and no `ap_bills` row), which is why
drafts still will not appear in a bills-backed list without server work.

A-O4: The Accounts tab grouping tiers. **Blocks A6.**
→ Both tiers are degraded (F10, F11). Options: (a) fetch `account_list`
alongside `account_balances` and join on `id` for `sub_type`, keeping both
tiers; (b) drop the sub-type tier and group by `acct_type` → account → child;
(c) ask the server for `sub_type` on `account_balances`.
→ Recommendation: (a) short-term — one extra GET the app already has a client
for, no server dependency — and file (c) as the durable fix. Either way the
`parent_account == true` lookup at `LedgerView.swift:47` must go.
