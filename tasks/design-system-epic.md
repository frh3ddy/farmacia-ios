# Epic: design system foundation + two pilot screens

**Branch:** `feature/design-system-foundation`

## Decisions

- **Look:** keep the current look and name what's already there (spacing 2/4/8/12/16/20/24, radius 4/8/12/16,
  system colors, built-in text styles). Pilots change only where the rules below require it.
- **Rollout:** build the foundation and convert 2 pilot screens (`CreateProductView`, `ReceiveInventoryFormView`);
  every other screen converts when a later task touches it.
- **Sources of rules:** `swiftui-pro` (`references/design.md`: shared constants, Dynamic Type, 44pt
  tap targets, hierarchical styles) + `/design-system` three-layer idea (raw → purpose → component).
  No online iOS design-system skill was worth installing.
- **Keyboard:** remove the app-wide tap-outside-to-dismiss detector (user chose option a). Dismissal comes from
  the keyboard toolbar's Done and `.scrollDismissesKeyboard(.immediately)`. Remove the extra
  space above the keyboard (`keyboardTopSpacing`) from the pilots.
- **Presentation:** one `Destination` enum per screen driving a single `sheet(item:)` /
  `fullScreenCover(item:)`; choosing a value inside a form is a push, not a sheet; a `Menu`
  instead of a `confirmationDialog` for picking an action.

## Logic vs UI

- FarmaciaKit (tested): `Tone`, `Margin` (percent + tone), `FocusOrder`.
- FarmaciaApp: `Core/DesignSystem/` constants, `Tone.color`, `AmountField`, `.formKeyboard`, pilots.
- Migrate now: margin percent (`CreateProductViewModel`, inline formula in `ReceiveInventoryFormView`)
  and the 20/10 cutoffs in those two screens.
- Migrate later, when touched: the cutoffs in `ProductRow`/`ProductDetailView`, `Adjustment.color` / `Expense.color`
  (stored as strings), and the `color` properties in `InventoryAging` and `Employee`.

## Steps

1. [x] FarmaciaKit `Tone` + `Margin.percent(price:cost:)`.
   First test: given price 100 and cost 80, should be 20%. Then: given price 0, should be nil.
2. [x] FarmaciaKit `Margin.tone`.
   First test: given a 20% margin, should be positive. Then 10% → caution, 9.9% → critical.
3. [x] FarmaciaKit `FocusOrder`.
   First test: given the last field, next should be nil (Done). Then: given the first field, previous should be nil.
4. [x] App `Core/DesignSystem/`: `DS.Spacing`, `DS.Radius`, `Tone.color`. New files go in
   `project.pbxproj` by hand. Smoke: build only.
5. [x] App `.formKeyboard(focus:order:)`: keyboard toolbar (‹ › Done), `submitLabel(.next)`/`onSubmit`,
   `.scrollDismissesKeyboard(.immediately)`. Remove `KeyboardDismissInstaller`.
6. [x] App `AmountField` (label + `$` + field + unit + tap anywhere on the row, 44pt, right keypad). Check whether
   `TextField(value:format:)` updates only when focus leaves the field (it would keep **Crear** disabled). If it does, add a
   FarmaciaKit amount parser (first test: given "12.5", should be 12.5).
7. [~] Pilot `CreateProductView`: tokens, `AmountField`, `Margin`/`Tone`, `.formKeyboard`, a `Destination`
   enum (photo/camera/crop/preview), supplier picker as a push (then remove `.animation(nil)`),
   photo source as a `Menu` + `PhotosPicker`, no `ImagePickerPresenter`, no `keyboardTopSpacing`.
   Then try removing `.immediately`.
   Smoke: create a product with stock (‹ › Done, margin color, **Crear** enables without leaving the field),
   library photo on the first try, Eliminar/Retake, supplier picker. Device: camera.
