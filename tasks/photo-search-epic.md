# Buscar por foto Epic

**Status**: 🚧 IN PROGRESS. Steps 1–4 ✅ (merged 7a94de3, 8551bca, 4fd1428)
**Branch**: `feature/photo-search`. Steps 1–12 are farmacia-ios only. Step 14 adds one API endpoint (farmacia-ops).
**Photos are never changed.** Reference photos are downloaded, background-removed and turned into vectors in memory only; nothing is uploaded and the Square images stay as they are. The search photo isn't saved or uploaded either.
**Goal**: Find a product that has no barcode by taking its photo. The result is a short ranked list to tap, not one guessed answer.

## Overview

Most pharmacy products have a barcode. About 50–100 don't. Photo search covers only those products ("sin código"), not the whole catalog. That keeps it small: about 100 reference photos per phone, computed once in seconds, with no background job and no server work.

A search photo is ranked by two signals:

1. **Text on the box.** Vision OCR (`VNRecognizeTextRequest`), already run by `ProductPhotoReader`, is fuzzy-matched against product names. The strength printed on the box ("500 mg", via `Presentation`) breaks ties between look-alikes.
2. **How it looks.** An image vector from Vision `VNGenerateImageFeaturePrintRequest` (no training) is compared with the vector of each product's `squareImageUrl` photo. Both the search photo and the reference photos are background-removed first, because most older Square photos still have their background.

The full "sin código" grid is always the fallback: a photo that reads no text and matches nothing still shows every candidate to scroll and tap. A result is never empty.

## Decisions (2026-11-19)

- **Entry points**:
  - a "Buscar por foto" button on the scanner screen;
  - a "¿Ya existe? Buscar por foto" choice when a scanned code is unknown, before Nuevo producto.
- **"Sin código" rule**, computed on the phone from the product cache:
  - included: `gtin` is empty **and** the SKU isn't barcode-shaped (`isGTIN`: 8/12/13/14 digits);
  - left out: `tracksInventory == false` (Yastás services);
  - the cache is already filtered to this store (`soldOnlyAtLocationId`).
- **Sueltos with printed SKU labels stay in the list.** Their Code128 labels still scan (`ScanSettings.symbologies`), and photo search covers the ones whose label fell off.
- **Indexing**:
  - per phone, the first time Buscar por foto opens, then cached;
  - only new products or a changed photo URL are re-indexed;
  - no Wi-Fi rule needed at about 100 photos (~20–40 MB).
- **What a photo can't tell**: the same design in two sizes (100 ml vs 500 ml) looks identical in a photo. Both rank near the top, and each cell shows the name **and** the presentation, so the person picks.
- **Packaging redesign**: if a box changed, retake its photo on Recibir/Detalle (the existing photo flow). The new URL re-indexes it.

## Review findings folded in (tdd-review, 2026-11-19)

| Finding | Where it's handled |
|---|---|
| A correct result must be defined as tests first | Steps 1–4 come before any Vision or UI work |
| Pure logic goes in FarmaciaKit, Vision stays out of it | Logic in steps 1–5 (FarmaciaKit); Vision in steps 6–7 (FarmaciaScan, macOS-testable); the app layer stays thin (steps 9–11) |
| Cache `[Float]`, never `VNFeaturePrintObservation` | Steps 3, 5, 7 |
| Reuse `LabelName`, `Presentation`, the diacritic folding in `LotNumber.swift:48`, the product cache, and `scan-bench` | Steps 2, 8, 9 |
| Indexing needs a concurrency limit and cancellation | Step 9 |
| Invalidate vectors by photo URL and Vision revision | Step 5 |
| Measure accuracy on device data, not the simulator | Step 8 (`scan-bench` on the Mac with real photos), step 12 (device) |
| Branch first | `feature/photo-search` |
| Lot lookup endpoint must live under `/inventory/` | Moved to Future: lot search isn't in this epic |

## Steps

### Logic: FarmaciaKit (Swift Testing, `swift test`)

1. ✅ **`PhotoSearch.isSinCodigo(sku:gtin:tracksInventory:)`** (734edf9, merged 7a94de3)
   - given an empty `gtin` and SKU "PARA-500", should be true *(first failing test)*
   - given SKU "7501234567890" (EAN-13 as SKU), should be false
   - given a `gtin`, should be false
   - given a whitespace-only `gtin`, should be true
   - given `tracksInventory == false`, should be false
   - given a nil SKU and nil `gtin`, should be true

