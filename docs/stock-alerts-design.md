# Stock alerts: per-product thresholds, Pausado, pause suggestions (proposal, 2026-11-11)

Status: **proposal, no code yet**. It replaces part C (`lowStockBelow`) of `tasks/product-detail-followups-epic.md`.

## 1. How the current design handles the three cases

| Case | Today (`main`) | With the planned days-of-cover rule (epic C) | Missing |
|---|---|---|---|
| 1. Slow movers sitting at 1–3 | **Alerts.** "Bajo" is a fixed 1–9 for every product: API `FILTER_SQL.lowStock` (`qty > 0 AND qty < 10`), `StockLevel`, the offline counts in `ProductsViewModel`, and `StockAlertProductsView`. | Mostly fixed: a slow seller's 14-day cover rounds to ≤ 1, so it's never Bajo. | The product's normal on-hand level isn't used, only its sales rate. At 0 it still counts as "Sin stock" in Alertas. |
| 2. Supplier can't restock | **Alerts** as Sin stock forever. The only escape is `Product.isDiscontinued`: global (every store), removes the product from the catalog list, isn't settable from iOS, and never comes back on its own. | Same. | A per-store, reversible **Pausado** status that comes back automatically when stock arrives. |
| 3. Replaced by an equivalent | **Alerts** as Sin stock. | Same. | Pausado, plus suggestions that see the equivalent selling instead. |

Other gaps found:
- **No prioritization.** Every product at 0 is one count, so a regular seller that ran out ranks the same as something
  nobody has bought in a year.
- **Alertas sees only the first 200 products.** `StockAlertViewModel` loads `limit=200` and filters on the device.
  The counts come from the server and are right, but the lists it opens miss everything past row 200.
- **No stock-level history.** We know sales (Square history back to 2020-07) and current stock, but not what stock was
  on past days. "Days at 0", "stock-outs" and a product's "normal" level need it.

### Active ingredients: the link exists but is sparse

The schema already models equivalence. `ActiveIngredient` → `MedicationDefinition` is the ingredient set, strength,
form and route. Two products are equivalent iff they share `Product.medicationDefinitionId`. `rankEquivalents` in
`medication-equivalence.ts` already ranks alternatives (in stock first, then cheapest), but it's used only by catalog
search. **Coverage is the problem:** locally only 4 of 46 products are linked, and production coverage is unknown
(ops to count). Suggestion (c) below only works for linked products. Raising coverage is its own job: ops has OCR and
classification scripts (`extract-medicine-from-ocr.ts`, `seed-active-ingredients.ts`), plus a manual "link
equivalent" action.

## 2. Proposed schema (farmacia-ops)

```prisma
/// Per product × store: paused or not. Absent row = active.
model ProductStoreStatus {
  productId           String
  locationId          String
  pausedAt            DateTime?          // set = paused
  pauseReason         PauseReason?
  pauseNote           String?
  replacedByProductId String?            // case 3: the equivalent sold instead (optional)
  pausedByEmployeeId  String?
  resumedAt           DateTime?          // last automatic or manual resume
  resumedBy           ResumeCause?       // STOCK_RECEIVED | MANUAL
  @@id([productId, locationId])
}
enum PauseReason { SUPPLIER_UNAVAILABLE  REPLACED_BY_EQUIVALENT  SLOW_MOVER  OTHER }
enum ResumeCause { STOCK_RECEIVED  MANUAL }

/// End-of-day stock per product × store. Nightly job from now on. Backfilled once from Square's inventory change
/// history (BatchRetrieveInventoryChanges: adjustments NONE→IN_STOCK, IN_STOCK→SOLD, physical counts; it goes back to
/// 2020-07-17) up to the cutover, then from our own movements (receivings, sales, adjustments, transfers).
model StockDay {
  productId  String
  locationId String
  day        DateTime @db.Date
  quantity   Int
  @@id([productId, locationId, day])
}

/// Nightly per product × store, read by lists, counts, alerts and suggestions.
model ProductStockStats {
  productId        String
  locationId       String
  windowDays       Int        // the window used (default 90)
  unitsSold        Int        // net of returns, in the window
  weeksWithSales   Int        // of the window's weeks
  lastSoldAt       DateTime?
  typicalOnHand    Int        // median end-of-day stock on days it was > 0
  daysAtZero       Int        // in the window
  stockOuts        Int        // times it went from > 0 to 0 in the window
  zeroSince        DateTime?  // current run at 0
  computedAt       DateTime
  @@id([productId, locationId])
}

/// A dismissed suggestion stays hidden until the window has passed or the evidence changes.
model PauseSuggestionDismissal {
  productId   String
  locationId  String
  kind        PauseSuggestionKind
  dismissedAt DateTime
  dismissedByEmployeeId String?
  @@id([productId, locationId, kind])
}
enum PauseSuggestionKind { NO_SALES_AT_ZERO  SLOW_WITH_STOCKOUTS  EQUIVALENT_SELLING }

/// Settings, one row per store (defaults shown). Owner-editable later; seeded with defaults.
model StockAlertSettings {
  locationId            String @id
  windowDays            Int @default(90)
  coverDays             Int @default(14)  // low = under this many days of sales on hand
  regularMinWeeks       Int @default(4)   // a "regular seller" sold in ≥ this many weeks of the window
  slowMaxUnits          Int @default(2)   // suggestion (b): ≤ this many units in the window
  slowMinDaysAtZero     Int @default(30)  // suggestion (b): or ≥ 2 stock-outs
  equivalentMinUnits    Int @default(3)   // suggestion (c): equivalent sold ≥ this since this one hit 0
}
```

