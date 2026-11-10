# Transfer Sheet Epic (newest first, a product sheet with a stepper)

**Status**: ✅ BUILT (2026-11-10), uncommitted. 704 tests pass, and the simulator smoke passed.
**Branch**: `feature/transfer-sheet` (from main `184c225`)
**Goal**: Transferencias is faster to fill. The newest product is at the top of the list. Picking or scanning a product opens a sheet that shows the product and asks how many, with a −/+ stepper. Each row in the list gets its own −/+.

## Decisions (asked 2026-11-10)

- **Re-picking a product already in the list edits it.** The sheet opens at its current quantity (e.g. 5). Guardar sets that quantity, not adds to it, and the line moves to the top. Today's "a second scan adds one" goes away.
- **After Agregar, the sheet goes back to the list.** You tap scan again for the next product. There's no scan loop.
- **Rows get an inline −/+** (a compact Stepper next to the number). Swipe still removes a line. The sheet is the way to type a big number: pick the product again.
- **The sheet shows** a large photo, the name, the SKU, "Hay N aquí", then the stepper. + stops at this store's stock. No destination stock (no extra call).
- **Expiry dates in the sheet: option 1, iOS only.** "Caducidades aquí" lists this store's lots from `GET /inventory/lots`, colored "vence pronto" / "ya venció" as in Conteo inicial.
  - The list is sorted by expiry, and it isn't necessarily the lots FIFO will send: FIFO takes the first received. The sheet says "Caducidades aquí", not "se enviarán".
  - A FIFO preview (`GET /transfers/preview`, ops) is out of scope for now.
  - A transfer already carries each lot's expiry and lot number to the other store (`transfer.service.ts:342-343`).

## What exists

- `TransferDraft` (FarmaciaKit) holds the lines in the order they were added. `add` appends, or adds 1 to a repeat.
- `TransfersView`: `onChange(of: picked)` adds the pick straight to the draft. The rows (`TransferLineRow`) have a typeable number.
- `QuantityStepper` (`Core/DesignSystem/QuantityStepper.swift`) is the big centered number with −/+ that Recibir and Contar use. It has no upper limit.

## Logic (FarmaciaKit, Swift Testing)

1. ✅ **`TransferDraft.set(productId:name:available:quantity:imageUrl:)`** replaces `add`. The sheet's quantity is saved, and the line goes first.
   - First test: *given Aspirina then Ibuprofeno, should list Ibuprofeno first*.
   - Then: *given Aspirina with 5, saving it again with 3 should leave one line with 3, at the top*.
   - Then: *given three lines, editing the last one's quantity in its row (`setQuantity`) should not move it* (only a pick moves a line).
   - Migrate-as-touched: the "second scan raises it to 2" test is replaced by the edit test above, and `add` is deleted.
2. ✅ **`TransferDraft.sheetStart(productId:available:)`**: the sheet's starting quantity.
   - First test: *given a product not in the list with 12 here, should start at 1*.
   - Then: *given it's in the list with 5, should start at 5*. *Given 0 here, should start at 0* (the sheet shows "Sin existencias en esta tienda", and Agregar is off).
3. ✅ **`TransferDraft.sheetAction(productId:)`**: the sheet's button.
   - First test: *given a product not in the list, should read "Agregar"*.
   - Then: *given one already in it, should read "Guardar"*.
4. ✅ **`TransferDraft.stepRange(available:)`**: the limits for the sheet's + and the row's −/+.
   - First test: *given 3 here, should be 1...3*.
   - Then: *given 0 here, should be 0...0*. Over-stock typing still shows `lineIssue` ("Solo hay 3 en esta tienda") and isn't clamped silently.

5. ✅ **`TransferLots.rows(_ lots: [CurrentLot], onHand: Int?, now:timeZone:)`**: the sheet's "Caducidades aquí" lines.
   - `CurrentLot` is the existing decoded `GET /inventory/lots` row (`StockCount.swift`). Its "YYYY-MM-DD" day is read as a calendar day, with no `Date()` math in the view. The text uses `Expiry.display`, and the tone uses `Expiry.daysUntil` / `tone`, per the CLAUDE.md expiry rule.
   - First test: *given 6 expiring 15 mar 2027 with lot A12, and today 10 nov 2026, should read "6 · vence 15 mar 2027 · lote A12" in neutral*.
   - Then: *given a lot expiring in 40 days, should be caution*. *Given one past its day, should read "2 · venció 3 oct 2026" in critical*. *Given no lot number, should leave the lote out*.
   - Then: *given 10 on hand and lots covering 6, should add "4 sin caducidad registrada"* (the endpoint skips lots with no expiry or lot). *Given no lots and 10 on hand, should read only "10 sin caducidad registrada"*.
   - Then: *given lots in any order, should list them soonest expiry first*.

## UI (FarmaciaApp)

