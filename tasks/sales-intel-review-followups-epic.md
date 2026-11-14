# Epic: sales-intel review fixes (/tdd-review, 2026-11-10)

**Branch:** `feature/sales-intel` (the reviewed work is uncommitted there). Step 0 uses `fix/local-server-host`.
**Decided (2026-11-10):** dead stock warns only when the oldest unit on hand is 90+ days old (the API sends its age,
so cashiers get it too); the Bonjour-name fix gets its own commit on `fix/local-server-host`.

## 0. Split out the address fix (finding 1)

- [x] Committed on `fix/local-server-host` (`b7bd9e8`), merged into `main` (`f71ad2e`, user OK 2026-11-10);
  `feature/sales-intel` fast-forwarded to it, so Debug builds keep the Bonjour name. Not pushed.

## 1. API (farmacia-ops-50, finding 2)

- [ ] `GET /products/:id/sales-velocity` adds `oldestUnitDays: Int|null`: days since the oldest lot with units on hand
  at that store was received (null when there's no stock). Same roles. iOS treats a missing field (old server) as null.

## Logic (FarmaciaKit, TDD)

2. [ ] `SalesVelocity.tone(stockOnHand:)` uses `oldestUnitDays` (finding 2).
   First test: **given 6 units on hand, no sale in 90 days and the oldest unit 10 days old, should be neutral**.
   Then: oldest 90+ days → caution; never sold and oldest 120 days → caution; `oldestUnitDays` missing → neutral;
   decode without the field.
3. [ ] `SalesVelocity.systemImage(stockOnHand:)`: the icon moves out of the view (finding 5).
   First test: **given dead stock, should use "exclamationmark.triangle.fill"**; otherwise "chart.line.uptrend.xyaxis".
4. [ ] Decode with the app's decoder (finding 7).
   First test: **given "2026-11-08T15:30:00.000Z" and `.iso8601`, should decode lastSoldAt**. The test uses the same
   strategy as `APIClient`, not a custom one.
5. [ ] `BusyHours.topText` tie order (finding 8).
   First test: **given Sat 19 h and Mon 9 h both at 50 orders, should list "lun 9 h" first** (equal counts: Monday-first
   day, then earlier hour).
6. [ ] `BusyHours.caption(timezone:)` (finding 5).
   First test: **given America/Mexico_City, should say "Pedidos por hora · hora de Ciudad de México"**. Then
   America/Chicago → "hora de Chicago"; an unknown id → the city part of the id with spaces.

Steps 6b–6d (migration note, aging-bar math, `ProductDetailView` split) moved to
`tasks/product-detail-followups-epic.md` (2026-11-11).

## UI fixes (FarmaciaApp)

7. [ ] Product detail (finding 4): a failed reload keeps the last sales line (only a first-load failure hides it), and
   overlapping reloads (pull-to-refresh, refresh after a save, offline sync) share one request through the existing
   `SingleFlight`, so an older answer can't land last. Uses steps 2–3 for tone and icon.
   Skip the request when `tracksInventory == false` (Yastás: the card is hidden, the call is wasted).
   Smoke: **receive inventory** (critical flow): the line stays after the save's refresh; pull-to-refresh.
8. [ ] Busy-hours grid (finding 3): `ViewThatFits(in: .horizontal)`. When the grid doesn't fit (accessibility text sizes,
   iPhone SE), show the top-3 slots as a list instead. The caption comes from step 6.
   Smoke: simulator at the largest accessibility text size, on iPhone 17 and an SE-size simulator, Inicio and Reportes.
9. [ ] `BusyHoursLoader` (finding 6): with no store selected it ends loaded (empty state), not an endless spinner.
10. [ ] Inicio (finding 9): the loader moves up to `DashboardView`, so its `.refreshable` reloads busy hours along with the
    dashboard. Smoke: **location switch** (critical flow) still reloads the card.
11. [ ] App build, `/tdd-review` again, README/epic status, `graphify update .`.

## Migrate-as-touched

- The tone→icon choice (`ProductDetailView`), the time-zone caption (`BusyHoursGrid`) move into FarmaciaKit (steps 3, 6). The loader and the `ViewThatFits` fallback stay app-side (SwiftUI).
