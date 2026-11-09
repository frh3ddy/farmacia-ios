# Photo Product Name Epic

**Status**: ✅ CODE DONE, uncommitted (2026-11-08). Device test and sign-off pending, see `tasks/photo-name-review-followups-epic.md`
**Branch**: `feature/photo-product-name` (farmacia-ios only; no API change)
**Goal**: In Nuevo producto, taking or choosing a photo suggests the product's name (and its presentation), in Spanish, even when the label has no readable name.

## Overview

The photo flow is unchanged: camera or library → crop → preview (`PhotoFlow`, `.productPhotoFlow`). Extraction starts in `CreateProductView.photoCropped` (`CreateProductView.swift:508`), next to `SubjectLifter`, so it only runs in Nuevo producto. Editing an existing product's photo doesn't trigger it.

## Decisions (asked 2026-11-08)

- **Name: fill if empty, otherwise suggest.**
  - An empty Nombre is filled with the suggestion (editable).
  - A typed Nombre is never overwritten. A chip appears under it instead: "Sugerencia: Botella verde · Usar".
- **Other info: presentation → Descripción**, only when Descripción is empty. Presentation means amounts like "100 ml", "30 tabletas", "500 mg". The barcode isn't read from the photo.
- **Apple Intelligence is included now.**

## What the phones can do (checked against the Xcode 27 SDK)

| | iPhone 13 Pro (A15) | iPhone 15 Pro (A17 Pro) |
|---|---|---|
| Vision OCR, Spanish (`VNRecognizeTextRequest`) | ✅ | ✅ |
| Vision classify (`VNClassifyImageRequest`, ~1,300 English labels) | ✅ | ✅ |
| Subject lift (already used) | ✅ | ✅ |
| Apple Intelligence on-device model (`FoundationModels`) | ❌ (no Apple Intelligence) | ✅ if Apple Intelligence is on |
| Model takes the **image** (`Transcript.ImageAttachment`) | ❌ | iOS 27+ only |

**Tiers.** Each photo uses the first tier that answers:

1. **Model.** Needs iOS 27, `SystemLanguageModel.default.availability == .available`, and Spanish support (`supportsLocale`). The model gets the photo plus the OCR lines and returns a `@Generable` `{ nombre, presentacion }`. Its instructions:
   - answer in Spanish;
   - use the brand/product name if one is visible;
   - otherwise describe the object as noun + color (noun + color, e.g. "Caja blanca").
   On error, unavailability, or a 5 s timeout, it falls through to tier 2.
2. **Label text (Vision).** The largest-text line(s) that aren't noise.
3. **Object + color (Vision).** The top classification label, through a small Spanish table, with gendered color agreement. The color comes from the lifted subject's opaque pixels.

If nothing qualifies, there's no suggestion and the form behaves as it does today.

Both phones run iOS 27 (confirmed 2026-11-08). The 15 Pro uses tier 1 when Apple Intelligence is on in Settings; the 13 Pro always uses tiers 2–3. Not done: an iOS 26 text-only model tier, since no phone here needs it.

## Logic / UI split

**FarmaciaKit** (pure Swift, unit-tested):

- `LabelName.pick(lines:)`: OCR lines (text + relative height) → name, or nil.
- `Presentation.read(lines:)` → "100 ml", "30 tabletas", or nil.
- `ColorName.spanish(red:green:blue:)` → color + gender forms.
- `DominantColor.average(rgba:)`: average of the opaque pixels in an RGBA byte buffer.
- `ObjectName.spanish(label:color:)`: Vision label → "Botella verde". Unknown label → nil.
- `ModelName.clean(_:)`: strips quotes and trailing periods, collapses spaces, returns nil if blank or over 60 characters.
- `PhotoNameSuggestion`: picks the tier result (model > label > object) and decides what the form does (`fill` / `suggest` / `none`).

**FarmaciaApp:**

- `ProductPhotoReader`: runs Vision (OCR with es-MX/en, classification, pixels of the lifted image) and returns plain values for FarmaciaKit.
- `ModelProductNamer`: uses `FoundationModels` behind `#available(iOS 27, *)` plus availability and locale checks.
- `CreateProductView`: starts the read after the crop, cancels it on retake or close, applies the decision, and shows the chip.
- New files `ProductPhotoReader.swift` and `ModelProductNamer.swift` must be registered in `project.pbxproj` by hand.

**Migrate as touched:** nothing has to move. `photoCropped` only starts the work, and the form fields already live in `ProductDraft`. The fill/suggest decision is new and goes straight into FarmaciaKit.

---

## Steps (TDD: each logic step RED → GREEN → REFACTOR, then the full `swift test`)

1. **Logic: what the form does with a suggestion.** `PhotoNameSuggestion.action(currentName:suggestion:)`
   - First failing test: *given an empty Nombre and the suggestion "Botella verde", should fill it.*
   - Then: *given a typed Nombre, should offer it as a suggestion.*
   - Then: *given a suggestion equal to the typed name (ignoring case and spaces), should do nothing.*
   - Then: *given only whitespace typed, should fill.*

