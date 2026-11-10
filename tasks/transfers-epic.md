# Transfers Epic (send many products to another store)

**Status**: ✅ BUILT (2026-11-10), uncommitted. Steps 1–14 are done, and so are the review follow-ups. The ops endpoints are on farmacia-ops `feature/transfer-shipments` (uncommitted), so iOS must not ship before they deploy. 690 tests pass.
**Branch**: `feature/transfers`
**Goal**: From Más → Transferencias, pick the destination store, build a list of products (search or scan) with quantities, and send them all in one go. Today there are two stores: stock is received at the main one and sent to the other, or the main store gathers what the other one is missing.

## Decisions (asked 2026-11-10)

- **Receiving: both modes, and the default is received on send.** The send form has a switch "Confirmar al llegar", off by default.
  - **Off**: the stock leaves the origin and enters the destination in the same step, and Square moves it at once.
  - **On**: the shipment stays "En tránsito" until the other store opens "Por recibir" and taps Recibir. A line that arrived short can be fixed, and the shortfall is recorded as waste at the origin (ops' current receive).
- **Picking products: search by name or scan only.** There's no "other store's agotados" auto-fill for now (out of scope below).
- **Placement: Más → Transferencias**, next to Sueltos, for OWNER and MANAGER (the API's roles). Hidden for a cashier.

## 0. Ops prerequisite (farmacia-ops, not this repo)

What exists: POST /transfers ships **one** product (FIFO TRANSFER_OUT → IN_TRANSIT, no Square call). POST /transfers/:id/receive adds it at the destination and sends Square one cross-location move. GET /transfers?locationId&status. The web screen (`TransfersScreen.tsx`) sends one product at a time.

**Confirmed by ops (farmacia-ops-50, 2026-11-10)**, with its changes folded in:

1. **`POST /transfers/batch`** `{ toLocationId, clientRequestId, receiveOnSend, items: [{ productId, quantity }] }`.
   - All or nothing in one `$transaction`. The origin is the session store.
   - It creates a `Shipment` (id, from, to, createdBy, shippedAt, `clientRequestId` unique), and each product is its own `Transfer` with `shipmentId`.
   - A repeated `clientRequestId` returns the first result, so a retry after a timeout can't ship twice.
   - A duplicate productId → 400 `DUPLICATE_PRODUCT`. More than 100 items → 400 `TOO_MANY_ITEMS`. A repeated `clientRequestId` returns the first result even if the payload differs.
   - OWNER and MANAGER only.
   - `receiveOnSend: true` receives every line at its sent quantity in the same transaction. Then, after the commit, it syncs Square per transfer, as receive does today. The Shipment records `receiveOnSend`, and `receivedBy` is the sender, so the history shows nobody counted it on arrival. A Square failure doesn't fail the send.
   - **Access (decided 2026-11-10, option 2)**: receive-on-send is allowed for the OWNER, or for a manager with access to both stores. A manager at the origin only gets 403 unless they send with "Confirmar al llegar".
2. **`GET /transfers/shipments?locationId&status`**: shipments with their transfers (product id, name, sku, image) and lines, newest first. The status isn't stored; it's derived: IN_TRANSIT if any transfer is still in transit, otherwise RECEIVED. Non-owners see only shipments where their store is either side. Old single-product transfers have no shipment and don't appear (ops moves the web send to batch in the same change). "Por recibir" uses `status=IN_TRANSIT` with this store as the destination.
3. **`POST /transfers/shipments/:id/receive`** `{ lines?: [{ transferLineId, quantityReceived }] }`. A line without an override arrives at its sent quantity. Transfers already received one by one are skipped, and 409 comes back when none are left. A line not in the shipment → 400. It needs access to the destination.
4. **Error codes** (iOS doesn't read message text):
   - `PRODUCT_NOT_SOLD_AT_LOCATION` already exists;
   - new: `DESTINATION_NOT_CUT_OVER`, `INSUFFICIENT_STOCK` (with `productId`, `requested`, `available`), `SAME_LOCATION` and `INVALID_QUANTITY`;
   - plus `TOO_MANY_ITEMS` and `DUPLICATE_PRODUCT`;
   - the batch stops at the first failing item and returns **one** error, `{ code, message, productId }`. So iOS checks every line before sending (steps 2–3) to show all the problems at once.
   - The cutover and stock codes go where those checks live, so receiving and adjustments get them too (the message text doesn't change).

## Logic (FarmaciaKit, Swift Testing)

All of it goes in a new `TransferDraft.swift`. It takes primitives (ids, names, quantities), not the app's `Product`.

1. ✅ **`TransferDraft.add(productId:name:available:)`**: the list being built.
   - Added: `setQuantity(_:for:)`.
   - First test: *given an empty draft, adding Aspirina with 12 available should add one line with quantity 1*.
   - Then: *given Aspirina already in the list, adding it again (a second scan) should raise its quantity to 2, not add a second line* (the batch refuses duplicates).
   - Then: *removing a line should drop it*.
2. ✅ **`TransferDraft.lineIssue(quantity:available:)`**: what's wrong with one line.
   - First test: *given quantity 0, should read "La cantidad debe ser mayor que cero"*.
   - Then: *given 15 with 12 available, should read "Solo hay 12 en esta tienda"*. *Given 0 available, should read "Sin existencias en esta tienda"*. *Given 5 with 12 available, should have no issue*.
3. ✅ **`TransferDraft.canSend(destinationId:)`**.
   - First test: *given no destination, should be false*.
   - Then: *given a destination and no lines, should be false*. *Given a line with an issue, should be false*. *Given 101 lines, should be false and read "Máximo 100 productos por envío"* (ops' cap). *Given a destination and valid lines, should be true*.
4. ✅ **`TransferDraft.destinations(all:current:)`**: the stores you can send to.
   - First test: *given stores Centro and Oriente and the session at Centro, should offer only Oriente*.
   - Then: *given exactly one other store, should pick it by default* (today's two-store case needs no picking).
5. ✅ **`TransferDraft.summary`**: the confirm text and the Enviar button.
   - First test: *given 3 lines with 24 pieces in all, should read "3 productos · 24 piezas"*.
   - Then: *given 1 line with 1 piece, should read "1 producto · 1 pieza"*.
6. ✅ **`TransferDraft.request(destinationId:receiveOnSend:)`**: the batch body.
   - First test: *given two lines, should encode `toLocationId`, `receiveOnSend` and `items` with productId and quantity*.
   - Then: *given the same draft encoded twice, should keep the same `clientRequestId`* (a retry is the same shipment). The id is created when the draft is, and injected in tests.
   - Then: *after a send succeeds and the draft is reset, should use a new `clientRequestId`*.
7. ✅ **`TransferError.message(code:productName:available:destination:fallback:)`**: a batch error in Spanish, naming the product.
   - First test: *given `INSUFFICIENT_STOCK` for Aspirina with available 4, should read "Aspirina: solo hay 4 en esta tienda"*.
   - Then: `PRODUCT_NOT_SOLD_AT_LOCATION` → "Aspirina no se vende en Oriente". Also `RECEIVE_ON_SEND_NOT_ALLOWED` ("…envía con «Confirmar al llegar»"), `LOCATION_NOT_CUT_OVER`, and INSUFFICIENT_STOCK without the amount. `DESTINATION_NOT_CUT_OVER` → "Oriente aún no ha hecho su conteo inicial". An unknown code → the server's message, as `NetworkError.from` does now.
8. ✅ **`ShipmentReceipt`**: the confirm-mode receive form.
   - First test: *given a line sent with 10 and no edit, should send no override* (it arrives at the sent quantity).
   - Then: *given 8 received of 10, should send the override and read "Faltan 2"*. *Given more than was sent, should be an issue*. Added: *a line edited back to its sent quantity sends no override* (proven to bite).
9. ✅ **`TransferDraft.receiveOnSendAllowed(isOwner:accessibleStoreIds:destinationId:)`**: whether "Confirmar al llegar" can be off.
   - First test: *given a manager without access to Oriente, should be false* (the switch is forced on and locked, with the note "Oriente confirmará al recibir").
   - Then: *given a manager with access to both stores, should be true*. *Given the owner, should be true*.
10. ✅ **`TransferStatus` titles**: "En tránsito", "Recibida", "Cancelada", and "Pendiente" (the API's enum has PENDING).
   - First test: *given IN_TRANSIT, should read "En tránsito"*.

## UI (FarmaciaApp)

11. ✅ **Models and endpoints**: `Shipment`, `TransferRow` and the batch response (Decodable, in `Models/`). Add `APIEndpoint` cases `.sendTransfers`, `.listShipments(status:)` and `.receiveShipment(id:)`.
12. ✅ **Shared product picker**: move `ProductSearchPicker`, `ProductOptionLabel` and `ProductThumbnail` out of `SueltosView.swift` into `Features/Products/Views/ProductSearchPicker.swift`, unchanged. This is a new file, so register it in pbxproj. Smoke: Sueltos still searches, scans and shows photos.
    - Done: the picker is generic over its focus field and takes `scanLabel` and `subtitle`, so Sueltos keeps its own subtitle. Simulator smoke (2026-11-10): typing "A" listed Audifonos with its photo and Aguja gris with the box icon, and picking Aguja gris showed it with Cambiar.
13. ✅ **`TransfersView`** (Más → Transferencias, `arrow.left.arrow.right`), with three sections:
    - **Nueva transferencia**:
      - "Para": the destination store (preselected when there's only one).
      - The product picker (type or scan). Each pick goes through `TransferDraft.add`, and the picker clears for the next product.
      - The lines: photo, name, "Hay N aquí", a quantity field with a stepper, and swipe to remove. `lineIssue` shows under the line.
      - The "Confirmar al llegar" switch, off by default. It's locked on when `receiveOnSendAllowed` is false.
      - Enviar (`summary`) → a confirm dialog "Enviar 3 productos · 24 piezas a Oriente". The button disables and shows a spinner while sending.
      - On success, the result shows ("Enviado a Oriente", or "En tránsito a Oriente"), and the draft resets. Any Square sync failure shows per product.
      - On error, the draft stays as it was, and the error names the product.
    - **Por recibir**: shipments in transit to this store. Tapping one opens a sheet with its lines and the received quantities (`ShipmentReceipt`), then Recibir.
    - **Recientes**: the last shipments in or out, with the status, date, store and summary.
    - **Smoke** (local API; this is a critical inventory flow, like receiving):
      - At farmacia dev ops, add two products (one typed, one scanned; scanning the same one again raises it to 2) and send with the switch off. The origin quantities drop, and at the other store they rise.
      - Send with the switch on. "Por recibir" shows it at the other store. Receive it with one line short, and it shows Recibida.
      - Asking for more than the store has is blocked before sending.
      - Turn off Wi-Fi mid-send, then retry: only one shipment exists.
      - The cashier doesn't see Transferencias.
14. ✅ **Docs**: the README features line, this epic (✅ + hashes), and `graphify update .` (`--force`, since step 12 moves code).

## Review follow-ups (/tdd-review, 2026-11-10), all ✅

1. **Por recibir counts per product, not per lot.** `ShipmentReceipt(transfers:)`: one received quantity per transfer. A shortfall comes off the last lot, then the one before (5 tests, proven to bite).
2. **Unknown stock counts as none** (`add(available: Int?)`, proven to bite).
3. **The send's result comes from the server's shipment**, not the draft (a replayed `clientRequestId` returns the first shipment). Refusals keep their code: `NetworkError.refused(Refusal)` with `code`, `message`, `productId` and `available`, for the transfer codes only (`NetworkError.refusalCodes`), on 400 and 403. A 403 used to become a bare `.unauthorized`, which hid RECEIVE_ON_SEND_NOT_ALLOWED (proven to bite).
4. **Statuses decode as Strings**: `TransferStatus.title(raw:)` shows an unknown value as is.
5. The INSUFFICIENT_STOCK-without-amount test was added.
6. **The scan pick moved** from `LooseLinkForm.scanPick` to `BarcodeLookup.pick`, since both pickers use it.
7. **Found in the smoke**: `Product.quantity` is piezas por caja, not stock, so the screen showed "hay 10 aquí" at both stores. It now reads `totalInventory` (the store's lots). The over-stock check is now right too, and the server would have refused an over-send anyway.

## Second review (/tdd-review, 2026-11-10), all ✅

1. **Screen rules moved into FarmaciaKit, with tests**:
   - `ShipmentList.isToReceive` / `recent` (Por recibir vs Recientes, last 10);
   - `TransferDraft.receivesOnSend(confirmOnArrival:allowed:)`;
   - `destinations(all:inactive:current:)` (closed stores left out).
   - Two of them were proven to bite.
2. **An unanswered send** (timeout, lost connection) shows `TransferError.mayHaveSentText` ("Puede que ya se haya enviado. Revisa Recientes antes de cambiar la lista…") and reloads Recientes. The list stays, so resending it as is can't duplicate it (proven to bite).
3. **Store switch**: in the simulator a switch returns Más to its list, so the screen doesn't survive it. A reset on `currentId` change stays anyway: new list, new request id, reload.
4. **Dead code removed**: `ShipmentTransfer.received`, and `TransferStatus`'s `Decodable`.
5. **"unidades", not "piezas"**: a box product's unit is the box. Checked in the simulator: "1 producto · 2 unidades".
6. Picking or removing a product clears an old error.
7. **New ops code, 409 `CLIENT_REQUEST_ID_REUSED`** (the id was used by another store's send): the list keeps its products with a new id (`renewRequestId`), and the message reads "No se pudo enviar. Toca Enviar de nuevo." Tested, including the 409 mapping.

## Smoke (simulator, local API on ops' branch, 2026-11-10)

- At farmacia dev ops, Oriente local is preselected (the only other store).
- Typing "A" lists products with "hay N aquí". Picking Aguja gris adds 1, and the same scan again makes it 2 ("1 producto · 2 piezas").
- 122 of the store's stock shows "Solo hay … en esta tienda", and Enviar is blocked: "Revisa las cantidades marcadas".
- **Received on send**: 1 piece, then the confirm "¿Enviar 1 producto · 1 pieza a Oriente local?" → "Enviado a Oriente local… Ya están en su inventario." Recientes shows "Para Oriente local · Recibida". The inventory value moved by $0.90 at both stores.
  - The local API has no Square sync, so the Square note showed ("Aguja gris: Square no se actualizó…").
- **Confirmar al llegar**: 2 pieces → "En camino a Oriente local…", En tránsito. After switching to Oriente local, Por recibir lists them, and the sheet shows "Enviadas: 2". Recibir → Recibida, and Por recibir is empty.
- **Not checked in the simulator**:
  - Editing the received quantity (the UI tool couldn't edit the field; the shortfall split is unit-tested).
  - A retry after a dropped connection (the stable `clientRequestId` is tested; ops tests the replay).
  - The cashier (the Más row uses the same `isManager` gate as Sueltos).
  - A manager without access to the other store (the access rule is tested; there's no such employee locally).

## Migrate-as-touched

- `InventorySource.transfer` (`Models/Inventory.swift`) stays as it is. It's only a label.
- Nothing else moves. The draft rules are new and start in FarmaciaKit. The pickers stay in the app (SwiftUI) and only change file.

## Out of scope

- The "other store's agotados / bajos" suggestion (ops can add `GET /transfers/suggestions` later). For now, check stock by search or scan.
- Cancelling a shipment in transit (the API has CANCELLED, but there's no endpoint).
- Retrying a failed Square sync from iOS (owner-only; the web screen has it).
- The web app's multi-product send (ops' side).
