# Epic: Conteo inicial — fix migration stock without touching profit

## Status (2026-11-05)

✅ Steps 1–13 and 2b built test-first on `feature/opening-count` (both repos), not committed yet.
- API: 521 tests green (new: `stock-count.pg.spec.ts`, `stock-count.controller.spec.ts`, opening-count and
  relabel cases in `inventory-reports.pg.spec.ts`); worker 67 green. Routes live under
  **`/inventory/stock-counts`**: `/stock-counts` fell into the web app's SPA fallback (`main.ts` allow-list).
- Kit: 429 tests green (`AdjustmentTypeTests`, `StockCountTests`). `AdjustmentType` moved to FarmaciaKit;
  an unknown type now decodes as `.unknown` instead of failing the whole history list.
- A Conteo inicial down goes to Square as IN_STOCK → NONE (not WASTE), like break-bulk.
- Smoke (simulator, local API): start → status → No contados (sorted by value) → Poner en 0 on one product →
  it left the list, "Productos contados 1"; Ganancia neta unchanged (−$227.30), Valor de inventario −$250;
  "Poner todos en 0" confirmation showed the summary (not confirmed). Count form in a session shows title
  "Conteo inicial" and the note. **Not smoked:** saving from the count form (typing into the amount field
  doesn't register through simulator automation), scanner chip, "Terminar conteo".
- API-session review fixes (2026-11-05): "Poner en 0" skips a product counted after the list loaded
  (`code: ALREADY_COUNTED`, shown as skipped via `ZeroOutcome`); entries take the form's `clientRequestId`
  (a retry after commit returns the first result, even if a sale landed); entries/active refuse another
  store (`assertActingAtOwnStore`); `StockCountEntry.adjustmentId` is a real FK (migration `…120200`).
  Known, carried over from Corrección de Conteo: the lock covers batches with stock > 0 only, so two phones
  counting a product at 0 at the same moment both add.
  Also known: a recount from another phone replaces the entry's `clientRequestId`, so a late retry of the
  first request re-applies its total (harmful only if a sale landed in between; rare).
- /tdd-review follow-ups (2026-11-05): a Conteo inicial Square didn't take shows "Conteo guardado, pero no se
  sincronizó con Square…" in the scanner and the detail screen (`StockCountEntryResult.squareWarning`); a failed
  Conteo inicial save reloads the session, so a form left open after "Terminar conteo" switches to Corrección de
  Conteo instead of failing on every tap; Ajustes shows Reintentar when the first session load fails. Not smoked
  (needs typing into the count form / a forced failure). Locally, without Square credentials, every count that
  changes stock shows the warning, which is accurate.
- dev-ee review (2026-11-05): "Poner todos en 0" goes in batches of 25 (`ZeroBatch`) with "Poniendo en 0… N de M";
  a failed batch stops the run and says so, the rest stay listed. A 404 from `active` (API from before this
  feature) reads as no count open (`StockCountSession.noCountOnServer`), so the app no longer has to wait for the
  API deploy. The session-decode test now uses APIClient's `.iso8601`; all devices are on iOS 27 (iPhone 13 Pro
  27.0.1, iPhone lolita 27.2, iPad 27.0.1), no iOS 17 simulator installed.
