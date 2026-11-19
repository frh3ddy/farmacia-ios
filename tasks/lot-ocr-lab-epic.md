# Epic: faster, surer lot and expiry reading (lot OCR lab)

**Status:** steps 1–5 (logic) ✅ 23f1453 + the confusable-letters fix (dev-f8's review), 976 tests pass. Next: step 6 (lab reader on the iPhone). Branch `feature/lot-ocr-lab`.

## Why

The lot scanner (`LotScannerView`, VisionKit's `DataScannerViewController`) gives one transcript
per text item, with no image filters and no second tries. Hard labels it misses (photos
IMG_5793–5797, 2026-11-19):
- Blind-embossed digits on a white box (no ink, only relief): "5133022884 / MAY 27".
- Dot-matrix inkjet on round bottle caps, tilted ~25°: "LOTE: D26U908 / CAD: JUL 28".
- Transparent bottles (no photos yet).

## Mac findings (Vision `VNRecognizeTextRequest`, accurate, no language correction, label crop)

| Photo | Truth | What came back |
|---|---|---|
| 5794 embossed | 5133022884 · MAY 27 | lot `513302288` in most variants; date `MAY 27` in 5 of 12, else `KAY/HAY/M4Y 27` |
| 5797 red cap | D26U908 · JUL 28 | lot `D26U908` and `026U908`; month only `IUL/IL/11 28` |
| 5796 blue cap | E25U?24 · JUL 27 | lot `E25V824`, `E2SU82…`; the date is smudged in the print |
| 5793 upside down | as 5794 | almost nothing |

- No single filter wins: plain, max-component (black ink on a coloured cap), dot-join
  (`CIMorphologyMinimum` r2–4), relief (unsharp + contrast) each read different fields.
  Together every field but the smudged date came back right at least once.
- Most misses are one wrong character in a field whose shape we know.
- Each pass is 50–150 ms on the Mac on a label crop, so the camera can cycle filters.

## Plan

### Logic (FarmaciaKit, Swift Testing)

1. **Month one-character misreads.** `ExpiryText` reads a 3-character month token before a
   2-digit year when exactly one month name is one substitution away.
   - First test: *given "KAY 27", "HAY 27", "M4Y 27" or "IUL 28", should read May 2027 / July 2028*.
   - *Given "JUI 27" (JUL or JUN), should read nothing.*
   - Only OCR-confusable letters count (review dev-f8): M↔K/H/N, A↔4, J↔I/1/L, O↔0, S↔5, B↔8.
     *Given "1 AL DIA 30 TABLETAS", "PAR 27", "NOS 27", "ABS 27" or "ONE 28", should read nothing.*
2. **The new photos as fixtures** (`LotScanPhotoTests`): IMG_5794's lines
   `["Lote:", "Caducidad:", …, "513302288", "HAY 27", "$ 161, 25"]` → lot `513302288`, May 2027;
   IMG_5797's `["LOTE: D26U908", "CAD:", "IUL 28", "PRECIO:$ 52.63"]` → D26U908, July 2028.
3. **`LotVote`: what the passes add up to.** Ingests one `LotScan` per pass.
   - **The date comes first (user, 2026-11-19):** it's taken from the first pass that reads
     one, and the scanner closes then, with whatever lote it has. The lote is optional.
     `votesNeeded` (default 1) is a setting so the bench data can raise it to 2 if misread
     dates show up; decide from the metrics in step 7 (`edited` plus the after-close reads).
   - **Plausible dates only (review 2):** a past date, or one over 6 years out, never closes
     the scanner, even after "CAD" (a smudged "JUL ?7" read as JUL 17). A product that's
     really expired gets its month picked by hand (the form warns "Ya vencido").
   - Tests: *given a date read once, should take it right away*; *given 2 reads needed,
     should wait for the second matching read*; *given CAD JUL 17 or JUL 37, should not take
     it*; *given 0 reads needed, should still need 1*; *given lots D26U908 ×2 and 026U908 ×1,
     should pick D26U908*; ties go to the longer read.
   - Known limit (review): a digit the reader misses every time (5794's last `4`, at the
     edge of the white box) wins the lote vote. The form shows the lote to check, and
     `edited` measures it.
4. **`LotFilter` cycle:** which filter frame *n* uses (plain, max-component, dot-join,
   relief). First test: *given frames 0–4, should cycle plain, max-component, dot-join, relief, plain*.
   - **Order matters (review 3):** the scanner closes on the first date, often in pass 1 or 2,
     so the later filters may never run. Reorder by `lot-bench`'s date read rate per filter
     (step 9) once frame-size photos are in; plain read the date in only 1 of 4 photos.
5. **`LotScanMetrics`** row + CSV, like `ScanMetrics`: date, device, reader (live text /
   lab), ms to expiry, ms to lot, passes, winning filter, lot, expiry, and whether the user
   changed either before saving (the misread count).
   - First test: *given a row, should write the CSV line with the header's columns*.
   - Definitions (review 6): `filter` is the filter of the pass that read the date (the app
     records it; `LotVote` doesn't track filters). `msToLot` is when the final lote was
     first read. Step 7 adds `same_date_reads` and `other_date_reads`.

### App

6. **Lab reader:** a camera controller for text, with the barcode scanner's camera setup
   (scan box, close focus, startup zoom, torch). Frames → crop to the box → the frame's
   filter → `VNRecognizeTextRequest` → `ReadingOrder.lines` → `LotScan` → `LotVote`.
   On the iPhone: check frame rate and time per pass.
   - **Sharing the camera (review 5):** `CameraController` is built around the barcode
     detector and `ResultAggregator`, and it's in the store version. Pull the device, focus,
     zoom and torch setup into a shared piece and pass the frame handler in; then re-run a
     short barcode check on the iPhone (a few boxes, the torch) before committing.
   - **Resolution (review 4):** the Mac numbers came from 12 MP crops (1,000–1,600 px across
     the label); 1080p puts maybe 300–500 px there. Try 1080p and 4K, and check the startup
     zoom: it's sized for a 30–40 mm barcode, not 2 mm characters.
7. **Debug lab** (DEBUG only): Ajustes › Escáner gets a "Lector de lote" switch (live text vs
   lab), the metrics list and CSV export. The receive form records whether the scanned
   values were edited before saving. Release keeps live text until the bench says otherwise.
   - **Data for 1 read or 2 (review 1):** with 1 read the scanner closes on the first date,
     so there's never a second read to compare. In DEBUG the lab reader keeps reading ~1 s
     after it fills the form (the close isn't delayed) and logs `same_date_reads` and
     `other_date_reads`. With `edited`, that shows how many misreads 2 reads would have
     stopped and how much later a right date would have come.
   - How the form finds the row for `edited`: the scan hands back its row id with the values.
8. **Hints:** "Gira la caja" after N passes with no text; "Inclina la caja hacia la luz" for
   embossed boxes (the torch flattens relief). No auto torch.
9. **`lot-bench`** (Mac CLI, FarmaciaScan): runs a photo folder through each filter with the
   expected lot and expiry in a sidecar; prints the read rate per filter.
   - Also runs each photo shrunk to 1080p and 4K frame size (review 4), since the camera
     never sees the full 12 MP.

### Docs

10. README, LEGAL_REVIEW.md (text OCR on a fixed crop: no zoom into what it finds, focus
    never reacts to a reading; stays clear of 11244147 and 11087105), this epic.
    `graphify update .`.

## Open

- Photos of transparent bottles (the background shows through; a finger or white card
  behind the print may be the only fix).
- Upside-down boxes: trying both orientations doubles the cost; a hint may be enough.
