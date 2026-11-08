# Store Strip Epic

**Status**: ✅ DONE (uncommitted) — verified on device (iPhone 13 Pro, Release/prod) 2026-11-08
**Branch**: `feature/store-strip` (farmacia-ios only; no API change)
**Goal**: Anyone changing stock can see which store it lands in, at a glance and before saving.

## Overview

Receiving into the wrong store is easy today. Inside the Recibir sheet, the store name shows up only in the small footer line under Cantidad (`ReceiveInventoryFormView.swift:375`), and only after a quantity is typed. Inicio shows it in secondary gray (`DashboardView.swift:114`). Stock-changing sheets cover the tabs, so whatever the tabs show is hidden while the sheet is open.

## Decisions (asked 2026-11-07)

- **Color: derived from the store id.** A fixed palette of about 6 colors, picked by a *stable* hash of `SessionLocation.id`. The same store gets the same color on every device and for every employee. A collision between two stores costs only the color cue, because the name is always shown. No server field.
- **Scope: stock-changing sheets only.** Recibir, Ajustar / Conteo inicial, the scanner (Contar mode), and Nuevo producto (it can take stock). The tabs are unchanged.
- **Hidden for single-store employees** (`availableLocations.count <= 1`), since they have no wrong store to pick.
- **Say it at the save button too:** Recibir's primary action reads **"Recibir en {tienda}"**, which matches brief §D ("Which location is affected").

The strip is about 24pt, sits under the nav bar via `.safeAreaInset(edge: .top)`, and shows the store's color with `building.2` + name in white semibold, plus the VoiceOver label "Tienda: {name}".

## Logic / UI split

- **FarmaciaKit:** `StoreTint`
  - `paletteIndex(forLocationId:paletteCount:) -> Int`, using FNV-1a over UTF-8. **Not** `hashValue`/`Hasher`: those are seeded per launch, so the color would change on every app start.
  - `showsStrip(storeCount:) -> Bool`
- **FarmaciaApp:**
  - The palette lives here as `[Color]` (no SwiftUI in Kit).
  - A `.storeStrip()` modifier in `Core/DesignSystem/StoreStrip.swift` reads `AuthManager` and is applied to each sheet's root.
  - The new file must be registered in `project.pbxproj` by hand.

**Migrate as touched:** nothing has to move. The sheets only read `currentLocation?.name`, with no logic to extract.

---

## Steps

1. **Logic: the palette index.** `StoreTint.paletteIndex` in FarmaciaKit.
   - First failing test: *given location id "loc-centro" and a palette of 6, should return the pinned index N.* Pin it to the FNV-1a result; the pin is what catches a switch to a seeded hash.
   - Then: *given any id, should return an index in 0..<paletteCount.*
   - Then: *given an empty id, should still return a valid index.*

2. **Logic: when to show.** `StoreTint.showsStrip(storeCount:)`.
   - First failing test: *given 1 store, should not show the strip.*
   - Then: *given 2 stores, should show it.*

3. **UI: the `.storeStrip()` modifier.**
   - Pick 6 palette colors that each pass contrast with white text in light and dark mode. Avoid Tone red/orange so the strip never reads as a warning.
   - Preview it with two stores.
   - No simulator smoke; the previews cover it.

4. **UI: apply it to the stock-changing sheets.** Add `.storeStrip()` on the `NavigationStack` of:
   - `ReceiveInventoryFormView`
   - `AdjustmentFormView`
   - `ScanFlowSheet` (its scanner root; its nested Recibir, Ajustar and Nuevo sheets get the strip from their own roots)
   - `CreateProductView`

   Then change Recibir's `PrimaryActionBar` title to `"Recibir en \(name)"`. Keep `doneTitle` as is. Check that a long store name truncates instead of wrapping.

   Smoke in the simulator, **receiving** (critical flow), with the local test data, as Test (Sucursal Prueba + farmacia dev ops):
   - Productos → a product → Recibir. The strip shows Sucursal Prueba in its color, and the button reads "Recibir en Sucursal Prueba".
   - Switch to farmacia dev ops from Inicio, then reopen Recibir. The color and name have changed.
   - Scanner → Contar. The strip is visible above the camera.
   - Log in as a single-store employee. No strip appears, and the button still names the store.

5. **Docs.**
   - README: add the store strip to the Inventory features.
   - Mark this epic ✅ with its commit hashes.
   - Run `graphify update .`.

## Out of scope

- An owner-chosen color per store (needs a `Location.color` field + admin UI in farmacia-ops). Revisit if collisions confuse people.
- A strip on the tabs (Inicio already names the store).

## Outcome (2026-11-08)

- Prod store ids checked for collisions: Farmacia Lolita → plum (4), Oriente → green (3). Both are pinned in `StoreTintTests`.
- On device, the solid fill was too loud and bled up behind the nav bar. It's now a 35% tint with the icon and a 2pt bottom edge in the full color, the name in primary text, and `ignoresSafeAreaEdges: []`. The user approved the look in light and dark mode on both stores.
- Review nits applied: `precondition(paletteCount > 0)`, and the action bar title gets `.minimumScaleFactor(0.8)` before truncating.
- Local data has a single store (farmacia dev ops), so the simulator only confirmed the strip stays hidden for one store. The multi-store check was done on device.
