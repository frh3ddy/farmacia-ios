# Receiving run supplier epic

Branch: `feature/receiving-run-supplier`

## Goal

Productos › Escanear › **Recibir**: pick the supplier the delivery is from, once.
Every receive form in that run starts on that supplier, until the scan sheet
closes. The cost field shows the previous cost as a hint, even after it's cleared.
An unknown code goes to Nuevo producto, then the receive form, then back to the
scanner. The cost typed in Nuevo producto carries over, so it isn't asked for twice.

## Decisions (2026-11-11)

- **The run supplier wins** over the product's preferred supplier. The preferred
  supplier only applies when no run supplier was picked.
- **The run lasts as long as the scan sheet.** Closing the sheet clears the supplier.
  It isn't saved anywhere else, and it isn't added to Ajustes.
- **Cost: auto-fill stays, plus a hint.** An empty or cleared field shows
  `Anterior $12.50` as its placeholder. That's the supplier's last cost, else the
  product's average cost (`ReceivingPrice.oldCost`).
- **The bug fix is app-only.** In Recibir, Nuevo producto doesn't create stock, so the
  API drops the cost and supplier (`farmacia-ops` `products.service.ts:492`). The app
  passes the typed cost and the chosen supplier to the receive form instead.
- **Routing is unchanged.** `ScanNext` already goes unknown → create → receive → scan.

## Background (what exists)

- `ScanFlowSheet` has one `InventoryViewModel` per run, so suppliers load once.
  The steps are `scan / choose / create / receive / count`.
- `ReceiveInventoryFormView.applyPreferredSupplier` → `PreferredSupplier.pick`.
  Picking a supplier then triggers `supplierChanged`, which calls
  `ReceivingCost.offerSupplierCost`. That auto-fills the cost, but only into an empty field.
- `AmountField` uses `Value.placeholder` as its only prompt. There's no custom hint yet.
- `CreateProductView(showsInitialStock: false)` still shows Costo and Proveedor in Recibir.
  `onClose` returns only the `Product`.

## Steps

### Logic (FarmaciaKit, `swift test`)

1. **Supplier precedence.** Generalize `PreferredSupplier.pick` to take an ordered
   list of candidate ids: the supplier carried from Create, then the run supplier,
   then the preferred one. It returns the first one that's in `available`, or nil
   if the user already chose.
   - First failing test: *given a run supplier and a different preferred supplier,
     should pick the run supplier.*
   - Then: *given the run supplier isn't in the list yet, should pick nothing (it
     waits for the list)*. *Given no run supplier, should pick the preferred one*
     (the existing tests keep passing). *Given a supplier carried from Create,
     should pick it over the run supplier.*
2. **Carried cost.** Add `ReceivingCost.prefill(_:forProductId:)`.
   - First failing test: *given a cost carried from Nuevo producto, should keep it
     after the supplier's last cost is offered.*
   - Then: *given a carried cost of 0 (a gift), should keep 0*. *Given a carried cost
     for another product, should not fill.*
3. **Cost hint text.** Add `ReceivingCost.hint(previous:) -> String?`.
   - First failing test: *given a previous cost of 12.5, should be "Anterior $12.50".*
   - Then: *given no previous cost, should be nil* (the field keeps its default
     placeholder).

### UI (FarmaciaApp)

4. **`AmountField` takes an optional `prompt`.** When it's nil, the field falls back
   to `Value.placeholder`. Nothing else changes.
5. **Receive form hint.** The Costo unitario field passes
   `ReceivingCost.hint(previous: ReceivingPrice.oldCost(supplierLast:average:))`.
   - Smoke: open receiving from a product, clear the cost, and check that the hint shows.
6. **Run supplier in the scanner.** In Recibir mode, a row under the mode picker reads
   `Recibiendo de: <proveedor> ›`, or `Elegir proveedor`. It pushes
   `SupplierPickerView` from `inventoryViewModel.suppliers`. It's kept in `@State` on
   `ScanFlowSheet` and passed as `defaultSupplierId` to `ReceiveInventoryFormView`,
   which feeds it into step 1's pick.
   - Smoke (critical flow, receiving): pick a supplier, then scan two products whose
     preferred suppliers are different. Both forms should start on the run supplier.
     Close the sheet, reopen it, and the supplier should be unset.
