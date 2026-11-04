# Epic: inventory forms redesign (Recibir inventario, Nuevo producto)

**Branch:** `feature/inventory-forms-redesign`. Branch it from `main` after `feature/product-cards` merges. That
branch has uncommitted work in `Product.swift`, which both forms read.

**Sources:** `~/Downloads/Inventory form UX notes.md`, `~/Downloads/Inventory Form Redesign.html`,
`~/Downloads/screenshots/state-01…17.png`, `docs/inventory-ux-brief.md` (§5B, §5D, §6.1, §6.2, §7, §8), and the
design system in `FarmaciaApp/Core/DesignSystem/`. This epic replaces the layout from `form-ux-polish-epic.md`:
the "Más detalles" accordion goes, and the toolbar Guardar/Crear becomes a bottom button.

**No API change.** `POST /inventory/receive` already takes the invoice, lot, expiry, notes, `sellingPrice` and
`clientRequestId`. `POST /products` uses `costPrice` only together with `initialStock`
(`products.service.ts:450`), and the app already drops the cost when there is no quantity.

## Decisions

- **Margin is on the sale price**: `(price − cost) / price`, the existing `Margin.percent`. Nothing changes here.
- **Margin chips are fixed at 30 · 40 · 50 %** in FarmaciaKit. A store setting can come later if the owner asks.
- **The "Actual" chip** (Recibir) uses the **selected supplier's last cost** as the old cost. Without a supplier or
  a last cost, it falls back to `product.averageCost`. This is the same baseline as the ▲/▼ cost badge.
- **Validate on submit.** The button always shows the same label and can always be tapped. No errors appear
  before the first tap. After that, errors update live as the user fixes fields.

## Polish over the mockup (where the build differs from the HTML)

The mockups show the intent; they aren't a spec. Where they differ, the build does this:

- **System appearance and the app tint**, not the mockup's forced dark theme and hard-coded blue. Check both light
  and dark mode.
- **One margin color rule for the whole app.** Keep `Margin.tone`: green from 20 %, orange from 10 %, red below
  10 %. The mockup's "red only below cost" would disagree with Productos and the reports. Each margin is also
  written out as text ("Margen 34 %"), so it never relies on color alone.
- **The supplier stays a push** (`SupplierPickerView`), not a bottom sheet. The forms present nothing else on
  purpose (see the stacked-presentation crash memory). The picker gets a **"Sin proveedor"** row with a checkmark,
  so it does the ⓧ's job.
- **Cost badge tones.** A higher cost is `caution` ("▲ 8 % vs último $16.50"). A lower cost is `positive` ("▼").
  Changes under 1¢ are hidden. Today a higher cost shows in red, which reads as an error, not a heads-up.
- **Quantity hero.** The − and + buttons are 48 pt, repeat when held (`.buttonRepeatBehavior(.enabled)`), and give
  a light `.sensoryFeedback(.increase/.decrease)`. The number uses `.largeTitle`, rounded and `monospacedDigit`, so
  it scales with Dynamic Type. VoiceOver gets one adjustable element (`accessibilityAdjustableAction`). Tapping the
  number focuses it for typing. The value can't go below 0.
- **Bottom action bar** (`safeAreaInset(.bottom)` on `.bar` material):
  - The summary line goes above the button: "12 uds × $17.90 · Total $214.80", or "Falta cantidad y costo"
    after a failed tap. The whole bar fades out while the keyboard is up (the field shows its own message
    then); `.formKeyboard`'s Siguiente/Listo bar takes over.
  - The button is full width, `.borderedProminent`, `.controlSize(.large)`. While saving it shows a spinner in place
    and ignores taps. That's the same double-tap guard as today: `isSubmitting` is set before the `Task`.
- **Error presentation:**
  - A red tint and a message under the field.
  - Focus and scroll go to the first problem field. This reuses `.formKeyboard`, which already scrolls to `.id(field)`.
  - One shake, skipped under Reduce Motion.
  - `.sensoryFeedback(.error)`, and a VoiceOver announcement of the summary.
