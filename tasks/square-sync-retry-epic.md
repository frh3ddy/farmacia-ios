# Square Sync Retry Epic

**Status**: ✅ DONE — merged `604abdc` (merge `cccecb0`); device check pending
**Branch**: `fix/square-sync-retry`
**Goal**: An owner can see and retry a receiving or adjustment that didn't sync to Square, from the screens that list them; activity lists color adjustments by the stock change they made.

## Overview

Every receiving and adjustment records `squareSynced` / `squareSyncedAt` / `squareSyncError` (farmacia-ops `prisma/schema.prisma`). When the push to Square fails, the app's stock and Square's drift until someone retries. The API has a retry for both, but the app has none reachable:

- `AdjustmentRow` shows "No sincronizado con Square" with a **Reintentar** button, but its handler (`onRetrySync`) was only passed by the removed adjustments list. Today every failed adjustment shows a permanently disabled button.
- `ReceivingRow` doesn't show sync failures at all, and nothing calls `.retrySquareSync(receivingId:)`.

Separately, the combined activity lists still color adjustments by type, so a count correction that removed stock shows green there (the rows were fixed in `f580589`).

## API contract (farmacia-ops `main`)

- `POST /inventory/adjustments/:id/retry-square-sync` and `POST /inventory/receive/:id/retry-square-sync`, both `@Roles('OWNER')`.
- Response is **HTTP 200 even when the retry fails**: `{ success: synced, message: "Successfully synced to Square" | "Square sync failed: <error>", data: { synced, error? } }`. The app must read `data.synced`, not the status code.
- Safe to repeat: an already-synced record returns `{ synced: true }` without calling Square, and the Square call uses the record id as its idempotency key, so a double tap or a retry racing another can't apply the change to Square twice.
- Since 2026-10-31 (farmacia-ops `717df0f`, `tasks/square-sync-retry-recorded-failures-epic.md`) the adjustment and receiving retries refuse (400) a record with no recorded failure, as the transfer retry does. The app already offers the retry only for a recorded failure (`SquareSync.failed`), so nothing changes in the app.
- Transfer adjustments are rejected (400). The app never creates them, but the error message must still show.
- The retry isn't in the offline queue's allowlist (`OfflineReplay`). Offline, it fails with `networkUnavailable`, which is correct: it needs Square.

## Logic (FarmaciaKit) / UI (FarmaciaApp) split

**FarmaciaKit (new `SquareSync.swift`, tested):** whether a record counts as a failed sync, who may retry, and how a retry response becomes what the user sees. It takes primitives, so `InventoryAdjustment` / `InventoryReceiving` stay in the app.

**FarmaciaApp:** the warning row and button shared by both rows, the retry calls and reloads in the two activity screens, and owner gating from `AuthManager.isOwner`.

**Migrate as touched:** nothing has to move. The combined-activity color rule is duplicated in `ProductActivityModels.swift:62-71`, `ProductActivityFullView.swift:82-91` and `GlobalActivityHistoryView.swift:303-309`. All three switch to the tested `StockChange`, and `Color` stays app-side. Their `displayQty` (`type.isNegative ? -abs(q) : q`) is redundant because the API's quantity is already signed. Drop it while in there.

---

## Steps

1. **Logic — what counts as a failed sync.** `SquareSync.failed(synced:error:)`.
   First failing test: *given squareSynced false and squareSyncError "LOCATION_NOT_FOUND", should count as a failed sync.*
   Then: *given squareSynced true with a leftover error, should not* · *given never attempted (false, no error), should not.*

2. **Logic — who may retry.** `SquareSync.canRetry(isOwner:)`, matching the API's `@Roles('OWNER')`.
   First failing test: *given a manager, should not offer the retry.*

3. **Logic — reading a retry response.** `SquareSync.RetryOutcome(synced:error:)` → `.synced` / `.failed(String)`.
   First failing test: *given a retry answered with synced false and error "LOCATION_NOT_FOUND", should fail with "No se pudo sincronizar con Square: LOCATION_NOT_FOUND"* (HTTP 200 is not success).
   Then: *given synced true, should be synced* · *given synced false with no error, should fail with "No se pudo sincronizar con Square".*
   A thrown error (offline, 400 for a transfer, 403) goes through the existing `SaveOutcome(error:fallback:)`. `.queuedForSync` can't happen because the retry isn't queued.

4. **UI — shared sync-status line.** A small view in `Products/Views` (register the new file in `project.pbxproj`). It shows "No sincronizado con Square" when step 1 says the sync failed. **Reintentar** appears only when a retry handler is passed, so there are no more dead disabled buttons. The view shows a spinner while the retry runs. `AdjustmentRow` uses it in place of its inline block, and `ReceivingRow` gains it.
   Smoke: none (not a critical flow).

5. **UI — retry from global history.** In `GlobalActivityHistoryView`'s view model, add `retrySync(receiving:)` / `retrySync(adjustment:)`. Each POSTs, maps the answer through step 3, shows the result in an alert, and reloads that list. Pass the handlers to the rows only when `SquareSync.canRetry(isOwner:)` allows.
   Smoke on a device: as owner, a failed row → Reintentar → the warning clears or the reason shows; as a manager, the warning shows with no button.

6. **UI — retry from a product's full activity.** `ProductActivityFullView` receives value arrays from `ProductDetailView`. Pass it retry closures that call the same retry and then reload `ProductDetailView`'s `activityViewModel`, so the list and the 5-row preview both update. Owner gating as in step 5.
   Smoke: same as step 5, from Productos → product → Ver Toda la Actividad.

7. **UI — activity colors by stock change.** In the three combined-activity builders above, take the icon color from `StockChange(quantity:)` (green / red / orange) and drop the redundant `displayQty`. This reuses `StockChangeTests`, so no new logic.
   Smoke: a count correction that removed stock is red in global history's "Todos" and in the product activity preview.

8. **Docs and graph.**
   - README's Inventory section: "Square sync status" becomes "Square sync status, with retry for owners".
   - The follow-ups epic's Square item points here.
   - Run `graphify update . --force`: plain `update` keeps nodes from deleted files (it still listed `InventoryView`).

## Done

Steps 1–8 implemented. `SquareSync` (failed / canRetry / RetryOutcome) in FarmaciaKit with tests; `SquareSyncStatusLine` (shared warning + Reintentar) and `SquareSyncRetry` (the call, outcome from `data`) in `Products/Views`; retry wired in global history and a product's full activity (owner only), each reloading its list; combined activity lists and `AdjustmentRow` color by `StockChange` via an app-side `StockChange.color`.

Limits: the product-detail preview (first 5 rows) shows no sync status; a product's failed sync is reachable from Ver Toda la Actividad (more than 5 items) or global history.

## Testing a failed sync

Square sync failures are rare on demand. To get one for the device check, receive or adjust a product with no Square catalog mapping at that store. Or ask farmacia-ops for a record already in `squareSyncError`: `SELECT id FROM "InventoryAdjustment" WHERE "squareSynced" = false AND "squareSyncError" IS NOT NULL LIMIT 5` (and the same for `"InventoryReceiving"`).

## Decided

- **Owner only,** matching the API. Managers and cashiers see the warning so they can tell the owner.
- **No automatic or bulk retry.** One record at a time, on demand. Revisit if failures pile up after cutover.