8. [~] Pilot `ReceiveInventoryFormView`: same keyboard/tokens/`Margin` treatment, its own `Destination`
   enum, no `keyboardTopSpacing`. Smoke: receiving end to end incl. the new-margin row.
9. [x] Scan feedback: already there. `CodeScannerView` runs with `shouldVibrateOnSuccess: true`, so no change.
10. [x] Review (2026-11-03, feature/form-ux-polish): SupplierPicker empty state → `ContentUnavailableView`; UIKit `Color(.systemGray5)` → `.fill.tertiary`; photo badge → `.tint`; `AmountField` generic over `AmountValue` (Int/Double), no `Binding(get:set:)`; `CreateProductViewModel` and `AmountValue` in their own files. Accepted: Tone colors as text rely on iOS Increase Contrast and are paired with the number. Original scope: `swiftui-pro` on everything touched + the `ui-ux-pro-max` mobile checklist (contrast, Dynamic Type).
    Add to the README and this epic, and run `graphify update .`.

## Status (2026-11-02)

- Steps 1–6 done: FarmaciaKit `Tone`, `Margin`, `FocusOrder`, `AmountText` (213 tests green);
  `Core/DesignSystem/` (`DesignSystem.swift`, `AmountField.swift`); `.formKeyboard` in
  `KeyboardHelpers.swift`; app-wide tap-outside detector removed.
- Steps 7–8 built (`[~]`): code done, smoke tests pending. The simulator automation can't reach
  sheet content (taps and typing land on the list behind), so the user runs the smoke tests.
- Extras made along the way: `SupplierPickerView` is now pushed (both callers were pilots);
  `CameraPicker` / `LibraryPicker` (inline `PhotosPicker`) in `ImagePicker.swift`;
  `ProductPhotoPreviewView` shows a spinner while the background is being removed (`isLifting`); crop goes straight
  to preview. ReceiveInventoryFormView presents nothing now, so no destination enum was needed.
- Keyboard, tuned on device (iPhone 13 Pro): the Listo bar is an overlay above the keyboard, the
  focused field scrolls to a third down on the keyboard's own timing, and dismissal is interactive.
  Measured: the system keyboard toolbar adds 14pt to the form's bottom inset and releases it after
  the keyboard animation (the jump at the end of every dismiss); a `safeAreaInset` bar jumped too.
  `ScrollPosition` can't move a SwiftUI `Form`. Details in `KeyboardHelpers.swift`.
- Unsaved-changes protection (Nuevo Producto): FarmaciaKit `ProductDraft` (TDD, 5 tests); the sheet
  can't be swiped away once anything is entered, and Cancelar asks "¿Descartar producto?".
  Verified on device.
- Recibir Inventario: FarmaciaKit `ReceivingDraft` (TDD, 6 tests; the form's own auto-fill of the preferred
  supplier and its cost, and values behind a switch that's off, aren't changes), same protection
  ("¿Descartar recepción?"), and Guardar turns into a spinner while saving (form, Cancelar and swipe
  locked). Verified on device.
- Discard prompts sit on the NavigationStack, not the Cancelar button: attached to the button, iOS 26
  shrinks the dialog back into it before the sheet starts closing (a half-second stall, measured).

## Follow-ups (`tasks/design-system-review-followups-epic.md`)

- swiftui-pro: one type per file — `ImagePicker.swift`, `KeyboardHelpers.swift`, and the view models
  inside `CreateProductView.swift` hold several.

- `ProductDetailView`: 12 presentation modifiers → one `Destination` enum; photo via `Menu`/`PhotosPicker`.
- Scanner flow: one sheet with its own navigation (scan → candidates → create) instead of
  `pendingScannedCode` + `onDismiss`.
- Delete `ImagePickerPresenter` and `keyboardTopSpacing` (still used by `EditPriceView` / `AdjustmentFormView`)
  once nothing uses them.
- UIKit haptics → `.sensoryFeedback`.
- Convert the other screens as they get touched; continuous scan-to-count in receiving; a frame over the camera view
  showing where to place the product.
