# Epic: design system cleanup — product screens

**Branch:** `refactor/design-system-product-screens`
**Scope:** `ProductRow`, `ProductsView`, `ProductDetailView` (most of the app's hand-picked colors and fixed font
sizes). Same look; colors come from rules, sizes from text styles. Other screens still convert as they're touched.

## Logic (FarmaciaKit, TDD)

1. [x] `StockLevel(quantity:)` — out (≤0) / low (1–9) / ok, same cutoffs as the API's list filters
   (`products.service.ts` `FILTER_SQL`); `tone` and a Spanish label ("Agotado", "Bajo").
   First test: given 0, should be out. Then 9 → low, 10 → ok.
2. [x] `BatchAge.tone(days:)` — under 30 days positive, under 90 caution, else critical (the detail's age dot and
   the <30d / 30-90d / >90d pills). First test: given 29, should be positive. Then 30 → caution, 90 → critical.
3. [x] `ProductFilter.tone` — chip colors by meaning. First test: given Sin Stock, should be critical.

## UI

4. [x] `ProductRow`: stock badge from `StockLevel` (Spanish, text style instead of 9pt), margin from `Margin.tone`.
5. [x] `ProductsView`: filter chips from `ProductFilter.tone`; fixed sizes → text styles.
6. [x] `ProductDetailView`: margin (`Margin.tone`), batch age (`BatchAge.tone`), aging pills; the repeated card
   background → one `.card()` modifier in `Core/DesignSystem/`; fixed sizes → text styles; spacing → `DS.Spacing` where
   the value is a token.
7. [x] Build; device check of Productos and a product detail (owner), README, `graphify update .`.

## Status (2026-11-03)

- Device smoke test passed (owner).

- Kit (TDD, 296 tests): `StockLevel` + `BatchAge` (`StockLevel.swift`), `ProductFilter.tone`.
- New components: `ToneBadge` (tinted caption tag, `Tone` or a plain `Color`) and `.card()` in
  `Core/DesignSystem/ToneBadge.swift`.
- ProductRow: Spanish badges ("Agotado", "Bajo", "Crítico", "Riesgo"; were OUT/LOW/CRIT/RISK), margin via `Margin.tone`.
- ProductsView: chips by `ProductFilter.tone` (Margen Bajo is now caution orange, was purple), 44pt tap area,
  empty state → `ContentUnavailableView` in Spanish, sync row on `Tone.caution`.
- ProductDetailView: 8 cards → `.card()`; margin, batch age, aging pills, Square sync, cost trend, other-stores
  highlight and the cash-at-risk callout (now Spanish) by tone; no fixed font sizes; 81 spacing/radius/padding
  values → `DS` tokens (non-token values like 1, 3, 6, 10 kept, to keep the look).
- Kept on purpose: section-header accent icons (decorative), `BatchPill` category colors (lot/supplier/invoice),
  `bucketColor` (the aging service's 4 tiers at 31/61/91 days — a different scale; a follow-up if it should match
  `BatchAge`), `InventoryRiskLevel.color` (model).
