# farmacia-ios

SwiftUI iOS app (iOS 17+, Xcode 15+, Swift 5.9) for the Farmacia multi-location
pharmacy system — mobile front end to the `farmacia-ops` NestJS API. Device
(deviceToken) + employee-PIN (sessionToken) auth, inventory receiving/adjustments,
reports (COGS, margin, valuation, P&L), expenses, Square sync visibility.

Xcode project: `FarmaciaApp.xcodeproj` (single `FarmaciaApp` target). Source under
`FarmaciaApp/` — `App/`, `Core/` (Network, Auth, Storage, Extensions), `Features/*/Views`, `Models/`.

> Global rules live in `~/dev/CLAUDE.md` and `~/CLAUDE.md`. This file is project-specific only.

## Session checklist — if working on X, read Y

- **Architecture / "where does X live" / data flow** → `graphify query "<question>"` (graph at `graphify-out/`). Don't browse `FarmaciaApp/` blind.
- **README.md** has the full auth flow, API headers, and feature breakdown — read it before touching Auth or Network code.
- **SwiftUI code** (views, state, `@Observable`, navigation) → the `swiftui-pro` skill. **SwiftUI perf / slow scrolling / excessive body updates** → `swiftui-performance`.
- **Swift concurrency** (async/await, actors, `Sendable`) → the `swift-concurrency-pro` skill.
- **API contract** — the backend is `farmacia-ops` (`apps/api`). Endpoints live in its NestJS controllers; models mirror `farmacia-ops/prisma/schema.prisma`.
- After changing code, run `graphify update .` (AST-only, no API cost).

## Workflow

- Branch: `feature/{desc}` or `fix/{desc}` — never develop on `main`.
- Commit: `{type}: {description}` (feat/fix/refactor/test/docs/chore).
- Commit or push only when asked.

## Build & test

```
xcodebuild -project FarmaciaApp.xcodeproj -scheme FarmaciaApp -destination 'generic/platform=iOS Simulator' -derivedDataPath build/DerivedData build
```

- Release build + install: `scripts/release-build-install.sh`
- Open in Xcode: `open FarmaciaApp.xcodeproj`
- Simulator run / UI / logs / screenshots → the XcodeBuildMCP server (`.mcp.json`, config in `.mobilebuildmcp/config.yaml`).

## Local test

Business logic lives in the local package `FarmaciaKit/` (Foundation only) and is tested with Swift Testing on the Mac host — no simulator:

```
cd FarmaciaKit && swift test
```

- Any behavior change → follow the `swift-tdd` skill (red/green/refactor, migrate-as-touched). Commands: `/task` (plan), `/execute` (TDD steps), `/tdd-review`.
- Simulator/UI checks only for critical flows (activation → PIN → location switch, receiving, report date ranges, expense create).

## Rules

- Don't persist the session token to the Keychain. Instead keep it in memory only (4-hour expiry); only the device token goes to Keychain.
  Because: sessions are short-lived and per-employee, and persisting them defeats the PIN gate.
- Don't commit build output. Instead keep `build/` gitignored.
  Because: xcarchives and exports are large binaries that bloat history.
- Don't hand-maintain an architecture doc. Instead update the graphify graph (`graphify update .`).
  Because: prose docs drift; the graph regenerates from the AST.
- Don't import SwiftUI/UIKit/SwiftData in `FarmaciaKit`. Instead keep UI-only members (e.g. `Color`) as app-side extensions.
  Because: the package must build and test on macOS with `swift test` in seconds.
- Don't hand-roll `yyyy-MM-dd` formatters. Instead use `LocalDay.string(from:)` / `LocalDay.date(from:)`.
  Because: `ISO8601DateFormatter` defaults to GMT and sent the wrong day to the API (1d7d355).