/// Manual equivalence, independent of the medication catalog: products in the same group are interchangeable.
/// Set from the product detail ("Equivalentes · Vincular") or when pausing with REPLACED_BY_EQUIVALENT.
model EquivalenceGroup {
  id        String    @id @default(uuid())
  products  Product[] // Product.equivalenceGroupId String?
  createdByEmployeeId String?
  createdAt DateTime  @default(now())
}

`isDiscontinued` stays as it is: global and permanent ("we'll never carry it"). Pausado is per store and temporary.

## 3. Logic

**Regular seller** (per store): `weeksWithSales ≥ regularMinWeeks` in the window. Only regular sellers alert.

**Alert level** (per product × store, computed on the server and sent on every product row as
`stockAlert: { level, priority, paused }`):

| Condition | Level |
|---|---|
| Paused | `none` (shown as Pausado) |
| Not tracked (Yastás) | `none` |
| Not a regular seller | `none`; the state still shows as "Agotado" / stock count, without the alert |
| Regular, qty = 0 | `out` |
| Regular, 0 < qty < ceil(rate × coverDays) **and** qty < typicalOnHand | `low` |
| Otherwise | `none` |

- `rate = unitsSold ÷ windowDays`. The second condition for `low` keeps a product that normally sits at 1 from alerting at 1.
- **Priority** = lost sales per day: `rate` for `out`, and `rate ÷ max(qty, 1)` for `low`. Alertas lists highest first,
  so a regular seller that ran out comes first.

**Equivalents** = same `medicationDefinitionId` (automatic catalog) **or** a manual link (below). Manual links win
where the catalog has nothing; the automatic one is never required.

**Pause / resume**
- Pause: owner or manager, per store, with a reason (and optionally the replacement product).
- **Auto-resume (decided; widened 2026-11-13):** in the same transaction as any **receiving** or **received transfer**
  of the product at this store, whatever its stock was (a product paused with units left must resume when the
  supplier delivers). Adjustments (Encontrado, count corrected up) don't resume it. Sets `pausedAt = null`, `resumedBy = STOCK_RECEIVED`. Done once,
  in the shared "store stock changed" path (ops already stamps product changes with a trigger), so no write path can
  skip it.

**Suggestions** (nightly per store, never applied automatically, each with its evidence):

| Kind | When | Evidence shown |
|---|---|---|
| `NO_SALES_AT_ZERO` | qty = 0 and no sale in the window | last sale date, units in window (0), days at 0 |
| `SLOW_WITH_STOCKOUTS` | `unitsSold ≤ slowMaxUnits` and (`daysAtZero ≥ slowMinDaysAtZero` or `stockOuts ≥ 2`) | last sale, units in window, days at 0, stock-outs |
| `EQUIVALENT_SELLING` | qty = 0 and an equivalent (same `medicationDefinitionId`, not paused) is in stock here and sold ≥ `equivalentMinUnits` since `zeroSince` | the equivalent's name, its units since, days at 0 |

Excluded from suggestions: already paused, not tracked, and dismissed (until the window passes or the kind's evidence
changes, e.g. it sold again).

### Rebuilding stock history (Square before the cutover, our movements after)

