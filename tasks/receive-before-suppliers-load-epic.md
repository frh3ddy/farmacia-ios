# Epic: Recibir inventario tapped before the supplier loads

Branch: `fix/receive-before-suppliers-load`

**Status:** ✅ steps 1–5 done (uncommitted). Step 1: with a 6 s delay on the iPhone 13 Pro, an early tap showed "Falta costo" and the supplier and cost still filled in afterwards, so the only cause was validating too early. After the fix, the same early tap shows the spinner and saves with Catesa's $0.33 (checked on the phone). Delay removed. Not checked: the failed-load message (needs the request to fail).

**Review follow-ups** (branch `fix/receive-review-followups`):
- ✅ The wait also covers the full supplier list (`viewModel.suppliers`). Without the list, the preferred supplier can't be picked, so a tap before it arrived still showed "Falta costo" (test: *given the product's suppliers loaded but not the supplier list, should wait*). The form loads the list itself if the product page hasn't, which replaces the sheet's fallback `.task` in `ProductDetailView`.
- ✅ `ReceivingSubmit.Action.showIssues` carries the first issue, and the form acts on the kit's answer instead of deciding again.
- ✅ The price note (`PriceEditing.scopeNote`, `inSquare:`) doesn't mention Square POS for a product that isn't in Square, in Editar Precio or in a receiving.

## Bug

Open Recibir inventario and tap the button before the supplier list has loaded. "Falta costo" shows, and Proveedor and Costo unitario are empty.

## What the code does today

- The form loads the product's suppliers in `.task` (`loadProductSuppliers`). Proveedor shows a spinner while `isLoadingSuppliers` is true.
- When the list arrives, `applyPreferredSupplier` selects the preferred supplier. `supplierChanged` then fills its last cost through `ReceivingCost.offerSupplierCost`, which fills only an empty field.
- The button ignores loading. `submit()` validates at once, so with no cost yet it shows `ReceivingForm.Issue.cost` ("Indica el costo unitario…", summary "Falta costo") for a cost that was about to arrive.
- `isLoadingSuppliers` starts `false` and turns `true` only once the task runs, so there's also a short window where the form doesn't even look like it's loading.
- A failed load only `print`s, so the user sees no supplier and no cost, with no reason given.
- Not confirmed: whether the supplier and cost still fill in after an early tap. The reporter isn't sure. I couldn't reproduce it, because the simulator stopped taking taps, and reading the code found nothing that would block the fill. Step 1 settles it.

## Decision

A tap while the supplier and its cost are loading **waits**: the button shows its spinner until loading ends, then continues as a normal tap. It saves, or shows what's missing if there's still no cost (for example, the load failed or the supplier has no cost). There's no error for a cost that's on its way.

## Steps

1. **Reproduce first** (bug fix = reproduction before the fix):
   - Add a temporary 4 s delay before the supplier request.
   - On the iPhone, or the simulator once it takes taps again: tap early, then wait.
   - Write down whether Proveedor and Costo fill in after the load. If they stay empty, find that cause and add its failing test before step 2. The suspects are the error row rebuilding the cost field, and the focus moving to Costo.
   - Remove the delay.
2. **Logic: what a tap does.** `ReceivingSubmit.action(isLoadingSupplierCost:unitCost:issues:)` returns `.wait`, `.showIssues` or `.save` (FarmaciaKit).
   - First test: *given the supplier's cost still loading and no cost typed, should wait instead of reporting a missing cost*.
   - Also: *given a cost already typed, should not wait* (the supplier's cost never overwrites a typed one).
   - Also: *given loading finished with issues, should show them*, and *given none, should save*.
3. **UI: the form waits.**
   - `isLoadingSuppliers` starts `true`.
   - Add `@State waitingForSupplier`: set on `.wait`. While it's set, `PrimaryActionBar` shows its spinner and the form is disabled, like a save in flight.
   - `.onChange(of: isLoadingSuppliers)` clears it and calls `submit()` again.
   - Critical flow to smoke: **receive inventory**, with the temporary delay from step 1:
     - tap early: spinner, then it saves with the preferred supplier's cost;
     - make the request fail: spinner, then "Falta costo" on Costo.
4. **UI: say when the supplier list fails.** In the "Proveedor y costo" footer: "No se pudieron cargar los proveedores; elige uno o escribe el costo." Without it, empty fields after a failed load look like the bug.
5. **Docs:** README (Receiving) and this epic's status. Then `graphify update .`.

## Migration

The submit decision moves out of `ReceiveInventoryFormView.submit()` into `ReceivingSubmit` (step 2). Loading and focus stay in the view.

## Not now

- A retry button for the supplier load. Picking a supplier by hand already works.
