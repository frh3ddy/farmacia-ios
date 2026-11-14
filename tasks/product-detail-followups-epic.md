# Epic: product detail follow-ups: migration note, view split

**Branch:** `feature/product-detail-followups`, from `main` (`551ebcc`, 2026-11-13). Planned first on
`feature/sales-intel` (`c321d83`), which still isn't merged; it adds ~33 lines to the detail's Inventario block, so
merging it after this split means moving that sales line into `ProductInventoryCard`.
**From:** `tasks/inventory-review-followups-epic.md` § Product detail redesign follow-ups (three items). This moves
steps 6b–6d out of the sales-intel fixes epic.

**Decided (2026-11-11):**
- Supplier notes: leave out "Migrated from cutover <uuid>" entirely. The note stays in the database.
- ~~Low stock = days of cover, everywhere~~ — superseded by the stock alerts epic (see C).

## A. Hide the migration note

1. [x] `SupplierNote.display(_:) -> String?` (FarmaciaKit). Done 2026-11-13 (`a64e7aa`), `SupplierNoteTests`;
   also keeps a real note's own leading dash ("-10% en caja"): separators are trimmed only where the phrase was cut.
   First test: **given "Migrated from cutover 3f2a9c1e-5b7d-4e8a-9c0f-1a2b3c4d5e6f", should be nil**. Then: other
   notes unchanged; inside a longer note only the phrase and its separator are removed; empty or whitespace → nil.
2. [x] Suppliers sheet: notes go through `SupplierNote.display`; nil → no notes line. (Lands in `CostSupplierSheet`
   after step 4; doing it before the split is fine too.) Smoke: the suppliers sheet opens on the first tap, with no
   migration note.

## B. Split `ProductDetailView` (1,477 lines)

3. [x] `BarSegments.widths(fractions:total:spacing:minimum:)` (FarmaciaKit): the aging bar's split, so the bar can drop
   `GeometryReader`. First test: **given 98% and 2% on a 100 pt bar with a 2 pt minimum and 1 pt spacing, should sum to
   100 pt** (today's math overflows and relies on clipping). Then: one bucket fills the width; zero-unit buckets get no
   segment. Done 2026-11-13 (commit "refactor: split ProductDetailView"), `BarSegmentsTests`; the bar is a `SegmentedBar` `Layout`.
4. [x] Extract `View` structs into their own files in `Features/Products/Views/`, each registered in `project.pbxproj`
   by hand. Pure moves; no behavior change other than steps 2–3.
   - `ProductEconomicsBox.swift`: `economicsBox`, `marginLine`, `provenanceRow`.
   - `ProductInventoryCard.swift`: `inventoryCard`, `otherStoresRows`, the sales line.
   - `ProductLotsSection.swift`: `fifoBatchSection`, `batchRow`, `expiryRow`, the aging bar as a small `Layout` sized by
     `BarSegments`.
   - `ProductRecentActivitySection.swift`: `recentActivitySection`, `activityRow`.
   - `ProductDetailsCard.swift`: `detailsCard`, `detailRow`, `squareSyncLine`.
   - `CostSupplierSheet.swift`: `costSupplierHistorySection`.
   - Stays in `ProductDetailView`: header and photo flow (its state and sheets), action bar, every load and `.task`, the
     single `.sheet(item: DetailSheet)`. Extracted views take values and closures, not view models, so the
     stacked-presentation crash can't come back. Target: under ~600 lines.
   Smoke (critical): **receive inventory** from the detail (stock and lots refresh), Ajustar → Daño, the suppliers sheet
   on the first tap, Editar precio, owner vs cashier; the 72-character name at iPhone SE width and the largest Dynamic
   Type (never checked in the redesign).
   Done 2026-11-13 (commit "refactor: split ProductDetailView"): six files, moved byte-for-byte then renamed to values and closures; `showAllBatches`
   and `expandedSupplierHistory` moved into the views that use them. `ProductDetailView` 1,497 → 708 lines (header,
   photo flow, action bar, loads, the one sheet; still over the ~600 target, the photo flow is ~120 of it).
   Smoke on the simulator: every section renders; the aging bar fills the width; the suppliers sheet opens on the first
   tap; Ajustar → Daño opens; a real receiving (1 × $100, Audifonos) refreshed stock 1 → 2 and lots 1 → 2; a lot
   opens its sheet; Editar precio opens. Not checked: iPhone SE width and the largest Dynamic Type; a supplier with a
   migrated note (none locally; the rule is unit-tested).

## C. ✅ Low stock per product — done by the stock alerts epic

Superseded 2026-11-11 by `docs/stock-alerts-design.md` and built as `tasks/stock-alerts-epic.md` (merged into `main`
in `551ebcc`, pushed 2026-11-13). What shipped, from the server's `stockAlert` on every product row:
- Alerts only for regular sellers (sold most weeks): **Agotado** at 0; **Bajo** when the stock covers fewer than 14
  days at the product's own rate *and* sits under its normal level. Slow movers at 0–3 stay quiet.
- Detail, list chips and counts, cards, rows and Alertas all read it; an old server falls back to the fixed cutoffs.
- **Pausado** per store (owner/manager, with a reason); it resumes itself on any receiving or received transfer.
- Alertas ranks Sin Stock / Stock Bajo by sales lost a day, with the reason ("Vende ~3 al día · alcanza para ~4 días").
- For later (ops O7–O9): pause suggestions, equivalents, the medication report.

5. [ ] App build, specialist reviews (`swiftui-pro` for the split; `swift-concurrency-pro` unchanged), `/tdd-review`,
    README, mark the two follow-ups ✅ in `inventory-review-followups-epic.md`, `graphify update .`.

## Migrate-as-touched

- Into FarmaciaKit: the supplier-note cleanup (1), the aging-bar width math (3). The `Layout` and the extracted views stay app-side.

## Notes

- The low-stock notes that were here moved with C to the stock alerts epic.
