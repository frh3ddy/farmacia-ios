# Epic: stock alerts that fit the pharmacy (per-product alerts, Pausado, pause suggestions)

**Design:** `docs/stock-alerts-design.md` (decisions in §6). **iOS branch:** `feature/stock-alerts`.
**Status:** approved by the user; ops part (O1–O9) sent to farmacia-ops-50 on 2026-11-11. Ops confirmed the shapes; O1 (migration
`20261111120000_stock_alerts`) and O2 (`npm run import-stock-history -w apps/api`, dry run by default) are built on their
`feature/stock-alerts`, not deployed. The production O2 report waits on the user's go-ahead to deploy. `StockDay` is
sparse (a row only when the level changes or on a restock; readers carry the last level forward). iOS steps 1–7 done
(uncommitted).

Goal: alerts only for regular sellers that ran out or are running low, ranked by lost sales. Slow movers stay quiet at
1–3. Products the supplier can't restock, or that were replaced by an equivalent, can be **paused** per store (not
discontinued: they may come back) and resume when stock is received. Suggestions to pause come from the sales and stock
history, with their evidence, and a person reviews them.

## Part 1: farmacia-ops (farmacia-ops-50; to send after review)

Each step has its own tests on their side. Order matters: O2 feeds O3, and O3 feeds everything after it.

- **O1. Schema** (additive migration): `ProductStoreStatus`, `StockDay`, `ProductStockStats`,
  `PauseSuggestionDismissal`, `StockAlertSettings` (seeded per store: window 90, cover 14, regular ≥ 4 weeks, slow ≤ 2
  units, ≥ 30 days at 0, equivalent ≥ 3 units), `EquivalenceGroup` + `Product.equivalenceGroupId`.
- **O2. Stock history rebuild** (one-time script, dry run by default, like `import-sales-history`):
  - Before the cutover: Square `BatchRetrieveInventoryChanges` since 2020-07-17. Everything into IN_STOCK from supply
    (receivings, adjustments, transfers in) is a restock. A recount sets stock to the counted value; above the replay it
    is a restock, below it a correction. A return to IN_STOCK adds units but isn't a restock. Clamp at 0; a day with a
    sale is never a day at 0.
  - After the cutover: our own movements.
  - **Report before saving:** per store, the share of variations whose replay ends at Square's current count, and the
    worst mismatches. The user decides whether to keep it.
  - Then a nightly job writes the day's `StockDay`.
- **O3. `ProductStockStats` nightly** from `StockDay` + `SalesHistoryLine` ∪ `SaleItem`: units sold, weeks with sales,
  last sale, typical on-hand (median end-of-day stock on days > 0), days at 0, stock-outs, `zeroSince`.
- **O4. Alert level on every product row** (list, sync, detail):
  `stockAlert { level: none|low|out, priority, paused, pauseReason?, zeroSince? }`.
  - Rules: paused or untracked → none; not a regular seller → none; regular at 0 → out;
    regular, 0 < qty < ceil(rate × 14) and qty < typical → low.
  - Priority = rate for out, rate ÷ max(qty, 1) for low.
  - List filters: `outOfStock` = qty ≤ 0 and not paused (stock state), sorted by `zeroSince` desc (unknown last).
    `lowStock` = level low. New `paused` filter. `/products/counts` gains `paused`.
  - Changed rows reach delta sync within a day.
- **O5. Pause / resume:**
  - `POST /products/:id/pause` `{ locationId, reason, note?, replacedByProductId? }`; with `REPLACED_BY_EQUIVALENT` and
    a replacement, both products join one `EquivalenceGroup`.
  - `POST /products/pause` `{ locationId, productIds[], reason }` for several at once.
  - `DELETE /products/:id/pause?locationId`.
  - **Auto-resume** in the same transaction as a receiving or a received transfer that takes the store's on-hand from 0
    to > 0. Adjustments, counts and returns don't resume.
  - Owner/manager only.
- **O6. Alerts list:** `GET /inventory/stock-alerts?locationId&level=out|low&page` ranked by priority (fixes Alertas'
  200-row cap).
- **O7. Pause suggestions:** `GET /inventory/pause-suggestions?locationId` →
  `[{ product, kind, lastSoldAt, unitsInWindow, daysAtZero, stockOuts, equivalent? { id, name, unitsSince } }]`.
  - Kinds: `NO_SALES_AT_ZERO`, `SLOW_WITH_STOCKOUTS`, `EQUIVALENT_SELLING` (equivalent = same `EquivalenceGroup`, or
    confirmed same `medicationDefinitionId`).
  - `POST /inventory/pause-suggestions/dismiss` `{ locationId, items[{ productId, kind }] }`: hidden until the window
    passes or the evidence changes.
- **O8. Equivalents:**
  - `GET /products/:id/equivalents` (group members + catalog matches marked `suggested`).
  - `POST /products/:id/equivalents` `{ productId }` links two products: joins or merges groups.
  - `DELETE /products/:id/equivalents/:otherId`.
  - Catalog matches are shown as suggestions only; nothing links itself.
