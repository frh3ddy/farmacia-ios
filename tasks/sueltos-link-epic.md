# Sueltos Link Epic (per store)

**Status**: 📋 PLANNED (2026-11-08). Blocked on the ops prerequisite (step 0): it's built on farmacia-ops `feature/per-store-loose-link` (2026-11-09) and waits for dev-67's review, the user's go, and the merge to main.
**Branch**: `feature/sueltos-link`. It needs an API change in farmacia-ops first.
**Goal**: OWNER/MANAGER can link a box product to its loose (suelto) product **for the store they're logged into**, set the pieces per box, and unlink it. This mirrors the web's "Vincular caja con suelto" card.

## Overview

The ops web screen is `apps/web/src/sections/ops/BreakBulkScreen.tsx` ("Sueltos"). The ops session confirmed the contract on main at 6c37a00.

**What the API does today.**
- **Link**: `PATCH /products/:id/loose-link`, where `:id` is the BOX. Body: `{ looseProductId: string | null, quantity?: number }`.
  - Roles: OWNER, MANAGER.
  - DB only; it doesn't touch Square.
- **Where the link is stored**: on `Product.looseProductId`, so **one link covers every store**. The break-bulk service and the sale worker's automatic opening read it from there.
- **Search**: `GET /products?search=&limit=8` already lists only products sold at the session's store (`soldAt(locationId)`). It spreads the full row, so `quantity` and `looseProductId` come back.
- **Errors**: shown as-is; nothing branches on the message.
  - "Un producto no puede ser su propio producto suelto"
  - "El producto suelto ya lleva de vuelta a este producto"
  - "La cantidad debe ser un número entero mayor que cero"
  - "Product <id> not found"

## Decisions (asked 2026-11-08)

- **Scope: link only.** Abrir caja and "Por ventas" are left out (see Out of scope).
- **Entry: a standalone "Sueltos" screen** under Más, shown when `authManager.isManager` (which includes the owner). It has a box picker, a suelto picker, and Piezas por caja.
- **Unlink: yes.** "Desvincular" is behind a confirmation dialog.
- **The link is per store.** Each store's suelto can be a different product, with its own barcode/SKU, so store A's box → suelto pairing must not change store B's.
  - **Piezas por caja is the same everywhere** (confirmed 2026-11-08). It stays on the box product (`Product.quantity`); only the box → suelto pairing is per store.

## 0. Ops prerequisite (farmacia-ops, not this repo)

**Built** on farmacia-ops `feature/per-store-loose-link`, not on main yet (ops reply, 2026-11-09). Contract as built:

- **Storage**: one link per store; `Product.looseProductId` is **dropped** in the same migration.
  - **Migration**: each old link is copied to every store where both products are sold (`soldOnlyAtLocationId` null or that store). A link no store sells both of is dropped.
  - **Creating a product** with `looseProductId` links it at the store it's created at.
- **`PATCH /products/:id/loose-link`** (OWNER, MANAGER): same body `{ looseProductId: string | null, quantity?: number }`.
  - It writes only the session store's link. `null` removes only that store's link. `quantity` sets `Product.quantity` at every store.
  - Response: `{ success, data: { product } }`, the box row plus this store's `looseProductId` (or null).
  - Errors: the existing four, with the loop check over this store's links only, plus **new: 400 "<producto> no se vende en <tienda>"** (e.g. "Paracetamol Suelto no se vende en Oriente").
- **`GET /products` (incl. `?search=`), `GET /products/:id`, `GET /products/sync`**: `looseProductId` is resolved for `?locationId=`, or the session store when it's missing. It's null when there's no link.
  - A trigger stamps the box on every link change, so `/products/sync` resends it.
- **Break-bulk and the sale worker** read the link at that store. Without one, `POST /inventory/break-bulk` refuses with 400 "<caja> no tiene suelto vinculado en <tienda>. Vincúlalo primero." (changed 2026-11-09; it used to be "El producto <id> no tiene un producto suelto vinculado…").
- **Web**: the link card says "Se vincula solo en <tienda>; cada sucursal elige su propio suelto."
- **Still open (not needed for this epic)**: `clientRequestId` on `POST /inventory/break-bulk`.

**iOS impact**
- Steps 1–8 are unchanged. The new error is shown as-is, like the others.
- The smoke in step 8 adds: a suelto sold only at another store → "… no se vende en …".
- iOS work can start on its logic steps (1–5) now. The steps that call the API wait for the merge.
- **Product cache (checked for dev-67, 2026-11-09)**: the cache is per store. On a store switch, `prepare(for: ProductCacheScope)` clears the rows and the sync cursor, and every sync sends `?locationId=`. `CachedProduct` doesn't store `looseProductId`.
  - If it ever does, bump `ProductCacheScope.key`'s suffix (the way `|gtin` was added) so old caches resync.

