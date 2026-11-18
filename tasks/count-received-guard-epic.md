# Count Received Guard Epic

**Branch**: `feature/count-received-guard`
**API**: farmacia-ops `feature/count-received-guard`, in production at main 117b834 (Railway deploy ba428217).

**Why**: stock that comes in during an open Conteo inicial doesn't mark the product counted, so it stayed in No contados with old plus new units, and "Poner todos en 0" zeroed what had just arrived.

## Contract

- `GET /inventory/stock-counts/:id/uncounted`: each row has `receivedAt` (ISO or null), the last time stock came in at the store since the count started: a supplier receiving, a customer return, a box opened into loose units, a transfer received, Encontrado and other positive adjustments. Not the count's own corrections, nor the batch that covers a sale with no stock.
- `POST /inventory/stock-counts/:id/zero` takes `includeReceived: true`; without it, such a product is skipped as `{ ok: false, code: "RECEIVED_DURING_COUNT", error: "Entró existencia durante el conteo: cuéntalo antes de ponerlo en 0" }`.

## Steps

1. ✅ `UncountedProduct.receivedAt` (nil on an older server) and `receivedNote`: "Entró existencia durante el conteo · 12 nov".
2. ✅ `StockCountZeroRequest(includeReceived:)`: the key only when true.
3. ✅ `ZeroOutcome`: RECEIVED_DURING_COUNT is a skip with its own line, not a failure.
4. ✅ `ZeroAll`: "Poner todos en 0" sends only the rows without `receivedAt`, and its confirmation says how many stay; off when every row has it.
5. ✅ `UncountedListView`: the label on the row, the per-row button sends `includeReceived: true`, the bulk one uses `ZeroAll`.

## Still to check

- On a phone, with an open count: receive a product, open No contados: it has the label; "Poner todos en 0" leaves it and says so; its own "Poner en 0" zeroes it.
- `ReceiveCountWarning` in Recibir still says "Poner en 0" would zero the received units. Now only the product's own button does: the text could say so.
