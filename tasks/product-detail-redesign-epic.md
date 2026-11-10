# Epic: Detalle de producto redesign (v3)

**Branch:** `feature/product-detail-redesign`
**Source:** `~/Downloads/FINDINGS.md` + mockups `~/Downloads/export/` (v3 = target, 402×874).
**Scope:** `ProductDetailView` (1556 lines, 8 cards over 4 screens → 5 blocks on 1 screen + bottom action bar),
the design-system pieces it needs (accessible green, money text), and the knowledge docs.

## Decisions (2026-11-10)

- **Cost = latest supplier cost** (preferred supplier, else first; average cost only when no supplier is on record).
  Margin % and margin $ use it. Provenance on the same line ("Simi · compra 1 nov"). The detail's margin moves off
  `averageCost`; product **cards keep average cost** (the list doesn't load suppliers). Follow-up below.
- **No "Bajo" on the detail.** Some products normally carry 1–2 units, others sit at 0 for weeks, so a fixed 1–9 rule
  raises false alarms. The detail flags only 0 units here. The real threshold is learned per product from history
  later (follow-up). List filters and cards keep `StockLevel` (the same rule as the API filters).
- **Accessible green app-wide.** `Tone.positive.color` changes once in `DesignSystem.swift` (light `#0F7B3F`, 5.35:1;
  dark keeps systemGreen). This applies to all 19 call sites.
- **Sell-through deferred.** There's no API for it yet (follow-up).
- Expiry escalation already exists: `Expiry.tone` is critical when expired, caution within 90 days (`warningDays`). Reuse it.
- `[Otro proveedor]` placeholders exist only in the v2 mockup, not in code. Build it right the first time: with one
  supplier, show no second row and no "Ver los N proveedores" link.

## Knowledge

0. [x] Copy `FINDINGS.md` to `docs/product-detail-findings.md` and the 4 PNGs to `docs/mockups/product-detail/`, with
   image paths fixed. Add a **"Detail screens"** subsection to `docs/inventory-ux-brief.md` §7 covering these rules:
   money is ink (tabular), green means state only, one formatter per type (date / timestamp / money), the currency is
   stated once per block, names never truncate, an empty state is one 44pt row, and no meaning is carried by color alone
   (glyph + text too). Add the same rules to the header comment in `DesignSystem.swift`.

## Logic (FarmaciaKit, TDD — `cd FarmaciaKit && swift test`)

1. [x] `ReportFormat.currencyParts(_:)` returns `("$", "220", ".00")` for the big-integer/small-cents style.
   Reuse `ReportFormat.currency` (es_MX, "$") for all other money.
   First test: **given 220, should split into "$", "220", ".00"**. Then 1234.5 → "1,234" / ".50".
2. [x] `DisplayDate`: `.day` "24 sep 2026", `.timestamp` "2 nov · 2:57 a.m.", `.relative` "hace 2 días"
   (es_MX, with locale and time zone injected).
   First test: **given 2026-11-02 02:57 local, should format the timestamp "2 nov · 2:57 a.m."**.
3. [x] `UnitCost.pick(suppliers:history:averageCost:)` returns cost, source ("Simi · compra 1 nov" from the supplier
   group's current `effectiveAt`, or "costo promedio"), `isBestPrice` (cheapest of 2 or more), and `showsAllSuppliers`
   (more than 1 supplier). Pass Kit value types; the app maps `ProductSupplier` / `SupplierCostHistoryGroup` into them.
   First test: **given a preferred supplier at 98 and average 105, should pick 98 from that supplier**.
   Then: no suppliers → average cost with "costo promedio"; 1 supplier → `showsAllSuppliers == false`, no badge.
4. [x] `Margin.perUnit(price:cost:)` plus a `PriceMargin` value (percent, perUnit, tone).
   First test: **given price 220 and cost 98, should be $122 per unit and 55.5%**. Then: cost above price →
   negative, critical; no price → nil.
5. [x] `ProductAlert.worst(lots:stockHere:aging:)` drives the Lotes chip: expired lot → critical "Vencido"; out here →
   critical "Agotado"; lot within 90 days → caution "Por vencer"; aging HIGH/CRITICAL → critical, MEDIUM → caution;
   otherwise **neutral** "Sin alertas" (never green by default). Each case carries a `systemImage`.
   First test: **given an expired lot and low aging risk, should be critical "Vencido"**. Then: everything healthy →
   neutral; 1 unit here → neutral (no "Bajo").
6. [x] `AgingSentence.text(buckets:)` replaces "inmovilizado" and the bar legend.
   First test: **given 2 units all in 0–30 d, should say "las 2 unidades llevan menos de 30 días en piso"**.
   Then: 1 unit → "la unidad lleva…"; mixed → "1 de 3 unidades lleva más de 90 días".
7. [x] `Expiry.countdown(daysUntil:)` returns "15 meses" / "20 días" / "venció hace 3 días", for the lot row
   "Vence feb 2028 · 15 meses".
   First test: **given 456 days, should be "15 meses"**.
8. [x] `ActivityPreview(count:)` returns collapsed (0), list (1–5), or list plus "Ver todo" (more than 5). Move the
   view's `prefix(5)` and lot `prefix(3)` rules here.
   First test: **given 0 events, should be collapsed**.

## UI (SwiftUI, FarmaciaApp)

9. [x] Design system: the adaptive `Tone.positive` green (`UIColor { traits in … }`); a `MoneyText` view (ink,
   `.monospacedDigit()`, `currencyParts`) and a 44pt `EmptyRow` view in an **existing** DS file (no pbxproj edit).
   Smoke: light/dark screenshots of Productos and the detail.
10. [x] Header card: 64pt thumbnail on the left, camera badge outside the image bounds, name wraps (no `lineLimit`),
    `SKU · ‖ barcode` monospaced on one line, no category. Nav title "Producto"; the toolbar gets a single "Editar"
    (price). Drop the `···` menu (its only item was Editar Precio) and the "Editar" in Precios.
    Smoke: the 72-character name on iPhone SE (375pt) and at the largest Dynamic Type.
11. [x] Economics block (inside the header card): Precio de venta / Costo as `MoneyText`, then
    `Margen 55.5% · $122.00 por unidad`, with the currency shown once. Provenance row
    `★ Simi  Mejor precio  compra 1 nov  $98.00 ›` opens a new `DetailSheet.suppliers` that holds the moved
    `costSupplierHistorySection`. Cashier: price only (`canViewCosts`).
    Smoke: owner vs cashier PIN; the supplier sheet opens on the first tap (see stacked-presentation memory).
12. [x] Inventario block: `2 uds en esta tienda · Farmacia Lolita`. Merge `otherStoresCard` in as rows (0 → neutral
    "0 uds"). "Movimientos ›" opens `ProductActivityFullView`. Remove the stats row from the header.
13. [x] Lotes block: `ProductAlert` chip, `AgingSentence`, the bucket bar with text labels, then lot rows
    `2 uds × $98.00 · Sale siguiente · $196.00 valor del lote` / `Recibido 1 nov · saldo inicial` and an expiry row
    `Vence feb 2028 · 15 meses` tinted by `Expiry.tone`, or a neutral "Sin caducidad". Remove "inmovilizado". Keep the
    cash-at-risk callout. Owners/managers only, as today.
    Smoke: receive with an expiry date, then confirm the lot row and chip.
14. [x] Activity: an `EmptyRow` "Sin movimientos aún · Historial ›" when there are no events; up to 5 rows otherwise.
15. [x] Detalles: Categoría, Creado (`DisplayDate.day`), and Descripción only when it differs from the name; the Square
    sync card becomes a line "● Square POS sincronizado hace 2 días" (sync card deleted).
16. [x] Bottom bar (`.safeAreaInset(edge: .bottom)`): the "Ajustar" menu plus "Recibir inventario", each at least 44pt.
    Remove the header buttons. Keep the "solo en otra tienda" rule (`canAddStock`).
    Smoke (critical flow): receive and adjust from the detail, then confirm the screen refreshes.
17. [x] Build, run the smoke list above in the iOS 27 simulator against the local API, update the README features and
    this epic's status, run `graphify update . --force` (sections deleted).

## Status (2026-11-10)

- Kit (TDD): 739 tests green (+28): `ReportFormat.currencyParts`, `DisplayDate`, `UnitCost`, `PriceMargin`,
  `ProductAlert`, `AgingSentence`, `Expiry.countdown`, and `ListPreview` (named for both lists; the plan called it `ActivityPreview`).
- Simulator (iPhone 17, local API): owner at 368pt: long name wraps; supplier sheet opens on the first tap; **receive**
  1 unit refreshed stock 9 → 10, 3 lotes, and "compra 10 nov"; the Ajustar menu opens Daño with the right type. Cashier
  (PIN 2528): price only, with no cost, margin, lots, edit or action bar. Dark mode on Productos.
- Fixed during the smoke test: the Menu label's `maxWidth`/`minHeight` frame made the bottom bar ~170pt tall (now
  `.controlSize(.large)`); the provenance row wrapped (now 2 lines); the margin glyph is now a triangle, not a clock.
- Beyond the plan: the activity timestamps and `InventoryReceiving.formattedDate` now use `DisplayDate.timestamp` (they
  were "5 Nov 2026 at 1:29 p.m."); `Product.currencyFormatter` writes "$" (it was "USD 220.00" app-wide, product cards too);
  the costs sheet is in Spanish ("c/u", "registros").
- Not done: the iPhone SE / largest Dynamic Type check (only 368pt checked). Follow-ups are in
  `tasks/inventory-review-followups-epic.md`.

## Migrate into FarmaciaKit (as touched)

- `latestSupplierCost` (view) → `UnitCost` (step 3); `Product.profitMargin` on the detail → `PriceMargin` (step 4).
- `Product.formattedPrice/formattedCost` ("USD 220.00" via `currency`) and the `String(format: "$%.2f")` calls in
  `ProductSupplier`, `CostHistoryEntry`, and the cash-at-risk callout → `ReportFormat.currency`.
- `createdAt.formatted`, `syncedAt.formatted()`, and `receivedAt.formatted` on the detail → `DisplayDate` (step 2).
- The activity `prefix(5)` / lots `prefix(3)` rules → `ActivityPreview` (step 8); the expiry pill label →
  `Expiry.countdown` (step 7).

## Follow-ups (→ `tasks/inventory-review-followups-epic.md`)

- **Per-product low-stock threshold learned from history** (typical on-hand, time at 0). farmacia-ops.
- **Sell-through / last sold**: endpoint from `SaleItem`; a line in Inventario.
- **Edit a lot's caducidad**: no PATCH endpoint, so "Sin caducidad · agregar" is text-only for now.
- **"Sin proveedor alterno · agregar"**: no add-supplier-to-product flow on iOS.
- **Cards vs detail margin**: cards use average cost, the detail uses the latest supplier cost. Decide whether cards follow.
- Photo guidance (package front) at capture time.
