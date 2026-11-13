# Parking refactor

## A — Baseline and contract

- Flutter/Riverpod customer + staff, React/TypeScript admin, Supabase RPC/RLS, Drift outbox. Migrations 001–008 are immutable. Existing working tree: untracked `Reports/`, `supabase/.temp/`; preserve both.
- Existing: operation receipts, plate OCR on device (ML Kit), cash checkout/minimum one hour, no-show deletion, extension, push queue. Reminder lead time is **10 minutes** (reuse it).
- Replace individual parking-space allocation with per-lot **car/motorcycle capacities**. Vehicle kind and plate on a ticket are immutable snapshots from the owned vehicle. No inferred legacy plates/kinds. Backfill only from the linked vehicle; abort with an actionable error for unresolved active tickets.
- Capacity is maximum simultaneous occupancy over a half-open interval `[start,end)`, not the total number of tickets overlapping any portion. Overdue parked vehicles occupy capacity without an assumed departure until actual checkout. Non-overdue vehicles retain their scheduled interval; entry checks physical capacity again.
- Serialize mutations on lot rows and normalized plate advisory locks. Retain operation receipts and parking-event/payment uniqueness. Existing historical slot IDs remain archival; new tickets have no slot. Retire old map/QR RPCs from client access.
- Staff confirms OCR/manual plate and lot before online lookup; entry requires an unexpired booking within the existing 15-minute early-entry allowance. Checkout retains actual-time pricing and cash confirmation. No offline ticket lookup; any outbox transition waiting for acknowledgement is explicitly shown as pending, not server approval.
- Reports expose the submitted plate/description/status/history, never owner identity. Only the lot owner can request a move or assign active staff; assigned staff may progress/resolve; reporters read only their reports.
- Owner-approved conversion: each vehicle kind receives the old **enabled** slot count. Admin can adjust both independently, including zero. No Cloud migration, push or release in this task.

## Acceptance / verification

- B: upgrade legacy fixtures without loss; reject full intervals; adjacent intervals work; two DB sessions contesting the last unit admit exactly one; reductions reject peak confirmed/parked occupancy.
- C: plate normalization, cross-lot/role denial, repeat entry/exit and lost-ACK retries, no-show expiry, overdue occupancy, full extension, reminder schedule/deduplication; retain one payment per checkout.
- D: reporter → owner → owner notification/assignment → staff resolution; invalid transitions and unauthorized users denied; no owner PII in report response.
- E: trace/remove replaced UI/routes/dependencies; analyzer, Flutter tests, admin typecheck/build/tests, SQL migrations/concurrency, push transport tests. Camera and real FCM delivery require a real device/service.

## Progress

- A: source and Git inspection complete. All requested skills are available. Postman CLI is absent; use repository SQL integration tests and existing Supabase HTTP simulator instead. Security review is focused source review; this Windows host does not provide all isolation controls required for dynamic security-audit probes, so no live service probing.
- B: migration 009 applied to a disposable PostgreSQL 18 database populated through schema 008. Fingerprints confirm every existing ticket/payment field is preserved. Full-capacity, adjacent intervals, reductions and two independent users/plates contesting the last unit all pass.
- C: SQL plate lookup/normalization, repeated entry/exit (one event/payment), full extension, successful extension, overdue occupancy, deadline deduplication and slot-free no-show deletion pass. Flutter uses on-device OCR or manual confirmation; the scanner form returns after successful entry/exit. Account changes cannot receive an old booking/lookup response.
- D: SQL reporter → owner move request → staff assignment → progress/resolution, history and negative permission cases pass. Reporter cannot read vehicle-owner profiles; staff ticket access no longer grants customer profile access. UI tests cover report submission/lost response, assigned-staff resolution, owner actions/history and capacity rejection reasons.
- E: individual-space widgets/routes and QR UI/capability parsing removed; mobile_scanner, qr_flutter and transitive qr removed using offline package cache. Geographic lot map retained. Old slot/QR data and original migrations remain archival; deprecated map RPCs and table access are revoked. A destructive cleanup proposal was rejected by automatic review; no receipt/history redaction or old-function deletion is performed.