- **Success:**
  - The button turns into "✓ Inventario recibido" / "✓ Producto creado" for about 0.6 s with
    `.sensoryFeedback(.success)`, then the sheet closes.
  - Nuevo producto keeps its alert only when there is something to read: offline-queued, the image upload
    failed, or the photo couldn't be saved. The "all good" alert goes.
- **Footer copy instead of row captions.** Text like "Sugerido · redondeado a $0.50" wrapped badly inside rows
  (state-15), so explanations live in section footers. Rows stay one line.
- **"Opcional" in grey** next to the headers of optional sections. Required sections have no marker.

## Logic (FarmaciaKit, TDD)

1. [x] `PriceSuggestion.price(cost:marginPercent:)` gives the price that yields that margin, rounded **up** to the
   next $0.50. It returns nil for margins ≥ 100 or a cost ≤ 0. `PriceSuggestion.chips = [30, 40, 50]`.
   First test: **given cost 12 and 30 %, should be 17.50.**
   Then: given cost 12 and 40 %, should be 20.00. Given cost 21 and 30 %, should be 30.00, not 30.50:
   21 / 0.7 = 30.000000000000004, so round to cents before taking the ceiling. (12 / 0.6 is exact in Double;
   the test only failed with the rounding removed once the 21 / 0.7 case was added.) Given cost 12 and 50 %, should be 24.00. Given 100 %, should be nil.
2. [x] `MarginPick` is the chip state: `selected: Double?`.
   - `price(forCost:)` gives the suggested price.
   - `priceTyped(_:cost:)` keeps the chip only if the typed price equals the suggestion. Otherwise it releases the chip.
   First test: **given 40 % picked and the cost changes from 12 to 15, should suggest 25.00.**
   Then: given 40 % picked and the user types 22, should release the chip. Given the user types exactly 20.00 at
   cost 12, should keep 40 %.
3. [x] `CostChange(current:last:)` gives `percent`, a `tone` (up = caution, down = positive) and `text`
   ("▲ 8 % vs último $16.50"). It is nil when the last cost is ≤ 0 or the change is under 1¢.
   First test: **given current 17.90 and last 16.50, should be up 8 % with caution tone.**
   Then: given 15 vs 16.50, should be down with positive tone. Given 16.50 vs 16.50, should be nil.
   *Migrates* the inline diff and percent math in `ReceiveInventoryFormView.supplierSection`.
4. [x] `ReceivingPrice.keepingMargin(currentPrice:oldCost:newCost:)` is the "Actual" chip: the old margin applied
   to the new cost through `PriceSuggestion`. `ReceivingPrice.oldCost(supplierLast:average:)` picks the supplier's
   last cost, then the average cost.
   First test: **given price 25, old cost 16.50, new cost 17.90, should be 27.50** (34 % kept).
   Then: given no supplier last cost, should use the average cost. Given neither, should be nil, and the chip is hidden.
5. [x] `ReceivingForm.issues(quantity:unitCost:updatesPrice:newPrice:) -> [Issue]`, in top-to-bottom order. Each
   `Issue` has a `field` key, a `message` and a short `noun`:
   - `.quantity`: "Indica cuántas recibiste"
   - `.cost`: "Indica el costo unitario (0 si fue regalo)"
   - `.price`: "Indica el nuevo precio"

   `ReceivingForm.summary(_:)` gives "Falta cantidad y costo". `canSave` becomes `issues(...).isEmpty`, and its
   existing tests must stay green.
   First test: **given quantity 0 and no cost, should list quantity then cost, and summarize "Falta cantidad y costo".**
