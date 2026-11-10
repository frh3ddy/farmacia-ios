# Expiry Picker Styles Epic (try on device, keep one)

**Status**: ✅ DONE (2026-11-09). The user tried all three on the iPhone 13 Pro and kept the **bottom sheet** (the default); the trial code is removed. Committed as `d10b9f2`.
**Branch**: `feature/expiry-picker-styles` (from main)
**Goal**: The "Vence" month/year wheels are always fully on screen when they open. Today in Conteo inicial they open inline under a lot row near the bottom, behind the Guardar bar, so the months are hard to scroll.

## Why it happens

`MonthYearPicker` (`Core/DesignSystem/MonthYearPicker.swift`) opens its two `.wheel` pickers inline, under the row. Lot rows sit low in the count form (`AdjustmentFormView.swift:400`), so the wheels land under the pinned action bar and off the bottom edge. The same component is used in Recibir (`ReceiveInventoryFormView.swift:684`) and Nuevo producto (`CreateProductView.swift:418`), so fixing it once fixes all three.

## Decision (asked 2026-11-09)

**Build all three styles, try them on the iPhone, and keep one.** A temporary switch in Ajustes picks the style. After the device test, the chosen style becomes the only one, and the switch and the other two styles are deleted.

1. **Bottom sheet**: a short sheet (`.presentationDetents([.height(…)])`) with the two wheels, plus Listo and "Quitar caducidad". Native, and always fully visible.
2. **Centered pop-up**: a card in the middle of the screen over a dimmed form, with the same contents. Custom, since iOS has no native centered picker.
3. **Inline, auto-scroll**: as today, but opening scrolls the wheels fully into view above the Guardar bar. This needs each host form's `ScrollViewProxy`, passed down through the environment.

All three keep today's behavior:
- an empty value opens one year out;
- "Quitar caducidad" clears it;
- the "ya venció" warning stays under the row.

## Logic (FarmaciaKit, Swift Testing)

1. ✅ **`MonthYear.openingValue(current:today:)`**: what the wheels start on. It's shared by all three styles, so it moves out of `MonthYearPicker.toggle()` (migrate-as-touched).
   - First test: *given no expiry yet and today March 2026, should open on March 2027*.
   - Then: *given an expiry of May 2028, should open on it*.
2. ✅ **`ExpiryPickerStyle`** (`sheet`, `popup`, `inline`): the switch's options, with Spanish titles, defaulting to `sheet`.
   - First test: *given no saved style, should be the bottom sheet*.
   - Then: *given an unknown saved raw value, should fall back to the bottom sheet* (the switch is temporary, and old values mustn't break it).
   - Added: each saved style is kept, and the Spanish titles are "Hoja inferior", "Ventana centrada" and "En línea". 619 tests pass.

## UI (FarmaciaApp)

3. ✅ **Bottom sheet style** in `MonthYearPicker`: the row button opens a sheet with "Caducidad", the wheels, Listo and "Quitar caducidad".
4. ✅ **Centered pop-up style**: a full-screen overlay card. Use `.fullScreenCover` with a clear background, so it's above the form's Guardar bar and the tab bar. Tapping outside, or Listo, closes it.
5. ✅ **Inline auto-scroll style**. `.formKeyboard` already wraps each form in a `ScrollViewReader`, so it hands its proxy down (`\.formScrollProxy`) and no form needed its own reader.
   - Learned in the smoke: the form scrolls to whole rows only. A count lot is one row (Vence + Cantidad + Lote), so the picker takes a `scrollTarget`, and that lot row gets `.id(lot.id)`. Recibir and Nuevo producto put the picker directly in a section, so the wheels are their own row (they scroll to the wheels' id).
   - It scrolls 0.4 s after opening, once the open animation has laid out the wheels; scrolling sooner measures the closed row and doesn't move.
6. ✅ **The temporary switch**: Ajustes → "Selector de caducidad (prueba)" with the three options (`@AppStorage("expiryPickerStyle")`). It shows in Release too, since the test is on the iPhone's release build.
   - **Smoke** (simulator, then iPhone): in Conteo inicial / Contar, add a lot near the bottom and open Vence in each style. The wheels are fully visible, and month and year both scroll. Listo keeps the value, and Quitar clears it. Check Recibir and Nuevo producto the same way.
   - Simulator smoke passed (2026-11-09) in Conteo inicial, on Aba alcanforada's lot: all three styles show the wheels fully. Listo keeps nov 2027. The sheet and the pop-up show Quitar caducidad.
   - Device: the **Debug** build on the iPhone 13 Pro (user's choice). It uses the local API on the Mac, so the phone must be on the same Wi-Fi.
7. ✅ **After the user picks** (bottom sheet): delete the other two styles, the switch and `ExpiryPickerStyle` with its tests. Run `graphify update . --force` (code was removed).
8. **Docs**: README (if the picker is mentioned), this epic (✅ + hashes), and `graphify update .`.

**Final shape**: `MonthYearPicker` always opens a bottom sheet (`.presentationDetents([.height(320)])`) with "Caducidad", Listo, the wheels and "Quitar caducidad". Everything else from the trial is gone:
- `ExpiryPickerStyle` and its tests, and the Ajustes switch;
- the pop-up, the inline wheels and `\.formScrollProxy`;
- the lot row's `.id`.

`KeyboardHelpers`, `SettingsView` and `AdjustmentFormView` are back to main. `MonthYear.openingValue` stays (2 tests). 615 tests pass.

## Review fixes (/tdd-review, 2026-11-09)

- ✅ **Swiping the sheet away is a cancel**: `MonthYear.closingValue(before:current:confirmed:)` has 4 tests. Listo or Quitar keep what's shown; a swipe-away puts back the expiry from before opening (empty stays empty, so a year-out start nobody chose isn't saved).
- ✅ **Height**: `.presentationDetents([.medium, .large])`, not a fixed 320 pt, which clipped with larger text. The content is pinned to the top.
- ✅ **Smoke in Recibir and Nuevo producto** (both host other sheets): no "already presenting" crash.
  - Recibir: swipe-away → "Elegir" (back to empty); open + Listo keeps nov 2027.
  - Nuevo producto: Quitar caducidad in the sheet → "Elegir".
  - Nothing was saved; both forms were discarded.
- 619 tests pass.

## Migrate-as-touched

- The opening-value rule (`today.year + 1`, same month) moves from `MonthYearPicker.toggle()` into `MonthYear` in FarmaciaKit (step 1).
- `MonthYearPicker` stays in the app (SwiftUI).

## Out of scope

- The day-based DatePickers in Nómina (`PayrollView`): that's a different control, and nobody reported an issue with it.
