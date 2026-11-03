# Epic: risk colors, gain/loss colors, expense money tidy

**Branch:** `refactor/risk-colors-expense-decimal` (on top of `fix/aging-colors`)

## Decisions (2026-11-03)

- Risk levels on the three tones: Bajo positive, Medio caution, **Alto and Crítico critical** (icon and name still
  differ: triangle vs octagon).
- Expense money: **tidy only.** `Double` is the app-wide money type (receiving, prices, `AmountField`,
  `ReportFormat`), and the server does the totals, so no amount is wrong today. A full `Decimal` switch is a later
  epic (below).

## Steps

1. [x] `InventoryRiskLevel` moved to FarmaciaKit with `tone` (app keeps `color` = `tone.color`).
   Test: given Bajo/Medio/Alto/Crítico → positive/caution/critical/critical; decodes "HIGH".
2. [x] `ReportFormat.tone(_:)`: gain or zero → positive, loss → critical. Replaces 8 `isNonNegative ? .green : .red`
   (Dashboard, P&L, margin trends, adjustment impact). Activity quantities use `StockChange.tone`.
   Test: given 0 / 12.50 / −3 → positive / positive / critical.
3. [x] Expenses: `formattedAmount` and the summary card format the server's decimal strings with `ReportFormat.currency`
   (own `NumberFormatter` gone); unused `totalDouble`/`paidDouble`/`unpaidDouble`/`percentageDouble` removed.
4. [x] Device check (owner): Alertas severities, a product's "Riesgo …" card, Dashboard profit, Gastos amounts.

## Kept on purpose

- Report/Dashboard stat-card accents (revenue, cost, units…) and alert kinds (`SignalType.color`): they name a
  metric or category, not a status.
- Role colors, expense type colors: identity.

## Later

- **Money as `Decimal` app-wide:** `AmountValue`/`AmountField`, `ReceiveInventoryRequest.unitCost`, product prices,
  `CreateExpenseRequest.amount`, `ReportFormat.currency`. One pass with tests; JSON stays a number.
