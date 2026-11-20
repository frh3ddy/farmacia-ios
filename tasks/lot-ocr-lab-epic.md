# Epic: faster, surer lot and expiry reading (lot OCR lab)

**Status:**
- Steps 1–5 (logic) ✅ on main: 23f1453 + 2358e81, merged as 5a82f79.
- Steps 6–7, the automatic test, bench 1 and its fixes ✅ on main: merged as 1c56c0f.
  - `LotReading`: accept + 1 s follow-up + metrics row; tested.
  - `LotTextReader` (FarmaciaScan): crop, filter, upright, Vision text; tested on rendered labels,
    including both 90° turns.
  - `CameraController` split into the shared camera + `BarcodeFrameHandler` (barcode logic moved
    as is) + `LotFrameHandler`.
  - The DEBUG switch and metrics in Ajustes › Escáner › Lector de lote; Recibir's save marks
    `edited` (`LotScanMetrics.recordSave`, `LotScanLog`; tested).
  - Review dev-f8 (fixed in 230a3db): the follow-up runs only after a read (a give-up stops at
    once; `LotReading.stop()` keeps late frames from turning it into a read); `LotScanLog`
    forgets the fill on a give-up or a form closed unsaved.
- Automatic lot test (user, 2026-11-19): `BenchPlan.lotStandard` (Apple's live text, then the lab
  at 1080p and 4K) drives `LotLab` like the barcode bench: N openings per mode, switching by
  itself with an alert and a badge. Ajustes › Escáner › Prueba automática de lote. The CSV gains
  `setup` (e.g. wide-hd4K). Both labs share the tested `BenchPlan.recordOpening`; the lot
  scanner counts an opening when it closes, not when the row arrives 1 s later.
- **Lab reader in the store version** (branch `feature/lot-lab-release`, user 2026-11-20): Release
  reads lots with the lab at 1080p and the square box, without the DEBUG data (no follow-up,
  no metrics). Its two gaps closed first:
  - A lote with no date: `LotReading` offers it (`.offerLot`) after 3 s without a date, again
    if another lote takes the lead; "Usar lote …" shows under the torch (tested).
  - GS1 DataMatrix: `LotTextReader.codes` finds codes in the scan box each pass and `LotScan`
    takes their exact lote and date (tested with a QR, since Core Image draws no DataMatrix).
  - Live text stays as the DEBUG baseline. Gaps left: only Recibir marks `edited` (DEBUG); in
    the DEBUG CSV a lote taken with "Usar lote" looks like a give-up that read a lote (lote, no
    date): add a column if the bench needs to count them.
  - /tdd-review (dev-f8): tests added that no lote is offered after a date or a stop, and that
    `codes()` ignores code types it wasn't asked for (each one red on a deliberate break).
    The Release wiring has no logic to pull out: followUp 0 is `LotReading` (tested), and the
    tap passes on the lote `LotReading` offered.
- **Bench 1 (iPhone 13 Pro, 2026-11-20, 20 products per mode):** dates read Apple 11/20
  (5/10 on the first 10 in order), lab 1080p 18/20, lab 4K 18/20 (same 18 dates); median time
  to the date 6.9 s / 1.5 s / 1.5 s. Lotes: the two lab rounds agree on 5 of 12. A different
  date in the 1 s follow-up 3 times in 49, and the other round confirmed the accepted one, so
  `votesNeeded` stays 1. 1080p = 4K, so 1080p. `edited` empty (nothing saved via Recibir).
- **Misses fixed in the parser** (photos IMG_5837–5839, Mac Vision reads them): "CADO228" (MMYY
  glued to CAD, 0 as O); "FEB 2031" with a 4-digit year read as PEB/FED (F←P, B←D added).
  IMG_5838 only reads with a tight crop on the CAD line (the dots are far apart); IMG_5839
  (embossed, clear bottle) and IMG_5845 (blind embossing under a big printed "C/10") stay
  unread: the user types them.
- **Slow reads** (IMG_5836, 5840–5844, 5846; mostly blind embossing): NOV as NOU and SEP as SEB
  added (V←U, P←B). Spaced years ("ENE 2 8") already read. The same box reads with light from
  the side (5841: 260085 ENE 28) and not under flat light (5842), so step 8's "Inclina la caja
  hacia la luz" hint is the lever for embossing; 5840 and 5844 barely read even at 12 MP.
- **Two more filters** (Mac test of 16 colour/contrast filters on the embossed photos):
  `darkened` (gray, gamma 3) read IMG_5846 whole and 5841/5843's dates; `deepRelief` (unsharp
  r25 ×6, contrast 3) read 5844's NOV 27, which nothing else did. Grayscale alone, single
  channels, black/white thresholds, edge maps and high-pass added nothing. The cycle is now 6
  filters (each one every ~0.6 s at 10 passes/s). The Vision tests run serialized (in
  parallel they deadlocked on Vision's queue).
- **Review follow-ups (/tdd-review of f6936c9):** the keyword+MMYY rule also takes the spaced
  form ("CAD 0228", "CAD: O228", "EXP. 1229") and has tests for every keyword and non-MMYY
  tails; 20xx years have the words-stay-words tests. Three small real crops in
  `FarmaciaScanTests/Photos` test the filters through the app's reader: deep relief reads
  IMG_5844's NOV 27 (as NOY, so V←Y added); darkened reads IMG_5846's lote right at ~4K size
  (plain reads 26010513); 5843's SEB 27 reads as September. At 1080p size darkened wins no
  date on its own: watch its share in the next bench.
- **Lab by default, square box (user, 2026-11-20):** the DEBUG switch wasn't kept, so every
  launch went back to live text (no box, no torch). The lab is now the DEBUG default (bench 1),
  at 1080p, with a square box 70% of the preview's width (`ScanSettings.squareBox`, tested).
- **Month and year apart:** wide embossing at frame size reads "ENE" and "28" (or "2 8") as two
  lines (IMG_5846, 3 filters); a lone month-like word followed by a lone year is joined
  before parsing. Words still need to be a month or one misread away ("ONE" / "28" stays unread).
- Next: a Release build on the iPhone (real boxes, a DataMatrix box, a lote-only box), review, push.

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
