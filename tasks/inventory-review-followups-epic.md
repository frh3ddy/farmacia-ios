# Inventory Review Follow-ups Epic

**Status**: 🔄 IN PROGRESS
**Goal**: Fix what the 2026-10-30 reviews of `FarmaciaApp/Features/Inventory/` found, so that after cutover a user can adjust inventory, add products and see accurate money numbers.

## Overview

The first review found three critical bugs: count correction computed its change from a stale or other-store stock snapshot, the Inventory tab didn't reload on a location switch, and every save tap made a new `clientRequestId`. A second review, focused on the post-cutover workflow, found two more that affect stock and cost. Those and the items marked ✅ below are merged to `main` (not yet pushed or deployed); the 📋 items are still open, highest severity first.

---

## ✅ Count correction from live stock, one request id per form

Merged: iOS `b3c0918` (merge `9262a24`), farmacia-ops `9b40232` (merge `9b21958`). The form loads the current location's stock and sends `countedQuantity`; the API derives the change from its own stock. Offline count corrections are blocked.

---

## ✅ Receiving cost belongs to the selected product

Merged: `c2e3630` (merge `d046810`). Picking another product in the receive form kept the previous product's auto-filled `unitCost`, recording the receiving at the wrong cost (wrong FIFO batch → COGS, margin, valuation). `ReceivingCost` clears the cost on a product change and ignores a supplier response for a product no longer selected.

---

## ✅ Save errors shown inside the form

Merged: `c02f3ab` (merge `5dfd3ea`). Receive and adjustment save errors now show in an alert inside the open form, with the API's reason (`SaveOutcome`); the form stays open with its input. Not yet seen in the simulator.

---

## ✅ Positive adjustments can carry a unit cost

Merged: `18bc267` (merge `9dcaf1a`). An adjustment that adds stock on a product with no cost on record (created without initial stock) was rejected — "Indica el costo unitario…" — and the form had no cost field. The form now shows an optional unit cost whenever the adjustment adds stock (`AdjustmentCost`).

---

## 📋 Product picker sees only the first 50 products

`InventoryViewModel.loadProducts` calls `GET /products` with no `page`/`limit`; the API defaults to 50, newest first. `ProductPickerView` filters only those on the device, so older products can't be received or adjusted from the Inventory tab (the product-detail path is unaffected).

**Requirements**:
- Given a store with more than 50 products, should let the picker find any of them (server-side `search`, or page through `hasMore`)
- Given a search typed in the picker, should query the API rather than filter a partial list

---

## 📋 Money as `Decimal`

`unitCost` and `sellingPrice` are `Double` from the form fields through `ReceiveInventoryRequest`, and form totals are computed in `Double`. The adjustment unit cost added above is `Double` too. A wider change: the API models across the app use `Double`/`String` today.

**Requirements**:
- Given a cost or price entered, should keep it as `Decimal` through to the request body
- Given totals and margins on screen, should compute them in `Decimal`

---

## 📋 Preferred supplier not picked when the supplier list loads late

The wrong-product half of this item is fixed (see above). Still open: auto-picking the preferred supplier does nothing if `viewModel.suppliers` hasn't loaded yet (the product-detail path loads it in parallel).

**Requirements**:
- Given the supplier list loading after the product's suppliers, should still auto-pick the preferred supplier

---

## 📋 Ask for the adjustment cost only when the API needs it

The adjustment cost field shows for every adjustment that adds stock, because the API's "no previous cost" error has no stable `code` and the app doesn't branch on message text. With a code from farmacia-ops, the form could show the field only when the product has no cost on record.

**Requirements**:
- Given a positive adjustment rejected for a missing cost, should return a stable `code` (farmacia-ops)
- Given that code, should reveal the cost field instead of showing it up front

---

## 📋 Small fixes

- Given a receiving in history, should show formatted costs, not raw decimal strings like `$12.5000/unit` (`ReceivingRow`; formatted helpers exist in `Models/Inventory.swift`)
- Given a count correction that removed stock, should color it red, not green (`AdjustmentRow` treats `.countCorrection` as positive)
- Given "Actualizar Precio de Venta" on with an empty price, should disable Guardar rather than save without the price
- Given a cancelled load, should detect it by error type, not by "cancel" in `errorDescription` (`InventoryViewModel` load functions)
- Given a create-product response with no `data`, should show an error rather than nothing (`CreateProductView.swift`)
- Given `ProductsViewModel` building the list request, should not capture the `var params` in `async let` (Swift 6 error)

---

## Decided not to do

- **Lock stock during a count correction (farmacia-ops).** The server reads stock just before writing, not under `SELECT … FOR UPDATE`. A sale of that product at that store would have to land within milliseconds; the human count already spans minutes of possible sales, which no lock fixes, and the next count corrects any error. Revisit only if counts drift during busy hours (see the `ponytail:` comment in `inventory-adjustment.service.ts`).
- **Key the product-detail inventory sheets on location.** Not needed: the count-correction form fetches stock for the current location itself.
