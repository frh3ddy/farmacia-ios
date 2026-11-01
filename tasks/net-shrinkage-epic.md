# Net Shrinkage (Mercancía recuperada) Epic

**Status**: ✅ DONE — `2c6422c`, tests `9a32f6b` (merge `4ef2d32`); API farmacia-ops `9bf3c62`
**Goal**: The P&L shows what the store lost and what came back as separate rows, never a negative merma.

## Overview

The API's merma is now net: losses minus recovered stock (farmacia-ops `tasks/net-shrinkage-epic.md`). It sends both parts:

- `shrinkageLosses`: every stock removal except transfers and break-bulk.
- `shrinkageRecovered`: Encontrado (`FOUND`) and count corrections that went up. Any count correction up counts, even with nothing lost earlier in the period (decided 2026-10-31).
- `shrinkage`: losses − recovered; can be negative. `operatingExpenses.total` includes this net figure.

## What the app shows

- **Dashboard card** (`ProfitLossLines`): Gastos Operativos = total − net merma; Merma = losses; "Mercancía recuperada" (green) when above 0. `addsUp` checks revenue − cost − expenses − losses + recovered + Yastás = net profit (Decimal).
- **Full P&L report** (`ProfitLossReportView`): the same merma rows (`ProfitLossLines.shrinkageLines`), "Mercancía recuperada" in green; Total de Gastos = the server's net total.
- **Older servers** (no `shrinkageLosses`): one Merma row with the net figure, as before.

## Review follow-ups (2026-10-31 `/tdd-review`) — `05f54ae`

- ✅ The full P&L report builds its merma rows from `ProfitLossLines.shrinkageLines` (Decimal, tested), the same rows as the dashboard card, so a server that sends `shrinkageRecovered` without `shrinkageLosses` no longer counts the recovery twice.
- ✅ Tests for the older-server fallback: recovered but no losses shows one net Merma row, on the card and the statement.
- ✅ In the full report "Mercancía recuperada" shows green, as on the dashboard, so it reads as a deduction.
- ✅ The full report's margin subtitles say "margen".
