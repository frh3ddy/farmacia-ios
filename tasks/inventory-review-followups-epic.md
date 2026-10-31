# Inventory Review Follow-ups Epic

**Status**: 📋 PLANNED
**Goal**: Fix what the 2026-10-30 review of `FarmaciaApp/Features/Inventory/` found that the count-correction fix left out of scope.

## Overview

The review found three critical bugs, fixed on `fix/inventory-count-correction-location` (iOS, b3c0918) and `fix/count-correction-counted-quantity` (farmacia-ops, 9b40232): count correction computed its change from a stale or other-store stock snapshot, the Inventory tab didn't reload on a location switch, and every save tap made a new `clientRequestId`. The items below are what it also found and are still open, highest severity first.

---

## 📋 Product picker sees only the first 50 products

`InventoryViewModel.loadProducts` calls `GET /products` with no `page`/`limit`; the API defaults to 50, newest first. `ProductPickerView` filters only those on the device, so older products can't be received or adjusted from the Inventory tab (the product-detail path is unaffected).

**Requirements**:
- Given a store with more than 50 products, should let the picker find any of them (server-side `search`, or page through `hasMore`)
- Given a search typed in the picker, should query the API rather than filter a partial list

---

## 📋 Save errors invisible while a form is open

The only error alerts for `viewModel.showError` are on the screens that present the forms (`ReceiveInventoryView`, `AdjustmentsListView`, `ProductDetailView`). iOS won't present an alert from a view already presenting a sheet, so a failed save probably shows nothing until the form is cancelled. Not yet confirmed in the simulator.

**Requirements**:
- Given a receive or adjustment save that fails, should show the error inside the form
- Given the error dismissed, should leave the form open with its input intact

---

## 📋 Money as `Decimal`

`unitCost` and `sellingPrice` are `Double` from the form fields through `ReceiveInventoryRequest`, and form totals are computed in `Double`. A wider change: the API models across the app use `Double`/`String` today.

**Requirements**:
- Given a cost or price entered, should keep it as `Decimal` through to the request body
- Given totals and margins on screen, should compute them in `Decimal`

---

## 📋 Supplier suggestions can belong to the wrong product

`ReceiveInventoryFormView.loadProductSuppliers` has no cancellation: switching product quickly lets the previous product's response overwrite `productSuppliers` and auto-fill its preferred supplier and unit cost. Separately, auto-picking the preferred supplier does nothing if `viewModel.suppliers` hasn't loaded yet (the product-detail path loads it in parallel).

**Requirements**:
- Given a product changed while its suppliers load, should ignore the superseded response (`.task(id: selectedProduct?.id)`)
- Given the supplier list loading after the product's suppliers, should still auto-pick the preferred supplier

---

## 📋 Small fixes

- Given a receiving in history, should show formatted costs, not raw decimal strings like `$12.5000/unit` (`ReceivingRow`; formatted helpers exist in `Models/Inventory.swift`)
- Given a count correction that removed stock, should color it red, not green (`AdjustmentRow` treats `.countCorrection` as positive)
- Given "Actualizar Precio de Venta" on with an empty price, should disable Guardar rather than save without the price
- Given a cancelled load, should detect it by error type, not by "cancel" in `errorDescription` (`InventoryViewModel` load functions)

---

## Decided not to do

- **Lock stock during a count correction (farmacia-ops).** The server reads stock just before writing, not under `SELECT … FOR UPDATE`. A sale of that product at that store would have to land within milliseconds; the human count already spans minutes of possible sales, which no lock fixes, and the next count corrects any error. Revisit only if counts drift during busy hours (see the `ponytail:` comment in `inventory-adjustment.service.ts`).
- **Key the product-detail inventory sheets on location.** Not needed: the count-correction form fetches stock for the current location itself.
