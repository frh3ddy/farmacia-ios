# Inventory Review Follow-ups Epic

**Status**: ✅ DONE (2026-10-31)
**Goal**: Fix what the 2026-10-30 reviews of `FarmaciaApp/Features/Inventory/` found, so that after cutover a user can adjust inventory, add products and see accurate money numbers.

## Overview

The receive and adjustment forms are reached only from a product's detail screen (Productos → product → Recibir Inventario / Ajustar Inventario), with the product fixed. The standalone Inventory screen (Recibir / Ajustes / Historial segments, product picker) had been unreachable since the Products hub replaced the Inventory tab (`bc7f68c`) and is now removed — so findings that needed it (Inventory tab reload, product switch in a form, picker limited to 50 products) never affected users.

The first review found three critical bugs: count correction computed its change from a stale or other-store stock snapshot, the Inventory tab didn't reload on a location switch, and every save tap made a new `clientRequestId`. A second review, focused on the post-cutover workflow, found two more that affect stock and cost. Those and the items marked ✅ below are merged to `main` (not yet pushed or deployed) and were checked on a device on 2026-10-30 (receiving, adjustments, product activity and global history); the 📋 items are still open, highest severity first.

---

## ✅ Count correction from live stock, one request id per form

Merged: iOS `b3c0918` (merge `9262a24`), farmacia-ops `9b40232` (merge `9b21958`). The form loads the current location's stock and sends `countedQuantity`; the API derives the change from its own stock. Offline count corrections are blocked.

---

## ✅ Receiving cost belongs to the selected product

Merged: `c2e3630` (merge `d046810`). Picking another product in the receive form kept the previous product's auto-filled `unitCost`, recording the receiving at the wrong cost. `ReceivingCost` clears the cost on a product change and ignores a supplier response for a product no longer selected. **Correction:** switching product was only possible through the unreachable picker, so this never happened in the app; `ReceivingCost` now only applies its fill rules (empty field, positive cost).

---

## ✅ Save errors shown inside the form

Merged: `c02f3ab` (merge `5dfd3ea`). Receive and adjustment save errors now show in an alert inside the open form, with the API's reason (`SaveOutcome`); the form stays open with its input. Seen in the 2026-10-31 simulator review: an Encontrado adjustment on a product with no cost asked for the unit cost inside the form, and the save showed its result in the form's alert. **Correction:** until `4a4c45e`, NestJS's plain exceptions (no `success` field) failed to decode and showed "Error HTTP: 400" instead of the reason — see below.

---

## ✅ Positive adjustments can carry a unit cost

Merged: `18bc267` (merge `9dcaf1a`). An adjustment that adds stock on a product with no cost on record (created without initial stock) was rejected — "Indica el costo unitario…" — and the form had no cost field. The form now shows an optional unit cost whenever the adjustment adds stock (`AdjustmentCost`). Narrowed below: it now appears only when the API asks.

---

## ✅ Unreachable Inventory screens removed

Merged: `789cc0f` (merge `e77976e`). Reported as "product picker sees only the first 50 products", but nothing opened the picker: `InventoryView` had no caller. Removed `InventoryView`, `ReceiveInventoryView`, `AdjustmentsListView`, `ReceivingHistoryView` and `ProductPickerView`; the forms now take a required `product`. `ReceivingRow` and `AdjustmentRow` (used by product activity and global history) moved to their own files in `Products/Views`. Product detail no longer fetches 50 products (and could no longer raise a spurious "Error al cargar productos") for the unused picker. `ProductListQuery.params(page:limit:)` now builds the Products tab's list query (also clears its Swift 6 capture warning).

---

## ✅ API error reasons reach the user

Merged: `4a4c45e` (merge `21f3d68`). `APIErrorResponse.success` was a required `Bool`, but NestJS's own exceptions (`BadRequestException('…')`, `ConflictException`, `NotFoundException` — about 115 throw sites in the API) send `{message, error, statusCode}` with no `success`. Decoding failed, so every one of them reached the user as "Error HTTP: 400/404/409" instead of its Spanish reason (e.g. "Las existencias cambiaron…"). `success` is now optional.

---

