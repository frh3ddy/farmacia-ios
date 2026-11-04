# Epic: scanned barcodes and editable SKU

**Branch:** `fix/scan-gtin-variants`

The iPhone scanner can read an EAN-13 as its 14-digit GTIN form (`3664798067460` → `03664798067460`). A
product saved with the 13 digits wasn't found, so the scan opened Nuevo Producto; some products were saved with
the 14 digits.

## Logic (FarmaciaKit, TDD)

1. [x] `BarcodeLookup.codeVariants(_:)`: a GTIN (8/12/13/14 digits) → all its zero-padded forms, the scanned one
   first; anything else → only itself. First test: given `03664798067460`, should also try `3664798067460`.
2. [x] `BarcodeLookup.newProductSku(_:)`: the 14-digit form with a leading zero → the 13 digits on the box.

## App

3. [x] Scan lookup (memory, cache, server exact search) tries every form; the server is asked one form at a time
   until one matches a SKU exactly. Nuevo Producto from a scan is prefilled with `newProductSku`.
   Smoke: scan a product whose SKU is the 13-digit barcode — opens it instead of Nuevo Producto.
4. [x] **Match Square's GTIN** — some barcodes are in the Square variation's GTIN field (`upc`), not the SKU: e.g.
   Buscapina 10 mg 12 tab, SKU `8857379`, GTIN `3664798067460` (the box in the report). farmacia-ops doesn't store
   it. Asked ops (2026-11-03) for `Product.gtin` from Square sync + backfill, exact search on sku OR gtin, and
   `gtin` in list/detail/sync payloads. Live (ops main f972cf7). iOS: `Product.gtin` (optional, decodes when
   absent), `CachedProduct.gtin` + `findByGtin`, `BarcodeLookup.matches(sku:gtin:variants:)` (tested) for memory and
   cache, and the barcode in product detail. The cache scope key changed (`store:<id>|gtin`), so every phone downloads
   the catalog once more, with barcodes.
   Import ran in production (2026-11-03): 798 of 3,356 products got a barcode from Square, with 0 conflicts. The other
   ~2,560 had none in Square.
   Smoke, after the import: scan the Buscapina box (GTIN `3664798067460`, SKU `8857379`) → opens Buscapina.
5. [ ] **Edit SKU (and GTIN) in product detail** — needs a farmacia-ops endpoint (none today; `Product.sku` is unique and the
   Square variation's SKU must follow). Asked the ops session for `PATCH /products/:id/sku` (2026-11-03).


## Proposed API contract (farmacia-ops `tasks/product-barcode-epic.md`, 2026-11-03; not built yet)

Build steps 4–5 only once ops confirms each part is live.

- `Product.gtin: String?`, indexed and not unique, filled from Square's variation `upc`. It's in the list, detail and
  `/products/sync` rows, and a barcode change stamps the product so delta sync sends it.
- Exact search (`search=X&exact=true`) matches sku **or** gtin, case-insensitive, and `exactMatch` is true for
  either. There's no zero-padding on the server, so iOS keeps sending each form.
- Import: a one-off, read-only Square backfill. Products whose variations carry different barcodes stay empty and go
  on a list for the owner. After this, barcodes are edited in the app (catalog sync is migration-only).
- `PATCH /products/:id { sku?, gtin? }`, **owner only** (403 otherwise), with no locationId. Values are trimmed, an
  empty string clears the field and a field left out is unchanged. Square is written first: if it fails, nothing
  changes and the error has a Spanish message. Yastás or non-Square products are saved in the app only.
  - 409 `{ code: "SKU_TAKEN", message, product: { id, name } }` → "Ese SKU ya es de <name>".
  - 200 `{ success: true, data: <product detail shape> }`.
- Create: `POST /products` will take an optional `gtin` (approved, not built yet). It must be 8/12/13/14 digits
  (anything else is a Spanish 400), may be shared with another product, and is sent to Square as the new variation's
  `upc`. **Decided (owner):** a scan that found nothing opens Nuevo Producto with the code
  in **gtin only**, and the SKU stays empty unless typed (a SKU is unique, a barcode can be shared). The code keeps
  `newProductSku`'s 14 → 13 rule; rename it for the barcode. Until ops says create takes gtin, a scan fills the SKU
  only.
- Deploy: the gtin field, search, sync and the import script are merged into farmacia-ops main locally; the
  production push is waiting on the owner.
- Create contract (final, built on ops `feature/barcode-on-create`, not live yet):
  - `gtin` is an optional **string**. It's trimmed, and an empty string means none.
  - It must be 8/12/13/14 digits; anything else (including a number) is a 400 "El código de barras debe tener 8, 12,
    13 o 14 dígitos", and nothing is written.
  - It's returned in `data.product.gtin` and sent as Square's `upc`. If Square is down, it's saved locally and pushed
    later.
  - [x] iOS: Nuevo Producto has a "Código de barras" field (`ProductDraft.gtin`, `CreateProductRequest.gtin`, tested). A
    scan fills it (`newProductBarcode`, 14 → 13) and leaves the SKU empty. The form says "El código de barras debe tener
    8, 12, 13 o 14 dígitos." when Crear is off for that reason. Live on ops.
    Smoke: scan a code nobody has → Nuevo Producto shows it under Código de barras with SKU "Automático"; create it,
    then scanning again opens it.
