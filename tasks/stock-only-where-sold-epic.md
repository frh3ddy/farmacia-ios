# Stock Only Where Sold, Readable Square Errors Epic

**Status**: ✅ DONE — farmacia-ops `83acfb3` (merge `bbbc36b`); iOS hashes below. Deploy farmacia-ops first, then run the step 10 production check.
**Branch**: `fix/stock-only-where-sold` in both farmacia-ops and farmacia-ios
**Goal**: Stock can only be added at a store that sells the product, and Square sync problems reach the user as a short Spanish reason, never Square's raw error.

## Overview

Found in the 2026-10-31 simulator review (local API, test store "Sucursal Prueba"):

1. **Stock added where the product isn't sold.** A product sold only at store A (`Product.soldOnlyAtLocationId`) could be received at store B: open it at A, switch store, and Recibir is offered. The API accepted it (1 unit at B, at $8). B's product list hides the product, so that stock is invisible except in history and valuation, and its Square sync fails. No stock-entry path checks `soldOnlyAtLocationId`: receiving, positive adjustment (including a count above stock) and transfer receipt.
2. **Square's raw errors shown to users.** Success alerts read "Received 1 units successfully (Square sync failed: Status code: 404 Body: { "errors": [ … ] })" or "(Square sync failed: fetch failed)". The retry result shows the same JSON after "No se pudo sincronizar con Square:". The controllers build these messages in English from the raw Square SDK error.

## API contract

- `getProduct` already sends `soldOnlyAtLocationId`, because it spreads the product row into `data`. The app's `Product` model doesn't decode it.
- New refusal: `400 { success: false, code: 'PRODUCT_NOT_SOLD_AT_LOCATION', message: 'Este producto no se vende en esta tienda.' }`. The app already shows API reasons (`4a4c45e`), so no new error case is needed.
- **Removals stay allowed** at any store (damage, theft, expired, write-off, a count below stock). Stray stock created before the fix has to be removable, and a removal can't put stock where it doesn't belong.
- Square sync responses keep their shape (`squareSync: { synced, error }`, retry `data: { synced, error }`). `error` becomes the short Spanish reason. The raw Square error stays in the `squareSyncError` column and the server log, for diagnosis.

## Logic / UI split

**farmacia-ops (vitest + riteway, PGlite for database behaviour):**
- a `soldAtLocation` guard shared by the three stock-entry paths;
- `squareSyncReason(rawError)`, which turns a raw sync error into a short Spanish reason;
- Spanish success messages in both inventory controllers.

**FarmaciaKit (Swift Testing):** `StockEntry.canAdd(soldOnlyAtLocationId:currentLocationId:)`.

**FarmaciaApp:** decode `soldOnlyAtLocationId`, and gate Recibir plus the adjustments that add stock in `ProductDetailView`.

**Migrate as touched:** nothing has to move. The gating rule is new, takes plain values, and goes straight into FarmaciaKit. The `Product` model stays in the app.

---

## Steps

### farmacia-ops

1. **Guard: receiving.** In `InventoryReceivingService.receiveInventory`, refuse when `soldOnlyAtLocationId` is set and differs from `locationId`.
   First failing test (`inventory-receiving.pg.spec.ts`): *given a product sold only at another store, should refuse a receiving here with PRODUCT_NOT_SOLD_AT_LOCATION and record nothing.*
   Then: *given a product sold everywhere, or only here, should receive as before.*

2. **Guard: adjustments that add stock.** Apply the same check on the positive path of `createAdjustment`, which covers Encontrado, Devolución, a count above stock, and Otro with a positive quantity.
   First failing test (`inventory-adjustment.pg.spec.ts`): *given found stock for a product sold only at another store, should refuse it.*
   Then: *given damage of stray stock at that store, should still remove it* (removals allowed).

3. **Guard: transfer receipt.** Refuse receiving a transfer at a destination that doesn't sell the product, and say which product in the message.
   First failing test (`transfer.pg.spec.ts`): *given a transfer of a product sold only at the origin, should refuse to receive it at the destination.*

4. **One guard, three callers.** Refactor the checks into one `assertSoldAtLocation(product, locationId)` helper, keeping all three tests green. Message: "Este producto no se vende en esta tienda."

