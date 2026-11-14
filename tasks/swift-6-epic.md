# Epic: Swift 6 language mode (app + FarmaciaKit)

**Branch:** `refactor/swift-6` (from `main`, after `feature/product-detail-redesign` merges)
**Goal:** data races become build errors instead of rare crashes or wrong numbers. No behavior change; the 739 Kit
tests are the regression net, and the critical flows get a simulator smoke test.

## Measured (2026-11-10, Xcode compiler Swift 6.4)

Both targets are in Swift 5 mode today: the app has `SWIFT_VERSION = 5.0`, and the Kit has `swiftLanguageModes: [.v5]`
(set in `66176b5` when the package was added).

| Build (overrides only, no file changes) | Unique diagnostics |
|---|---|
| App, `SWIFT_STRICT_CONCURRENCY=complete` | 72 warnings, mostly "sending X risks data races" (54) in view models calling `APIClient` |
| App + main-actor default isolation + approachable concurrency | 21 (1 error). 18 of them are artifacts: the command-line override also isolated FarmaciaKit. **3 real** |
| FarmaciaKit, `-swift-version 6` | **1 error**: `Deadline.RaceState` isn't `Sendable` |

The 3 real app diagnostics:
- `ProductsViewModel.swift:249` **error**: `Product`'s main-actor `Identifiable` conformance can't satisfy a `Sendable`
  requirement (`ProductSync.run`).
- `ProductsViewModel.swift:134`: `ProductListResponse`'s `Decodable` conformance is used in a `@concurrent` context.
- `APIClient.swift:230`: an `await` with nothing async in it.

More may appear once the error is fixed (the compiler can stop a file at its first error), so plan for "a few dozen at
most", not 3.

## Decisions

- **App target: main-actor default isolation + approachable concurrency** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`). It fits a UI app, and the 72 warnings drop to a handful.
- **FarmaciaKit stays nonisolated.** It's pure logic that background work calls (photo reading, decoding, sync).
- **Kit first.** It's the smallest step, it's tested in seconds, and the app depends on it.
- **The one real risk:** under approachable concurrency, a nonisolated `async` function runs on its *caller's* actor.
  With main-actor default, that means heavy work called from a view or view model (Vision text reading, background
  lift, JPEG resize, image downsampling, big JSON decodes) would run **on the main thread** and hitch the UI. Each of
  those gets an explicit `@concurrent` (step 6). This is the step to review hardest.

## FarmaciaKit (`cd FarmaciaKit && swift test`)

1. [ ] `Deadline.RaceState: Sendable`. The compiler is the RED: `swift build -Xswiftc -swift-version -Xswiftc 6` fails
   on `Deadline.swift:17`. GREEN: add the conformance (`T: Sendable`, and `CheckedContinuation` is `Sendable`).
   The existing `DeadlineTests` must stay green. Also build the tests in Swift 6 mode (`--build-tests`) and fix
   whatever surfaces.
2. [ ] Remove `swiftLanguageModes: [.v5]` from `Package.swift`. The Kit is then in Swift 6 mode (tools 6.0).
   Full `swift test` green.

## App (FarmaciaApp)

3. [ ] Turn on, in `project.pbxproj` for the app target only (Debug and Release):
   `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
   `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Stay in Swift 5 mode, so these are warnings only. Build and record the real
   count in this epic.
4. [ ] Models decoded off the main actor become `nonisolated` (`nonisolated struct Product: …`): the API response types
   in `FarmaciaApp/Models/` (13 files, ~150 types) that `APIClient` decodes, starting with `Product` and
   `ProductListResponse`. That fixes the error. Migrate-as-touched: a model that moves into FarmaciaKit instead is
   nonisolated for free.
5. [ ] `APIClient`: make it `nonisolated final class APIClient: Sendable`, so decoding stays off the main actor. Read it
   first: whatever it reads from `AuthManager` (the session token, which stays in memory only, per CLAUDE.md) must cross
   actors safely. Drop the stray `await` (line 230). This should clear most of the 54 "sending X" warnings.
6. [ ] Mark heavy async work `@concurrent` so it doesn't move onto the main thread: `SubjectLifter.liftSubject`,
   `ProductPhotoReader` (Vision), `jpegDataForUpload`, the `CachedProductImage` downsample, and the `ProductSync` page
   decodes. Then grep for other `async` functions that do CPU work.
7. [ ] Delete what main-actor isolation makes redundant, only where touched: the `NSLock` around
   `Product.currencyFormatter` (main-actor static now) and explicit `@MainActor` on types that now get it by default
   (33 occurrences; remove as touched, not in bulk). Keep `NetworkMonitor`'s `DispatchQueue` (`NWPathMonitor` needs one)
   and `ProductImageCache: @unchecked Sendable` (`NSCache` is thread-safe), each with a one-line reason.
8. [ ] Set `SWIFT_VERSION = 6.0`. The build must be clean, with no concurrency warnings left behind.

## Verify

9. [ ] Kit: full `swift test`. App: CLAUDE.md build line. Specialist reviews: `swift-concurrency-pro` (isolation,
   `@concurrent`, `Sendable`) and `swiftui-performance` (main-thread hitches from step 6).
10. [ ] Simulator smoke test (XcodeBuildMCP, local API):
    - device activation → PIN → location switch (`AuthManager`, Keychain)
    - receive inventory from the product detail
    - offline queue: write while offline, reconnect, confirm the replay lands (`OfflineQueueManager`)
    - new product photo → name suggestion within the deadline (`Deadline`, Vision): no UI freeze
    - scroll Productos fast with images: no hitches (watch for main-thread decode/downsample)
11. [ ] Docs: CLAUDE.md "Swift 5.9" → "Swift 6"; README; `graphify update .`.

## Not in this epic

- **Typed throws** (`throws(NetworkError)` on `APIClient.request`): small, separate, and touches every caller's `catch`.
- **`@Observable` migration** (180 `ObservableObject`/`@Published` uses): an iOS 17 feature that doesn't need Swift 6.
  Migrate as touched.
- **Default isolation for FarmaciaKit**: it stays nonisolated on purpose.