6. ✅ **`QuantityStepper` gets an optional `maximum`** (default nil, so Recibir and Contar don't change). + is disabled at it.
   - Smoke: Recibir's stepper still counts up past 100.
7. ✅ **`TransferProductSheet`** (new file `Features/Inventory/Views/TransferProductSheet.swift`, registered in pbxproj):
   - A 120pt photo (`CachedProductImage`, box icon fallback), the name, "SKU …", and "Hay N aquí" (`totalInventory`).
   - `QuantityStepper(maximum: available)`, starting at `sheetStart`, with `lineIssue` under it.
   - **Caducidades aquí**: loads `.inventoryLots` (productId and this store) in `.task` when the sheet opens, and shows `TransferLots.rows` as StatusLabels.
     - While loading, a small spinner. On failure, "No se pudieron cargar las caducidades" (caution); the sheet still works, since Agregar doesn't depend on it.
   - Toolbar: Cancelar, and `sheetAction` ("Agregar" / "Guardar"), disabled while there's an issue.
   - Detents medium and large. Swiping it down is a cancel (nothing changes).
8. ✅ **`TransfersView`**:
   - A pick (typed or scanned) opens the sheet (`sheet(item:)`) instead of adding straight away. Save → `draft.set(…)`. The picker clears either way.
   - **The rows**: the photo, name and "Hay N aquí", then a compact `Stepper` with the number (`stepRange`), replacing the typeable field. `lineIssue` stays under the row.
   - The keyboard focus order is now only the search field, since rows have no text field.
   - Watch the memory note on stacked presentation modifiers: the screen already has a sheet (Por recibir), a confirm dialog and the picker's scanner sheet. Put the new `.sheet(item:)` on the Form, not on a Section.
   - **Smoke** (local API; a critical inventory flow):
     - Scan Aguja gris → the sheet shows its photo, name, SKU, "Hay 3 aquí" and its Caducidades aquí lines (or "3 sin caducidad registrada"), at 1.
     - A product counted with lots in Conteo inicial shows each lot with its expiry and color. + twice → 3, and + is off. Agregar → it's in the list with 3.
     - Pick Audifonos → its sheet → Agregar → it's at the top.
     - Scan Aguja gris again → the sheet opens at 3 with "Guardar". − to 2 → Guardar → one line with 2, now at the top.
     - The row −/+ change the number without moving the row, and + stops at the stock.
     - Swipe the sheet down → nothing added.
     - Enviar still sends ("2 productos · 3 unidades"), and Por recibir still works.
9. ✅ **Docs**: the README Transferencias line ("a second scan adds one more" → the sheet and the stepper), this epic (✅ + hashes), and `graphify update .`.

## Built notes

- **The sheet layout changed from the plan**: an 88pt photo beside the name, not a 120pt block. At medium height the 120pt block pushed the stepper to the bottom edge and hid Caducidades aquí.
- **Row −/+**: a labelless `Stepper` with the number next to it. Its range is `stepRange`, so − stops at 1 (swipe removes a line) and + stops at the stock.
- **The shared `QuantityStepper`** got `maximum` (default nil). Recibir and Contar call it without one, so they're unchanged.

## Smoke (simulator, local API, 2026-11-10)

- **Scan Aguja gris**: the sheet shows the photo, "SKU 4968420506013", "Hay 3 aquí", the stepper at 1, and "3 sin caducidad registrada". + twice → 3, and + turns off. Agregar → the row shows 3, and the row's + is off.
- **Row +**: 1 → 2 ("1 producto · 2 unidades"), and the row keeps its place.
- **Pick Audifonos** (typed): its sheet shows the photo beside the name, and + is off at 1 of 1. Agregar → it's on top.
- **Re-scan Aguja gris**: the sheet opens at 2 with "Guardar". + → 3, Guardar → one Aguja gris line with 3, now on top ("2 productos · 4 unidades").
- **Enviar** → "¿Enviar 2 productos · 4 unidades a Oriente local?" → "Enviado a Oriente local: 2 productos · 4 unidades." It's in Recientes. The local API has no Square, so the Square notes showed.
- **Not checked in the simulator**:
  - A product with dated lots: the local data has none. The rows are unit-tested: tone, sorting, lote, "sin caducidad registrada".
  - Swiping the sheet down: only the button saves, so a swipe can't add anything.

## Review fixes (/tdd-review, 2026-11-10)

- ✅ **The sheet's stepper limit comes from the tested rule**: `maximum: TransferDraft.stepRange(available:).upperBound`, the same rule the rows use. Checked in the simulator with a product at 0 here: the stepper sits at 0 with −/+ off, "Sin existencias en esta tienda" shows, and Agregar is off. Cancelar adds nothing.
- ✅ **Expiry rows are keyed by position**, not by their text.
- ✅ **The lot load checks for cancellation** before setting state.
- **Open, not fixed**: the product sheet opens as the scanner sheet closes. It works because the scan lookup always awaits a network call. If a device ever shows "already presenting", open it from the scanner's `onDismiss` (recorded in `tasks/transfers-review-followups-epic.md`).

## Migrate-as-touched

- The repeat-pick rule changes in FarmaciaKit (`add` → `set`), with its test rewritten (step 1).
- Nothing moves from the app. The sheet's start, button, limits and expiry lines are new rules, and they start in FarmaciaKit (steps 2–5). `CurrentLot` is already in FarmaciaKit and is reused as is.

## Out of scope

- Which lots this transfer will take (a FIFO preview needs ops: `GET /transfers/preview?productId=&quantity=`). Recorded as a later feature in `tasks/transfers-review-followups-epic.md` §1.
- A scan loop (scan → sheet → scan again without going back to the list).
- The destination store's stock in the sheet.
- Tapping a row to open the sheet (the row has its own −/+; re-picking opens the sheet).