2. ✅ **`PhotoSearch.textScore(lines:name:)`** (6376a9e, merged 8551bca): the share of the name's words found on the box, with case and accents ignored. "500mg" splits into "500" and "mg". Words of 5+ letters survive one OCR slip; numbers must match exactly.
   - *As built:* there's no `presentation:` parameter. The strength's number is a name word, so "500" vs "750" already ranks correctly. `LabelName`'s noise rules weren't needed: the score counts the name's words, so lot/date lines can only add a coincidental match. The folding stays inline, a one-liner like `LotNumber`'s, rather than becoming a shared helper.
   - given OCR "PARACETAMOL" and name "Paracetamol", should score > 0 *(first failing test)*
   - given OCR "Jabón Neutro" and name "jabon neutro", should be a full match
   - given no lines, should be 0
   - given OCR with "500 mg" and products "Paracetamol 500 mg" / "Paracetamol 750 mg", should score the 500 mg one higher (read with `Presentation.read`)
   - given only noise lines (lot, date, registration), should be 0. Reuse `LabelName`'s noise rules rather than a new list.

3. ✅ **`FeatureVector.similarity(_:_:) -> Double?`**: cosine similarity over `[Float]`.
   - given two identical vectors, should be 1 *(first failing test)*
   - given orthogonal vectors, should be 0
   - given different lengths (vectors from different Vision revisions), should be nil

4. ✅ **`PhotoSearch.rank(_ candidates:, lines:, photo:) -> [Candidate]`**: blends the two scores with fixed weights (text 0.6, image 0.4). Image similarity is first rescaled above an "unrelated" floor of 0.5 (`likeness`), because real feature prints of unrelated products still score 0.2–0.58, which would otherwise give any product with a photo a head start (dev-f8 review of 346f824). `Candidate` is `{id, name, vector?}`, and rank computes both scores itself, so the app only passes data. A negative image similarity counts as 0, and equal scores fall back to name order. `ponytail: fixed weights; tune from step 8's bench numbers if top-5 is low.`
   - given no text and no image scores, should return every candidate in name order (the grid fallback, never empty) *(first failing test)*
   - given "500 mg" on the box, the 500 mg product should beat a 750 mg product with a higher image score
   - given a product with no reference photo, it should still rank first on a strong text match
   - given equal text scores, the higher image score should come first
   - given a blue and a pink variant with the photo closest to blue, blue should be first and pink still in the top 5

5. **`FeatureIndex` (Codable value plus rules)**: entries keyed by `productId`, each storing its `imageUrl` and vector, with one Vision `revision` for the whole index. `refreshed(for: [Ref], revision:) -> (index, queue)` keeps the valid entries and lists what to index next; `insert`, `vector(for:)`. Step 8's bench set must include IMG_5770 vs 5771, the hardest unrelated pair found so far at cos 0.58.
   - given an entry whose `imageUrl` differs from the product's current `squareImageUrl`, should need reindexing *(first failing test)*
   - given a stored revision different from the current one, every entry should be stale
   - given a product no longer "sin código" (a barcode was added), its entry should be dropped
   - given a product with no `squareImageUrl`, it should not be queued for indexing (it can still match on text)

### Vision: FarmaciaScan (Vision and Core Image also run on macOS, so `swift test` and `scan-bench` can use them)

6. **Migrate the subject lift into FarmaciaScan** (migrate-as-touched): `SubjectMask.lift(_ CGImage) -> CGImage?`, using `VNGenerateForegroundInstanceMaskRequest`. The app's `SubjectLifter` (UIImage) becomes a thin wrapper over it, and its behavior is unchanged.
   - given a plain single-color image, should return nil (no subject) *(first failing test)*
   - given a test photo of a box on a counter (fixture), should return an image with transparent corners

7. **`FeaturePrinter.vector(_ CGImage) -> (vector: [Float], revision: Int)?`**, using `VNGenerateImageFeaturePrintRequest` with its revision pinned.
   - given the same fixture twice, `FeatureVector.similarity` should be ≥ 0.99 *(first failing test)*
   - given two different fixtures, similarity should be lower than for the same one

8. **Bench before any UI: `scan-bench --photo-search <refs> <queries>`**
   - Reference photos are named `<productId>.jpg`, downloaded from `squareImageUrl`. Query photos are new phone photos named `<anything>_<productId>.jpg`.
   - It runs lift, OCR, vector and `rank`, then prints top-1 and top-5 hit rates for text only, image only, and both.
   - Run it on about 30 real "sin código" products, with old Square photos (background) and newer app photos (lifted) reported separately.
   - **Gate:** if top-5 for both signals combined is below about 80%, stop and revisit the weights or the model (see Future) before building the UI.

### App: FarmaciaApp (thin)

9. **`PhotoSearchIndex` (actor, app layer)**:
   - on first open, filters the product cache with `isSinCodigo` and asks `FeatureIndex` which entries are stale;
   - downloads with the existing image loader path (`CachedProductImage` downsample), at most 4 at a time, then lifts and computes the vector;
   - saves the `FeatureIndex` as JSON in Caches;
   - is cancelled when the sheet closes, and saved entries are kept, so the next open continues where it stopped.
   - No new logic here: the rules live in step 5. A cancelled index must not discard finished entries.