## API contract (authenticated Supabase RPC)

- `booking_availability(p_lot_id,p_start,p_end,p_vehicle_id)` → `{capacities:[{kind,capacity,remaining}],vehicle_conflict:null|{plate}}`. No foreign ticket/owner information. A legacy response without capacities produces an explicit migration-required error.
- `manage_lot` now takes `p_car_capacity` and `p_motorcycle_capacity` instead of `p_capacity`, with the existing metadata/expected-version arguments. `CAPACITY_CONFLICT` includes the kind and minimum required count in error details.
- `apply_operation(operation_id,kind,payload)`: booking.create uses owned vehicle_id + lot_id + starts_at/ends_at + id; the server derives plate/kind/rate. cancel/extend retain booking_id/expected_version. staff.lookup uses lot_id/plate; staff.check_in/check_out use booking_id/expected_version/plate/occurred_at. No QR field required. Exact operation retries replay receipts; repeated transitions also cannot duplicate entry/payments.
- report.create: id/lot_id/plate/description. report.request_move: report_id/expected_version. report.assign adds staff_id. report.progress adds status (in_progress/resolved; owner may reject). Existing operation IDs/receipts apply. Snapshot adds reports/report_events and privacy-safe current capacities.
- Relevant typed errors: CAPACITY_FULL, CAPACITY_CONFLICT, VEHICLE_TIME_CONFLICT, VALID_TICKET_REQUIRED, PLATE_AMBIGUOUS, VERSION_CONFLICT, FORBIDDEN, PARKED_OWNER_NOT_FOUND, STAFF_NOT_ASSIGNED. Ambiguous legacy plates require operator review; no guessed ticket is admitted.

## Reproduce / rollout

- `node tools/test_backend.mjs --pg-bin D:/PostgreSQL/18/bin --demo-seed`: real temporary DB, full migration chain, preserved-history fingerprint, concurrency, reports/RLS, both demo account configurations and non-destructive seed rerun. No Cloud writes.
- `flutter analyze --no-pub`; `flutter test --no-pub`: controller/widgets, narrow screens/dark mode, OCR suggestion handling, SDK HTTP simulator, cash/outbox and report workflows.
- In admin-web: `npm run build` and `npx playwright test`. API traffic is intercepted with fixture accounts; PostgreSQL tests separately verify real permissions/state.
- `node --test tools/push_dispatcher.test.mjs tools/firebase_config.test.mjs`: 19 passed, including fake FCM/transport failures. OCR itself has no external service; image recognition accuracy still needs real camera images.
- Both Flutter web entry points built successfully. Android debug builds are local verification only; see final verification below.
- Before installing this version against a real backend: back up DB, apply migrations 009 then 010 through the repo's Supabase migration workflow, verify capacities, and upgrade customer/staff/admin together. Old clients use incompatible slot-based booking/QR contracts. No production migration, live account E2E or release was executed.
- Background reminders retain the existing **10-minute** lead time in smartpark_private.process_deadlines (introduced in 008); change through a new migration, not by rewriting applied migrations. Existing cron/FCM dispatcher is reused.
- Not verified here: real-device OCR/camera permission/haptics, actual phone FCM delivery, production cron deployment. Local OCR outputs and push HTTP responses are fixtures. Strict isolated dynamic security probing is unavailable on this Windows host; focused source review plus the explicitly requested functional DB permission tests were performed.

## Final verification