2. **Logic: which tier wins.** `PhotoNameSuggestion.best(model:label:object:)`
   - First failing test: *given a model name and a label name, should prefer the model's.*
   - Then: *given no model name, should use the label's; given neither, the object's; given none, nil.*

3. **Logic: name from label text.** `LabelName.pick(lines:)`
   - First failing test: *given "ACNE PATCH" as the tallest line and "Lote 2501 / Cad 12/27" below, should return "Acne Patch".* Shouting all-caps becomes title case.
   - Then, with `@Test(arguments:)`: *given a tallest line that's noise, should skip it.* Noise is lot or caducidad text, a barcode-like run of digits, a bare amount ("500 mg"), "Reg. San.", or a URL.
   - Then: *given two tall lines of similar height (brand + product), should join them* ("Genfar Ibuprofeno").
   - Then: *given no line of at least 3 letters, should return nil.*

4. **Logic: presentation.** `Presentation.read(lines:)`
   - First failing test: *given "Frasco con 100 ml", should return "100 ml".*
   - Then, as arguments: "30 tabletas", "20 cápsulas", "500 mg" (alone), "1 L", "36 parches".
   - Then: *given an amount and a count ("500 mg", "30 tabletas"), should return "500 mg · 30 tabletas".*
   - Then: *given a date or lot number, should return nil.*

5. **Logic: color names.** `ColorName.spanish(red:green:blue:)`
   - First failing test: *given (0.1, 0.6, 0.2), should be verde.*
   - Then, as arguments: blanco/blanca (high value, low saturation), negro/negra, gris, rojo/roja, azul, amarillo/amarilla, rosa, morado/morada, café.
   - Each result carries masculine and feminine forms.

6. **Logic: dominant color.** `DominantColor.average(rgba:)`
   - First failing test: *given a 2×1 buffer with one opaque green pixel and one transparent red pixel, should return green.* The lifted subject has a transparent background, which must not count.
   - Then: *given an all-transparent buffer, should return nil.*

7. **Logic: object + color in Spanish.** `ObjectName.spanish(label:color:)`
   - First failing test: *given label "bottle" and green, should return "Botella verde".*
   - Then: *given "bottle" and white, should return "Botella blanca"* (feminine).
   - Then: *given a label not in the table, should return nil.*
   - The table only covers what a pharmacy photographs: packaging, health and personal care, baby, snacks and drinks, toys and gifts (`stuffed_animals` → "Peluche"), stationery, household, checked against the 3,273-item Square catalog, with plural agreement ("Lentes de sol negros"). It isn't a translation of all 1,300 labels.

8. **Logic: clean the model's answer.** `ModelName.clean(_:)`
   - First failing test: *given "\"Botella verde.\"", should return "Botella verde".*
   - Then: *given blank or more than 60 characters, should return nil.*

9. **UI: Vision reader.** `ProductPhotoReader.read(image:lifted:) async -> PhotoReading`
   - Runs OCR (`.accurate`, `["es-MX", "en-US"]`) with line heights from the bounding boxes.
   - Takes the top classification above 0.3 confidence.
   - Reads RGBA pixels from the lifted image, downscaled to 64×64.
   - Runs off the main actor.
   - Simulator smoke: none yet. It's checked through step 11.

10. **UI: model namer.** `ModelProductNamer.name(image:lines:) async -> (nombre, presentacion)?`
    - Behind `#available(iOS 27, *)`, `SystemLanguageModel.default.availability == .available` and `supportsLocale(es-MX)`. Otherwise it returns nil right away.
    - Uses a `@Generable` struct, Spanish instructions with the two examples, `Transcript.ImageAttachment` of the cropped photo, and a 5 s timeout.
    - Review: `swift-concurrency-pro` (cancellation, timeout, actor hops).

11. **UI: wire into Nuevo producto.**
    - `photoCropped` starts one `Task`: read → model (if available) → `PhotoNameSuggestion` → apply. It's cancelled on retake, a new photo, or close.
    - If the action is fill, set `viewModel.name`. If it's suggest, show the chip under Nombre: "Sugerencia: X · Usar".
    - If Descripción is empty and a presentation was found, fill it.
    - While it reads, show a small "Leyendo foto…" label beside Nombre. Typing is never blocked.
    - Review: `swiftui-pro`. Check that the chip lives on the name row, away from the photo flow's presentations (see the stacked-presentation memory).
    - Simulator smoke on **Nuevo producto** (local API): choose library photos of a labeled box (name filled), and 2–3 real, varied products from the shelf with no readable name. With a name typed first, the chip appears and "Usar" replaces the name. Retake the photo and confirm the old suggestion doesn't arrive late.

12. **Device check**, Release build:
    - **13 Pro:** Vision tiers.
    - **15 Pro:** the model tier (iOS 27; Apple Intelligence must be on in Settings, otherwise it falls back to Vision).
    - Compare names on the same 3 products. Cancel instead of creating.

13. **Docs.**
    - README: add the feature under Products.
    - Mark this epic ✅ with its commit hashes.
    - Run `graphify update .`.

## Out of scope

