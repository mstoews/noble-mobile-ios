# API Realignment — Decisions

Rulings for the realignment work. Findings referenced as F1–F17 live in
./FINDINGS.md. All decisions are now settled: A-O1/A-O2 became A-D13/A-D14,
and A-O3/A-O4 became A-D17–A-D19 (A-O4 overturned this plan's own
recommendation — see A-D19).

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

A-D15: The Banking cards show no balance, because no balance exists.
→ `list_bank_accounts` returns no balance field, and neither does
`read_bank_rec_snapshot`: Path B / Option II (locked 2026-04-29) rejected the
`reconciliation_session` table a statement balance would need, and records
that `cash_movements.journal_id IS NULL` is the single source of
"outstanding" with "no statement-balance side to subtract from the GL side".
The card now shows identity + GL mapping (institution, mask, subtype, GL
child, fund, paused state) instead of the old current/available figures,
which came from Plaid's own payload via the retired `/api/accounts` route.
→ Why: the alternative — joining `gl_child` against `/account_balances` to
show a GL book balance — is a product decision, not a routing fix, and a book
balance is not the bank balance the old card implied. Left as a follow-up for
the owner rather than decided here.

A-D16: Cash-movement amounts are read with the server's sign convention.
→ `+` is an inflow, `-` an outflow. The retired Plaid payload meant the
opposite, and the old row rendering hard-coded `amount < 0` as money in.
→ Why: reading it backwards inverts the arrow, the colour and the sign on
every row — wrong in a way that looks deliberate. Pinned by
`cashMovementSignConventionIsInvertedFromPlaid`.

A-D17: Payables is the bills surface, and creating a payable is not part of
it. (Resolves A-O3 as option (a).)
→ List from `read_aging_bills_by_period`; detail, approval and scheduling in
the shared `BillDetailView`; no create path.
→ Why: the `ap_transactions` routes are gone with no replacement for a
hand-entered AP transaction — bills enter through the capture flow's
`create_bill`. Adding a create path would mean inventing one.

A-D18: "Schedule a payment" is the only payment write the app offers.
→ `schedule_bill_payment` (future-dated, with a method and a source GL
account) is wired. Recording a payment already made is NOT — that is
`create_payment` → `create_payment_detail` → `post_payment`, a three-call flow
with its own approval semantics.
→ Why: A2's job was restoring a tab whose every call 404'd. The recording flow
is a feature in its own right, and half-building it would leave two ways to
register a payment, one of them broken. The sheet says so in its footer rather
than leaving the user to guess. Tracked as A10.

A-D19: The Accounts sub-type tier is dropped, not restored. (Resolves A-O4 —
and **overturns this plan's own recommendation of option (a)**.)
→ Group by account type, then parent account, then child. `Account.subType` is
deleted from the model.
→ Why: option (a) — "join `account_list` for `sub_type`" — is impossible.
`gl_accounts` has no `sub_type` column at all (F17); the spec's `GlAccount`
schema claims one, which is what made (a) look viable when the plan was
written. Option (c), asking the server for the field, is a schema change rather
than an API change, so it is a real ask rather than a quick follow-up. Keeping
a tier that buckets every account under "General" is worse than not having it.
