# farmacia-ios

SwiftUI iOS app (iOS 17+, Xcode 15+, Swift 5.9) for the Farmacia multi-location
pharmacy system — mobile front end to the `farmacia-ops` NestJS API. Device
(deviceToken) + employee-PIN (sessionToken) auth, inventory receiving/adjustments,
reports (COGS, margin, valuation, P&L), expenses, Square sync visibility.

Xcode project: `FarmaciaApp.xcodeproj` (single `FarmaciaApp` target). Source under
`FarmaciaApp/` — `App/`, `Core/` (Network, Auth, Storage, Extensions), `Features/*/Views`, `Models/`.

> Global rules live in `~/dev/CLAUDE.md` and `~/CLAUDE.md`. This file is project-specific only.

## When working on X, read Y

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
xcodebuild -project FarmaciaApp.xcodeproj -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15' build
```

- Release build + install: `scripts/release-build-install.sh`
- Open in Xcode: `open FarmaciaApp.xcodeproj`

## Local test

No test target exists yet. When one is added, run:

```
xcodebuild -project FarmaciaApp.xcodeproj -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Rules

- Don't persist the session token to the Keychain. Instead keep it in memory only (4-hour expiry); only the device token goes to Keychain. Because sessions are short-lived and per-employee, and persisting them defeats the PIN gate.
- Don't commit build output. Instead keep `build/` out of git. Because xcarchives and exports are large binaries that bloat history.
- Don't hand-maintain an architecture doc. Instead update the graphify graph. Because prose docs drift; the graph regenerates from the AST.
