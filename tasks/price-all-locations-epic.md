# Epic: price changes apply to every store by default

Branch: `feature/price-all-locations-default`

**Status:** ✅ steps 1, 2, 4–7 done ("feat: price changes apply to every store by default"). Step 3 needed no new code: `ReceiveInventoryRequest` already sent "every store" only with a new price; the form now passes `PriceEditing.appliesToAllLocations`. `PriceEditing.canApplyToAllLocations` was folded into it. Checked in the simulator: Editar Precio opens with the switch on and the note "Se aplica en todas las sucursales y en Square POS."; off → "Solo cambia en farmacia dev ops y en su Square POS.". **Still to check on the phone:** a receiving with Cambiar precio saves without a sheet (the simulator can't scroll the form down to Cambiar precio).

## Goal

When the owner changes a sale price, it applies at every store. This covers both places a price can change:

- **Editar Precio** (product detail)
- **Recibir inventario → Cambiar precio**

## Decisions

- **Owner only.** Managers keep changing only their own store. The API refuses anything else (403, `products.controller.ts`), and that stays as it is.
- **Editar Precio:** the owner's switch "Aplicar en todas las sucursales" starts **on**. It is the place to set one store's price on purpose.
- **Recibir inventario:**
  - **No choice and no review sheet.** The review sheet ("Revisar recepción") existed to ask where the price applies. With every store as the default it has nothing to ask, so it goes, and "Recibir inventario" saves directly again, with or without a price change.
  - **Owner:** a new price there goes to every store.
  - **Manager:** a new price goes to their store only.
  - A note under Nuevo precio says which.
- **No switch for a product sold at only one store** (`soldOnlyAtLocationId`): there's nowhere else to apply the price.
- **No API change.** `PATCH /products/:id/price` and `POST /inventory/receive` already take `applyToAllLocations` / `applyPriceToAllLocations`.

## How prices and costs are stored today (answers the question)

- **Price is per store.** Each store has its own `CatalogMapping.priceCents`, plus a per-store price in Square.
  - "Todas las sucursales" sets every store's row and Square's base price for all locations.
  - Otherwise, only the current store changes.
- **Cost, on receiving:**
  - **Per store:** the receiving creates a FIFO batch (`Inventory`) at the receiving store with that unit cost. That store's stock value, average cost and COGS use it. Other stores keep their own batches and costs.
  - **Shared by all stores:** the supplier's last cost (`SupplierProduct.cost`, no location) and the cost history (`SupplierCostHistory`). The next receiving from that supplier at **any** store pre-fills this cost, and Historial de costos shows it chain-wide.

## Logic (FarmaciaKit, Swift Testing)

1. **Where a new price applies:** `PriceEditing.appliesToAllLocations(isOwner:soldOnlyAtLocationId:)`. It is the receiving's value, and Editar Precio's starting value and whether it shows the switch.
   - First test: *given the owner and a product sold at every store, should apply to every store*.
   - Also: *given a manager, should not*, and *given a product sold at only one store, should not*.
2. **Saying where the price applies:** `PriceEditing.scopeNote(allLocations:syncToSquare:storeName:isOwner:)`, moved out of Editar Precio's footer (migrate-as-touched) and reused under Nuevo precio in the receiving.
   - First test: *given all stores with Square on, should say "Se aplica en todas las sucursales y en Square POS."*
   - Also: *given one store, should name it ("Solo cambia en Centro…")*.
   - Also: *given a manager, should say only their store, and that the owner changes the others*.
   - Also: *given Square off, should say Square POS keeps the old price*.
3. **Receiving request:**
   - First test: *given the owner changing the price, should send `applyPriceToAllLocations: true`*.
   - Also: *given a manager, or no price change, should not send it* (`ReceiveInventoryRequest`; the API refuses a manager's).
4. **Editar Precio's request:** move `UpdatePriceRequest` into the kit with a builder.
   - First test: *given Square off and all stores on, should still send `applyToAllLocations: true`*. Today the app drops it when Square is off, so the other stores' price in the app wouldn't change. The API already handles this case (`updateMany` on the catalog mappings).
   - Also: *given a manager, should never send `applyToAllLocations`*.

## UI (FarmaciaApp)

5. **Recibir inventario:**
   - Delete `ReceivingReviewSheet.swift` and remove it from pbxproj.
   - In the form, remove `showReview` / `reviewSummary` / `priceAtAllLocations`. `submit()` saves directly.
   - Under Nuevo precio, show the step 2 note.
   - Run `graphify update . --force`, since a file is deleted.
   - Critical flow to smoke: **receive inventory** with Cambiar precio. It saves straight from the button, with no sheet. Check the store's `CatalogMapping` price in the dev database.
6. **Editar Precio:**
   - The switch starts from step 1.
   - It shows for every owner-editable product, not only when "Actualizar en Square" is on.
   - Its footer comes from step 2.
   - Smoke in the simulator as the owner: the switch starts on; turn it off and check the footer; save.
7. **Docs:**
   - README: Productos → precio, and Receiving (drop the review sheet).
   - `tasks/inventory-forms-redesign-epic.md`: note the review sheet was removed.
   - This epic's status.

The dev database has only one store, so "every store" can only be checked end to end on production data, or after adding a second dev store.

## Migration

- Editar Precio's scope footer moves into `PriceEditing.scopeNote`.
- `UpdatePriceRequest` moves from `Models/Product.swift` into the kit.

## Not now

- Letting managers change other stores' prices (needs an API rule change; decided against).
- A way to set one store's price from a receiving. Use Editar Precio for that.
- Making the supplier's last cost per store. It's shared today; worth doing only if stores pay a supplier different prices.