- Reading the barcode from the photo (the scanner already does it).
- An iOS 26 text-only model tier.
- Name suggestions when editing an existing product's photo.
- Category, price or supplier from the photo.

## Notes from implementation (2026-11-08)

- The user's green bottle and white bear were only examples: nothing is tuned to them. The bear special case was dropped; `ObjectName` takes the first label in its pharmacy-stock list (specific before generic), so `bear` + `toy` → "Juguete".
- `SubjectLifter` composites onto white, not transparency, so the reader requests the subject mask itself (`generateMaskedImage`) for the color. A `ponytail:` comment notes that segmentation now runs twice.
- Added a decision tested in FarmaciaKit: `PhotoNameSuggestion.description(current:presentation:)` fills Descripción only when it's empty.
- Simulator: the photo picker runs out of process, so the automation can't pick a photo there. Instead, the same Vision calls plus the Kit rules were compiled and run on the Mac against a 146 px crop of the Acne Patch photo: "CNE PATCH" → "Cne Patch" (the stylized A was lost at that resolution), labels people/adult/sign → no object name, color "rojo" (purple package averaged with the hand, the averaging limit noted in the code). Full-resolution device photos are the real check.
- The Apple Intelligence tier can't run in the simulator or on the Mac; it's checked on the iPhone 15 Pro in step 12.

## Review round 1 (dev-79, 2026-11-08): all addressed

- **Bug, stuck "Leyendo foto…":** reset before the early return. A CIImage-backed crop with no `cgImage` is now rendered through `CIContext` instead of being skipped.
- **Bug, `hasPrefix("reg")` dropped Regaine/Regulax:** red tests first, then the registration is matched only as `^reg(\.|istro\b)`.
- **Promo stoplist** (nuevo, oferta, gratis, promoción, contenido neto), test-first.
- **Unit casing:** a test for "IBUPROFENO 400MG" → "Ibuprofeno 400mg" passed already, since `capitalized` lowercases after a leading digit. It's kept as a guard.
- **Hard timeout:** a task group waits for every child, so it can't bound the wait. Replaced with `Deadline.within` in FarmaciaKit, a continuation race that also holds early results. Its tests (a blocking `Thread.sleep` that ignores cancellation, and a cancelled caller) fail against a naive await (1.5 s overrun) and pass in about 60 ms.
- **`ModelProductNamer.prewarm()`** runs when Nuevo producto opens. Each answer logs its elapsed time (category PhotoName) for the device check.
- **Presentation:** Vision first, then the model (`PhotoNameSuggestion.presentation(vision:model:)`), since the model can invent counts.
- **UX (user chose "replace its own guess"):** `action`/`description` take `autoFilled`. A new photo replaces what an earlier photo filled, never typed or edited text.

- Square catalog check (Nov 2026): besides medicine, the stores stock plush toys, baby bottles and teethers, personal care, batteries, jewelry, stationery, candy and drinks. Vision has no label for combs, razors, batteries, mirrors, sponges or perfume, so on the 13 Pro those fall back to the label's text or nothing; Apple Intelligence (15 Pro) names them from the photo.

## Review round 2 (/tdd-review, 2026-11-08): done, uncommitted

Same branch, `feature/photo-product-name`: the epic isn't committed yet, so the fixes belong to it.

1. ✅ **Logic: promo word inside a name line** (`LabelName`). Remove the promo word from the line instead of dropping the line, and match whole words only.
   - First failing test: *given "NUEVO IBUPROFENO" as the only line, should return "Ibuprofeno".*
   - Then: *given "RENUEVO" (a name that contains "nuevo"), should keep it.*
   - Then: *given "¡OFERTA!" alone, should still skip it* (the existing `skipsPromo` cases stay green).
2. ✅ **Logic: Mexican count abbreviations** (`Presentation`). Read "tab", "tabs", "caps", "pz", "pza", "pzas" and an optional "c/" prefix. Normalize to the full word so Descripción reads the same whatever the box says.
   - First failing test: *given "c/20 TABS", should read "20 tabletas".*
   - Then (arguments): *"30 tab" → "30 tabletas", "12 caps" → "12 cápsulas", "40 pz" → "40 piezas".*
   - Then: *given "500 mg c/20 TABS", should read "500 mg · 20 tabletas".*
3. ✅ **UI: "Eliminar Foto" stops the reading** (`CreateProductView`). The button cancels `photoReadTask` and clears `nameSuggestion` and `isReadingPhoto`. It's view state only, with no rule to test, so nothing moves to FarmaciaKit. Nombre and Descripción keep whatever was already filled; the user can edit them.
4. ✅ **UI: a name taken from the chip counts as the photo's guess.** "Usar" also sets `autoFilledName`, so the next photo can replace it.
5. **Skipped:** running the model alongside Vision. Revisit only if the device timings (15 Pro) show the wait is too long.

Then: the full `swift test`, the app build, the `swiftui-pro` check on the two buttons, and `graphify update .`. No critical flow is touched: Nuevo producto isn't on the list, and the simulator can't drive the photo picker. The device test plan stays the same.