5. **Readable Square reasons.** Add `squareSyncReason(raw)` in `apps/api/src/square/`.
   First failing test: *given "Location not linked to Square", should say "La tienda no está conectada a Square".*
   Then, one assertion each:
   - *"Product not mapped to Square catalog" → "El producto no está en el catálogo de Square";*
   - *a 404 body whose detail mentions a location → "Square no reconoce esta tienda";*
   - *"fetch failed" or a timeout → "No se pudo conectar con Square; reintenta más tarde";*
   - *"Square client not configured" → "Square no está configurado";*
   - *anything else → "Square rechazó el cambio".*

6. **Use the reasons, and Spanish messages.** The receiving and adjustment controllers (create and retry) and the transfer retry send the reason in `squareSync.error` and the retry `data.error`, and build their messages in Spanish:
   - receiving: "Se recibieron 1 unidades";
   - adjustment: "Ajuste registrado: Encontrado, 2 unidades";
   - suffix on a failed sync: " — no se sincronizó con Square: <reason>. Puedes reintentar desde el historial";
   - retry: "Sincronizado con Square" / "No se sincronizó con Square: <reason>".

   The raw error is still stored in `squareSyncError`.
   First failing test (`inventory-receiving.controller.spec.ts`): *given a receiving whose Square sync failed with a raw 404 body, should answer with a Spanish message and no raw JSON.*

### farmacia-ios

7. **Logic: who may add stock here.** `StockEntry.canAdd(soldOnlyAtLocationId:currentLocationId:)` in FarmaciaKit.
   First failing test: *given a product sold only at another store, should not allow adding stock here.*
   Then: *given a product sold everywhere (nil) or only here, should allow it.*

8. **UI: gate the product screen.** Decode `soldOnlyAtLocationId` in `Product` (optional, so older API responses still decode). In `ProductDetailView`, when `StockEntry.canAdd` is false:
   - hide Recibir;
   - hide Encontrado and Devolución in Ajustar Inventario;
   - keep the removals and Corrección de Conteo, since a count above stock is refused by the API with its reason;
   - show "Este producto se vende solo en otra tienda".

   Smoke in the simulator: **receive inventory** (critical flow). Open the store-only product at its own store, then switch store with it open: Recibir disappears, Daño is still offered. The local test data (Sucursal Prueba, "Aceite de almendras" sold only at farmacia dev ops) is set up for exactly this.

9. **Docs.** README Inventory section: stock only at stores that sell the product. Mark the follow-ups epic and this one done with commit hashes. Run `graphify update .` (with `--force` if code was deleted).

### Before cutover (data check, read-only)

10. **Stray stock already in production?** Run against production, read-only, before deploying:

    ```sql
    SELECT p.name, l.name AS store, SUM(i.quantity) AS units
    FROM "Inventory" i
    JOIN "Product" p ON p.id = i."productId"
    JOIN "Location" l ON l.id = i."locationId"
    WHERE p."soldOnlyAtLocationId" IS NOT NULL
      AND p."soldOnlyAtLocationId" <> i."locationId"
      AND i.quantity > 0
    GROUP BY 1, 2;
    ```

    Any rows are stock no store list shows. Remove them with a Baja at that store; removals stay allowed.

## Done

- farmacia-ops: `assertSoldAtLocation` (`apps/api/src/inventory/sold-at-location.ts`) in receiving, positive adjustments and transfer **shipping**: refused before stock leaves the origin, rather than at receipt, where it would be stranded in transit. Plus `squareSyncReason` / `squareSyncNote` / `readableSync` (`apps/api/src/square/square-sync-reason.ts`) with Spanish messages in the receiving, adjustment and transfer controllers. 455 API tests pass.
- farmacia-ios: `StockEntry.canAdd` (FarmaciaKit, 182 tests pass), `Product.soldOnlyAtLocationId`, gated `ProductDetailView`. Simulator smoke passed with the local test data: Recibir shown at the product's own store; at the other store hidden, with the note, and only removals plus Corrección de Conteo in Ajustar.

## Deploy order

Deploy farmacia-ops first. The app's gating is a convenience; the API guard is what stops it. Older apps keep working: they simply get the new refusal, with its reason shown inside the form.

## Out of scope (separate items)

- **Más screens left open after a role drop** (review finding #2): an app-only fix that closes the Más and Productos stacks on a store change and clears a report's data when its reload is refused. Plan it separately.
- **"USD" prices:** first check whether production Square locations are MXN.