6. [x] `ProductDraft`: required issues and cost without stock.
   - Add `.nameMissing` and `.priceMissing`. `issues` is now in form order: name, price, barcode, then cost.
     The empty-field issues are part of the list, because errors show only after the first tap.
   - **Behavior change:** a cost without a quantity no longer blocks saving. The cost now lives in Precio and is
     used for the margin and the suggested price. It's still not sent without stock (the VM's `createsStock` gate).
     Drop `.quantityNeeded`.

   First test: **given name, price 20 and cost 12 with no quantity, should be able to save.** Update the old
   "cost without quantity blocks" test to match.
   Then: given an empty form, should list nameMissing then priceMissing. Given quantity 5 and no cost, should list
   costNeeded.
7. [x] `ProductName.lengthHint(_:)` returns nil under 28 characters. From 28 it returns "28/32". Over 32 it
   returns a caution: "Square POS y los tickets muestran ~32 caracteres". There's no hard limit, because the API
   has none.
   First test: **given a 27-character name, should be nil.** Then: 28 → "28/32", neutral. 40 → caution.
8. [x] Delete `ProductDraft.hasDetails` and `ReceivingDraft.hasDetails` and their tests. They're used only by the
   accordion this epic removes. `swift test` must pass.

## UI (FarmaciaApp)

New `.swift` files under `FarmaciaApp/` must be registered in `project.pbxproj` by hand.

9. [x] Design-system pieces in `Core/DesignSystem/`:
   - `PrimaryActionBar`: summary line, button, saving and success states, haptics.
   - `QuantityHero`: Unidades/Cajas segmented `Picker`, ± buttons, typeable number. With Cajas it shows
     "Unidades por caja" and "3 × 12 = 36 uds" through `PackQuantity`.
   - `.fieldError(_ message: String?, shakeTrigger:)`: tint, message, shake, Reduce Motion.
   - `MarginChips`: chips with the % and the price under it, "Otro" focuses the price, the selected chip uses the
     tint fill. At accessibility sizes they wrap with `ViewThatFits`.

   Delete `MoreDetailsLabel.swift` (no other callers) and run `graphify update . --force`. Add one `#Preview` per
   component in light and dark. Smoke: none here (steps 10 and 11).
10. [~] **Recibir inventario** (`ReceiveInventoryFormView`):
    - `ProductSummaryRow`
    - Cantidad recibida (`QuantityHero`)
    - Proveedor y costo: Proveedor push, Factura, Costo unitario + `CostChange` badge. The footer says
      "Último costo de <proveedor>" when the cost was filled in.
    - Precio de venta: current price + "Margen 34 % con este costo", "Cambiar precio" toggle, then `MarginChips`
      with "Actual" (step 4) first and pre-selected, the new price field and the old price struck through. Footer:
      "También se actualiza en Square POS."
    - Lote y caducidad: Lote, Tiene caducidad, Vence. `expiryDate` handling is unchanged.
    - Notas (Opcional).
    - The `StockImpact` footer ("Oriente · 0 → 36 (+36)") and `PrimaryActionBar`.

    Remove the toolbar Guardar and keep Cancelar and the discard dialog. `focusOrder` follows the new order. The
    unsaved-changes baseline, `clientRequestId`, offline queue and preferred-supplier autofill are unchanged.
    Smoke (critical flow: receiving):
    - Tap with qty 0 → errors and focus on qty.
    - 3 cajas × 12 → 36.
    - Change the supplier and check that "Sin proveedor" works.
    - Raise the cost → ▲ badge → Cambiar precio → Actual → save.
    - Detail stock +36, and the new lot shows its lot number and expiry.
    - Double-tap the button → one receiving.
    - Light/dark, Dynamic Type XXL, VoiceOver on the hero.
