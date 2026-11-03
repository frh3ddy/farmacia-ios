# Epic: design system — Gastos, Empleados, Nómina/turnos, Ajustes row

**Branch:** `refactor/design-system-other-screens`
**Scope:** `ExpensesView`, `ExpenseDetailView`, `ExpenseFormView`, `EmployeesView` (incl. Agregar Empleado),
`PayrollView` (Ajustar turno), `AdjustmentRow`. Same look; colors by meaning, empty/error states native, spacing
from `DS`.

## Survey (2026-11-03)

- Text is already Spanish (a few title-case leftovers: "No Hay Gastos", "Error al Cargar").
- Status colors picked by hand: paid/unpaid (green/orange), employee active (green/gray/red), PIN set (green/orange),
  adjustment row (`StockChange.color` green/red/orange), destructive icons (red).
- Expense type colors: the same 12-case `String → Color` switch copied in `ExpensesView` and `ExpenseDetailView`.
  These are category identity colors (not status), so they stay; only the copy goes.
- Empty/error states hand-built with `.font(.system(size: 36/48/60))` icons.
- Expense type chips: `blue` active tint, no 44pt tap area (Productos chips already fixed).

## Logic (FarmaciaKit, TDD)

1. [x] `StockChange.tone` — added → positive, removed → critical, none → caution (replaces the app-side `color`).
   First test: given +3, should be positive. Then −2 → critical, 0 → caution.

Paid/active/PIN are one ternary each on app-side models — no kit step (YAGNI).

## UI

2. [x] `AdjustmentRow`: `StockChange.tone`, `ToneBadge` for the type tag, `DS` spacing.
3. [x] Gastos (`ExpensesView`, `ExpenseDetailView`): one shared `ExpenseType.color`; paid/unpaid via
   `Tone.positive`/`.caution` + `StatusLabel`/`ToneBadge`; empty state → `ContentUnavailableView`
   ("Sin gastos"); chips like Productos (tint, 44pt); fixed sizes → text styles; `DS` spacing; `.card()` where cards.
   Smoke: Gastos list → detail → mark paid.
4. [x] `ExpenseFormView`: `DS` spacing; issues shown like Nuevo Producto if the Guardar button is disabled silently.
   Smoke: create an expense.
5. [x] Empleados (`EmployeesView`, Agregar Empleado): active/PIN status by tone (`StatusLabel`); loading/error/empty →
   `ProgressView`/`ContentUnavailableView` with Reintentar; fixed sizes → text styles; `DS` spacing.
   Smoke: open an employee, add one (owner).
6. [x] Nómina / Ajustar turno (`PayrollView`): empty state → `ContentUnavailableView`; paid badge → `ToneBadge`;
   `DS` spacing. Smoke: edit a shift.
7. [x] Build, device check (owner), README, `graphify update .`.

## Out of scope / later

- `InventoryRiskLevel.color` — a 4-step scale (low/medium/high/critical); `Tone` has no "high". Leave until a risk
  screen is touched.
- Role colors (`Employee.Role.color`) — identity, not status; kept.

## Status (2026-11-03)

- Kit (303 tests): `StockChange.tone`; the app-side `StockChange.color` is gone (activity lists use `.tone.color`).
- `ExpenseType.color` is now a `Color` (one place, was a `String` switched on in two views); `Expense.paymentLabel` /
  `paymentTone` / `paymentIcon` for every paid/unpaid badge.
- Gastos: `ToneBadge`/`StatusLabel` for paid status, summary money via `ReportFormat.currency` (was a
  `NumberFormatter` per call), chips on `Tone.info` with 44pt, "Limpiar" no longer red (it isn't destructive),
  empty state → `ContentUnavailableView`.
- Gasto form: `AmountField` + `.formKeyboard`; "El monto debe ser mayor a $0." when a typed amount is ≤ 0.
- Empleados: loading/error/empty native; role tag → `ToneBadge`; Sin PIN / Activo / PIN Establecido by tone.
- Nómina: empty state native; "EN CURSO" → `ToneBadge("En curso")`; "Total a pagar" no longer green (not a status).
- Later: expense amounts are `Double` (the review rule says `Decimal`) — change with the request model.
- Review fixes: expense rows are `Button`s (VoiceOver), "No pagado" casing everywhere (incl. the expense summary
  report), the detail's paid tag back to subheadline size, filter bar without extra vertical padding.
- Device check passed (owner).
