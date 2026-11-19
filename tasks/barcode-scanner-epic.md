# Epic: High-accuracy barcode scanner (AVFoundation + Vision)

Branches:
- **Step 0:** `fix/scan-no-qr` (from `main`, ships first, on its own)
- **Steps 1–16:** `feature/vision-barcode-scanner` (from `main`, after step 0 lands)

## Problem

Scanning at the counter misreads or picks the wrong code. When a product barcode sits
next to a QR code, the scanner usually reads the QR first. All scanners use twostraws
`CodeScanner` (AVCaptureMetadataOutput), and it gives no control over the camera
device, zoom, focus range, region of interest, validation or multi-frame confirmation.

## Decisions (asked 2026-11-18)

- **QR off now**, in its own small fix (step 0), before the rebuild.
- **Symbologies:** EAN-13, EAN-8, UPC-E, Code 128 only. Code 39, Code 93 and ITF-14 are
  dropped. They stay configurable in `ScanSettings.symbologies` so they can come back.
  **Revised 2026-11-19:** Code 39 is back on by default (the user confirmed). Store labels
  like `124111SP` are Code 39 and only the old scanner read them (56d3f5e).
- **Debug/benchmark screen:** DEBUG builds only, under Ajustes. Device benchmarks use a
  Debug build pointed at the local API (never prod).
- **Simple mode = the old `CodeScanner`**, behind a DEBUG toggle, kept as the benchmark
  baseline. No VisionKit `DataScannerViewController` mode. CodeScanner is removed once
  the new scanner beats it (its own follow-up).
- **Stages:** steps 1–16 (brief steps 1–7, plus metrics and the harness), then **stop and
  show benchmark results**, then stage 2 (brief steps 8–13), re-planned from the data.

## What the code does today

- `CodeScannerView(codeTypes:scanMode: .once, showViewfinder: true, simulatedData:, shouldVibrateOnSuccess: true)`
  appears in three places:
  - `ScanFlowSheet.swift:133` (Escanear: Consultar/Recibir/Contar): `[.ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .qr]`
  - `ProductSearchPicker.swift:117` (Sueltos and Transferencias pickers): same list, **with `.qr`**
  - `CreateProductView.swift:451` (Nuevo producto barcode field): same list, without `.qr`
  - `SueltosView.swift:3` imports CodeScanner but doesn't use it (remove the import in step 14).
- QR came in with the scan flow sheet (baf0d64) and was copied to the picker (e833b48).
  Nothing depends on it: no QR payload is parsed anywhere.
- FarmaciaKit already has `BarcodeLookup.codeVariants` (GTIN zero-padding for lookups)
  and `BarcodeLookup.newProductBarcode` (14-digit read → 13 digits on the box). Reuse
  them; the new scanner returns the same strings CodeScanner returns today.
- There is no GS1 check-digit validation anywhere (`GS1Code` parses AIs only).
- `ScanFlowSheet.simulatedCode` (the `simScanCode` default) is how the simulator "scans".
  The new view keeps it.
- `LotScannerView` (DataScanner for DataMatrix + text) is out of scope and unchanged.

## Package layout

- **`FarmaciaKit`** (Foundation only, unchanged rule): validation, normalization,
  `ScanSettings`, `ResultAggregator`, zoom math, ROI math, `ScanMetrics` + CSV,
  `BenchReport`. Plain values only, with an injected clock (`now: Date`).
- **New target `FarmaciaScan`** in the same package: imports Vision, CoreImage,
  CoreVideo and ImageIO, all of which exist on macOS, so `swift test` still runs on the
  host. It holds the `BarcodeDetector` protocol and `VisionBarcodeDetector`. The app and
  the bench share the same detector code.
- **New executable `scan-bench`** (same package): `swift run scan-bench <folder>`.
- **App (`FarmaciaApp/Features/Scanner/`)**: `CameraController`, `ScannerViewController`,
  `BarcodeScannerView` (SwiftUI wrapper with overlay) and `ScannerDebugView`. Each new
  .swift file goes into `project.pbxproj` by hand. The app links the `FarmaciaScan` product.