10. **Search screen.** "Buscar por foto" on the scanner opens the camera through the existing `.productPhotoFlow` (camera → crop). The photo is lifted, then OCR and vector run in parallel off the main actor (`@concurrent`, like `ProductPhotoReader.read`), then `rank`.
    - A grid of thumbnails, each with name + presentation.
    - Header: "N productos sin código", plus "Indexando fotos… x / N" while step 9 runs.
    - Tapping a product goes through `route(.matched, product:)`, so Consultar, Recibir and Contar behave as they do for a scan.
    - The grid also works with no photo taken: a plain scrollable list.
    - **Simulator smoke:** scanner → Buscar por foto → library photo → pick → product opens (Consultar) / receive form opens (Recibir).

11. **Unknown-code choice.** In the `.create` step, a "¿Ya existe? Buscar por foto" button opens step 10's screen. Picking a product continues as `.matched`, and Nuevo producto stays one tap away.
    - Add a `ScanEvent`/`ScanNext` case only if the route differs from `.matched`. If it does: given an unknown code then a photo pick in Recibir, should go to `.receive`.
    - **Simulator smoke:** unknown code (`simScanCode`) → ¿Ya existe? → pick → receive form.

12. **Device check and docs**:
    - device run on both iPhones with real "sin código" products: the first-open indexing time, and whether the right product is in the top 5;
    - README feature entry, this epic marked ✅ with commit hashes, then `graphify update .`.

## Migrations (migrate-as-touched)

- `SubjectLifter`'s Vision mask and composite → `FarmaciaScan.SubjectMask` (step 6).
- Diacritic and case folding duplicated in `LotNumber.swift:48` and `ExpiryText.swift:114` → one shared FarmaciaKit helper, once step 2 needs it.
- `ProductPhotoReader`'s OCR setup → reused as is. Move it into FarmaciaScan only if `scan-bench` (step 8) needs OCR on the Mac, which is likely; do that in step 8.

### Save the scanned code (decided 2026-11-19)

An unknown code followed by a product found by photo means the box *has* a barcode the product lacks. Offer to save it, so each search like that shrinks the "sin código" list.

13. **`BarcodeSave.offer(code:product:) -> String?`** (FarmaciaKit). Returns the code to offer, or nil for no offer.
    - given an EAN-13 code and a product with an empty `gtin`, should offer the code *(first failing test)*
    - given a product that already has a `gtin`, should be nil (never overwrite one)
    - given a 14-digit read of an EAN-13, should offer the 13 digits on the box (reuse `BarcodeLookup.newProductBarcode`)
    - given a code that isn't barcode-shaped (a printed Code128 SKU label), should be nil (`isGTIN`)

14. **API: `PATCH /products/:id/gtin`** (farmacia-ops session; a new endpoint, since none sets the barcode on an existing product today).
    - Sets `Product.gtin` and the Square variation `upc`, the same field create already sends (`products.service.ts:923`).
    - Rejects the request if the product already has a `gtin`.
    - Roles OWNER and MANAGER, like `:id/price`. `ponytail:` widen to every role if counter staff need it.
    - It's under `/products`, which is already an API prefix, so the route allow-list isn't affected.

15. **App: the offer.** After a photo pick from the unknown-code path (step 11), show a confirm: "¿Guardar 7501234567890 como código de barras de este producto?" with Guardar and No.
    - Shown only when `BarcodeSave.offer` returns a code and the employee's role can use the endpoint.
    - On save: update the cached product (`ProductCacheManager.saveProduct`) so it leaves "sin código", and the next scan of that box opens the product directly.
    - On failure: show the error (`NetworkError.from`) and carry on with the pick; the scan flow isn't blocked.
    - **Simulator smoke:** unknown code → ¿Ya existe? → pick → Guardar → close → scan the same code → the product opens.

## Future (not in this epic)

- **Grocery or non-pharmacy expansion**, where many products have no barcode:
  - index the whole catalog instead of only "sin código";
  - background indexing after each product sync (first run on Wi-Fi);
  - share vectors through the API, so one phone indexes and the others download about 3 MB (worth it at around 4–5 or more devices; needs matching iOS/Vision revisions).
- **MobileCLIP (Core ML)** if `FeaturePrint` falls short in step 8. Stronger vectors and text-to-image search, at the cost of a 50–100 MB model in the app.
- **Lot-number search:**
  - a new `GET /inventory/lots/search?lot=` (it must stay under `/inventory`, per the API allow-list);
  - this store only, all roles;
  - OCR the lot with the existing `LotNumber`.
  - Low value in a pharmacy, where barcoded boxes scan and loose items rarely print a lot.
- **A custom-trained model:** not planned. Retraining per new product doesn't fit a changing catalog.
