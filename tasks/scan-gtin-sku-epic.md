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
4. [ ] **Match Square's GTIN** — some barcodes are in the Square variation's GTIN field (`upc`), not the SKU: e.g.
   Buscapina 10 mg 12 tab, SKU `8857379`, GTIN `3664798067460` (the box in the report). farmacia-ops doesn't store
   it. Asked ops (2026-11-03) for `Product.gtin` from Square sync + backfill, exact search on sku OR gtin, and
   `gtin` in list/detail/sync payloads. Then iOS: decode `gtin`, cache it (indexed like `normalizedSku`), match
   scans on both (with `codeVariants`), show it in product detail.
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