Square's inventory changes include every way stock went up: **receivings** (NONE→IN_STOCK, "received"), returns,
other adjustments into IN_STOCK, transfers, and **recounts** (physical counts). All of them add to the stock level;
all but returns are restocks. Recounts need extra care, because in Square (before the cutover only; farmacia-ops records real receivings)
receivings were often entered as a recount instead of a receive:
- A physical count is the truth for its moment: stock **jumps** to the counted value, whatever the replay had.
- Any change into IN_STOCK from supply (receiving, adjustment in, transfer in) is a **restock**: it adds units and ends
  a run at 0.
- A **return** put back on the shelf (Square: refund → IN_STOCK; a refund to WASTE adds nothing) adds its units to the
  stock level but is **not a restock**: it doesn't count as a resupply and doesn't resume a paused product. Days it
  leaves stock above 0 aren't days at 0, because the unit really is on the shelf. Returns are rare here (negligible in
  the 2020–2026 history).
- A count above the replayed stock is a restock too; a count below is a correction (shrink), not a sale.
- Between counts, apply adjustments and sales. If the replay would go below 0, clamp at 0: a sale proves there was stock,
  so the units came from an unrecorded restock.
- **A day with a sale is never a day at 0.** Days at 0 = days whose end-of-day stock is 0 and that had no sale.
- `zeroSince` = start of the current run at 0 (the last time stock reached 0 and stayed there).
- Check: the replay must end at Square's current count per variation; ops reports the mismatch rate before we trust it.

## 4. API (farmacia-ops)

- Product rows (list, sync, detail): `stockAlert { level: none|low|out, priority, paused, pauseReason?, zeroSince? }`.
  The `outOfStock` list filter sorts by `zeroSince` desc (most recent stock-out first). The list
  filters `outOfStock`/`lowStock` and `/products/counts` use `level`. A new `paused` filter and count.
- `POST /products/:id/pause` `{ locationId, reason, note?, replacedByProductId? }`, `DELETE /products/:id/pause?locationId`.
- `POST /products/pause` `{ locationId, productIds[], reason }` (pause several at once).
- `GET /inventory/stock-alerts?locationId&level=out|low` → ranked by priority, paginated (fixes the 200 cap).
- `GET /inventory/pause-suggestions?locationId` → `[{ product, kind, lastSoldAt, unitsInWindow, daysAtZero, stockOuts,
  equivalent? }]`; `POST /inventory/pause-suggestions/dismiss` `{ locationId, items[{productId, kind}] }`.
- Roles: owner/manager pause, resume and review suggestions; everyone sees the Pausado state.

## 5. iOS

- FarmaciaKit: `StockAlert` (decode, label and tone: Agotado critical only for `out`; a non-alerting 0 is neutral
  "Agotado"), `PauseSuggestion.reasonText` ("Sin ventas desde 3 mar 2026 · 0 en 90 días · 120 días en 0"),
  `PauseReason` labels. The fixed `< 10` checks in `StockLevel`, `ProductsViewModel.computeCounts` and
  `StockAlertProductsView` go away. Offline, the row's cached `stockAlert` is used (stale by up to a day).
- Alertas: "Sin stock" and "Stock bajo" open server-ranked lists; a new **"Sugerencias para pausar (N)"** opens a review
  list with each reason, per-row Pausar / Descartar, and multi-select to pause several.
- Productos: a "Pausados" chip; paused rows show "Pausado · Proveedor sin surtido".
- Product detail: a Pausado line in Inventario, and Pausar / Reanudar (owner/manager) in the Ajustar menu.
- `CachedProduct`: `stockAlert` fields as optional attributes (SwiftData lightweight migration).

## 6. Decisions (2026-11-11)

1. Defaults OK: window 90 d, cover 14 d, regular seller = sold in ≥ 4 of ~13 weeks.
2. Auto-resume on **receiving and received transfer** only. Recount-as-receiving was a Square habit; in farmacia-ops receivings are entered
   properly, so counts don't resume (confirmed 2026-11-11).
3. Productos "Sin Stock" = stock state (every product at 0, minus paused), **sorted by most recent stock-out first**
   (`zeroSince` desc; unknown last). Alertas = alerting products only (regular sellers, not paused), by priority.
4. Stock history: rebuild it. Square's inventory changes go back to 2020-07, so it isn't limited to the cutover. Ops to
   check quality (were receivings entered in Square? does the replay end at Square's current counts?).
5. Equivalents: manual links first (EquivalenceGroup); the active-ingredient catalog is optional help, with suggested
   links that a person confirms, never trusted on its own.