- **O9. Report:** how many production products have `medicationDefinitionId` (for the user; it doesn't block anything).

## Part 2: iOS logic (FarmaciaKit, TDD)

1. [x] `StockAlert` (Decodable: level, priority, paused, pauseReason, zeroSince).
   First test: **given `{"level":"out","priority":2.5,"paused":false,"zeroSince":"2026-11-08T…"}`, should decode with
   level out**. Then: a missing `stockAlert` (old server) → nil, and callers fall back to today's `StockLevel`.
2. [x] Display, on `StockLevel(quantity:alert:)` (new cases `.empty` and `.paused`) rather than a second badge type.
   First test: **given level out, should be "Agotado" with critical tone**. Then:
   - quantity 0 with level none → "Agotado" neutral (state, no alert)
   - low → "Bajo" caution (the existing badge text)
   - paused → "Pausado · Proveedor sin surtido" neutral (one label per `PauseReason`)
3. [x] `StockAlert.zeroSinceText`.
   First test: **given zeroSince 3 days ago, should say "Agotado hace 3 días"**. Then today → "Agotado hoy", none → nil.
   Uses `DisplayDate.relative`.
4. [x] `PauseSuggestion` (Decodable) + `reasonText`.
   First test: **given NO_SALES_AT_ZERO, last sold 3 mar 2026, 0 in 90 days, 120 days at 0, should say "Sin ventas desde
   3 mar 2026 · 0 en 90 días · 120 días en 0"**. Then:
   - SLOW_WITH_STOCKOUTS: "2 vendidas en 90 días · se agotó 3 veces · 45 días en 0"
   - EQUIVALENT_SELLING: "Su equivalente Paracetamol Genfar vendió 14 desde que se agotó · 30 días en 0"
   - never sold → "Sin ventas registradas · 1 día en 0"
   - the window comes in as a parameter (default 90, from the store's settings)
5. [x] `PauseReason` (enum, labels, `allCases` for the picker).
   First test: **given REPLACED_BY_EQUIVALENT, should say "Reemplazado por equivalente" and require a product**.
6. [x] `ProductFilter.paused` ("Pausados", neutral tone, `apiValue` "paused").
   First test: **given the Pausados chip, should send filter=paused**. Hidden (and coerced to Todos) unless the server
   counts paused products (`ProductCountsResponse.paused` non-nil), so an old server never gets the filter.
7. [x] Migrate-as-touched: the fixed `< 10` in `ProductsViewModel.computeCounts` and in `StockAlertProductsView` move
   onto one FarmaciaKit counter, which uses `StockAlert` when present and today's rule when not.
   First test: **given a product at 0 that is paused, should count it as paused, not out of stock**. Done as
   `StockTally`, used by `ProductsViewModel`, `StockAlertViewModel` and `StockAlertProductsView`. `Product.stockAlert`
   (optional) landed here so the counters can read it; the cache fields stay in step 8. Smoke against today's server:
   Productos and Alertas show the same counts (6 / 24) and no Pausados chip.
   - Review fixes (/tdd-review 2026-11-11): a paused product counts only as Pausados, even with stock left, on both
     sides (`StockTally`, and `ProductCountsResponse.inStock` = total − out − low − paused; ops told). The "no
     Pausados count on an old server" rule moved into `StockTally.paused: Int?`. Tests cover the decode defaults and
     use the API's millisecond timestamps.

## Part 3: iOS UI (FarmaciaApp)

8. [ ] Model, endpoints and cache:
   - `Product.stockAlert: StockAlert?`; `CachedProduct` gains the same fields as optional attributes (SwiftData
     lightweight migration).
   - Endpoints for O5–O8.
   - Smoke: cache-first launch offline still shows the list (critical: activation → PIN → list from cache).
9. [ ] Productos:
   - "Pausados" chip.
   - "Sin Stock" shows the server order (most recent stock-out first) with "Agotado hace N días" on rows.
   - Cards and rows use the `StockAlert` label and tone.
   - Smoke: Sin Stock order, the Pausados count matches its list, location switch (critical) reloads both.
10. [ ] Product detail (owner/manager):
    - A Pausado line in Inventario.
    - Pausar / Reanudar in the Ajustar menu: reason picker, a product picker for "Reemplazado por equivalente" (reuses
      `ProductSearchPicker`), optional note.
    - An "Equivalentes" row that opens the list with Vincular / Quitar. Catalog suggestions are marked "Sugerido" and
      need a tap to confirm.
    - All of it through the single `.sheet(item: DetailSheet)`.
    - Smoke: pause → the product leaves Sin Stock and shows under Pausados; **receive inventory** (critical) on that
      paused product → it resumes (the Pausado line goes away and it leaves Pausados).
11. [ ] Alertas:
    - "Sin stock" and "Stock bajo" cards use the O6 ranked, paginated list (no 200 cap). Rows show the reason to care
      ("vende ~3 al día · agotado hace 2 días").
    - New "Sugerencias para pausar (N)" card opens a review list: each row's `reasonText`; swipe or buttons for Pausar
      and Descartar; Seleccionar → several → "Pausar (N)" with one reason.
    - Smoke: pause two from suggestions at once; dismiss one; both disappear and the counts update; a cashier doesn't see
      the card.
12. [ ] Build, `swiftui-pro` + `swift-concurrency-pro` reviews, `/tdd-review`, README, `docs/inventory-ux-brief.md` §7
    (Bajo = days of cover + normal level for regular sellers; Pausado), mark the low-stock follow-up ✅,
    `graphify update .`.

## Migrate-as-touched

- Into FarmaciaKit: the stock counters in `ProductsViewModel.computeCounts` and `StockAlertProductsView` (step 7), and
  the alert, suggestion and pause labels (steps 2–5). `StockLevel` stays as the fallback for an old server and goes
  away once every server sends `stockAlert`.

## Order and dependencies

- iOS steps 1–7 can start now, against the shapes above.
- UI step 8 needs O4; step 10 needs O5 and O8; step 11 needs O6 and O7.
- O2's report needs the user's OK before the rest of ops builds on it.
- Every UI step keeps working against today's server, because `stockAlert` is optional.

## Notes

- "Stock Bajo" in Productos becomes the alert definition (regular sellers below cover and below normal). A plain count
  has no meaning once thresholds are per product.
- Suggestion quality depends on O2's history. If the mismatch report is poor, kinds `SLOW_WITH_STOCKOUTS` and the
  typical level lean on post-cutover data only until the window fills.
