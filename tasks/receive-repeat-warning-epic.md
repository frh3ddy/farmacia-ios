# Receive Repeat Warning Epic

**Branch**: `fix/receive-repeat-warning`
**API**: none new: GET /inventory/receive/product/:id (newest first, with `receivedAt`, `quantity`, `location`, `supplier`).

**Why**: the scanner's "Ya recibiste… hace un momento" lived only in the scan sheet's memory (the last save). Closing and reopening the scanner, or scanning another product in between, lost it, so a delivery could be received twice.

## Decisions

- **Window: today and yesterday**, by calendar day in the device's zone (an evening receiving is still flagged the next morning). Chosen by the user on 2026-11-18.
- **This store only** (the owner's history spans every store; filtered on `location.id`).
- **A warning, not a block**: a second lot of the same product is normal.
- **The same request as the expiry placement**: no new call.
- The server's note takes the place of the scanner's in-memory one (it includes that receiving); the scanner's still shows if the history can't load.

## Steps

1. ✅ `RecentReceiving.note(_:locationId:now:timeZone:)`: one receiving ("Ya se recibieron 20 uds hoy a las 10:30 a.m. (Nadro). Revisa antes de recibir otra vez."), several ("Ya se recibió 2 veces desde ayer (30 uds); la última …"), ayer, "a la 1:15", 1 ud, another store and two days ago ignored. `DisplayDate.time`.
2. ✅ `ReceiveInventoryFormView`: the receivings response decodes `receivedAt`, `quantity`, `location`, `supplier`; the warning shows under the product, orange.

## /tdd-review fixes

1. ✅ The history decodes only the fields it uses (`location.id`, `supplier.name`), so fewer server changes can drop it. One bad row still drops all of it (the expiry placement then goes up top).
2. ✅ Several receivings all today say "hoy", not "desde ayer".
3. ✅ The history reloads per store (`.task(id:)`, like the count warning); a cancelled load leaves the state to the new one.
4. ✅ A history that couldn't load says "No se pudo revisar si ya se recibió hoy o ayer." (the scanner's note shows instead when there is one).

## Still to check

- In the simulator or a phone: receive a product, close the scanner, reopen it and scan the product again: the warning shows. Not smoked yet: the local API was down.
