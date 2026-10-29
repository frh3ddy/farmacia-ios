---
name: swift-tdd
description: Red/green TDD loop for farmacia-ios. Use whenever implementing or fixing behavior in the iOS app — business logic, models, date/money math, request building, parsing, view-model logic. Puts logic in the FarmaciaKit local package and tests it with Swift Testing via `swift test` (seconds, no simulator); reserves simulator/UI checks (XcodeBuildMCP) for critical flows.
---

# Swift TDD (farmacia-ios)

Adapted from paralleldrive/aidd's TDD skill for Swift. One requirement at a time; never write production code without a failing test that needs it.

## Where code goes

- **`FarmaciaKit/`** (local Swift package, Foundation only): models, parsing, formatting, money/date math, request building, retry/error logic. Tested in `FarmaciaKit/Tests/FarmaciaKitTests/`.
- **`FarmaciaApp/`**: SwiftUI views, `@MainActor` view models, `APIClient`, Keychain, SwiftData, UIKit bridges. Keep these thin; push decisions down into FarmaciaKit.
- **Migrate as touched:** when a task changes logic that still lives in the app, first move the pure part into FarmaciaKit (mark the used API `public`, add `import FarmaciaKit` in callers), then test it. Don't mass-migrate.
  - SwiftUI-only members (e.g. `var color: Color`) stay behind as app-side extensions.
  - A view model needs testing? Introduce a protocol covering only the `APIClient` calls that VM uses, inject it, fake it in the test. Not before.
- New files in FarmaciaKit need **no** pbxproj edits (SPM picks them up). New files in `FarmaciaApp/` still do.

## The loop

1. **RED** — write one `@Test` for the next requirement. Run `cd FarmaciaKit && swift test --filter <SuiteOrTest>`. Confirm it fails *for the expected reason* (not a typo/compile error you didn't intend).
2. **GREEN** — the minimum code to pass. Rerun the filter.
3. **REFACTOR** — clean up with the full suite green: `cd FarmaciaKit && swift test`.
4. Repeat 1–3 until the requirement is done.
5. **App compiles** — `xcodebuild -project FarmaciaApp.xcodeproj -scheme FarmaciaApp -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build` (or the XcodeBuildMCP simulator build tool).
6. **Specialist review** of what you touched:
   - SwiftUI views/state/navigation → `swiftui-pro` skill.
   - Slow lists, excess body updates → `swiftui-performance`.
   - async/await, actors, `Sendable`, `@MainActor` → `swift-concurrency-pro`.
7. **Critical flow touched?** Smoke it in the simulator via XcodeBuildMCP (build & run, describe UI / tap, screenshot, logs). Critical flows: device activation → PIN login → location switch; receive inventory (incl. purchase order); report/dashboard date ranges; expense create.
8. `graphify update .`

## Test style (Swift Testing)

```swift
import Testing
@testable import FarmaciaKit

struct LocalDayTests {
    @Test("given 11pm in Mexico City, should send the local day, not the GMT one")
    func lateEvening() { #expect(LocalDay.string(from: date, timeZone: mx) == "2026-03-10") }

    @Test("given a YYYY-MM-DD string, should round-trip", arguments: ["2026-01-01", "2026-12-31"])
    func roundTrips(day: String) throws { ... try #require(...) ... }
}
```

Every test answers aidd's five questions: what unit, what behavior (`given X, should Y` display name), actual value, expected value, how to reproduce (deterministic inputs — fixed dates, explicit `TimeZone`, no network, no `Date()` / `.current` inside assertions).

- `#expect` for checks, `try #require` to unwrap/stop, `#expect(throws:)` for errors, `@Test(arguments:)` instead of copy-pasted cases.
- Inject time/timezones/delays as parameters with production defaults (see `LocalDay(timeZone:)`, `RetryPolicy(baseDelay:)`) so tests never sleep or depend on the machine's zone.
- Bug fix = first a test that reproduces the bug (RED), then the fix.
- Prove a new regression test bites: temporarily break the code, see it fail, restore.

## Don'ts

- No XCTest for new unit tests; no simulator for logic tests.
- No SwiftUI/UIKit/SwiftData imports in FarmaciaKit.
- Don't persist the session token anywhere (see CLAUDE.md rules).
