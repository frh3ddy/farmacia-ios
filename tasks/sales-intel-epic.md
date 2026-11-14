# Epic: sales velocity + busy hours (from Square sales history)

> **Superseded in part (2026-11-13):** the detail's `SalesVelocity` line and its dead-stock caution were replaced by
> the stock alerts' own rate (`StockAlert.salesLine`), and the app no longer calls `/products/:id/sales-velocity`. See
> `tasks/sales-intel-review-followups-epic.md` § Decided. Busy hours stands as described.

**Branch:** `feature/sales-intel`. **Status (2026-11-10):** steps 1–6 done, uncommitted; 753 Kit tests green; app build green.
**API (requested from farmacia-ops-50 on 2026-11-10, dev-67 copied):**
- `SalesHistoryLine`: a history-only table filled by a one-time, idempotent Square `SearchOrders` import (~111k
  orders / ~178k units since 2020-07-17, both stores). It never touches `Sale`/`SaleItem`, so FIFO, COGS and P&L stay
  as they are. **The production import runs only when the user decides** (all history vs. the last 2 years).
- `GET /products/:id/sales-velocity?locationId` → `{ lastSoldAt, unitsLast30d, unitsLast90d, daysSinceLastSale }`
  (history ∪ live `SaleItem`, net of returns).
- `GET /inventory/reports/busy-hours?locationId&days=90` → `{ timezone, cells: [{ dayOfWeek, hour, orders }] }`
  (distinct orders, in the store's time zone, America/Chicago; owner/manager).

**Built (2026-11-10) on farmacia-ops `feature/sales-history`, uncommitted, not run on prod.** Final shapes:
- `GET /products/:id/sales-velocity?locationId=` → `{ success, data: { lastSoldAt: ISO|null, unitsLast30d, unitsLast90d,
  daysSinceLastSale: Int|null } }`. All four roles (units only). 404 `Producto no encontrado`. Net of returns.
- `GET /inventory/reports/busy-hours?locationId=&days=90` → `{ success, data: { timezone, cells: [{ dayOfWeek 0–6
  (0 = Sunday), hour 0–23, orders }] } }`. OWNER/MANAGER. `days` 1–730, else 400. **Only non-empty cells**, sorted.
- Time zone: the API uses `America/Mexico_City` (`BUSINESS_TIME_ZONE`), but Square lists both stores as
  `America/Chicago` (Midland, TX). **Open: the user decides which clock is right.** The app shows the `timezone` it gets.
- Import: `npm run import-sales-history -w apps/api` (dry run with counts), `-- --yes` saves. It dedupes against live
  sales by Square payment id.

Reference (Square Reporting, last 90 days, Lolita, Chicago clock): Mon 9h 67 orders, Sat 19h 58, Tue 9h 56, Thu/Fri 20h 54–55.

## Logic (FarmaciaKit, TDD)

1. [x] `SalesVelocity` (Decodable plus a display rule): the line in Inventario.
   First test: **given 12 units in 30 days, last sold 2 days ago, should say "12 vendidas en 30 días · última venta
   hace 2 días"**. Then: never sold → "Sin ventas registradas"; nothing in 30 days but some in 90 →
   "Sin ventas en 30 días · 4 en 90 días"; last sold today → "última venta hoy".
2. [x] `SalesVelocity.tone`: neutral by default; **stock on hand with no sale in 90 days → caution** (dead stock,
   decided 2026-11-10). First test: **given 6 units on hand and no sale in 90 days, should be caution**.
3. [x] `BusyHours(cells:)` (hours span the ones with orders, no openHours param): a 7 × open-hours grid, with each cell's share of the busiest one (0…1) and the top 3
   slots as text ("lun 9 h · sáb 19 h · mar 9 h").
   First test: **given the reference cells, should rank Mon 9h, Sat 19h, Tue 9h**. Then: hours missing from `cells` (the API
   sends only non-empty ones) are 0; an empty response → no grid ("Sin datos de ventas").

## UI (FarmaciaApp)

4. [x] Product detail → Inventario: the `SalesVelocity` line under the stock, with a placeholder while it loads and
   hidden when the request fails or the product isn't tracked. One more parallel load in the existing `.task`.
   Smoke: owner + cashier (role per the API's decision), a product with and without sales.
5. [x] Inicio (owner/manager): a "Horas pico" card with the heat grid (opacity by share, plus the top-3 text so it isn't
   color alone, and an accessibility summary) and a store picker that follows the current store.
   Smoke: location switch (critical flow), so the grid reloads for the other store.
5b. [x] Reportes (owner/manager): the same "Horas pico" grid as its own report (decided 2026-11-10), reusing the
   step-5 view. Smoke: report date ranges (critical flow).
6. [x] Build, README, this epic's status, `graphify update .`.


## Decided (2026-11-10)

- **Clock: America/Mexico_City.** The Square locations were switched to Mexico City, so Square's reports match the API.
- **Live in production (farmacia-ops `20fdfb9`):** both endpoints deployed; history imported (136,416 lines from 111,333
  orders, 2020-07-17 → 2026-11-10). `daysSinceLastSale` counts calendar days on the Mexico City clock (a sale last night
  reads 1 this morning). Busy hours count every order, including custom amounts and Yastás payments.
- Yastás items (`tracksInventory == false`) have velocity but no stock: the detail hides the whole Inventario card for
  them, so no line and no dead-stock caution.

- Dead stock (stock on hand, no sale in 90 days) → caution.
- Busy hours on Inicio **and** in Reportes.
- Prod import depth: all history (since 2020-07). Running it on prod still waits for the user's go.

## Status notes / follow-ups

- Smoke: detail line live against the local API ("Sin ventas registradas" → caution with 65 on hand); the Inicio and
  Reportes grid checked with stubbed cells (local DB has no sales), then with the real empty response ("Sin datos de
  ventas"). Location switch not exercised: the local setup has one store (the loads key on `currentLocation.id`).
- A product received recently and never sold also shows the dead-stock caution (no receipt date in the rule). Revisit
  once real history is imported; e.g. only after the oldest lot is 90+ days old.
- Store-wide dead-stock list: not requested. farmacia-ops offered `GET /inventory/reports/dead-stock?locationId&days`
  if a list is wanted.
