# SmartPark architecture

```
lib/domain/                 Dart contracts, rules, failures and QR identity
lib/data/                   Supabase SDK, Drift SQL and on-device ML Kit adapter
lib/presentation/           Riverpod-owned controller and view models
lib/presentation/features/  Existing Customer / Staff UI grouped by feature
lib/app/                    Composition root, concrete providers and route guards
lib/shared/                 Existing reusable visual components
```

Domain has no Flutter/UI dependency. `ParkingRepository` and
`PlateRecognitionService` are Domain interfaces. Composition selects concrete
adapters; screens access the controller instead of issuing SQL or Supabase calls.
The ChangeNotifier controller is owned/watched by Riverpod, with a separate
Riverpod theme provider.

## Online commands

`apply_operation(operation_id, kind, payload)` authenticates the actor, checks
membership/ownership, validates the expected booking/vehicle version and changes
state in one PostgreSQL transaction. A receipt bound to actor + operation ID
returns the prior result on an exact retry. Reusing an ID for a different payload
fails. Exclusion constraints protect overlapping slot and vehicle reservations;
partial unique indexes protect parked slots, active vehicles and one payment per
ticket. Fees are taken from the lot and snapshotted at booking time.

A booking trigger increments its public slot revision. Customers receive this
slot event even though RLS prevents reading another customer's booking/QR, then
reload privacy-safe availability. Reconnect and periodic refresh cover missed events.

Lifecycle: confirmed → parked → completed, or confirmed → cancelled/expired. Customers
can cancel before the planned start. Owners may cancel confirmed reservations.
Server maintenance moves unused confirmed bookings to expired at their end time.
Expired reservations remain in history with zero revenue. Parked vehicles never
expire: only an authorized checkout creates a payment. No job silently charges
or deletes tickets. See [NOTIFICATIONS.md](NOTIFICATIONS.md).

## Offline and reconciliation

Drift stores per-user snapshots and a durable ordered outbox. Reads use the last
snapshot; connectivity events trigger an attempt but only a successful API call
establishes reachability. RPC calls have timeouts. Transient failures use capped
exponential delay. No plaintext password is cached. Sign-out is blocked while
commands remain; explicit queue review/discard is available. Account changes
clear in-memory selections.

Synchronization is automatic while the app is running: on startup/auth recovery,
on connection restoration, on foreground resume and every 20 seconds in the
foreground. A snapshot request verifies server reachability before replay;
successful replay is followed by a fresh snapshot. This also detects Internet
recovery on the same Wi-Fi without requiring a new transport event. On Android,
transport is rechecked on resume because background connection events may be missed.

Reconnect/resume clears transient retry delays only for the current account's
pending commands. Conflicts remain blocked, payloads and operation IDs remain
unchanged, and concurrent refresh requests are coalesced without dropping a
reconnect signal. Polling pauses outside the foreground; no always-running OS
background worker is claimed. Persisted commands resume automatically when the
app is reopened. The account screen exposes synchronization status, not a
required manual sync action; exceptional conflicts still need review.

Allowed queued commands: staff.check_in, staff.check_out, vehicle.save and
notifications.read. Booking creation/cancellation and pricing require online
acceptance. A reservation never receives a success QR solely from local state.
An ambiguous online booking retry retains its ID during the running session;
the vehicle/time constraint also prevents overlapping reservations after restart.

Staff can record check-in then check-out offline for a cached authorized ticket.
Presentation projects pending state to allow the next action and labels it pending;
each command references the next expected version. Replay preserves order. A
parking-event conflict is retained for review and blocks later commands. No automatic
last-write-wins can overwrite money or occupancy. Pending vehicle edits appear in
the queue; the vehicle list shows server-confirmed records until acceptance.

Online editable commands are durably staged with their idempotency key before
sending. A definitive business rejection is removed immediately and thrown to the
form, which stays open. Only ambiguous transport errors remain pending. Cached
active-booking/duplicate-plate/QR/time checks reject known invalid edits offline.
An editable command rejected during later replay becomes a persisted `rejected`
notice, excluded from pending/retry/sign-out blocking; the user sees the reason
and can dismiss it. Existing vehicle conflicts migrate to this notice state.
Physical check-in/out observations retain explicit conflict review.

## Deadline notifications

Migration 004 wraps the existing RLS snapshot and command RPCs with authenticated,
scope-limited deadline maintenance. A private global worker is reserved for cron.
Booking locks serialize expiry with check-in/out. Unique notification dedupe keys
prevent repeated reminders on periodic refresh or cron runs.

Supabase stores the authoritative inbox plus RLS-protected, client-inaccessible
device tokens/jobs. User token registration uses auth.uid(); claims and ACKs are
service-role-only. Optional Android FCM sends notification payloads while the app
is closed; foreground presentation uses a local notification. Domain exposes the
DeviceNotifications contract and the composition root selects the Firebase adapter.
The cron-authenticated Edge worker uses OAuth HTTP v1, leases, bounded retries and
stable tags; stale pickup reminders are cancelled on claim. Actual delivery is
at least once and requires external Firebase/cron setup and device permission.

Observed staff timestamps are audited alongside server receipt time. Commands
older than 24h or more than 5min in the future require review. Fees are zero within
the grace period; otherwise full elapsed hours round up from actual check-in.
Grace minutes are not subtracted afterward.

## Platform boundaries

QR contains a random capability and ticket UUID, checked with state, role and plate
on the server. OCR uses ML Kit Latin text recognition on camera photos; extraction
is conservative and staff must verify/edit it. This is not a custom trained
license-plate model. Bundled Android models support offline OCR and QR. Web supports
QR scanning/manual entry but not ML Kit.

Map markers use real configured coordinates. OpenStreetMap tiles need a network;
cached listing/operational data remains usable offline. No offline basemap download
is implemented. Material 3, safe areas, responsive width and dark palettes retain
the existing visual language. 60fps is a target requiring real device profiling.
