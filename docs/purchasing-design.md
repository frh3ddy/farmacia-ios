# Purchasing (shopping lists → orders → receiving) — design note

Status: **removed** from the app on `fix/products-list-expiry`. The last version
with the old screens is commit `5d3069b` (`ShoppingListsView`, `ShoppingListDetailView`,
`AddItemsSheet`, `ReceiveFlowView`, `PurchaseOrderView`, `Models/ShoppingList*.swift`).
Their entry buttons had been commented out ("not fully ready"), so nobody could reach them.

## What it did

1. **Shopping list**: pick products (by hand, or a restock list from low stock in Alertas)
   with a planned quantity and a default unit cost (the last cost).
2. **Quick receive / purchase order**: one supplier, many lines, each received as a normal
   `POST /inventory/receive` (one FIFO batch per line).
3. **Receive flow**: walk a list line by line, entering the real quantity, cost, lot and expiry.

## Why it was pulled

- Lists were JSON files in the device's Documents: not synced, not per location, lost
  on reinstall, invisible to other employees.
- A cost that didn't parse ("12,50") silently fell back to the old cost, which then
  fed FIFO valuation.
- Money was `Double`; order totals were summed in the view.
- About 4,000 lines of SwiftUI with no tests and the math inside the views.

## A better shape

**Server (farmacia-ops)** owns the order, so every device and role sees the same one:

- `PurchaseOrder` (locationId, supplierId?, status `DRAFT | SENT | PARTIAL | RECEIVED | CANCELLED`,
  createdBy, notes) and `PurchaseOrderLine` (productId, orderedQty, expectedUnitCost `Decimal`,
  receivedQty).
- Receiving a line creates the usual `InventoryReceiving` (it already has a `purchaseOrderId`
  column) and updates `receivedQty`/status in the same transaction; it's idempotent by
  `clientRequestId` like the rest of the offline queue.
- Suggested lines: out of stock / low stock, expiring soon, and sales velocity
  (units per day × lead time − stock on hand).
- Roles: OWNER and MANAGER create, send and receive orders; expected costs are never sent
  to CASHIER (same rule as `withoutCosts`).

**FarmaciaKit** holds the logic, tested with Swift Testing:

- One money parser: `Decimal`, accepts "12,50" and "12.50", rejects anything else (no fallback).
- Line and order math: remaining quantity, line total, order total, received vs ordered
  status, cost change vs last cost.
- Lot/expiry input uses `Expiry` / `LocalDay` (expiry is a calendar day).

**App**: a thin list → order → receive UI over those endpoints; receiving stays on the
critical-flow smoke list.

## Open questions

- How orders go to suppliers (PDF, WhatsApp, email), or whether they're internal only.
- Partial deliveries and back orders: keep the order open, or split it?
- Any tie-in with Square (vendors / purchase orders) or keep it farmacia-ops only.
