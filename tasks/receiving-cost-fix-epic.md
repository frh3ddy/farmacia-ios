# Receiving Cost Fix Epic (Corregir costo)

**Status**: ✅ MERGED (2026-11-19): `e338a3d`, merged to main as `dceacad`; dev-f8 approved. Item 3 still open.
**Goal**: Let the owner fix a receiving saved with the wrong unit cost. The trigger was Dolprin Susp 120 ml (SKU 780083141929), real cost $26.71.

## Overview

API: `POST /inventory/receive/:id/cost` `{ unitCost }`, OWNER only (farmacia-ops `ea0fd7c`). It recosts the receiving, its batch and lots, past sales and losses from it, and the supplier's current cost when this is that supplier's latest receiving. It answers 409 "No se puede corregir el costo: …" when units were transferred, opened, or sold and returned.

---

## ✅ 1. Rules in FarmaciaKit (`ReceivingCostFix`)

- Owner-only gate, cost parsing (≥ 0, "." or ",", exact `Decimal`), Guardar only on a changed cost, and the `{"unitCost":26.71}` body sent as an exact number.
- The 409 message goes through `NetworkError.from` → `SaveOutcome` unchanged. The path isn't replay-safe, so it's never queued offline.

## ✅ 2. UI

- Producto → Movimientos → Recepciones: "Corregir costo" on each receiving (owner only). The sheet shows the receiving, the current cost, the new cost and "$old → $new", and Guardar asks for confirmation first.
- On success, product activity, supplier costs and lots reload.
- Simulator, local API: Audifonos $100 → $95.50 saved and the list updated; then set back to $100.

## 📋 3. Open

- **Device check on production** after the API deploy: Dolprin Susp 120 ml → $26.71. Confirm that the margin and the supplier cost update.
- **A 409 in the UI:** covered by a unit test only. No local receiving with moved units was handy.
- **Global Historial de Actividad** (receivings by store) has no Corregir costo. Add it there if the owner looks for it.
- **Pre-existing:** Recepciones rows in product activity say "Producto Desconocido". The by-product list doesn't include `product`. Use the screen's product name instead.