11. [~] **Nuevo producto** (`CreateProductView` / `CreateProductViewModel`):
    - Identity header: a 64 pt photo `Menu` beside a wrapping name `TextField(axis: .vertical)`. Return goes to
      the next field and newlines are stripped. Then `lengthHint`.
    - Precio: Costo por unidad, `MarginChips` (once there is a cost), Precio de venta, and the live margin in the
      header.
    - Identificación (Opcional): SKU "Automático", and Código de barras with a scan button. The scan button opens
      `CodeScannerView` (CodeScanner package, as in `ScanFlowSheet`). Attach it to the barcode row, not to a
      Section that hosts the photo flow (stacked-presentation crash).
    - Inventario inicial (Opcional): Cantidad. With quantity > 0, Proveedor appears and the footer says the cost
      from Precio is used.
    - Disponibilidad: the two toggles with today's `detailsFooter` copy.
    - Descripción (Opcional).
    - `PrimaryActionBar` "Crear producto".

    *Migrates:* the VM's `profitPerUnit` / `marginPercent` / `showMarginPreview` go (the chips and header replace
    them). The per-call `NumberFormatter` in `formatCurrency` is replaced by the app's cached currency formatter.
    Smoke (critical flow: product create):
    - Tap with an empty form → errors on name, then price.
    - Long name wraps, hint at 28+.
    - Cost 12 → 40 % → 20.00. Change the cost to 15 → 25.00. Type 22 → chip released.
    - Scan the barcode.
    - Qty 5 + supplier → created with stock. Cost with no qty → created without stock.
    - Offline → queued alert.
    - Photo still uploads.
    - Light/dark, Dynamic Type XXL.
12. [x] `SupplierPickerView`: a "Sin proveedor" row first, a checkmark on the current choice, and choosing pops
    back. Remove the ⓧ button from the Recibir supplier row. Smoke: inside steps 10 and 11.
13. [ ] Build, simulator smoke for steps 10 and 11 against the local API (never prod), then a device check.
    - Update the README (Inventario → Recibir, Productos → Nuevo producto).
    - Mark `form-ux-polish-epic.md` steps 4 and 5 as superseded by this epic.
    - Tick this epic with commit hashes.
    - Run `graphify update . --force`.

## Migrate-as-touched

- The inline cost-difference math in the Recibir supplier row → `CostChange` (step 3).
- `ReceivingForm.canSave` → derived from `ReceivingForm.issues` (step 5).
- `CreateProductViewModel.marginPercent` / `profitPerUnit` / `showMarginPreview` → `MarginPick` +
  `Margin.percent` (steps 2 and 11).
- Stay in the app: money formatting (cached formatter), stripping newlines from the name field, and the ±
  clamp at 0 (`max(0, q − 1)`, not worth a type).

## Out of scope (follow-ups)

- Barcode-first receiving (scan → product → qty) and PO-based receiving with multiple lots (brief §6.2).
- Short receipt name when the name is over about 32 characters (needs an API field).
- Margin chips as a store setting.
- Save draft vs post: a receiving posts at once, and the stock impact line plus the stable button cover the review
  (brief §5D). Revisit if receiving moves to purchase orders.

## Status (2026-11-04)

- Kit (steps 1–8): `PriceSuggestion`, `MarginPick`, `CostChange`, `ReceivingPrice`, `ReceivingForm.issues` /
  `summary` (`canSave` derives from them), `ProductDraft` issues in form order with `nameMissing` / `priceMissing`
  and cost-without-quantity allowed, `ProductName.lengthHint`; `hasDetails` removed from both drafts.
  355 tests green. The cents-rounding test was checked by removing the rounding and watching it fail.
