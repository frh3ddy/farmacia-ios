# Epic: Conteo inicial — stepper, "Sin cambios", and lots with caducidad

Branches: `feature/opening-count-lots` in **farmacia-ios**; the API part is owned by the farmacia-ops session
(contract below, sent 2026-11-05).

## Status (2026-11-05)

- ✅ Steps 1–5 (Kit, test-first; 449 tests green) and 6–7 (UI), not committed.
- Smoke (simulator, local API, session open): Corrección de Conteo outside a session shows the stepper, no
  Sin cambios; in a session "Sin cambios: hay 64" saved in one tap ("Productos contados" 0 → 1, stock 64);
  stepper + ×9 → Guardar took Aspirina 10 → 9 as Conteo inicial. Scanner path not smoked (needs a scan).
- ✅ Follow-ups (asked 2026-11-05): the stepper starts at the stock once it loads (a typed number is kept;
  `CountSave.startValue`), smoked: Aspirina's form opened at 9. Lots pre-fill logic (`CurrentLot`, untouched
  pre-filled rows not checked or sent, `quickMatchBlocker`) is in Kit; 455 tests green.
- ✅ Step 8 built (not smoked): "Lotes y caducidad" in the count form while a Conteo inicial is open, rows
  pre-filled from `GET /inventory/lots` (Vence, Cantidad, Lote optional), "Agregar lote", swipe to delete;
  footer shows "N sin lote" (hint) or the blocking reason; Guardar and "Sin cambios" blocked on lots over the
  count. Hidden when the lots read fails (an API without it), so lots are never typed into a void.
  Skipped: the receiving form's "caducidad up top vs. bottom" placement.
- ✅ Camera lot scan (asked 2026-11-05): a camera button on each lot row's Lote and "Escanear caja" (adds a row
  and scans into it), receiving's `LotScannerView` presented at the form level; `CountLot.applying(scan)` fills
  what the scan read and keeps the rest and the quantity (Kit, 459 tests). Not smoked: the camera scanner
  isn't available in the simulator (buttons hidden there); needs a device.
- ✅ `ExpiringBatchInfo` no longer decodes `receivingId` (a counted lot has none; null broke the list). Old
  builds hit that once a counted lot is expiring: update every device before counting with lots.
