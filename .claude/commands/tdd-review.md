---
description: Review the current diff for farmacia-ios (AIDD /review, Swift-adapted)
---

Review the current branch's diff against `main` (`git diff main...HEAD` plus uncommitted changes).

Check, in order:

1. **Tests**: every behavior change in logic has a Swift Testing test in `FarmaciaKit/Tests/` that would fail without it. `cd FarmaciaKit && swift test` is green.
2. **Placement**: pure logic lives in FarmaciaKit (Foundation only); the app layer stays thin.
3. **Correctness**: dates use `LocalDay` for `YYYY-MM-DD` fields; money uses `Decimal`; errors surface to the user; no session token persisted.
4. **SwiftUI**: apply the `swiftui-pro` skill to changed views; `swiftui-performance` if lists/scrolling changed.
5. **Concurrency**: apply `swift-concurrency-pro` to changed async code.
6. **Build**: the app builds for `generic/platform=iOS Simulator`.

Report findings ranked by severity with `file:line`. Don't fix unless asked.