- App: `PrimaryActionBar` (+ `Double.mxn`), `FieldError`, `QuantityStepper`, `MarginChips`, `OptionalHeader` in
  `Core/DesignSystem/` (one type per file after the swiftui-pro review; `MoreDetailsLabel.swift` deleted, its
  project entry reused for `PrimaryActionBar.swift`). Both forms rebuilt; `SupplierPickerView` has "Sin proveedor".
  The bar is an overlay with `contentMargins` so the form scrolls clear of it — a `safeAreaInset` bar would
  resize the form with the keyboard (see `.formKeyboard`'s notes). Smoke found it riding up with the keyboard
  over the focused field (`.ignoresSafeArea(.keyboard)` can't help: the form itself shrinks), so it now fades
  out on the keyboard's will-show/will-hide with the keyboard's timing; its space stays reserved, nothing moves.
- Nuevo producto also alerts when Square POS wasn't reached (`syncToSquare` on, `squareSynced` false): the API
  doesn't retry that create, and the old "all good" alert was the only place it showed.
- Simulator build passes; `AmountField` gained an `alignment` parameter for the centered hero number.
- Smoke (simulator, local API, 2026-11-04):
  - Recibir ✅: failed tap with qty 0 (red row, message, number pad, "Falta cantidad"); Cajas 3 × 12 = 36 with
    the error moving to "Unidades por caja"; supplier's last cost filled; cost 0.30 → 0.33 showed "▲ 10% vs
    último $0.30" and "El costo subió: revisa el precio."; an invalid cost turned the error back on live;
    saved → stock 49 → 85, last cost $0.33, average $0.31, synced with Square.
  - Nuevo producto ✅ (partly): empty tap → name and price errors, focus on the name; cost 12 → chips $17.50 /
    $20.00 / $24.00; 40 % → price 20, "40% · ganas $8.00"; cost 15 → price followed to 25.00.
  - Fixed from the smoke: the action bar rode up with the keyboard over the focused field (now fades out);
    the per-box error said "Indica cuántas recibiste" (now "Indica cuántas unidades trae cada caja"); unselected
    chips were tinted like selected ones (`.borderless` → `.plain`); the detail screen's "Éxito" alert doubled
    the button's checkmark (now only when Square didn't take the stock).
- [ ] Not smoked yet: those four fixes on screen; the "Cambiar precio" / "Actual" chip path (the UI automation
  loses that section's elements); creating a product (left out on purpose: Square sync is on by default and the
  local API may write to the real Square catalog); barcode scan; dark mode; Dynamic Type XXL.
- [ ] Step 13: device check, then tick 10–11 with commit hashes.

## Follow-ups from the device check (2026-11-04)

14. [x] **Keyboard bar covered the lower fields** (regression). `.formKeyboard` scrolls with `scrollTo(field)`,
    which inside a Form only finds a row-level `.id`; the redesign's wrappers (`.fieldError`, the cost badge
    stack, the stepper, the name header) put the field's id one level down, so the scroll silently did nothing.
    `.fieldError(_:shake:field:)` now gives the row the id; text fields inside a `LabeledContent` (Factura, Lote,
    SKU, and Ajuste's Razón, which had the same latent bug) get a row-level `.id` too.
    Smoke: cost field ✅ (reading position above the bar); Lote reproduced the bug before the LabeledContent fix.
15. [x] **Price at every store, chosen in a review step** (Square's pattern). API (`farmacia-ops`, branch
    `feature/receive-price-all-locations`): `POST /inventory/receive` takes `applyPriceToAllLocations`; a
    non-owner sending it is refused before the receiving is saved (3 controller tests). Kit:
    `ReceiveInventoryRequest(priceAtAllLocations:)`, sent only with a new price (2 tests). App:
    `ReceivingReviewSheet` — stock, cost, supplier, store stock before → after, old → new price and margin, and
    for the owner "Aplicar en todas las sucursales". Shown only when the receiving changes the price; a plain
    receiving still posts in one tap.
    Smoke: owner changes price → review → toggle on → price changes at another store too; manager sees no toggle.
16. [x] **In-control clear and release** (rule: an action that can live inside the control it affects goes there and
    costs no layout; only the primary action earns its own row).
    - `AmountField`: while focused and holding a value, a ⊗ between the number and the unit empties it (the iOS
      `.whileEditing` clear button). Not on the centered quantity hero (it has −/+).
    - `MarginChips` owns the header "Margen · 40% · ganas $8.00"; while a chip is applied a ⊗ releases it and the
      price stays as a manual price (was a dead end: no way back to manual without retyping). Recibir's chips get the
      same header; the duplicate "Margen X%" under its Nuevo precio is gone.
    Smoke: focus cost → ⊗ appears → tap empties it; pick 40% → ⊗ in the header → tap → chip released, price kept,
    a cost change no longer moves the price.
