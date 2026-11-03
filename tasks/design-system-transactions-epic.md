# Epic: design system, phase 2 — transaction screens

**Branch:** `feature/design-system-transactions`
**Source:** the inventory/POS UX brief (2026-11-03): "optimize for the transaction, not the dashboard";
fast, accurate data entry; show the consequence before posting; status never by color alone.
Phase 1 (tokens, `Tone`, `AmountField`, `.formKeyboard`, Más detalles, Guardar spinner, discard guard)
is in `tasks/design-system-epic.md` / `tasks/form-ux-polish-epic.md`.

## Audit: brief vs the app today

| Brief asks for | Here | Status |
|---|---|---|
| Persistent labels, units beside amounts, calculated values | `AmountField` (label + `$` + unit), Costo total, Margen | ✅ |
| Keyboard navigation, keep input after errors | `.formKeyboard` ‹ › Listo; save errors in an alert inside the open form (`SaveOutcome`) | ✅ |
| Progressive disclosure | Más detalles on Nuevo Producto / Recibir | ✅ |
| No duplicate submission | Guardar spinner + one `clientRequestId` per form (API dedups) | ✅ |
| Scan to find an item | `ScanFlowSheet` | ✅ |
| Count: system qty / counted / difference | Conteo: Cantidad actual (live) + Nueva cantidad + change line | ✅ (before → after missing) |
| Reason on adjustments | Razón (optional) + Notas | ✅ |
| FIFO costing, COGS, margin, P&L, valuation | API (FIFO batches) + Reports tab | ✅ — FIFO only, no method selector (see Later) |
| Show the consequence before posting (qty before → after, store, value) | adjustment says "Esto eliminará N unidades"; no resulting stock, no store, no value | **step 2, 5** |
| Status by text + icon, not color alone | expiry status: 90-day cutoff and red/orange picked inline in 3 places | **step 1, 4** |
| Errors next to the field, saying how to fix | Crear / Guardar just stay disabled | **step 3, 6** |
| Boxes × units per box | none | **step 7** |
| Several lots in one receipt; lot quantities add up to the received total | one lot per receiving (API: `InventoryReceiving` = one batch) | Later (ops) |
| Purchase orders: ordered vs received, partial receipts, Save draft vs Post | none (`purchaseOrderId` column exists, unused) | Later |
| POS checkout | Square POS does checkout; the app only sees synced sales | Later |

## Logic vs UI

- FarmaciaKit (tested): `Expiry.tone`, `StockImpact`, `ProductDraft.issues`, `PackQuantity`.
- FarmaciaApp: `StatusLabel` (icon + text + tone) in `Core/DesignSystem/`, the adjustment/receiving summary row,
  inline hints under fields, the boxes helper.
- Migrate now: the inline `stockEffect` in `AdjustmentFormView`; the 90-day expiry cutoffs/colors in
  `ProductDetailView` and `BatchDetailView`.

## Steps

1. [x] Kit `Expiry.tone(daysUntil:)` — expired → critical, within 90 days → caution, else neutral.
   First test: given −1 days, should be critical. Then 0 → critical (expired from the start of the day), 90 → caution, 91 → neutral.
2. [x] Kit `StockImpact(before:change:)` — `after`, signed change text ("−3"), and the summary "42 → 39".
   First test: given 42 and −3, should end at 39. Then: a removal past zero is flagged (`exceedsStock`), change 0 → nil.
3. [x] Kit `ProductDraft.issues` — the reason Crear is off, per field: no name, no price, a quantity without cost,
   a cost without quantity. First test: given a cost and no quantity, should ask for the quantity on the Cantidad field.
4. [x] App `StatusLabel(text:systemImage:tone:)` in `Core/DesignSystem/`; expiry rows in `ProductDetailView` /
   `BatchDetailView` use `Expiry.tone` + `StatusLabel`. Smoke: build; a product with an expired and a soon lot.
5. [x] App Ajuste/Conteo: the footer becomes the `StockImpact` summary ("Centro · 42 → 39 (−3)"); a removal past stock
   says so next to the field. Smoke: Daño −3, Conteo down and up.
6. [x] App Nuevo Producto: the first `issues` entry shows under its field once the user has typed something.
   Smoke: cost without quantity shows the hint; filling the quantity clears it.
7. [x] Kit `PackQuantity.total(boxes:perBox:)` + App: Recibir's Cantidad gets a "Por cajas" helper (Cajas × Piezas por caja
   → fills Cantidad). First test: given 3 boxes of 12, should be 36; 0 or missing → nil.
   Smoke: receive 3 × 12, Cantidad reads 36, Costo total follows.
