# Sueltos Linked List + Images Epic

**Status**: 🚧 BUILT (2026-11-09). Steps 1–6 are done; it's uncommitted and waits for the ops endpoint to merge.
**Branch**: `feature/sueltos-linked-list`
**Goal**: On Sueltos, see the box → suelto pairs already linked at this store, and see each product's photo, both in that list and in the search results, so the right product is easier to recognise.

## Decisions (asked 2026-11-09)

- **Data: ask ops for an endpoint.** Nothing lists a store's links today. They live in `ProductLooseLink` (`@@unique([locationId, boxProductId])`), read only by PATCH loose-link and break-bulk. The web screen has no list either.
- **Placement: a section on Sueltos**, "Vinculados en <tienda>", under the form. It reloads after each link or unlink.
- **Tapping a pair loads it into the form**: box + suelto selected, and Piezas por caja prefilled. From there you can change the suelto or the pieces, or tap Desvincular.
- **Images: a 48pt thumbnail**, the same as `ProductSummaryRow`. A box icon shows when there's no photo.

## 0. Ops prerequisite (farmacia-ops, not this repo)

**Built** on farmacia-ops `feature/loose-links-list` (2026-11-09). It's uncommitted, waiting for the user; api 599/599 pass. The contract is as proposed, plus: **a pair is skipped if either product is no longer sold at the store**. The web screen doesn't get the list for now.

The proposed contract:

- **`GET /products/loose-links`** (OWNER, MANAGER): the session store's links, ordered by box name.
  - Response: `{ success, data: [{ box: <product row>, loose: <product row> }] }`.
  - Each `<product row>` has the same shape as a `GET /products` item (`id, name, sku, squareImageUrl, quantity, looseProductId`…), so iOS decodes `Product` as is.
  - No paging: a store has dozens of links, not thousands. Ops can add paging later if that changes.
- Route order: declare it before `GET /products/:id`, or "loose-links" is read as an id.
- Main.ts `apiPrefixes` already covers `/products`.

## Logic (FarmaciaKit, Swift Testing)

The rules go in `LooseLinkForm`, next to the existing ones in `LooseLink.swift`.

1. ✅ **`LooseLinkForm.linkedRowDetail(quantity:)`**: the second line of a pair in the list.
   - First test: *given quantity 10, should read "10 piezas por caja"*.
   - Then: *given 1, should read "1 pieza por caja"*, and *given nil, should read "Sin cantidad"*.
2. ✅ **`LooseLinkForm.linkedEmptyText(store:)`**.
   - First test: *given store "Centro", should read "Ningún producto vinculado en Centro."*.
3. ✅ **`LooseLinkForm.linkedHeader(store:count:)`**: the section title.
   - First test: *given "Centro" and 3, should read "Vinculados en Centro (3)"*.
   - Added: *given a nil count (still loading), should leave the count out instead of showing 0*.

## UI (FarmaciaApp)

4. ✅ **Photos in the pickers.** Put a `CachedProductImage` (48pt, `squareImageUrl`, box-icon fallback) in `ProductOptionLabel`. Both the search results and the picked product's row use it.
   - Search results already carry `squareImageUrl`, so there's no API change.
   - Smoke passed (2026-11-09): "A" listed Audifonos with its photo and Aguja gris with the box icon.
   - Planned smoke: type "Aguja", and the photos show. A product with no photo shows the box icon. The rows still clear the keyboard.
5. ✅ **The "Vinculados en <tienda>" section** (`SueltosView`).
   - Smoke passed (2026-11-09, local API on ops' branch):
     - An empty store reads "Ningún producto vinculado en farmacia dev ops."
     - Linking Aguja gris → Aguja rosa adds the row "(1) … 10 piezas por caja".
     - Tapping the row loads the box ("ya vinculado"), the suelto, 10 pieces, and Suelto actual + Desvincular.
     - Desvincular → confirm empties the list.
     - A load failure shows the error (seen while the API still served the old routes and returned a 404).
   - **Not checked here**: the Oriente local isolation (ops' test covers store scoping), and the cashier (the Más row is unchanged).
   - **Open (ops, the user's call)**: a pair whose product is no longer sold at the store is left out of the list, but Abrir caja / automatic opening still use it. Either the list shows it (so it can be unlinked), or the system ignores it. iOS needs no change either way.
   - `APIEndpoint.listLooseLinks` (GET). `LooseLinkPair: Decodable, Identifiable { box: Product; loose: Product }`, keyed by `box.id`.
   - Load it in `.task`, and reload after a successful link or unlink.
   - A load failure shows a StatusLabel ("No se pudo cargar…"), not an empty list.
   - Each row: the box's photo and name, "→" and the suelto's photo and name, and `linkedRowDetail`.
   - Tap: `box = pair.box`, `suelto = pair.loose`. The existing `.task(id: box?.id)` prefills the quantity and shows "Suelto actual" + Desvincular. Then scroll to the top of the form.
   - **Smoke** (local API; store switching is a critical flow):
     - The list shows the pair linked at farmacia dev ops.
     - Link a new pair, and the list grows. Unlink one, and it goes away.
     - Tapping a pair fills in the form. Changing its suelto and tapping Vincular updates that row.
     - At Oriente local, the list shows only that store's pairs.
     - The Sueltos row is still hidden for a cashier.
6. ✅ **Docs**: the README features line, this epic (✅ + hashes), and `graphify update .`.

## Migrate-as-touched

- Nothing moves. The new rules are text helpers that take primitives, and the photo is UI-only (`CachedProductImage` stays in the app).
- `LooseLinkPair` is a decoded API model, so it stays in the app, like `Product`.

## Out of scope

- Searching or filtering within the linked list. Add it if a store ends up with too many pairs to scroll.
- Showing the links of other stores.