## Legal posture (stage 1)

None of steps 1–16 uses the three flagged methods. `LEGAL_REVIEW.md` records why:
- The zoom is set **once at startup** from `minimumFocusDistance`, as in Apple's
  AVCamBarcode sample. It never changes in response to a detection (US 11244147 family).
- Focus and exposure run in continuous auto with a fixed point of interest at the box
  center. There is no loop that detects a code at a focal position (US 11087105 family).
- Decoding is Vision's. We do no scanline work of our own (US 11893764 family).
- Multi-frame voting and GS1 mod-10 are long-established, generic techniques.

---

## Step 0: QR off now (`fix/scan-no-qr`)

0. ✅ (uncommitted) **Remove `.qr` from `ScanFlowSheet.swift:134` and `ProductSearchPicker.swift:118`.**
   This is a two-token config change with no logic, so no test.
   - Build. On a device, hold an EAN next to a QR (any medicine box with both): it reads
     the EAN. Simulator smoke isn't meaningful (simulated data skips the camera).
   - README: note in Escanear that QR codes are ignored.

---

## Stage 1: core scanner (`feature/vision-barcode-scanner`)

### Logic (FarmaciaKit, red/green)

1. ✅ (uncommitted; the target and executable moved to step 12, with the detector's real test) **Scaffolding.** Add the `FarmaciaScan` target, the `scan-bench` executable,
   `THIRD_PARTY_NOTICES` (CodeScanner MIT, SwiftyCrop, plus later additions) and
   `LEGAL_REVIEW.md` (the posture above, plus a "stage 2 to review" list).
   - First test (FarmaciaScanTests): *given the package builds, `VisionBarcodeDetector`
     type exists*. A placeholder that goes red→green once the target is wired.

2. ✅ (uncommitted) **GS1 mod-10 check digit** (`GTINCheck.isValid(_:)`).
   - *given `4006381333931`, should be valid* (EAN-13)
   - *given `4006381333932`, should be invalid*
   - *given `96385074`, should be valid* (EAN-8)
   - *given a 12-digit UPC-A `036000291452`, should be valid*
   - *given non-digits or a wrong length, should be invalid*

3. ✅ (uncommitted) **UPC-E: expand to UPC-A for validation** (`UPCE.expanded(_:)`).
   - *given UPC-E `04252614`, should expand to `042100005264` and be valid*
   - *given a UPC-E with a bad check digit, should be invalid*
   - The scanner still reports the 8 digits, as CodeScanner does today.

4. ✅ (uncommitted) **Per-symbology validation and normalization** (`BarcodeRead.validated(symbology:payload:enabled:)`, named so to avoid `ProductSearchPicker`'s private `ScannedCode`). It returns the value or a rejection reason. A 12-digit `.ean13` (an unpadded UPC-A) yields 0 + 12.
   - *given EAN-13 from a 14-digit read `04006381333931`, should yield `4006381333931`*
     (reuses `BarcodeLookup.newProductBarcode`)
   - *given EAN-13 `0036000291452` (a UPC-A), should yield it unchanged*. It's the
     13-digit form products are saved under, and `codeVariants` already finds the
     12-digit form.
   - *given Code 128 with a non-printable character or an empty payload, should reject*
   - *given a symbology not in settings, should reject*

5. ✅ (uncommitted) **`ScanSettings`** (one struct for every threshold, with defaults from the brief).
   - *given defaults, should list exactly ean13/ean8/upce/code128*
   - *given `votesRequired` 5, should clamp to 3; given 1, should clamp to 2*
   - Fields: `symbologies`, `minConfidence` 0.6 (0.7 after the device bench), `votesRequired` 2, `voteWindow` 10,
     `cooldown` 1.5 s, `scanBox` (0.8 × 0.3), `targetCodeWidthMM` 35, `camera`
     (`.wide | .dualWide | .triple`), `preset` (`.hd1080 | .hd4K`), `fps` 30.

6. ✅ (uncommitted) **`ResultAggregator` multi-frame voting** (`ingest(_: [BarcodeCandidate], now:) -> String?`).
   - *given one frame reading X, should not accept*
   - *given X in 2 frames inside the last 10, should accept X*
   - *given X twice but 11 frames apart, should not accept*
   - *given X below `minConfidence`, should not count the vote*
   - *given an invalid check digit, should not count it and should add one misread*
   - *given X and Y reaching the vote count in the same frame, should accept the one read with higher confidence*. A code is accepted the moment it reaches N, so a tie is the only way two codes get there together.

7. ✅ (uncommitted) **Cooldown and de-duplication.**
   - *given X just accepted, X again 1.0 s later, should not accept*
   - *given X accepted, X again 1.6 s later, should accept*
   - *given X accepted, Y 0.2 s later, should accept Y* (cooldown is per code)

8. ✅ (uncommitted) **Startup zoom from minimum focus distance** (`StartupZoom.factor(minFocusMM:fovDegrees:codeWidthMM:boxWidthFraction:maxZoom:)`, the AVCamBarcode approach but with the correct `2·d·tan(fov/2)` geometry). The caller passes the FOV along the code's axis, which in portrait is the sensor's short side.
   - *given a lens that focuses close enough for a 35 mm code to fill the box, should be 1.0*
   - *given min focus 200 mm and a FOV whose fill distance is 100 mm, should be 2.0*
   - *given a needed zoom above `maxZoom`, should clamp to `maxZoom`*

9. ✅ (uncommitted) **ROI conversion** (`ScanROI.visionRect(fromMetadataRect:)`).
   `metadataOutputRectConverted` returns a normalized rect with a top-left origin in
   sensor orientation. Vision wants a bottom-left origin.
   - *given metadata rect (x 0.35, y 0.1, w 0.3, h 0.8), should give Vision rect (x 0.35, y 0.1, w 0.3, h 0.8) with y flipped as `1 − y − h`*
   - *given a rect spilling outside 0…1, should clamp to the unit square*

10. ✅ (uncommitted) **`ScanMetrics` and CSV** (`ScanMetrics.csv(_:)`). The app keeps the list.
    - *given two scans, csv should have a header plus 2 rows: date, device model,
      detector, code, ms to first read, frames processed, misreads, settings tag*
    - *given a code containing a comma, should quote it*

11. ✅ (uncommitted) **`BenchReport`** (summary for the harness).
    - *given 9 of 10 images read correctly, should report a 90% read rate*
    - *given a read that differs from the expected code, should count an accepted misread, not a hit*
    - *given times 10/20/300 ms, should report a 20 ms median*
    - Ground truth comes from the filename: `{anything}_{expectedCode}.jpg`, and
      `_none.jpg` for photos with no code. No manifest file.

### Detector (FarmaciaScan, macOS-hosted tests)

12. ✅ (uncommitted) **`VisionBarcodeDetector`**: `VNDetectBarcodesRequest` at **revision 4**
    (iOS 17+). Inputs: a CVPixelBuffer or CGImage, the orientation, the ROI and
    `settings.symbologies`. Output: `[Candidate(symbology, payload, confidence)]`.
    - *given fixture `ean13_4006381333931.jpg`, should return that payload*
    - *given fixture `qr-and-ean_<code>.jpg`, should return only the EAN*
    - *given an ROI excluding the code, should return nothing*
    - Fixtures: synthetic EAN-13/EAN-8/UPC-A bars and a CIQRCodeGenerator QR, rendered in `SyntheticBarcode` (no committed photos). Vision returns a UPC-A as `.ean13` with all 13 digits.
    - Orientation: Vision gets the sensor buffer as `.up` (it reads barcodes at any rotation), so the ROI is the metadata rect with y flipped (step 9). No rotation mapping is needed.

13. ✅ (uncommitted) **`scan-bench` executable**: runs every image in a folder through each detector
    (stage 1: Vision only) and prints the `BenchReport` table per detector (read rate,
    median and mean ms, misreads). CSV output with `--csv`.
    - Covered by step 11's tests. Smoke: `swift run scan-bench Tests/FarmaciaScanTests/Fixtures`.

### UI / camera (app)

14. ✅ (uncommitted; device run pending) **`CameraController`** (AVFoundation, its own `sessionQueue`):
    - Device: `.builtInWideAngleCamera` back by default; `.builtInTripleCamera` or
      `.builtInDualWideCamera` from settings (macro auto-switch on Pro models), falling
      back to wide when the device has neither.
    - On configure: preset 1080p or 4K, 30 fps via `activeVideoMin/MaxFrameDuration`,
      `autoFocusRangeRestriction = .near` when supported, `isSmoothAutoFocusEnabled = false`,
      `.continuousAutoFocus` and `.continuousAutoExposure` with both points of interest at
      the box center, and `videoZoomFactor = StartupZoom.factor(…)` **once**.
    - `AVCaptureVideoDataOutput` with `alwaysDiscardsLateVideoFrames = true`. A separate
      serial `processingQueue` with a busy flag skips the frame if the last one is still
      running. Delegate callbacks never block.
    - Torch API exposed now (the button comes in stage 2).
    - Concurrency: the aggregator lives on `processingQueue`, and accepts hop to
      `@MainActor`. Review with `swift-concurrency-pro`.
    - Smoke: device only (the simulator has no camera).

15. ✅ (uncommitted; simulator smoke pending, needs the local API) **`BarcodeScannerView`** (UIViewControllerRepresentable around `ScannerViewController`):
    preview layer, scan-box overlay (80% × 30%, dimmed outside), ROI from
    `metadataOutputRectConverted` → `ScanROI`, haptic (`.sensoryFeedback(.success)`)
    plus a short system sound on accept. Its API mirrors today's call shape:
    `BarcodeScannerView(simulatedData:) { (Result<String, ScannerError>) in … }`,
    so each call site changes one block. It keeps `ScanFlowSheet.simulatedCode` in the
    simulator.
    - Swap all three call sites behind DEBUG `@AppStorage("useLegacyScanner")`. Release
      stays on CodeScanner until the benchmark passes. Remove the stray
      `import CodeScanner` from SueltosView.
    - Simulator smoke (critical flow, receiving): Escanear → Recibir with `simScanCode`
      set → the receive form opens → save → the strip shows. Repeat once with the legacy
      toggle on.

16. ✅ (uncommitted) **`ScannerDebugView`** (DEBUG, under Ajustes): every `ScanSettings` field as a
    control (camera, preset, votes, confidence, cooldown), the legacy toggle, the metrics
    list, and a `ShareLink` exporting the CSV. The scanner logs a `ScanMetrics` row per
    accept (device model from `utsname`).
    - Simulator smoke: open the screen and export the CSV (empty, header only).

**As built (14–16):**
- All three call sites (`ScanFlowSheet`, `ProductSearchPicker`, `CreateProductView`) use
  one wrapper, `ProductBarcodeScanner` (in `BarcodeScannerView.swift`), with
  `Result<String, Error>`. It shows the legacy CodeScanner or the new view, and it holds
  the only CodeScanner import and the only legacy symbology list. Legacy scans log metrics
  too (`detector: legacy`, time from opening), so the baseline comes from the same CSV.
- `ScannerLab` (@Observable, shared) holds the settings, the legacy flag (fixed `true` in
  Release) and the metrics list. Everything is in memory and resets on relaunch.
- New files: `CameraController.swift`, `BarcodeScannerView.swift`, `ScannerDebugView.swift`
  (Products/Views). The app links the `FarmaciaScan` product.
- `CameraController`: a virtual device's zoom never goes below its wide lens (its first
  switch-over factor). The startup zoom uses the short-side FOV, portrait only (ponytail
  note). `stop()` clears the output delegate so the controller is freed, and it sets a
  `stopped` flag (owned by sessionQueue). A start that lands later (permission granted
  after the scanner closed) doesn't turn the camera back on.
- Once configured, the camera hands its device to the preview on main
  (`onConfigured`). The preview builds its RotationCoordinator there and sets the ROI, so
  it never reads `session.inputs` on main and there's no retry loop.
- Simulator: the new view is a "Toca para enviar el código simulado" button that sends
  `simScanCode`.
- Skipped: the torch API (stage 2's step 10 adds it with its button).
- Builds: Debug simulator, Debug device and Release device (no signing) all succeed.

### ⏸ Benchmark checkpoint (stop here)

- Offline: `swift run scan-bench <your photos>`. You add shiny, curved, small and damaged
  products, named `…_<code>.jpg`.
- On device, Debug build against the local API: the same ~50 boxes scanned with legacy
  and with new (1080p wide, 1080p triple, 4K wide), then export the CSV.
- Report against the targets: ≥98–99% read rate, <1 s median time-to-read, 0 accepted
  misreads. Stage 2 gets re-planned from where it falls short.
- Docs: README Escanear section (how to run the bench and tune settings), and this epic
  marked ✅ with hashes.

**First device run (2026-11-19, iPhone 13 Pro, 64 scans):** 0 misreads in every mode.
Not usable for time or read rate: `ms_to_read` ran from the opening/previous accept (it
included picking up the next box; one row was 166 s for 125 frames), and give-ups left
no row. Photos of the misses, through raw Vision:
- `124111SP` is **Code 39** (0.999), off in the new scanner → Code 39 back on by default.
- `7503003406600` (small, blue bars): EAN-13 at 0.73 on the 12 MP photo; likely under
  the 0.6 cutoff at 1080p. Tune `minConfidence` from the new `top_confidence` column.
- `7500435138635` (crumpled bag): reads at 0.99 from the photo; device cause unknown.
- `7503005950017` (red bars): unreadable by anything. The printed check digit is wrong
  (`750300595001` → 9, label says 7), and red bars are invisible to red-light scanners.
  Needs manual entry/search (stage 2 step 13).

**Metrics fix (✅):** `ScanSettings` default + Code 39; `SightingClock`
(time from first sighting, any confidence; restarts after `voteWindow` empty frames;
best confidence); `ScanMetrics` code/msToRead optional + `msSinceOpen`,
`topConfidence`, `outcome` column, Codable; give-up rows (camera stop with no accept,
legacy `onDisappear` without a result); `BenchPlan` (standard 4 modes, `target` openings
each, `.next`/`.finished`) with the alert, the scanner badge and the debug section;
metrics + plan saved in UserDefaults (DEBUG). Simulator-checked: 5 cancels finished
the legacy mode and switched to wide 1080p with the alert. (56d3f5e)

**`scan-bench --list` (✅):** prints what each photo reads (and what was seen but not
accepted), ignoring filenames, for iPhone-named photos (`IMG_5756.HEIC` would otherwise
be scored as code `5756`).

**No-read photos (2026-11-19, `~/barcdoes/no reads`):** 0 of 5 read from the stills.
All have valid check digits, and 3 did read live in the first run (triple 4K, 1.8–28 s).
- `6928928377421` (clip in a crinkled bag), `7702018880409` (Gillette card): the photos
  are out of focus; retake them focused before using them as decoder fixtures.
- `8888021206074` (Energizer): torn card, the bottom of the bars and the digits missing.
  Stage 2 ZXing candidate; ⚠ damaged-code recovery sits near 11893764, so legal review first.
- `7503003406730` (bandage): curved roll, shiny wrap, small vertical bars → preprocess/ZXing.
- `7891317048815` (Melox): a glare streak across the bars → exposure bias. **Near-misread:**
  with every symbology on, Vision decoded it as `2056708016841` (valid check digit) at
  0.61, above the 0.6 cutoff. Only multi-frame voting stops that, so never set
  `votesRequired` to 1 (the 2–3 clamp in `ScanSettings.votesRequired` enforces it, so
  don't remove the clamp), and keep this photo as a misread regression fixture.
  Decided: `minConfidence` 0.7 (see the bench below), so this misread can't vote at all.

**Device bench (2026-11-19, iPhone 13 Pro, the same 20 products per mode, 0.6 cutoff):**
0 misreads in every mode, and every product read in every mode.

| Mode | Distinct read | Open → read (median) | Slowest | Lowest correct `top_confidence` |
|---|---|---|---|---|
| Legacy | 20/20 | 2.76 s | 6.7 s | – |
| Wide 1080p | 19/19 ¹ | 1.93 s | 6.1 s | 0.83 |
| Triple 1080p | 20/20 | 1.98 s | 6.0 s | 0.79 |
| Wide 4K | 20/20 ² | 1.76 s | 6.5 s | 0.76 |

From first sighting to accept takes a median of ~35 ms in every Vision mode, so most of the
open → read time is aiming. ¹ One box was read twice (it was already in view when the
scanner reopened), so one product was skipped. ² `7503003406600` failed once and was read
last (6.5 s); that failed opening left no give-up row, though closing the sheet logged one
elsewhere in the same run. Open: verify the give-up row on a closed sheet.
- **`minConfidence` 0.6 → 0.7 (✅):** the weakest correct read was 0.76 and the glare misread
  0.61. Test: *given the 0.61 misread in 2 frames before the right code at 0.76, should accept
  only the right code* (red at 0.6).

---

## Stage 2 (outline, re-plan after the benchmark)

| Brief step | First failing test | Notes / legal |
|---|---|---|
| 8 Preprocess retry (`PreprocessedVisionDetector`) | *given the low-contrast fixture that plain Vision misses, the contrast variant should read it* | Every Nth frame, 30 ms budget. ⚠ LEGAL_REVIEW: a digital crop of the fixed ROI only, never "detect a region, then re-capture/zoom it" (11244147). |
| 9 Blur filter | *given a box-blurred gray buffer, `Sharpness.laplacianVariance` should be below the sharp original's* | vImage is enough; skip the Metal kernel. Shows the "Mantén firme" hint. |
| 10 Torch + exposure bias | *given mean ROI luma below the threshold for N frames, `TorchHint` should suggest it* | Bias is a fixed setting (−0.5 to −1.0 EV), never driven by detections (11087105). |
| 11 ZXing-cpp fallback | *given the fixture Vision misses, ZXing should read it* | Feature flag. Apache-2.0 → THIRD_PARTY_NOTICES. ⚠ LEGAL_REVIEW: check whether ZXing's multi-row 1D reading (TryHarder) resembles 11893764's segment stitching before shipping. |
| 12 OCR digits | *given OCR text `7 501055 300075`, `DigitsExtractor` should yield a valid EAN-13; given an invalid check digit, nothing* | 2 matching frames, `source: .ocr`, asks for confirmation. |
| 13 Manual entry | *given typed `4006381333931`, should route like a scan* (through `BarcodeRead.validated`) | A keypad button on the scanner feeds `handleScan`. |

## Migrate-as-touched

- The `codeTypes:` literal lists in the three views become `ScanSettings.symbologies`
  (Kit). The mapping to `VNBarcodeSymbology` lives in FarmaciaScan.
- `BarcodeLookup.newProductBarcode` stays in Kit and gets reused by step 4. No
  scanner-related logic lives app-side today, so nothing else moves.

## Skipped on purpose

- The iOS 18 Swift `DetectBarcodesRequest` is skipped, because revision 4 is the same
  engine on iOS 17. Add it if the bench shows a difference.
- There's no DataScanner simple mode. The legacy CodeScanner toggle plays that role.

## Follow-ups (later)

- Remove CodeScanner (package, toggle, simulated path) once the new scanner wins on device.
