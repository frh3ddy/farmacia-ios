# Photo Name Review Follow-ups Epic

**Status**: 📋 OPEN (2026-11-08)
**Goal**: Finish and tune the photo product name feature (`tasks/photo-product-name-epic.md`) once it has run on real phones.

## Overview

All the feature's code is done on `feature/photo-product-name` and uncommitted: 590 tests pass and the app builds. The Release build was installed on the iPhone 13 Pro and the 15 Pro ("iPhone lolita") on 2026-11-08. The 📋 items below are still open, in order. The ones marked "only if" wait on what the device test shows.

---

## 📋 1. Device test on both phones

Use real products from the shelf, and cancel each form instead of tapping Crear (production API).

- A box with a printed name: Nombre and Descripción fill in.
- A product with no readable text: Nombre gets object + color.
- A name typed first: it stays, and a suggestion chip appears.
- Photo A, then photo B right away: only B's name lands in the form.
- Remove the photo during "Leyendo foto…": nothing fills in afterwards.
- Console.app, `category:PhotoName`: the 15 Pro's cold, warm and A→B times; the 13 Pro should log "skipped".

## 📋 2. Reviewer sign-off

Send the device results to the reviewer (dev-79) for final approval.

## 📋 3. Commit, merge, push

Only when the user asks. Push only after the reviewer signs off.

---

## 📋 4. Biberón instead of Botella (needs a decision)

Vision only sees `bottle`, so a baby bottle reads "Botella". The stores stock many baby bottles. A rule would be something like `baby` + `bottle` → "Biberón". It's the kind of special case dropped for the teddy bear, so ask the user first.

## 📋 5. Run Apple Intelligence alongside Vision (only if the 15 Pro is slow)

Today the model is asked after Vision so it gets the label text, which means waiting for Vision plus up to 5 s (`CreateProductView.readPhoto`).

## 📋 6. Skip the model while an earlier request is still running (only if the A→B swap times out)

This was the reviewer's suggestion: keep the last `LanguageModelSession` and skip the model when `session.isResponding`, instead of starting a second request (`ModelProductNamer.ask`).

## 📋 7. Keep the prewarmed session for the first photo (only if the log shows cold starts)

`ModelProductNamer.prewarm()` warms a throwaway session.

## 📋 8. Share the subject mask (only if photos feel slow)

The subject mask runs twice per photo, once in `ProductPhotoReader` and once in `SubjectLifter`.

## 📋 9. Better object color (only if colors come out wrong)

`DominantColor` averages the whole cutout, so a two-tone product averages to a third color. Clustering colors would fix it.

## 📋 10. Products Vision can't recognize

Vision has no label for combs, razors, batteries, mirrors, sponges or perfume, all of which the stores stock. On the 13 Pro these get the printed name or nothing. This is a known limit; act only if it bothers users.
