# Epic: Lotes FIFO section and batch detail

**Branch:** `feature/fifo-lots`
**Scope:** the Lotes FIFO section in `ProductDetailView` (`fifoBatchSection`, `batchRow`, `agingRiskSummaryCard`) and
`BatchDetailView`. Brief §6.3: show each lot's quantity and expiry with both text and an icon, and give each lot its
own movement history.

## Decisions (2026-11-03)

- Lots are listed **oldest first**, which is the order FIFO sells them. The first lot that still has stock gets a
  "Sale siguiente" tag. The first 3 shown are the next 3 to be sold.
- Batch history (the sales and adjustments that used up the lot) is listed **newest first**.
- The cost always follows FIFO. Suggesting lots by expiry (FEFO) is a later feature (see the transactions epic).

## What's wrong today

- The list is sorted newest first, the reverse of the selling order. Nothing shows which lot sells next.
- Text is half English. In the section: "batches", "d old", "@ $x/ea", "Risk", "tied up". In the batch detail: almost
  every title and label.
- Money is built by hand (`"$\(batch.unitCost)"`) instead of using `ReportFormat.currency`.
- Adjustment types show the raw server value ("DAMAGE") on the batch detail, in both the history and the "created
  by adjustment" card.
- The batch detail's age color uses `> 90`, while `BatchAge.tone` uses `≥ 90`. A 90-day-old lot is orange there and
  red on the product.
- The remaining-stock bar is a hand-drawn GeometryReader that turns green, orange or red by the fraction left. A lot
  that is mostly sold isn't a problem, so the color has no meaning.
- The error state has no retry, and none of the cards use the design system (`.card()`, `ToneBadge`, `DS`).

## Logic (FarmaciaKit, TDD)

1. [x] **Move** `BatchValuation` from `Models/Reports.swift` to FarmaciaKit (migrate-as-touched). It's
   Foundation-only, and `expiryTone`/`sourceLabel` already use kit helpers. Add a public init for tests.
   First test: given valuation JSON with an `expiryDate`, should decode it and give `expiryTone`.
2. [x] `BatchValuation.fifoOrder(_:)` sorts oldest received first, and `nextOut` is the first lot with quantity > 0.
   First test: given lots received on Mar 1 and Jan 1, should put Jan 1 first. Then: given that the oldest lot has
   0 left, `nextOut` should be the second.
3. [x] `LotSummary(lots:)` counts lots by age (`BatchAge.tone`: <30 / 30–89 / ≥90) and by expiry (expired / expiring
   soon). It replaces `ProductBatchViewModel.agingSummary` and the two filters inside the view.
   First test: given ages 29, 30 and 90, should count 1 / 1 / 1. Then: given one expired lot and one expiring in 30
   days, should count expired 1 and expiring soon 1.

These need no test, so they aren't steps:
- the history order (`reversed()`)
- the bar (native `ProgressView(value:total:)`)
- the adjustment label (`AdjustmentType(rawValue:)?.displayName`, a one-line lookup; `AdjustmentType` stays in the app)

## UI

4. [x] **Lotes FIFO section**, using the order from step 2 and the counts from step 3:
   - The first lot gets a `ToneBadge("Sale siguiente", tone: .info)`.
   - The header says "N lotes".
   - Rows read "X uds · $Y c/u" and "Z días · date · source"; the value comes from `ReportFormat.currency`.
   - The risk card reads "Riesgo …" and "inmovilizado".
   - "Ver Todos" gets a 44pt tap area.
   - Smoke check: a product with 4 or more lots. The oldest lot is on top with the tag, and Ver Todos expands the
     list.
5. [x] **BatchDetailView, design system and Spanish:**
   - Cards use `.card()`; the source is a `ToneBadge`; the age uses `BatchAge.tone`; spacing uses `DS`.
   - Everything is in Spanish: "Lote", "Recepción", "Creado por ajuste", "Fecha de fabricación", "Factura",
     "Restante", "Antigüedad", "Valor".
   - Adjustment types show their Spanish name.
   - The adjustment's notes are shown (the server sends them; the screen drops them today).
6. [x] **BatchDetailView, quantity and history:**
   - `ProgressView(value:total:)` reads "X de Y restantes · Z vendidas/usadas".
   - The history is newest first. Each row is a sale (`Tone.info`, short ticket #) or an adjustment (`Tone.caution`,
     Spanish type).
   - The empty state is a `ContentUnavailableView`.
   - The error state is a `ContentUnavailableView` with a Reintentar button.
   - Smoke check: open a lot that has sales. The latest sale is at the top and the bar matches the numbers.
7. [x] Build, device check (owner), README, `graphify update .`.

## Out of scope / later

- **Links from history rows to the receipt or sale** (brief §6.3). There's no sale detail screen yet.
- **"Recibido por":** the API sends `receivedBy`/`adjustedBy` as employee ids, not names. Ask ops if it's wanted.
- ~~**`bucketColor`'s 31/61/91-day scale vs `BatchAge`**~~ — done (`fix/aging-colors`): `BatchAge` now uses the API's
  aging buckets (0–30 / 31–90 / 90+), and the chart colors each bucket with it.
- **Moving `AdjustmentType` into FarmaciaKit:** it's used in many places, so it moves when its logic changes.

## Status (2026-11-03)

- Kit (302 tests): `BatchValuation` moved to FarmaciaKit with `fifoOrder` / `nextOut`; `LotSummary` replaces
  `ProductBatchViewModel.agingSummary` and the view's expiry filters.
- `AdjustmentType.label(_:)` (raw → Spanish) used by the batch history and the "Creado por ajuste" card;
  `BatchConsumption.typeColor` → `typeTone`.
- Built, installed and checked on device (owner).