8. [x] Review (`/tdd-review`, swiftui-pro, ui-ux-pro-max mobile checklist), README, this epic, `graphify update .`.
   Fixed (2026-11-03): turning "Por cajas" on no longer erases a typed Cantidad (it changes once the boxes add up);
   Cajas / Piezas por caja count as unsaved work (`ReceivingDraft.boxes`/`perBox`, TDD, 2 tests); unused
   `Expiry.isExpired` / `expiresWithin` deleted (tests moved to `daysUntil` + `tone`; CLAUDE.md rule updated).
   Before-stock: Ajuste now loads live stock for every type when online (falls back to the last loaded stock offline);
   the product summary row above still shows the loaded stock.
   **Open:** Recibir's "antes" still uses the last loaded stock — after `feature/other-stores-stock` merges, start it
   from that branch's `StoreStock` fetch for this store (no extra request).

## Status (2026-11-03)

- Kit steps done (TDD, 274 tests green): `Expiry.tone` (+ `warningDays` = 90), `StockImpact`, `ProductDraft.Issue`,
  `PackQuantity`. Per-box cost was left out: Costo stays per unit until someone asks.
- UI built; smoke passed on device (2026-11-03, Farmacia Dev via `scripts/dev-build-install.sh`):
  `StatusLabel` + `Tone.systemImage` (`Core/DesignSystem/StatusLabel.swift`); `BatchValuation.expiryTone` replaces
  `isExpired`/`expiresWithin(90)`; expiry copy now Spanish ("2 vencidos", "1 por vencer", "Vence"/"Vencido");
  a far-off expiry pill is neutral instead of green. Ajuste/Conteo footer "Centro · 42 → 39 (−3)" + a caution line
  when a removal is more than the last known stock (warns only; the API checks its own stock). Recibir: "Por cajas"
  toggle and the same footer ("Centro · 7 → 43 (+36)"). Nuevo Producto: price / quantity-without-cost /
  cost-without-quantity hints in their section footers.
- Merge note: `feature/other-stores-stock` (unmerged) adds a footnote under Recibir's Cantidad too — expect a conflict
  in that section's footer; keep both lines.
- Smoke: Daño −3 and a removal past stock; Conteo down and up; Recibir 3 × 12 → 36 and back to Cantidad;
  Nuevo Producto cost without quantity; a product with an expired and a soon-to-expire lot.

## Later features (documented, not built)

### Purchase orders
Create a PO per supplier (products, ordered quantity, expected cost) → receive against it: ordered / received before /
receive now, partial receipts, rejected quantity, discrepancy review. **Save draft** distinct from **Post**.
Needs the API: a `PurchaseOrder` model (today only `InventoryReceiving.purchaseOrderId String?`). The receiving form
becomes one line of a PO receipt.

### Several lots in one receipt
Lot rows (lote, cantidad, vencimiento) under one received total, "120 de 200 asignadas a lotes" until they add up.
Each lot is its own FIFO batch already (one `InventoryReceiving` → one `Inventory`), so the API needs either a
multi-lot receive endpoint (atomic) or the app posts N receivings (not atomic — a half-saved receipt).
**Ops answer (2026-11-03):** no multi-lot endpoint, no PurchaseOrder model; recommends N posts: each lot its own
stable `clientRequestId` (`<draftId>:<lotIndex>`) so the offline queue replays the set safely (recorded lots return
their receiving, missing ones get created); same `invoiceNumber` on every lot to group them; each lot re-saves the same
supplier cost (N cost-history rows, fine). An atomic `lots[]` endpoint only if half-recorded deliveries become a real
problem — ask the user before anyone plans it. Ops would skip PurchaseOrder (YAGNI) until the owner wants orders
tracked against deliveries; `invoiceNumber` covers grouping.

### POS checkout
Square POS runs checkout today; the app sees sales after sync. If the app ever sells: scan → cart → payment →
result, with pending / failed / completed shown apart and no promise of offline sales.

### Costing method
FIFO is the only method (API batches). No selector: changing it is an accounting-policy decision, would need an
effective date and must never recalculate history. LIFO isn't allowed under IFRS.
Fixture to keep if it's ever added: 100 @ $10 + 100 @ $12, sell 120 → FIFO COGS $1,240 / LIFO $1,400 / average $1,320.

### Landed costs
Freight/duties allocated over a receipt by quantity or value, previewed per item before posting. Out of scope until
the business asks for it.

### Picking (FEFO)
Suggesting the soonest-expiring lot is physical picking, separate from the FIFO cost layer; don't tie them.
