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

Lifecycle: confirmed → parked → completed, or confirmed → cancelled. Customers
can cancel before the planned start. Owners may cancel confirmed reservations.
Expired reservations cannot check in but remain in history; expired time ranges
do not block a later reservation. No job silently charges or deletes tickets.

## Offline and reconciliation

Drift stores per-user snapshots and a durable ordered outbox. Reads use the last
snapshot; connectivity events trigger an attempt but only a successful API call
establishes reachability. RPC calls have timeouts. Transient failures use capped
exponential delay. No plaintext password is cached. Sign-out is blocked while
commands remain; explicit queue review/discard is available. Account changes
clear in-memory selections.

Allowed queued commands: staff.check_in, staff.check_out, vehicle.save and
notifications.read. Booking creation/cancellation and pricing require online
acceptance. A reservation never receives a success QR solely from local state.
An ambiguous online booking retry retains its ID during the running session;
the vehicle/time constraint also prevents overlapping reservations after restart.

Staff can record check-in then check-out offline for a cached authorized ticket.
Presentation projects pending state to allow the next action and labels it pending;
each command references the next expected version. Replay preserves order. A
conflict/rejection is retained for review and blocks later commands. No automatic
last-write-wins can overwrite money or occupancy. Pending vehicle edits appear in
the queue; the vehicle list shows server-confirmed records until acceptance.

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
