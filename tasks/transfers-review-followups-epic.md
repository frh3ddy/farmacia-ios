# Transfers Follow-ups Epic

**Status**: 📋 BACKLOG (recorded 2026-11-10). Nothing here is started.
**Context**: `tasks/transfers-epic.md` (Transferencias, merged `184c225`) and `tasks/transfer-sheet-epic.md` (the product sheet).

## 1. FIFO preview in the product sheet: "Se enviarán" (needs ops)

**Why**: the sheet (transfer-sheet epic, option 1) lists this store's lots by expiry as "Caducidades aquí". The lots a transfer actually takes are FIFO (first received first), which isn't always the nearest expiry. The user wants to see exactly which lots, and so which expiry dates, will go to the other store. Chosen as a later feature on 2026-11-10.

**Ops prerequisite (farmacia-ops)**: a read-only preview of what a send of `quantity` would take, using the same FIFO order as `ship()` / `createAdjustment(TRANSFER_OUT)`.
- Proposed: `GET /transfers/preview?productId=&quantity=` (OWNER, MANAGER). The origin is the session store.
- Response: `{ success, data: { lots: [{ quantity, expiryDate: "YYYY-MM-DD"|null, lotNumber|null, receivedAt }], available } }`, in the order FIFO takes them. No costs.
- More than `available` → the lots up to `available`, plus `short: requested - available` (not a 400: the sheet shows it as it types).
- It must share ship's lot-selection code, so the preview can't drift from what's sent. The stock can still change between preview and send (a sale), and the send stays the truth.

**iOS (FarmaciaKit first, Swift Testing)**:
1. **`TransferPreview.rows(_:now:timeZone:)`**: "Se enviarán: 6 vence 15 mar 2027 · 4 vence 2 nov 2027", using `Expiry.display` / `tone`.
   - First test: *given lots 6 (mar 2027) and 4 (nov 2027), should read them in FIFO order, not by expiry*.
   - Then: *given a lot already expired, should be critical* (sending expired stock is worth a warning). *Given short 2, should add "Faltan 2 en esta tienda"*.
2. **Debounce**: `TransferPreview.shouldFetch(quantity:last:)` only fetches for a changed quantity of at least 1. In the view, use `.task(id: quantity)` with a ~300 ms sleep, so a burst of −/+ makes one request.
3. **UI**: the sheet's "Caducidades aquí" becomes "Se enviarán", updating as −/+ changes. If the preview fails, fall back to option 1's list (`GET /inventory/lots`).
4. **Smoke**: a product with two lots received in a different order from their expiry. The preview follows receive order, and after sending, the other store's lots match the preview.

## Other open items (from the transfers epic)

- **The product sheet opens right after the scanner sheet closes** (transfer-sheet epic review). It's fine while the scan lookup awaits the network. If "already presenting" ever shows on a device, open the product sheet from the scanner's `onDismiss`.
- Receiving fewer than were sent, untested in a simulator or device (the test tool couldn't edit the field; the split is unit-tested). Check on the first real short delivery.
- A retry after a dropped connection, untested in a simulator or device (the stable `clientRequestId` is unit-tested, and ops tests the replay).
- A manager without access to the other store sending (the rule is unit-tested; there's no such employee locally).
- Cancelling a shipment in transit (the API has CANCELLED, but no endpoint).
- Retrying a failed Square sync from iOS (owner-only; the web screen has it).