## ✅ Preferred supplier picked when the supplier list loads late

Merged: `fc2efde` (merge `21f3d68`). `PreferredSupplier.pick` (FarmaciaKit) runs when either list arrives — the product's suppliers or all suppliers — and never overrides the user's choice; the existing supplier `onChange` fills the cost.

---

## ✅ Adjustment cost asked only when the API needs it

Merged: iOS `4a4c45e` (merge `21f3d68`), farmacia-ops `74ff3e0` (merge `d44c7b7`). The API's no-previous-cost refusal now carries `code: 'UNIT_COST_REQUIRED'`; the app maps it (or the exact message, from an API without the code) to `NetworkError.unitCostRequired` → `SaveOutcome.costRequired`, and the adjustment form reveals its cost field only then (`AdjustmentCost.asksForCost(… costRequired:)`). Otherwise the API uses the last cost, as before.

---

## ✅ History rows and receive price check

Merged: `f580589` (merge `9fcbfc2`).
- Receiving history shows costs as currency (`$12.50/unidad`, `ReportFormat.currency`), not the API's raw `$12.5000/unit`.
- An adjustment row's color follows its signed quantity (`StockChange`), so a count correction that removed stock is red.
- With "Actualizar Precio de Venta" on, Guardar needs a positive price (`ReceivingForm.canSave`).

---

## 📋 Product detail redesign follow-ups (`tasks/product-detail-redesign-epic.md`)

- Given a product that normally carries 1–2 units (or sits at 0 for weeks), should flag low stock only below its own learned threshold (typical on-hand, time at 0) — farmacia-ops; until then the detail has no "Bajo".
- Given a product, should say how fast it sells (sell-through or last sold) — needs an endpoint from `SaleItem`; a line in Inventario.
- Given a lot with no caducidad, should let an owner add it from the lot row — needs a PATCH endpoint; "Sin caducidad registrada" is text only.
- Given one supplier on record, "Sin proveedor alterno · agregar" — needs an add-supplier-to-product flow on iOS.
- Given a product card and its detail, margins should agree — cards use average cost, the detail the latest supplier cost; decide whether cards follow (the list doesn't load suppliers).
- Given supplier notes "Migrated from cutover <uuid>" in the costs sheet, should hide the migration id.
- `ProductDetailView` is still one file of computed `some View` sections (swiftui-pro: extract `View` structs, own files — needs pbxproj registration); the aging bar still uses `GeometryReader`.
- Product photo guidance (package front) at capture time.

## 📋 Small fixes

- ✅ Given a create-product (or edit-price) response with no `data`, should show an error rather than nothing — `APIResponse.requireData()`, `4a4c45e`
- ✅ Given an adjustment whose Square sync failed, should offer a retry somewhere reachable — see `tasks/square-sync-retry-epic.md` (also covers receivings)
- ✅ Given an owner at Farmacia Lolita, product Actividad Reciente should show only Lolita's receivings/adjustments (it showed Oriente's Conteo inicial) — both product activity calls send `?locationId=`, `26cf20e`

---

## Decided not to do

- **Money as `Decimal` (2026-10-30).** Measured before planning:
  - Request bodies gain nothing. A typed amount (19.99, 12.35) encodes the same from `Double` as from `Decimal`, and the API requires JSON numbers (`typeof … === 'number'`) that it parses into JS doubles before `Prisma.Decimal`. No request sends a computed amount.
  - The only visible difference is on-screen math: with 4-decimal costs, a total or margin can round a half cent differently (3 × $0.335 shows `$1.00` with `Double`, `$1.01` with `Decimal`). This is display only; the server computes stored totals itself.
  - If this is ever revisited, build every `Decimal` from text (the field's format style or `Decimal(string:)`), never from a `Double`: `Decimal(19.99)` encodes as `19.98999999999999488`, worse than the `Double`.
- ~~**Lock stock during a count correction (farmacia-ops).**~~ Decided against here on 2026-10-30, then done in farmacia-ops on 2026-10-31: `e9786dc` locks a product's batches while a count is applied (merge `fa37f23`).
- **Key the product-detail inventory sheets on location.** Not needed: the count-correction form fetches stock for the current location itself.