- Smoke (simulator, local API on the API's lots branch, session open): Abatelenguas pre-filled 2 lots
  (1 + 36, both "nov 2027", from receivings) under a count of 90; untouched they don't block (Guardar and
  "Sin cambios: hay 90" enabled). "Quitar caducidad" on a row blocked both; picking the same month again
  made the rows equal to the pre-fill again (untouched, enabled). **Not smoked:** saving edited lots
  (the month wheel and the row quantity can't be driven by simulator automation) — covered by Kit tests
  (wire format) and the API's specs.
- Note: two lots with different days of the same month show as two "nov 2027" rows; once edited, the
  app sends the month's first day, so the original day is replaced (same month resolution as receiving).
- ✅ "Ya contado en este conteo: 10 · 5 nov, Fredy" under the product in the count form (detail and scanner
  Contar) while a session is open (asked 2026-11-05: counts span days, people lose track). `CountedEntry`
  (Kit, day in the store's time zone). Reads `GET /inventory/stock-counts/:id/entries?productId=` (requested
  from the API session; 200 with null when not counted); shows nothing if the read fails. Smoked (local API
  on the API's branch): Aspirina's form showed "Ya contado en este conteo: 9 · 5 nov, Fredy"; a product with
  no lots shows "Agregar lote" with the "Basta con la caducidad" hint.
- Released 2026-11-05: API `1a4ed42` live; app main `8aa745f` installed on iPhone lolita and iPhone 13 Pro.
  **iPad not updated (user's call):** its build can't load Lolita's adjustment history (OPENING_COUNT) or the
  expiring list once a counted lot exists. Update it before relying on the iPad for those screens.

## Problem

Counting a store product by product: the count field is a plain text row (receiving has the big −/+ stepper);
a product that matches its stock takes typing the same number and Guardar; and the migration loaded stock
without lots or caducidad, so a Conteo inicial is the moment to record them. One shelf often holds the
same product with different expiries (4 vencen ene-2027, 6 vencen mar-2027).

## Decisions (asked 2026-11-05)

- **Stepper for every count** (Corrección de Conteo and Conteo inicial): the receiving form's `QuantityStepper`.
- **"Sin cambios" (Conteo inicial only):** one tap saves count = current stock (the product counts as counted),
  keeps its lots as they are, and closes; the scanner goes on to the next item.
- **Lots (Conteo inicial only), optional:** rows of quantity + caducidad (month, **required**) + lote (optional, user 2026-11-05). Products without
  caducidad skip it. **Changed (user, via the API session):** lots may add up to less than the count; the rest
  stays without lot info ("3 unidades sin lote" hint). Only lots over the count block Guardar ("sobran N").
- **Stepper starts at the stock** (asked after step 7): counting is ± from the record.
- **Pre-fill lots** with the product's current ones (`GET /inventory/lots`). Untouched pre-filled rows are
  neither checked nor sent (lots stay as they are; stock without lot info can't block a save). Edited or
  added rows are sent; they can't exceed the count ("sobran N"), and a shortfall is a hint ("N sin lote").
- **"Sin cambios" honors lots:** with edited lots it sends them (they must add up to the stock; the API
  replaces lots on a change-0 entry; over the stock blocks it); untouched, lots stay as they are.
- **Replace:** the counted lots become the product's lots at that store; older lot/caducidad info for the
  remaining stock is dropped. Costs (FIFO layers) are untouched.

## What the code does today

- `AdjustmentFormView` count: `AmountField("Nueva cantidad")` under "Cantidad actual"; in a session a matching
  count saves via Guardar (`CountSave`). Validity for a session match is decided in the view (`:96`), not Kit.
- Receiving: `QuantityStepper` (`Core/DesignSystem`), "Lote y caducidad" = `MonthYearPicker` + lot field with a
  camera scan (`LotScan`); `ReceiveInventoryRequest` sends `expiryDate` as `LocalDay` of the month's first day
  and `batchNumber`.
- API: lot and caducidad live on `InventoryReceiving` (`batchNumber`, `expiryDate`), joined to the batch's
  remaining quantity for the expiring list (`inventory-aging.service.ts:729`). Migration batches
  (`OPENING_BALANCE`) have no receiving, so no caducidad.

## API contract (farmacia-ops session builds it)

- `POST /inventory/stock-counts/:id/entries` accepts optional
  `lots: [{ quantity: Int > 0, expiryDate: "YYYY-MM-DD", batchNumber?: String }]`; the app always sends
  `expiryDate` (required per lot), `batchNumber` only when typed.
- `lots` present: sum must be ≤ `countedQuantity`, else 400 with `code: "LOTS_TOTAL_MISMATCH"`; the rest of
  the stock stays without lot info. After the
  count applies, the product's remaining stock at the store carries exactly these lots (replace), costs kept;
  the expiring list and alerts read them. Storage design is the API's call.
- `lots` absent: lots untouched (today's behavior), including a count equal to stock.
- A replay (same `clientRequestId`) returns the first result. `zero` takes no lots.
- An entry with change 0 plus `lots` saves the entry, makes no adjustment, and replaces the lots (confirmed).
- `GET /inventory/lots?productId=…&locationId=…` (OWNER, MANAGER): `[{ quantity, expiryDate: "YYYY-MM-DD" | null,
  batchNumber | null }]`, remaining units, merged by (expiryDate, batchNumber), stock without lot info left
  out, soonest expiry first. Pre-fills the rows.
- **The app must not send `lots` before the API supports it**: Nest drops unknown fields, so lots typed
  against an old API would vanish silently. Step 13 waits for the API's "live".

## Steps

### Logic (FarmaciaKit, Swift Testing)

1. **Count validity moves to Kit** (migrate-as-touched, `AdjustmentFormView:96`):
   `CountSave.canSave(change:matches:inOpeningCount:)`.
   - First test: *given a Conteo inicial and a count equal to stock, should be savable; given a correction, not.*

2. **Quick "Sin cambios":** `CountSave.quickMatch(liveStock:inOpeningCount:) -> Int?`: the count to save in one
   tap, nil outside a Conteo inicial or before stock loads.
   - First test: *given a Conteo inicial and stock 12, should save 12.*

3. **Lot rows:** `CountLot { quantity: Int?, expiry: MonthYear?, batchNumber: String }`; a row counts when it
   has a quantity > 0 and a caducidad or lote; blank rows are ignored.
   - First test: *given a row with 4 and ene-2027, should count; given a row with 4 and nothing else, should not.*

4. **Lots against the count:** `CountLots(rows).check(counted:)` → `.none` (no lots), `.matches`,
   `.mismatch(text)` ("Los lotes suman 7 de 10: faltan 3" / "sobran 2").
   - First test: *given lots 4 + 6 and a count of 10, should match.*
   - Then: 4 + 3 for 10 says faltan 3; a lot row missing caducidad and lote is pointed out.

5. **Request:** `StockCountEntryRequest.lots` encodes each lot like receiving (`expiryDate` = `LocalDay` of the
   month's first day, empty lote → nil), omitted entirely when there are none.
   - First test: *given ene-2027 × 4 with lote "A12", should send `{quantity: 4, expiryDate: "2027-01-01", batchNumber: "A12"}`.*
   - Then: no lots → no `lots` key.

### UI (FarmaciaApp)

6. **Stepper:** the count's "Nueva cantidad" becomes `QuantityStepper` ("unidades") under "Cantidad actual",
   for Corrección de Conteo and Conteo inicial; Guardar validity from step 1.
   Smoke (critical: count flow): detail → Corrección de Conteo → − / + / typed → impact line → Guardar.

7. **"Sin cambios" button** (Conteo inicial only, once stock loads): saves count = stock (step 2) and closes;
   in the scanner it returns to scanning with the strip "12, sin cambios".
   Smoke: scanner Contar in a session → Sin cambios → next item; "Productos contados" +1.

8. **Lots section** (Conteo inicial only): "Lotes y caducidad" rows (quantity, `MonthYearPicker`, lote with the
   receiving's camera scan), "Agregar lote", swipe to delete; footer from step 4; Guardar blocked on a
   mismatch with the receiving forms' "what's missing" line. Built behind the API's "live" (see contract).
   Rows pre-fill from `GET /inventory/lots`; "Sin cambios" is disabled with `quickMatchBlocker`'s reason
   when edited lots don't add up to the stock.
   Smoke: count 10, lots 4 ene-2027 + 6 mar-2027 → saved; 4 + 3 → blocked with "faltan 3"; Alertas shows the lots.

8a. **Count split over lots** (`CountLots.split`, rules in `LotSplit`; the view only forwards user events): a changed count, "Agregar lote", "Escanear caja" or a
   deleted lot spreads the count over the rows (1 lot = all, N lots = even, remainder first); each lot row
   has a ± stepper. A lot typed or stepped by hand is kept; the others share the rest of the count. The form loading the stock and "Sin cambios" don't re-split, so pre-filled lots stay untouched.
   Smoke: count 10 → Agregar lote → 10; Agregar lote → 5 + 5; + on one → 6 + 5; Agregar lote → 6 + 2 + 2 (edited lot kept).

8b. **Workflow review fixes** (2026-11-05, on `feature/count-lot-split`):
   - A lot at 0 units is ignored; lots over the count say "sobran N" before asking for a caducidad (`CountLots.check`).
   - An added lot takes its share of the count, so it needs its caducidad; deleting it gives the share back.
   - Razón/Notas are sent with the entry (API: farmacia-ops `feature/stock-count-notes`, ≤500 chars).
   - Entries, start, end and "Poner en 0" send `locationId` (the store shown, not the session's).
   - Lots are read once per store and Conteo inicial (`CountLotsLoad`), so a store switch never shows stale lots.
   - The form's reads run in parallel once the count is known; reloads go through `.task(id:)` (`reloadID`), so a stale one is cancelled.
   - Ajustes: no alert on background reload failures; a store switch clears the previous store's count. "No contados": a failed first load shows Reintentar.

9. **Docs:** README (Conteo inicial bullet), this epic's status; `graphify update .`.

## 📋 Follow-ups (2026-11-05)

- **Release order:** farmacia-ops `feature/stock-count-notes` to production before this branch ships; until then Razón/Notas are ignored.
- ✅ **End-to-end check:** a "Sin cambios" count with Razón against the local API showed the Razón under "Ya contado" when the form was reopened (2026-11-05, simulator).
- **Device check:** clear the count and type a single digit (the simulator tool couldn't clear the centered field); lots should re-split.
- ✅ **Released 2026-11-05:** `main` `4fed1a9` (Release build, production API) installed on the iPhone 15 Pro and the iPhone 13 Pro.
- **iPad:** the lots release was never installed on the iPad (`95bd06a`); this branch isn't either. The iPad (A16) is paired; install after review and once the API is deployed (`scripts/release-build-install.sh` picks an iPhone; pass `DEVICE_UDID`).
- ✅ **Pre-filled lots keep their quantities** (`LotSplit(prefilled:stock:)`); only a single lot that is the whole stock follows the count. Lots the counter adds share the rest.
- ✅ **Hint on a lot with a caducidad or lote but no units:** "Sin cantidad: este lote no se guardará" (`CountLot.ignoredHint`).
- ✅ **Notes on a matching count** show under "Ya contado" (`CountedEntry.remarks`; API GET entries returns reason/notes on `feature/stock-count-notes`).
- ✅ **Razón/Notas cap (500 characters, from the review nit):** Guardar and Sin cambios are blocked, with a hint under Notas (`CountNotes.problem`).
- ✅ **50-lot cap** (API 400 past it): Guardar blocked past 50, and Agregar lote / Escanear caja disabled at 50 (`CountLots.maxLots`).
- **Untested view rules:** Ajustes' clear-on-store-switch and "No contados" Reintentar are small and stay in the views; move them into FarmaciaKit if they grow.

## ✅ Lot camera: caducidad alone is accepted (2026-11-06, `feature/lot-scan-expiry-only`)

When the scan reads a caducidad but no lote, it no longer waits for Usar. ~~First after a 1 s grace~~; since 2026-11-06 (user: "some read it for a split second and get lost") it fills the caducidad and closes as soon as one is read, with the lote if read in the same moment. A lote alone still waits for Usar. Applies to receiving and Conteo inicial.

## ✅ Lot camera: header labels, dot-matrix (2026-11-06, `feature/lot-scan-header-labels`)

From 8 photos of boxes the scanner struggled with (IMG_5659–5666, as tests in `LotScanPhotoTests`): "Lote:" and "Caducidad:" printed in a header, values inkjet-printed elsewhere, so neither was beside its label.
- Lote with no value beside a label (labels in a header, or no labels at all — the "Lote" requirement was dropped 2026-11-06 at the user's request): the first lot-looking number (5–20 characters, at least 3 digits, not an amount like 700MG) before the caducidad on its line, else on one of the two lines above (`LotNumber.unlabeled`).
- Text blocks are read in page order, rows top to bottom and left to right (`ReadingOrder`, from VisionKit's bounds).
- Spaced dot-matrix joined ("2 5 0 1 0 1 7 8" → 25010178, "E N E 2 7" → ENE27); months read with a zero ("0CT", "AG0", "N0V"); a lote glued to the month ("254875AG0 27"); prices are never dates ("$10.30").
- Not a lote: the sanitary registration ("Reg. No. 123M2015 SSA", its line skipped) and barcode digits (12–14 digits). A lote glued to the month is split off only before a spaced 2-digit year, so a lote code with a month inside ("A23DIC45") isn't read as a date (review, dev-ee).
- ~~A guessed lote waits like a caducidad alone~~: superseded, a caducidad now closes the scanner right away; the guessed lote is shown in the form to check.
- Barcode digits and the registration number are rejected on the labeled path too ("Lote:" with the GTIN on the next line).
- ✅ A lote printed before the keyword on the same line ("B24017 CAD 08/2027") is read (review nit).
- With instant accept (review, dev-ee): a price line's number is never a date, even without "$" ("PRECIO MAX 12.50", "P.M.P. 12.50"); a date with no keyword more than 6 years away is ignored ("12.50" isn't Dec 2050); postal codes, phone numbers and the maker's "S.A. de C.V." line aren't lotes.
- Real Vision OCR of the photos (run on the Mac, 2026-11-07; `LotScanVisionOutputTests`): AGO is read "A60 27" (now AGO when spaced from its year, never on a lote line) and "A6028" (left unread: it can't be told from a lote code like "A6029", review dev-79); a price read "< 10.00" was a second loose date (loose dates now within 6 years either way). IMG_5663 reads only at full resolution (closer helps). Not readable by Vision at all, even full resolution and blurred: IMG_5665's AGO, IMG_5669 (widely spaced dot-matrix: SAL/FLL/NAL/CAD block), and the embossed IMG_3410's "MAR" (read "AR", "M"/"R"); type those in.
- Device check: scan each of the 8 boxes and confirm Lote and Vence.

## Migration (migrate-as-touched)

- The session-match validity in `AdjustmentFormView` → `CountSave.canSave` (step 1).

## Not now

- Lots on a Corrección de Conteo outside a Conteo inicial (the decision limits lots to Conteo inicial).
- Editing a product's lots without counting it.
- Lots in "Poner en 0" (zeroed stock has none).