- Analyzer: no issues. Flutter: **163 passed**. Admin: **44 passed**, plus screenshot review of a populated report at 390/1440 px; final CSS retest is recorded in the same log. Push/config: **19 passed**.
- SQL: full 001–010 migration chain, unchanged historical ticket/payment fingerprints, last-capacity race (different users/plates), booking/plate/deadline/extension/report/permission checks, and both seed configurations all passed. Seed reruns preserve edited prices/capacities and operational transitions.
- Builds: admin production, customer/staff web release, customer/staff Android debug all succeeded. Android build rerun after scanner reset: staff 41.9 s, customer 35.8 s. Existing Vite chunk-size and Android Java/ML Kit warnings are non-fatal.
- No Android device is attached (adb devices); real camera/OCR accuracy and physical haptic feedback remain unverified. No actual FCM message was sent. UI/API simulation results do not establish live Cloud behavior.
- Focused security review: checked SECURITY DEFINER search paths, RPC grants, lot ownership/staff membership, ticket ownership/plate matching, RLS on reports/history/profiles, operation receipts and transitions. Fixed SQL NULL authorization on unassigned reports and stale booking/lookup responses after account changes; functional regression tests cover these boundaries.
- All changes remain uncommitted on release/booking-fix-v1.2.1. Reports/ and supabase/.temp/ remain untouched. Logs/screenshots/builds stay in ignored .smartpark/ and build/ paths. No Cloud migration, Git push or release occurred.

## Prepaid booking update — 2026-11-12

- Customer flow: vehicle type → time → **Tiếp tục** → confirmation → **Thanh toán** → QR payOS or existing wallet balance. Normal booking skips the capacity-selection page; backend capacity validation remains mandatory.
- Migration **012** adds `bookings.prepaid` (default false for existing tickets) and makes `payments` the wallet debit/refund ledger. New `booking.pay` / `booking.extend.pay` operations derive fees on the server, debit and mutate the booking in one transaction, and replay the same receipt after a lost response. Client `expected_amount` is only a price-change guard. Direct unpaid `booking.create` is rejected after rollout.
- New reservations charge the reserved duration, rounding up to at least one hour. Prepaid extensions charge only the duration between the old and new scheduled ends. Existing cash tickets keep their previous checkout/extension behavior. Prepaid checkout records the actual exit without charging the reserved fee again. No new overtime penalty or gate-blocking policy is introduced; staff sees a reminder to ask for an extension.
- A valid cancellation uses the existing authorization/time/version rules and returns the entire prepaid amount to the wallet, never to a bank account. A negative `wallet_refund` payment reverses revenue and credits the wallet exactly once. Admin reports distinguish cash/QR/wallet/refunds and do not count prepaid parked tickets as unpaid revenue.
- QR reuses `payos-topup`, the configured credentials and the existing webhook URL/signature verification. Its top-up row stores the immutable booking request and operation ID. Provider settlement credits the wallet and automatically attempts the corresponding debit/booking. There is no slot hold while QR is pending: if the schedule/capacity changes, the verified money stays available in the wallet, with an explicit customer message to rebook. Retries cannot create another debit. The QR page is the existing hosted payOS checkout.
- Paid no-shows become expired and release capacity, retaining their ticket/payment records for financial history. Existing unused unpaid no-shows retain the previous deletion policy. Reminders retain the existing 10-minute lead and end-based deduplication; a successful paid extension updates the end before future reminders are generated.
- Verification: applied migrations **001–012** to a fresh local PostgreSQL test database and passed `supabase/tests/prepaid_bookings.sql`: server pricing, wallet debit/replay, capacity rejection without debit, foreign cancellation denial, wallet refund/replay and revenue reversal, paid extension/replay, checkout without a second charge, verified QR/replay, full-capacity QR credit fallback, and service-only settlement. The local test server was stopped. Flutter test startup returned no result and was stopped; updated widget/domain tests are present but have not passed in this session. No app/APK build or live bank transfer was run.
- **Not deployed:** apply 012 after 011, then deploy the updated `payos-topup` function and update customer/staff/admin together. Secrets and webhook registration stay unchanged. Cloud still uses its previous behavior until that rollout; no production database migration, function deployment, Git push or release was performed for this update.

