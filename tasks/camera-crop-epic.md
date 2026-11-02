# Epic: crop screen doesn't open after taking a photo

**Branch:** `fix/camera-crop-not-presenting`

## Likely cause

`ImagePickerPresenter.Delegate` (`FarmaciaApp/Core/Components/ImagePicker.swift`)
called `onImagePicked(image)` **before** `picker.dismiss(animated:)`. The callback
sets `imageToCrop`, so SwiftUI tried to present the SwiftyCrop
`fullScreenCover` while the full-screen camera was still on screen. UIKit refuses
("Attempt to present … already presenting") and the crop screen never appears.

Secondary suspect: the image `Section` hosts a `confirmationDialog` + two
`fullScreenCover`s on one chain (see the stacked-presentation-modifiers memory).

## Logic vs UI

- FarmaciaKit: none. This is a UIKit/SwiftUI presentation-order bug, and the
  types involved (`UIImage`, `UIViewController`) can't live in the package.
- Migrate-as-touched: nothing. `CreateProductViewModel` logic (`isValid`,
  `profitPerUnit`, `marginPercent`) is not touched.

## Steps

1. [ ] Confirm on a device: Nuevo Producto → Tomar Foto; check the console for
   `already presenting`. Compare with Biblioteca. (The simulator has no camera.)
✅ Fixed in 8b089e2 (steps 2 + 3). Library flow verified in the simulator on the first try;
camera on a device still to confirm.

2. [x] Shared fix: dismiss the picker first, then call `onImagePicked` in the
   dismiss completion. This also fixes `ProductDetailView`'s camera/library callers.
   (Built clean; FarmaciaKit 198/198. Device + sim smokes pending the user, since the
   sim needs a PIN.)
   - Smoke (device): Nuevo Producto → Tomar Foto → crop → lift → preview → Crear,
     with the image uploaded.
   - Smoke (sim): Nuevo Producto → Biblioteca → crop → preview.
   - Smoke (device): ProductDetailView → change photo via camera.
3. [x] Needed: after step 2 the library crop opened, then closed right away on the
   first try (worked on the second). Done: merge the two `fullScreenCover`s into one
   `fullScreenCover(item:)` driven by a private `PhotoStep` enum, attached at the
   `Form` level; the Section keeps only the `confirmationDialog`.
4. [ ] Docs: README features + this epic (✅ with hashes); `graphify update .`.

## Out of scope

- Upload resize (`UIImage+Resize.swift`): not involved.
- SwiftyCrop upgrade (2.3.1): revisit only if the crop opens but misbehaves.