## Logic (FarmaciaKit, Swift Testing)

Steps 1–5 are done in `FarmaciaKit/Sources/FarmaciaKit/LooseLink.swift`, tested by `LooseLinkTests.swift` (14 tests), `e1ffc83`. Extra cases beyond the plan: "2.5" is refused, and an empty field with a known box quantity sends no `quantity`.

1. ✅ **`LooseLinkRequest` encodes unlink as an explicit null.**
   - First test: *given an unlink, should encode `"looseProductId": null`*.
   - Why: synthesized `Encodable` omits nil. The server would then see `undefined`, Prisma would leave the link alone, and the unlink would silently do nothing.
   - Then: *given no quantity change, should omit `quantity`*, and *given a typed quantity, should encode it*.
2. ✅ **`LooseLinkForm.validate(boxId:boxQuantity:sueltoId:quantityText:)` returns the request or the web's error text.** It takes primitives.
   - First test: *given no box or no suelto, should fail "Elige el producto de caja y el producto suelto"*.
   - Then:
     - *given a box with no quantity and an empty field, should fail "Este producto no tiene cantidad (piezas por caja) — indícala"*;
     - *given "0", "-3" or "abc", should fail "La cantidad debe ser un número entero mayor que cero"*;
     - *given the same product as box and suelto, should fail "Un producto no puede ser su propio producto suelto"*;
     - *given the field equal to the box's quantity, should omit `quantity`*.
3. ✅ **`LooseLinkForm.prefill(boxQuantity:)`**.
   - First test: *given a box with quantity 20, should prefill "20"*. *Given nil, should prefill ""*.
4. ✅ **`LooseLinkForm.pickerSubtitle(sku:quantity:linked:)`**.
   - First test: *given sku "123", quantity 20 and linked, should read "SKU 123 · cantidad 20 · ya vinculado"*. *Given no sku, should start "Sin SKU"*.
   - "ya vinculado" means linked at this store, since the server resolves `looseProductId` per store.
5. ✅ **`LooseLinkForm.linkedText(box:suelto:store:)` / `unlinkedText(box:store:)`** names the store.
   - First test: *given store "Centro", should read "\"Caja X\" vinculado con \"Suelto Y\" en Centro."*.
   - Unlink: *given an unlink, should read "\"Caja X\" desvinculado en Centro."*.

## UI (FarmaciaApp)

6. **`Product` decodes `quantity: Int?` and `looseProductId: String?`.**
   - Both get `= nil` defaults so the cached JSON still decodes.
   - Add `APIEndpoint.setLooseLink(productId:)` (PATCH).
   - Smoke: none (build only).
7. **`SueltosView` + `ProductSearchPicker`.**
   - **`StoreStrip`** (`Core/DesignSystem/StoreStrip.swift`) sits at the top, like the stock-changing sheets, so it's clear which store's link is being set.
   - **Piezas por caja gets a footnote: "Aplica en todas las sucursales."** The link is per store, but pieces per box is saved on the box for every store (review finding, 2026-11-09).
   - The picker searches the live API with a 300 ms debounce via `.task(id:)`. It doesn't use the product cache, because the cache isn't store-resolved for this field.
   - A linked box shows its current suelto at this store (`getProduct`), plus "Desvincular" with a `confirmationDialog`.
   - **Switching store** while the screen is open resets the form and reloads, because the link differs per store.
   - Register the new files in `project.pbxproj`.
8. **Más → "Sueltos"**, behind `authManager.isManager`.
   - **Simulator smoke** against the local API:
     - link at store A; switch to store B: the box shows **not** linked there;
     - link B to a different suelto;
     - switch back: A's link is unchanged;
     - unlink at B: A is still linked;
     - self-link and loop errors show the server message;
     - log in with a cashier PIN: the row is hidden.
   - Locally there's 1 store (PIN 1234), so the smoke needs a second store seeded first.
9. **Docs**: README features + this epic (✅ + hashes); run `graphify update .`.

## Migrate-as-touched

- `Product` stays in the app (formatters/UI). The epic only adds two decoded fields, and the new rules take primitives.
- Nothing else in the app has sueltos logic to move. `AdjustmentType.breakBulkIn/Out` is already in FarmaciaKit.
- The web's validation, in a React component, is ported straight into FarmaciaKit (steps 1–5).

## Out of scope → follow-ups

- **Abrir caja** (`POST /inventory/break-bulk`): needs ops to add `clientRequestId` first, because today a resent request opens the boxes twice.
- **"Por ventas"** (`GET /inventory/break-bulk/automatic`).
- **A "Suelto" row on ProductDetailView**.
- **Box stock as "9 cajas + 7 tabletas"** (ops `formatStock`).
