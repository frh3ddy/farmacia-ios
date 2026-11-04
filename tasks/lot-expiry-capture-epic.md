# Epic: lot and expiry capture (Recibir inventario)

**Status:** ✅ steps 1–7 and 9–13 done ("feat: lot and expiry capture in Recibir inventario"; also fixed after device testing: scanner opened from the form level, Spanish month names and expiry dates). Step 8 was dropped: there is no "Tiene caducidad" switch; Vence starts empty, and empty means no expiry, so the form never saves a default month the user didn't pick. Checked in the simulator: aspirin (latest receiving without expiry) shows the section at the bottom; Abatelenguas (with expiry) shows it on top; a saved receiving stored 2027-11-01. **Still to check on the iPhone:** the scanner, with real boxes.

Branch: `feature/lot-expiry-capture`

## Goal

- Read the lot number and the expiry date from the box with the camera.
- Show the expiry near the top of the form, already on, for products that have expiry dates.
- Pick the expiry by month and year only, with no day calendar.

## Decisions

- **Which products show the expiry near the top:** decided by the product's own history, not by a category or a medication flag (some categories are wrong, and some non-medications expire too).
  - If the latest receiving of the product had an expiry, or the product has never been received, "Lote y caducidad" sits right after Cantidad and "Tiene caducidad" starts on.
  - If the latest receiving had no expiry, the section stays at the bottom and the switch starts off.
  - Either way the user can turn it off.
- **Saved day:** month/year is saved as the **first day** of that month. This gives the store time to sell the lot at a discount before it really expires. Any expiry alerts count from that day. A full date read from the label (15/03/2027) is also saved as the 1st, to match the picker.
- **Required?** No. It starts on and can be skipped.
- **Capture:** a live scan (VisionKit `DataScannerViewController`) reads text and a GS1 DataMatrix together. Once it has both a lot and an expiry, it fills them in and closes; the user checks them in the form. If the box has a DataMatrix, it wins over the text.
- **API:** no change. The form loads the latest receiving from `GET /inventory/receive/product/:productId`, which allows the same roles as `POST /inventory/receive` (OWNER, MANAGER).

## Logic (FarmaciaKit, Swift Testing)

1. **`MonthYear` value** (year, month): built from a `Date`, gives its first day as a `Date` in the given time zone, and displays as "mar 2027".
   - First test: *given March 2027, should save 2027-03-01* (`LocalDay.string(from: firstDay)`).
   - Also: *given a lot's expiry date, should read back the same month* (for editing).
2. **Read an expiry from label text:** `MonthYear.parse(_ line:)`.
   - First test: *given "CAD 03/2027", should read March 2027*.
   - Arguments: `CAD. 03-27`, `EXP 2027/03`, `VENCE MAR 2027`, `CAD ENE 28`, `EXP: MAR-2027`, `CAD: 15/03/2027` → March, `Caducidad 3/2027`.
   - Spanish and English month abbreviations; two-digit years read as 20YY.
3. **Skip manufacturing dates:**
   - *Given "FAB 01/2025" and "CAD 01/2028", should read January 2028.*
   - *Given a date with no keyword, should read it only when it's the only date on the box and it's in the future.*
4. **Read the lot:** `LotNumber.parse(lines:)`.
   - First test: *given "LOTE: A23B45", should read A23B45*.
   - Arguments: `LOT A23B45`, `L. 2304567`, `LT:XK12`, `Lote 23-0456`.
   - *Given "LOTE" on one line and "A23B45" on the next, should read A23B45.*
   - *Given "LOTE: A23B45 CAD 03/27", should stop the lot before CAD.*
5. **GS1 DataMatrix:**
   - First test: *given `0107501234567890` `172703`+`31` `10` `23A45` with GS separators, should read lot 23A45 and expiry March 2027*.
   - Also: *given the printed form "(17)270331(10)23A45", should read the same*, and *given day 00 in AI 17, should still read the month*.
6. **`LotScan` result:** combines the text lines and barcodes the camera sees into a lot, an expiry, and `isComplete`.
   - First test: *given a DataMatrix and text that disagree, should use the DataMatrix*.
   - Also: *given only a lot, should not be complete*.
7. **Where the expiry goes:** `ExpiryPlacement.for(latestReceivingExpiry:)` returns `.prominent` or `.optional`.
   - First test: *given a product never received, should be prominent*.
   - Also: *given a latest receiving without an expiry, should be optional*, and *given one with an expiry, should be prominent*.
8. **Unsaved-changes baseline:** *given a form that turned "Tiene caducidad" on by itself, should have no changes* (`ReceivingDraft`). The form updates its baseline after it auto-sets, the same way it does for the preferred supplier.
9. **Past-month hint:** *given an expiry month that started on or before today, should warn "Ya vencido: se guarda el 1.º de mes"* (caution tone; doesn't block saving). Built on `Expiry.daysUntil` of the first day.

## UI (FarmaciaApp)

10. **`MonthYearPicker`** (DesignSystem, new file, register it in pbxproj).
    - A Form row "Vence · mar 2027". Tapping it opens two wheels in place (month, year from last year to +10).
    - Shows the step 9 hint under it.
    - Check it in the preview and in the simulator.
11. **Recibir inventario**:
    - Replace the `DatePicker` with `MonthYearPicker`.
    - Load the latest receiving for `ExpiryPlacement`. While loading, show the prominent layout so only no-expiry products ever move (to the bottom).
    - Prominent layout: section "Lote y caducidad" after Cantidad, switch on.
    - Critical flow to smoke: **receive inventory**. Run it for a product with earlier expiry lots and for one without, then save, and check that the lot's expiry is the 1st of the picked month.
12. **Lot scanner** (`LotScannerView`, a `DataScannerViewController` bridge, new file in pbxproj):
    - Reads text plus `.dataMatrix` and feeds `LotScan`.
    - When it's complete: success haptic, fill Lote and Vence, close.
    - While it's partial: show what it found so far, with a "Usar" button.
    - Opened by a camera button inside the Lote row (the rule that actions live in the control they affect). The button is hidden when `DataScannerViewController.isSupported` is false.
    - The simulator has no camera, so check it **on the iPhone** with real boxes: one medication with a DataMatrix if we have one, and one with printed "LOTE / CAD" only.
13. **Docs:** README (Receiving section) and this epic's status. Then `graphify update .`.

## Migration

Nothing moves out of the app. `ReceivingDraft` and `Expiry` are already in FarmaciaKit. All new parsing and decision logic (steps 1–9) goes in the kit. Only the picker and the camera bridge are app-side.

## Not now

- Requiring two matching frames before auto-fill (to guard against a misread). Add it if wrong lots show up in practice; the user checks the fields anyway.
- Lot/expiry on Nuevo producto's initial inventory (it has none today).
- Showing month-only lots as "mar 2027" in product details. They'll read "1 mar 2027" until then.