7. **Nuevo producto in Recibir starts on the run supplier.** `CreateProductView` gets an
   optional `defaultSupplierId`.
8. **Carry the cost and supplier from Create to the receive form.** `onClose` returns
   the product plus a small `ReceivePrefill(cost:, supplierId:)` (the cost is from the
   Precio section). `Step.receive` holds it, and the form applies it with step 2's
   `prefill` and step 1's carried candidate. The baseline counts the prefill as filled
   in by the form, like the supplier auto-fill does, so it isn't an unsaved change.
   - Smoke (critical flow, receiving): Recibir › scan an unknown code › Nuevo producto
     with a cost of $20 › Crear. The receive form should show the supplier and $20,
     and only ask for Cantidad. Save, and you're back at the scanner with the strip
     showing `+N uds`.

### Wrap-up

9. Update the README receiving section and this epic (✅ with hashes). Then run
   `graphify update .`.

## Migrate-as-touched

- The receive form's ordering of default suppliers (inline in `applyPreferredSupplier`)
  moves to `PreferredSupplier.pick` (step 1).
- Prefilling the cost moves into `ReceivingCost` (step 2), and the hint text into
  FarmaciaKit (step 3), so the view only wires them up.

## Out of scope → follow-ups

- On the API side, `POST /products` could save the supplier and cost link (a
  `SupplierProduct`) even without initial stock. Then a product created in Recibir
  would remember its supplier for next time. That's a farmacia-ops change.
- Money as `Decimal`, not `Double`, across receiving (`ReceivingCost`, `ReceiveInventoryRequest`,
  `CreateProductRequest`, `AmountField`): a codebase-wide change, out of scope for this epic.
- Remembering the run supplier across sheet opens or in Ajustes. Add it if people
  ask for it.

## Status (2026-11-11, uncommitted)

- ✅ 1 Supplier precedence: `PreferredSupplier.pick(runId:preferredId:…)`. There's no
  carried-supplier option: Nuevo producto in Recibir doesn't show Proveedor (it sits
  under the hidden Inventario inicial), so there's nothing to carry.
- ✅ 2 `ReceivingCost.prefill`
- ✅ 3 `ReceivingCost.hint`: the text is `Anterior 16.50`, not `Anterior $16.50`. The
  field already shows "$" in front.
- ✅ 4 `AmountField(prompt:)`
- ✅ 5 Receive form hint. Also: `loadSupplierList` now picks a supplier even when the
  list was already loaded, so the run supplier doesn't depend on the product's
  suppliers loading.
- ✅ 6 Run supplier row in the scanner (`ScanFlowSheet.runSupplier`)
- ⏭ 7 Dropped (see step 1).
- ✅ 8 `CreateProductView.onClose(product, cost)` → `Step.receive(cost:)` → `prefillCost`
- ✅ 9 README
- ✅ Simulator smoke (iPhone 17, local API): the delivery supplier wins over the preferred
  one (Abatelenguas opened on Bodega Aurrera, its preferred is Catesa), "Sin proveedor" opens
  on none, and the choice stays set after cancelling. An unknown code opens Nuevo producto with
  the barcode. Not automatable: typing into the number fields, so check the $20 carry-over by hand.

### /tdd-review fixes (2026-11-11)

- ✅ "Sin proveedor" for the run means none for every form, not the preferred one
  (`RunSupplier` .unset / .noSupplier / .supplier, `PreferredSupplier.pick(run:)`).
- ✅ The cost from Nuevo producto goes through `ScanEvent.created(cost:)` →
  `ScanNext.receive(cost:)` (tested; only Recibir carries it).
- ✅ The carried cost counts as entered: Cancelar asks before discarding it.
- ✅ The supplier list loads once per run (`InventoryViewModel.loadSuppliers` shares the
  request in flight); if it fails, "Recibiendo de" says so.
- ✅ The picker uses `navigationDestination(isPresented:)`; the row reads as one VoiceOver element.