- API (2026-11-05, user's decision): a Corrección de Conteo at a store with an open Conteo inicial gets 409
  "Hay un conteo inicial abierto en esta sucursal; registra el conteo ahí". The form shows it and reloads the
  session, so the next Guardar goes to the Conteo inicial (only reachable if the session started after the form
  loaded, or `active` failed).
- Square: the six relabeled Lolita adjustments (39 units) stay IN_STOCK → WASTE in Square (Square adjustments
  can't be edited). Square's own waste report keeps showing them; our P&L doesn't.
- **Deploy order:** API first (migrations + routes), then the app (an app shipped first still counts, as Corrección de Conteo). Builds older than this decode
  `[InventoryAdjustment]` strictly, so after the relabel Lolita's global history and those six products' activity
  fail to load until updated; and they'd keep counting as Corrección de Conteo during a session.

Branches: `feature/opening-count` in **farmacia-ops** (API first) and **farmacia-ios**.

## Problem

The migration (cutover + cost extraction) loaded stock without anyone checking the shelves,
so some counts are wrong. Nothing was stolen or damaged: the opening stock was wrong.
Fixing it with Corrección de Conteo books every drop as shrinkage, a loss in this month's
P&L that never happened. Products nobody gets to keep their phantom stock, with no list of them.

## Decisions (asked 2026-11-04)

- **New adjustment type `OPENING_COUNT` ("Conteo inicial"), dated today.** Changes units and
  inventory value (down: oldest cost layers first, as a sale would; up: a new layer at the
  last known cost). P&L, Costo de ventas, Ganancia neta, shrinkage and the adjustment
  loss/gain report leave it out, like transfers. The activity history shows it. Square gets the count.
- **Store-level session, started and ended by the owner from Settings.** While it's active,
  every phone's count in that store (scanner Contar and the detail screen's Corrección de Conteo)
  is a Conteo inicial. A count that matches the stock is recorded too: it's how a product counts
  as "counted".
- **Uncounted list:** products still showing stock at the store that nobody counted in the session,
  each with "Poner en 0", plus "Poner todos en 0" after a confirmation with products, units and value.

## What the code does today

- API `POST /inventory/adjustments` with `countedQuantity` (COUNT_CORRECTION) locks the product's
  batches, derives the change from its own stock, and **rejects a count equal to stock**
  ("no hay nada que ajustar") — so a match leaves no record (`inventory-adjustment.service.ts:274`).
- `adjustment-types.ts`: `USER_ADJUSTMENT_TYPES` (what the API accepts), `STOCK_MOVE_TYPES`
  (left out of loss/gain), `SHRINKAGE_RECOVERY_TYPES` (FOUND, COUNT_CORRECTION).
- Money reads: P&L net shrinkage (`inventory-reports.service.ts:961`, losses `notIn STOCK_MOVE_TYPES`)
  and the adjustment-impact report (`:651`, same filter). Valuation reads batches, so it follows units.
- iOS: `AdjustmentType` (app `Models/Adjustment.swift`) has raw values, `isVariable`, `isNegative`,
  `displayName`, `icon`; counts go through `AdjustmentFormView` (live stock, `CountCorrection`,
  "Sin cambios" closes without saving). Settings: `Features/Dashboard/Views/SettingsView.swift`.

## Steps

### API (farmacia-ops, jest + pg specs)

1. **Schema.** `AdjustmentType.OPENING_COUNT`; `StockCount { id, locationId, startedAt, startedBy,
   endedAt?, endedBy? }` (one open per store: partial unique index on `locationId` where `endedAt` is null);
   `StockCountEntry { stockCountId, productId, countedQuantity, previousQuantity, adjustmentId?, countedAt,
   countedBy, clientRequestId? @unique }`, `@@unique([stockCountId, productId])` (a recount overwrites).
   - First test (pg): *given an open count at a store, should refuse a second one for that store.*

2. **Out of the money reports.** `NON_SHRINKAGE_TYPES = [...STOCK_MOVE_TYPES, 'OPENING_COUNT']`, used
   by the P&L shrinkage query and the adjustment-impact report.
   - First test: *given an OPENING_COUNT of −6 at $10 in the period, P&L shrinkage should stay 0.*
   - Then: the adjustment-impact report leaves it out; inventory valuation still drops by $60;
     the integrity (books) check still balances.

2b. **Relabel the 2026-11-04 Lolita migration fixes.** Owner confirmed all six were migration errors,
   not losses (count to 0, then receive; or plain recount). A separate data migration (Postgres can't use
   a new enum value in the transaction that adds it) sets `type = 'OPENING_COUNT'` for exactly these ids,
   with one AuditLog row each. Stock, batches, valuation, COGS and Square stay as they are; Lolita's
   shrinkage that day goes from $300.08 to $0. These are the only COUNT_CORRECTIONs in prod.
   - `31e5eb4b-d39e-4896-b18a-7102f5e589b4` Condones Don Juan 1 pz −28 ($70.84)
   - `e000c3ef-f65c-4705-a049-fbc84ff0464d` Cefuroxima 500 mg −1 ($141.19)
   - `2659834b-5b0f-4a3d-b6b3-e8bfdb4926e6` Bennet desloratadina susp −1 ($26.63)
   - `60ef0212-6791-4e68-9ad4-02fcc735f89b` Carbocisteína 250 mg −1 ($44.22)
   - `0bba5d62-d537-46c0-8547-0bb9f024b2c3` Jeringa gris 5 ml −6 ($13.20)
   - `ba17fe40-0d78-4e3c-9445-661070c645fe` Aguja verde −2 ($4.00)
   - Check (pg): *given these six as COUNT_CORRECTION, after the migration P&L shrinkage for Lolita on
     2026-11-04 should be 0 and stock per product unchanged.* After deploy, re-read prod to confirm.

3. **Start / read / end.** `POST /stock-counts` (OWNER, store from the session), `GET /stock-counts/active`,
   `POST /stock-counts/:id/end` (OWNER).
   - First test: *given a manager, starting a count should be forbidden.*

4. **Record a count.** `POST /stock-counts/:id/entries { productId, countedQuantity, unitCost?, clientRequestId }`
   (OWNER, MANAGER). Same locked read as today; change ≠ 0 → an OPENING_COUNT adjustment through
   `createAdjustment` (FIFO, cost-required rule, Square sync); change = 0 → entry only. Upserts the entry.
   - First test: *given a count equal to stock in an open session, should save the entry and no adjustment.*
   - Then: −6 creates OPENING_COUNT −6 and an entry with previousQuantity; a replayed clientRequestId
     returns the first result; an ended session refuses entries.

5. **Uncounted.** `GET /stock-counts/:id/uncounted`: products with stock > 0 at the store (sum of batches)
   and no entry, with units and value at cost, largest value first.
   - First test: *given A counted and B with 3 units not counted, should list only B with 3.*

6. **Zero.** `POST /stock-counts/:id/zero { productIds }` (OWNER): each one through step 4 with
   `countedQuantity: 0`, one at a time, returning what was zeroed and any failure per product.
   - First test: *given two uncounted products, should zero both and leave the list empty.*

### Logic (FarmaciaKit, Swift Testing)

7. **Migrate `AdjustmentType` into FarmaciaKit** (raw values, `isVariable`, `isNegative`, `displayName`;
   `icon` stays an app extension) and add `.openingCount` ("Conteo inicial", variable).
   - First test: *given "OPENING_COUNT", should decode as Conteo inicial and be variable.*
   - Then: an unknown raw type still decodes (history from a newer server can't break the list).

8. **`StockCountSession`** (decoded from `/stock-counts/active`) + `CountTarget.resolve(session:)`:
   `.opening(sessionId)` while a session is open, else `.correction`.
   - First test: *given an open session, a count should go to Conteo inicial.*

9. **What a matching count does:** `CountSave.action(matches:target:)` → `.closeWithoutSaving` for a
   correction (today's "Sin cambios"), `.save` for Conteo inicial (it marks the product counted).
   - First test: *given Conteo inicial and a count equal to stock, should save.*

10. **Uncounted summary** for the confirmation: `UncountedSummary(rows).text`.
    - First test: *given 3 products with 5, 2 and 1 units worth $80, should read "3 productos · 8 unidades · $80.00".*
    - Money stays `Decimal`.

### UI (FarmaciaApp)

11. **Settings → "Conteo inicial" section (owner).** Off: "Iniciar conteo inicial" with a confirmation
    explaining it (fixes migration stock; doesn't touch profit). On: started date, products counted,
    "Ver no contados", "Terminar conteo".
    Smoke: start → status shows → end.

12. **The count follows the session.** `AdjustmentFormView` for a count resolves `CountTarget`: in a
    session, title "Conteo inicial", posts to `/stock-counts/:id/entries`, and a matching count saves
    ("Coincide") instead of closing. The scanner's Contar shows a "Conteo inicial" chip so counters
    know it's on. The detail screen's Corrección de Conteo goes the same way.
    Smoke (critical: count flow + receive unaffected): session on → Contar → count lower → saved as Conteo
    inicial; count equal → saved; Recibir still receives normally.

13. **No contados list.** Rows: name, units, value; "Poner en 0" per row; "Poner todos en 0" with the
    `UncountedSummary` confirmation; refreshes after each.
    Smoke: a product with stock not counted shows; zero it; it leaves the list; its stock is 0.

14. **History + reports check.** Activity history shows "Conteo inicial" with its icon.
    Smoke (critical: report date ranges): P&L and dashboard for today unchanged by a Conteo inicial;
    Valor de inventario changes.

15. **Docs:** README (Inventory → Conteo inicial), this epic's status, ops README/API notes.
    Then `graphify update .` in both repos.

## Migration (migrate-as-touched)

- `AdjustmentType` (app `Models/Adjustment.swift`) → FarmaciaKit (step 7); `icon` stays app-side.
- The count form's "matches → close" decision → `CountSave` (step 9).

## Not now

- Counting by shelf/section or assigning products to counters.
- A Conteo inicial report (totals of what the session changed): the history and valuation cover it.
- Offline counting in a session: counts already need a connection for live stock.
- More than one Conteo inicial per store over time is allowed, but no comparison between them.
