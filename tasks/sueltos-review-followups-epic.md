# Sueltos Review Follow-ups Epic

**Status**: 📋 OPEN (2026-11-09)
**Goal**: Close the small gaps dev-67 found reviewing the Sueltos screen and its barcode scan (`tasks/sueltos-link-epic.md`).

## Overview

dev-67 approved `c9a0be9..683edf8` on 2026-11-09 with no blockers. It was merged to main as `683edf8`, and the release build was installed on the iPhone 13 Pro and the 15 Pro ("iPhone lolita") the same day. The items below are open, and none blocks the feature.

---

## 📋 1. Device check: a scan that matches several products

Not reachable in the simulator: no two local products share a barcode. `LooseLinkForm.scanPick` is tested, so the risk is only in the UI.

- On a phone, scan a box and suelto that share a barcode. Both rows should be listed, and tapping one should select it.
- Production API: tap Cambiar afterwards instead of Vincular.

## 📋 2. Productos' scanner says when the camera fails

`ScanFlowSheet.handleScan` (`.failure`) just dismisses. Sueltos now says "No se pudo usar la cámara. Revisa el permiso en Ajustes o escribe el nombre."

- Do the same in Productos.
- If the wording is shared, it becomes a FarmaciaKit constant with a test.

## 📋 3. Before Swift 6 language mode: `BarcodeLookup.searchVariants` isolation

It takes non-Sendable closures. That's fine in Swift 5 mode, where they take on the MainActor.

- Before switching `FarmaciaKit` to `.v6`, add `isolation: isolated (any Actor)? = #isolation`, so it runs on the caller's actor and the "sending non-Sendable" errors never show up.
- Not now.

## ❓ 4. Relinking an already-linked box asks nothing

Picking a box that's already linked at this store and tapping Vincular replaces its suelto without a confirmation. "Suelto actual" and "ya vinculado" are on screen.

- Keep it if the web works the same way. Check BreakBulkScreen.tsx before changing anything.
