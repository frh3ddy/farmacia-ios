# Epic: stock alerts that fit the pharmacy (per-product alerts, Pausado, pause suggestions)

**Design:** `docs/stock-alerts-design.md` (decisions in §6). **iOS branch:** `feature/stock-alerts`.
**Status:** approved by the user; ops part (O1–O9) sent to farmacia-ops-50 on 2026-11-11. Ops confirmed the shapes; O1 (migration
`20261111120000_stock_alerts`) and O2 (`npm run import-stock-history -w apps/api`, dry run by default) are built on their
`feature/stock-alerts`, not deployed. The production O2 report waits on the user's go-ahead to deploy. `StockDay` is
sparse (a row only when the level changes or on a restock; readers carry the last level forward). iOS steps 1–7 done
(`e25702d`).
**Later (user, 2026-11-13):** O7 (pause suggestions), O8 (equivalents) and O9 (report) are documented for a later
implementation; the iOS parts that need them (Equivalentes on the detail, the Sugerencias card) wait with them.
- 2026-11-12: O2 saved in production with the user's OK (98,747 `StockDay` rows; replay matched Square's count for
  99.6% of Lolita items and 97.3% of Oriente items, and every mismatch so far is Square gone negative, with the replay
  clamped at 0). Nightly stock days run at 03:00 Mexico City. Square's negative counts stay as they are (the app is the
  stock source of truth). O3 never counts a day with sales as a day at 0. Next: O3, then O4.

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
    a replacement, both products join one `EquivalenceGroup`: a new group if neither has one, else the other joins
    it. If both are already in different groups, the replacement stays on the pause and the groups aren't merged
    (merging is a deliberate O8 action; user, 2026-11-13).
  - `POST /products/pause` `{ locationId, productIds[], reason }` for several at once.
  - `DELETE /products/:id/pause?locationId`.
  - Responses (confirmed by ops 2026-11-13): pause and resume answer `{ success, data: <product row> }`, the same row as
    `GET /products/:id?locationId` with `stockAlert`. Bulk answers `{ success, data: [rows] }` in the order sent.
    Resuming a product that isn't paused returns its row. Refusals are 400/403 with a Spanish `message`. iOS takes the
    row to update the detail screen, the list and the cache with no refetch.
  - Bulk pause is all or nothing (ops 2026-11-13): one refused product (Yastás "no lleva existencias", "está
    descontinuado", "no se vende en esta sucursal") fails the whole call with 400 (404 for an unknown id) and
    `{ success: false, message: "<name>: este producto <why>", productId }`. 1–200 ids, else 400 "Indica de 1 a 200
    productos". Single-pause refusals have no `productId`. iOS (step 11): `NetworkError` keeps only the message today,
    so read `productId` from the error body, mark that row, keep the selection, and let the person deselect it and retry.
  - **Live in production (ops 2026-11-13)**, with O4's `stockAlert`, the `paused` filter and its count. All three
    endpoints are OWNER/MANAGER only, at the session's own store. `stockStats.stockAtEnd` fills in after the first
    03:00 run, so until then a product that sells out today has `zeroSince: null` (the badge falls back to "Agotado").
  - **Auto-resume** in the same transaction as any receiving or received transfer of that product at that store,
    whatever its stock was (user, 2026-11-13: a product paused with 2 left must resume when the supplier delivers).
    Adjustments, counts and returns don't resume.
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

8. [~] Model, endpoints and cache (cache part done 2026-11-13: `CachedProduct.stockAlertData` holds the encoded
   `StockAlert`, an optional attribute, so a lightweight migration; the O5–O8 endpoints wait for ops):
   - `Product.stockAlert: StockAlert?`; `CachedProduct` gains the same fields as optional attributes (SwiftData
     lightweight migration).
   - Endpoints for O5–O8.
   - Smoke: cache-first launch offline still shows the list (critical: activation → PIN → list from cache).
9. [x] Productos, search-first (the user's idea via ops, decided 2026-11-12): staff search or scan, they never
   scroll the catalog.
   - Top: the search field, ready to type, with the scanner next to it.
   - Under it, chips with counts: Agotados, Bajo, Por vencer, Pausados, and Margen bajo for owners and managers.
     Each opens its short server-filtered list. Pausados shows only when counts send `paused`.
   - No search and no chip: **the 10 products opened most recently on this phone** (no catalog list). The
     ranked-alerts list from O6 stays behind the chips and in Alertas, not here.
   - A "Ver todo" link opens today's full list, with its sort options and the cards/list switch.
   - Agotados shows the server order (most recent stock-out first) with "Agotado hace N días" on rows. Cards and rows
     use `StockLevel(quantity:alert:)`.
   - Delta sync is unchanged: the full catalog stays on the phone, so offline search stays local. This is a screen
     change only, and it drops the full-list page requests.
   - Logic (FarmaciaKit, TDD) `RecentProducts`: an ordered list of ids, newest first, no duplicates, capped at 10.
     First test: **given A, B, then A opened again, should list A, B**. Then: the 11th drops the oldest; an id no
     longer in the catalog (deleted or discontinued) is skipped when shown. Stored per device in `UserDefaults`
     (product ids only, no session data).
   - Smoke: activation → PIN → Productos opens on search with recents (critical); search offline from the cache;
     each chip's count matches its list; Ver todo; location switch (critical) reloads the counts and chip lists.
   - Done 2026-11-13 (uncommitted). Kept the existing chip names (Sin Stock, Stock Bajo, Por Vencer) to match Alertas;
     In Stock and Todos are gone as chips (Ver todo replaces Todos). The sort menu shows only under Ver todo. Counts show
     "—" until they load. Smoke on the simulator against ops' O4 locally: start screen counts (Sin Stock 6, Ver todo
     46, Pausados 0), the Sin Stock chip list, opening a product puts it under Recientes, search "Aba" → 2, clearing
     the search returns to the start screen, Ver todo and back. Not checked: location switch (1 store locally),
     offline launch, and "Agotado hace N días" (no local stats yet).
10. [x] Product detail (owner/manager). Pausar / Reanudar done 2026-11-13 (`3351ded`); Equivalentes is for later, with O8:
    - A Pausado line in Inventario.
    - Pausar / Reanudar in the Ajustar menu: reason picker, a product picker for "Reemplazado por equivalente" (reuses
      `ProductSearchPicker`), optional note.
    - An "Equivalentes" row that opens the list with Vincular / Quitar. Catalog suggestions are marked "Sugerido" and
      need a tap to confirm.
    - All of it through the single `.sheet(item: DetailSheet)`.
    - Smoke: pause → the product leaves Sin Stock and shows under Pausados; **receive inventory** (critical) on that
      paused product → it resumes (the Pausado line goes away and it leaves Pausados).
    - Done: `PauseForm` in FarmaciaKit (`validate` → `PauseRequest`, `action` → Pausar / Reanudar / nothing,
      `StockLevel.detailText`), tests in `ProductPauseTests.swift`. First test: **given Proveedor sin surtido and no
      note, should send the store and the reason only**. The app adds `.pauseProduct` / `.resumeProduct`,
      `PauseProductView` (reason, replacement picker for Reemplazado por equivalente, which the app requires though the
      API doesn't, and an optional note), and Pausar / Reanudar at the end of Ajustar. The menu shows only to owners and
      managers, when the server sends `stockAlert`, and for products this store stocks. Reanudar is always offered on a
      paused product. The response row updates the detail, the list and the cache with no refetch.
    - Smoke on the simulator against ops' local O5: Pausar with no reason → "Elige un motivo" (which stayed after a
      reason was picked; fixed). Se vende poco → "Pausado · Se vende poco" with "Se reanuda solo cuando recibas
      inventario.", Sin Stock 6 → 5, Pausados 1, and the recents row shows Pausado. **Receive 1 unit → resumed** (the
      Pausado line is gone). Pausing with stock on hand, then Reanudar, works. Not checked: a cashier (no menu, by the
      rule's tests) or a pause with a replacement.
11. [x] Alertas (ranked lists `776ded2`; the Sugerencias card is for later, with O7). O6 as built by ops (2026-11-13, live in production 2026-11-13, ops main a8eb30f; every sorted list breaks ties on product id, so pages never repeat or skip): no
    `/inventory/stock-alerts` route. Use `GET /products?filter=outAlert` / `filter=lowAlert` instead, with the same rows,
    pages (limit ≤ 200, `totalCount`, `hasMore`) and cost stripping, only regular sellers that aren't paused, sorted by
    `stockAlert.priority` desc then newest. `/products/counts` adds `outAlert` (Alertas "Sin stock"). "Stock bajo" uses
    the existing `lowStock`. Productos "Sin Stock" stays `outOfStock`.
    - "Sin stock" and "Stock bajo" cards use the O6 ranked, paginated list (no 200 cap). Rows show the reason to care
      ("vende ~3 al día · agotado hace 2 días").
    - New "Sugerencias para pausar (N)" card opens a review list: each row's `reasonText`; swipe or buttons for Pausar
      and Descartar; Seleccionar → several → "Pausar (N)" with one reason.
    - Ranked lists done 2026-11-13 (committed, "feat: ranked Alertas lists"): `AlertList` (filter, count with an `outAlert` → `outOfStock` fallback,
      Margen Bajo only with costs, `keeps` for rows changed on the detail) and `StockAlert.reasonText`, tests in
      `AlertListTests.swift`. First test: **given the Sin Stock list, should ask the server for the alerting products
      only (outAlert)**. The app drops the 200-row fetch and the fallback counts: the card reads `/products/counts` only,
      and `AlertListViewModel` pages each list (50 a page), dropping pages from an earlier pick. The suggestions card
      waits on O7.
    - Smoke on the simulator against ops' seeded local stats (3 out, 3 low), with a temporary page size of 2:
      the card shows Sin Stock 3 and Stock Bajo 3. Both lists come in ops' order, and the third row came from page 2.
      Reasons: "Vende ~3 al día", "Vende ~4 a la semana", "Vende ~2 al día · alcanza para ~2 días". Pausing Cable USB
      from the list drops its row without a reload, and the card shows 2 when you go back (resumed after). The out
      reason first repeated the badge ("· agotado hace 2 días"), so it now gives the rate only.
    - Review fixes 2026-11-13 (committed, "feat: ranked Alertas lists"): `AlertListViewModel` now pages through the tested `ProductListLoad`
      (`ProductListQuery(locationId:alert:)`), not its own untested page/generation state; a refresh keeps the rows
      until page 1 lands. Alertas' Sin Stock / Stock Bajo show `AlertList.note` ("Solo productos que se venden seguido
      y no están pausados…") because their counts differ from the Productos chips of the same name (3 vs 4 locally).
      Tests: **given Sin Stock's page 2 still loading when Stock Bajo is picked, should drop it**; notes. Smoke: both
      tabs show their note and ranked rows.
    - Later, with O7 — smoke: pause two from suggestions at once; dismiss one; both disappear and the counts update; a cashier doesn't see
      the card.
12. [x] Final review 2026-11-13 (commit "fix: reload an Alertas list whose first page never landed"): build, `swiftui-pro` + `swift-concurrency-pro` + `/tdd-review` over
    the merged diff (`8a3434a..551ebcc`). One fix: an Alertas list whose page 1 was cancelled by leaving the tab came
    back empty ("No hay productos") because `show` skipped any list it had *started*; it now skips only a list whose
    rows are on screen (`ProductListLoad.needsFirstPage`; test **given Sin Stock's page 1 cancelled (left the tab),
    coming back should load it; once shown, should keep it**). Brief §7 has the alert and Pausado rules; the
    low-stock follow-ups are ✅. Original plan: Build, `swiftui-pro` + `swift-concurrency-pro` reviews, `/tdd-review`, README, `docs/inventory-ux-brief.md` §7
    (Bajo = days of cover + normal level for regular sellers; Pausado), mark the low-stock follow-up ✅,
    `graphify update .`.

## Migrate-as-touched

- Into FarmaciaKit: the stock counters in `ProductsViewModel.computeCounts` and `StockAlertProductsView` (step 7), and
  the alert, suggestion and pause labels (steps 2–5). `StockLevel` stays as the fallback for an old server and goes
  away once every server sends `stockAlert`.

## Order and dependencies

- iOS steps 1–7 can start now, against the shapes above.
- UI step 8 needs O4; step 10 needs O5 (O8 later); step 11 needs O6 (O7 later).
- O2's report needs the user's OK before the rest of ops builds on it.
- Every UI step keeps working against today's server, because `stockAlert` is optional.

## Notes

- "Stock Bajo" in Productos becomes the alert definition (regular sellers below cover and below normal). A plain count
  has no meaning once thresholds are per product.
- Suggestion quality depends on O2's history. If the mismatch report is poor, kinds `SLOW_WITH_STOCKOUTS` and the
  typical level lean on post-cutover data only until the window fills.
