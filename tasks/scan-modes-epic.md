# Epic: Escanear — Consultar, Recibir, Contar (continuous scanning)

Branch: `feature/scan-modes` (from `main`, after `fix/receive-review-followups` lands)

## Problem

Receiving or counting 20 products by scan today, per product:
scan → detail → **Recibir Inventario** / **Ajustar → Corrección de Conteo** → fill + save
→ back on detail → **‹** back to Productos → scan button. That is 3 navigations of
overhead per item, and nothing confirms the last save once the form closes.

Three jobs share one button:
1. **Consultar** — scan to see stock, supplier cost, price (detail screen is right).
2. **Recibir** — scan to add stock, many items in a row (detail screen is in the way).
3. **Contar** — scan to correct stock to what's on the shelf, many items in a row.

## Decisions (asked 2026-11-04)

- **Mode toggle in the scanner:** `Consultar | Recibir | Contar` segmented control at
  the top of the scan sheet. Remembered (`@AppStorage`). Recibir and Contar only for
  `canManageInventory` (the API's OWNER/MANAGER on both endpoints); otherwise the
  toggle is hidden and the mode is Consultar.
- **Recibir loop:** scan → receive form (no detail screen) → save → scanner reopens
  with a strip `✓ Aspirina 500mg · +20 uds`. Tapping the strip closes the flow and
  opens that product's detail (to check or correct it).
- **Contar loop:** scan → Corrección de Conteo form (live stock, counted qty, change)
  → save → scanner reopens with `✓ Aspirina 500mg · 12 → 10 (−2)`. Same strip tap.
  A count equal to stock saves nothing (`CountCorrection.preview` is nil): the form
  says "Sin cambios" and closes back to the scanner with `✓ Aspirina 500mg · 12, sin cambios`.
- **Each count posts immediately.** The API computes the change from its own stock at
  save time (`inventory-adjustment.service.ts:292`), so counts must not be held and
  posted later — a sale in between would be erased. One item at a time keeps that
  window to seconds.
- **Unknown code in Recibir / Contar:** Nuevo Producto (code prefilled) → on save, the
  mode's form (receive / count) → scanner. Created offline (queued, no product yet)
  → back to the scanner; strip says it was created and can be received/counted once
  it syncs.
- **Consultar** behaves as today, except a product created from an unknown code opens
  its detail screen (today the flow just closes). Created offline → closes as today.

## What the code does today

- `ScanFlowSheet` (FarmaciaApp/Features/Products/Views/ScanFlowSheet.swift) is one
  sheet with steps `.scan / .choose / .create`; one match → `onOpen` + dismiss,
  ProductsView pushes `ProductDetailView`.
- `ReceiveInventoryFormView` is only opened from `ProductDetailView` (`DetailSheet.receive`),
  using the detail page's `InventoryViewModel` (it preloads suppliers). On save it
  calls `onComplete`, shows the checkmark 600 ms, then `dismiss()`.
- `AdjustmentFormView(adjustmentType: .countCorrection, …)` is only opened from
  `ProductDetailView` (`DetailSheet.adjust`). It loads live stock itself, sends
  `countedQuantity`, asks for a cost when the count adds stock (`costRequired`), and on
  `.saved` calls `onComplete` then `dismiss()`.
- `CreateProductView` calls `onCreated(product?)` then `dismiss()`; Cancelar /
  Descartar also `dismiss()`. Inside the scan sheet, `dismiss()` closes the whole flow.
- `InventoryViewModel.receiveInventory` / `createAdjustment` treat queued offline as saved.
- `StockImpact(before:change:)` (FarmaciaKit) already formats a stock change
  (`changeText`, `summary`). No toast/strip component exists in the design system.

## Steps

### Logic (FarmaciaKit)

1. **`ScanMode`** (`consult`, `receive`, `count`) + `ScanMode.effective(saved:canManageInventory:)`.
   - First test: *given a saved `count` and an employee who can't manage inventory, should be `consult`.*
   - Then (`@Test(arguments:)`): nil saved → `consult`; `receive`/`count` + can manage → itself.

2. **`ScanNext`** — the flow's decision table, out of `ScanFlowSheet.handleScan`'s inline switch.
   Inputs without the app `Product` type: `.matched`, `.severalMatched`, `.unknown`,
   `.created(hasProduct: Bool)`, `.formSaved`, `.formCancelled`.
   Outputs: `.openDetail`, `.receive`, `.count`, `.choose`, `.create`, `.scan`, `.close`.
   - First test: *given `receive` mode and one match, should go to `.receive` (not `.openDetail`).*
   - Then (`@Test(arguments:)`): consult + match → `.openDetail`; count + match → `.count`;
     any mode + several → `.choose`; any mode + unknown → `.create`;
     receive/count + created(hasProduct: true) → `.receive`/`.count`;
     receive/count + created(hasProduct: false) → `.scan`;
     consult + created(hasProduct: true) → `.openDetail` (decided; today it closes);
     consult + created(hasProduct: false) → `.close` (queued offline: nothing to open yet);
     receive/count + formSaved/formCancelled → `.scan`.

3. **`RecentScanSave`** — the strip's text and the repeat check. Two kinds:
   `.received(quantity)` and `.counted(StockImpact?, counted:)` (reuse `StockImpact`, don't
   re-format signs).
   - First test: *given "Aspirina 500mg" received 20, should read "Aspirina 500mg · +20 uds".*
   - Then: received 1 → "+1 ud"; *given counted 10 against 12, should read
     "Aspirina 500mg · 12 → 10 (−2)"*; given counted 12 against 12 (no impact), should read
     "Aspirina 500mg · 12, sin cambios"; *given the same productId scanned again in the same
     mode, `isRepeat(of:)` should be true* (the form shows a non-blocking "Ya recibiste
     20 uds hace un momento" / "Ya contaste este producto hace un momento" — guards the
     brief's duplicate rule without blocking a second lot or a recount).

### UI (FarmaciaApp)

4. **Embeddable receive form.** `ReceiveInventoryFormView` gets `onClose: (() -> Void)?`;
   when set, Cancelar/Descartar and the post-save close call it instead of `dismiss()`.
   `onComplete` passes the saved quantity (`(Int) -> Void`) so the strip can show it.
   Product detail keeps passing nothing → unchanged.
   Smoke: receive from product detail still saves and closes (critical flow).

5. **Embeddable count form.** Same `onClose` on `AdjustmentFormView`. `onComplete` passes
   `(liveStock, counted)` for count corrections. A count equal to live stock: the save
   button reads "Sin cambios" and just closes (reports the no-change result) instead of
   staying disabled — in a counting run, "it matched" is an answer, not an error.
   Detail's other adjustment types keep passing nothing → unchanged.
   Smoke: Corrección de Conteo from product detail still saves and closes.

6. **Embeddable Nuevo Producto.** Same `onClose` on `CreateProductView` (close
   after save / Cancelar / Descartar). Default nil → Productos `+` unchanged.

7. **Mode toggle.** `Picker(.segmented)` under the scanner's nav bar, `@AppStorage("scanMode")`
   through `ScanMode.effective`; hidden when the employee can't manage inventory. Pass
   `canManageInventory` in from ProductsView.

8. **Recibir / Contar steps in `ScanFlowSheet`.** New steps `.receive(Product)` and
   `.count(Product)`; route every outcome through `ScanNext`. The sheet owns one
   `@StateObject InventoryViewModel` (used for both receive and adjustments) and calls
   `loadSuppliers()` once when entering Recibir — reused for all items. The choose list
   follows the mode. `.receive`, `.count` and `.create` use the `onClose` from steps 4–6
   to come back to `.scan` (fresh `CodeScannerView`, so `.once` re-arms).
   Smoke (critical flow — receive): Recibir → scan → save → scanner is back → scan next → save.
   Smoke: Contar → scan → count lower → save → scanner back; scan → count equal → "Sin cambios".
   Smoke: Consultar → unknown code → Nuevo Producto → save → its detail screen opens
   (via the existing `onOpen` close + push, after `viewModel.upsertProduct`).

9. **Recently-saved strip.** Bottom of the scanner: `RecentScanSave` text + checkmark,
   `.sensoryFeedback(.success)` on appear, tap → `onOpen(product)` (existing close +
   push detail). Shows only the last save. Repeat scan of the same product → the
   note from step 3 in the form.
   Smoke: strip shows after a receive and after a count; tap opens the right product's detail.

10. **Refresh Productos.** `ScanFlowSheet` reports each saved product (`onStockChanged`);
    ProductsView updates those rows (stock) the way detail's `onProductUpdated` does.
    Smoke: stock on the Productos row is new after closing the scanner.

11. **Simulator scanning.** Pass `simulatedData:` to `CodeScannerView` in `#if DEBUG`
    with a known local-API barcode so steps 8–10 can be smoked without a camera.

12. **Docs:** README (Products → Scan; Receiving; Adjustments), this epic's status with
    hashes. Then `graphify update .`.

## Migration (migrate-as-touched)

- The routing switch in `ScanFlowSheet.handleScan` / `open` / `onCreated` → `ScanNext` (step 2).
- `ScanOutcome` stays app-side (it carries `Product`); it maps to `ScanNext` inputs.
- The forms' close-after-save timing (600 ms) stays in the views — UI timing, not logic.

## Not now

- **Store-wide count** (count session, "142 of 380 counted", review differences, post
  all at once, policy for uncounted products). Needs `farmacia-ops` work: a count model
  for the audit trail, a bulk idempotent endpoint, each count carrying its time or the
  stock it was compared against (so sales during the count aren't erased), and batched
  Square sync. Its own epic if a full count is ever needed.
- Session summary ("12 productos recibidos") — the strip covers the last save; add when
  someone asks for an end-of-delivery tally (that's the purchase-order flow in
  `docs/purchasing-design.md`).
- Other adjustment types (Daño, Vencido, …) in the scanner — they're one-offs, not runs;
  they stay on the detail screen.
- A scan button on the product detail screen (to scan the next item while in Consultar).
- Telling apart a save queued offline in the strip — the connectivity banner already says it'll sync.


## Status (2026-11-04, uncommitted on `feature/scan-modes`)

- ✅ 1–3 Logic: `ScanMode`, `ScanNext`, `RecentScanSave` (`FarmaciaKit/Sources/FarmaciaKit/ScanFlow.swift`,
  `ScanFlowTests.swift`), plus `CountCorrection.matches` for "Sin cambios".
  Changed from the plan: the form events became one `.closed` (a form's save and its
  Cancelar both arrive through `onClose`), and Consultar + `.closed` closes the flow as before.
- ✅ 4–6 Embeddable forms: `onClose` on Recibir inventario, Corrección de Conteo, Nuevo Producto;
  `note:` for the repeat reminder; receive `onComplete` passes the quantity; count `onCounted`.
- ✅ 7–9 `ScanFlowSheet`: mode picker, `.receive` / `.count` steps routed by `ScanNext`, one
  `InventoryViewModel` per run, strip with a success haptic.
- ✅ 10 Productos refreshes a received/counted product's row (`refreshRow`).
- ✅ 11 Simulator scan code: `xcrun simctl spawn booted defaults write com.farmacia.ios.dev simScanCode <code>` (DEBUG only).
- ✅ 12 README.
- Dropped: the strip note for a product created offline. Nuevo Producto's own "Sin conexión" alert already says it.
- ✅ Simulator smoke tests (2026-11-04, local API, Abatelenguas Madera `7501281200101`):
  - Recibir: scan → receive form, no detail screen → +5 saved once → scanner back with `+5 uds`, row 86 → 91.
  - Repeat scan shows "Ya recibiste 5 uds…"; Cancelar goes back to the scanner.
  - Contar: count 91 → "Sin cambios" → `91, sin cambios`; count 90 → `91 → 90 (−1)`, row 90; repeat note shown.
  - Strip tap opens the detail screen. The mode is remembered between scanner openings.
  - Consultar opens the detail screen as before.
  - Detail screen → Recibir Inventario → Cancelar → Descartar closes the sheet.
  - Not smoked: saving a receive from the detail screen (the simulator's keypad covered the button; the same
    `close()` path was exercised by the scanner saves), and unknown code → Nuevo Producto (would create a real product).

## Review fixes (/tdd-review, 2026-11-04)

- ✅ Nuevo Producto opened from Recibir/Contar hides "Inventario inicial" (`showsInitialStock`); the
  receive/count form that follows takes the stock, so it was added twice.
- ✅ One success haptic per receive: the scanner's haptic plays for counts only (the receive form's
  button already plays it).
- ✅ The repeat note is worked out when the form opens (`Step.receive/count(_, note:)`), so it no
  longer appears on the product just saved during the checkmark.
