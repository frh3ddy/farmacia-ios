# Epic: product cards in Productos

**Branch:** `feature/product-cards`

Productos gets a **Tarjetas / Lista** switch. Tarjetas is the default, and each phone remembers its choice. A card is
one full-width column (like sample 1). It shows the photo, SKU and barcode, a stock badge, the **full name** on up
to 2 lines, and a row of figures: **Precio · Costo · Stock · Valor**. Lista is today's `ProductRow`, unchanged.

**Already there, no API change:** list rows (`GET /products`, `/products/sync`, the cache) already carry
`sellingPrice`, `averageCost` (the average cost of the stock on hand at this store), `totalInventory`, `sku`, `gtin`,
`tracksInventory`, `name`, `squareProductName` and `squareVariationName`. For cashiers the API already removes cost
(`withoutCosts`, `products.service.ts`), and the app hides it too (`canViewCosts`).

**Full name:** `displayName` prefers the Square *item* name, so the variations of one item look the same in the list
("Buscapina" and "Buscapina"). The API's `Product.name` is `Item (Variation)` (`catalog.service.ts:112`). Placeholder
variations (`regular`, `sin variación`, `no variation`, `unknown`) are left out. The card shows that full name.

## Logic (FarmaciaKit, TDD)

1. [x] `ProductName.display(name:item:variation:)` and `ProductName.full(...)`. Move `Product.displayName`'s rules
   into the kit (migrate-as-touched). `full` = `Item (Variation)` unless the variation is a placeholder (the API's
   `PLACEHOLDER_NAMES`) or already in the item name. Otherwise it falls back to `display`.
   First test: **given item "Buscapina", variation "10 mg 12 tab", should be "Buscapina (10 mg 12 tab)"**.
   Then: given variation "Regular", should be "Buscapina". Given no item, should be `name`. Port the existing
   `displayName` cases ("sin variaci…", "no variation", blank names) as `display` tests first, all green.
2. [x] `ProductFigures(price:cost:stock:tracksInventory:canViewCosts:)` → `price`, `cost`, `stock`, `stockValue`,
   `marginPercent` (through the existing `Margin.percent`).
   First test: **given cost 14, stock 18, should have stock value 252**.
   Then: given `canViewCosts` false, should have nil cost, value and margin. Given stock ≤ 0, should have nil value.
   Given `tracksInventory` false (Yastás), should have nil stock and value.
3. [x] `ProductCodes.lines(sku:gtin:)` → the code lines to show. When the barcode is only another form of the SKU
   (`BarcodeLookup.codeVariants`), show it once.
   First test: **given sku "3664798067460", gtin "03664798067460", should give one line**.
   Then: given sku "8857379", gtin "3664798067460", should give both. Given both nil, should give none.

## UI (FarmaciaApp)

4. [~] `ProductCard` view (`Features/Products/Views/ProductCard.swift`, register it in `project.pbxproj`). It has:
   - a 64 pt `CachedProductImage` (targetSize to match)
   - SKU and barcode in monospaced caption, with the `StockLevel` / risk `ToneBadge`s
   - `ProductName.full`, `.lineLimit(2)`
   - a `Divider`, then the figures row from `ProductFigures`. Cashiers see only Precio and Stock.

   From the UX brief (`docs/inventory-ux-brief.md` §5C, §6.8, §7):
   - Each figure has a label above its value. Numbers are right-aligned, with money in MXN and 2 decimals.
     Stock carries its unit ("18 uds").
   - The cost is labelled **Costo prom.**, because it's the average cost of the stock on hand, not a fixed price.
   - Stock state is always written out as well as colored: "Agotado" and "Bajo" as today, plus a stock number
     tinted by `StockLevel.tone`.
   - Tapping a card keeps the list's place: scroll position, search and chip.

   For layout: `ViewThatFits` drops the figures to a 2×2 grid at accessibility sizes. Use
   `.accessibilityElement(children: .combine)` so VoiceOver reads one sentence per card.
   Smoke: none on its own (step 6).
5. [~] `ProductsView`: `@AppStorage("productsLayout")`, a segmented Tarjetas / Lista `Picker` in the chips section.
   In card mode the same `ForEach` / `NavigationLink` / `onAppear` paging draws `ProductCard` rows inside the
   current `List`, using `.listRowBackground(Color.clear)` and the existing `.card()`. This keeps search, pull to
   refresh, paging and the header and footer with no second scroll container. While a search is active the chips
   section is hidden, and the chosen layout stays.
   Smoke (critical flow): Productos as **owner** (cost, value and margin shown) and as **cashier** at a store where
   they can't view costs (no cost figures). Scroll past page 1 (paging works). Switch layouts and relaunch (the
   choice is kept). Tap a card to open the detail. Scan opens the product. Check Dynamic Type XXL and dark mode.
6. [ ] Build, then a device check. Update the README Productos feature, run `graphify update .` and tick this epic.

## Migrate-as-touched

- `Product.displayName` → `ProductName.display` (step 1). The app keeps a one-line forwarding property, so
  `ProductRow`, detail and alerts don't change.
- `Product.profitMargin` repeats `Margin.percent` → forward it to `ProductFigures` / `Margin.percent` (step 2).
- Stay in the app: `formattedPrice` / `formattedCost` (NumberFormatter cache is UI formatting) and `ProductCard`.

## Out of scope

- A two-column grid (iPad could use one later; on iPhone the 4 figures and long medicine names don't fit).
- Sorting by stock value. Add it if owners ask; it would need an API sort, since the list is paged on the server.

## Status (2026-11-04)

- Kit: `ProductName` (display + full; `Product.displayName` / new `fullName` forward to it), `ProductFigures`
  (`Product.profitMargin` now goes through `Margin.percent`), `ProductCodes`. 338 tests green; the placeholder and
  cost-gate tests were each checked by breaking the code once and watching them fail.
- App: `ProductCard` (figures row split into its own view after the swiftui-pro review) and the Tarjetas / Lista
  switch (`@AppStorage("productsLayout")`). The gap between cards comes from `.listRowSpacing` (cards mode only) on the
  default row background instead of `.card()`, since `.card()`'s gray6 fill would disappear on the grouped gray.
  The simulator build passes.
- [ ] Simulator smoke for step 5: waiting on a PIN for the local API.
