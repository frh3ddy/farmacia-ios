---
description: Execute a planned task epic step by step with red/green TDD (AIDD /execute, Swift-adapted)
argument-hint: <task epic or step to execute>
---

Execute: $ARGUMENTS

Follow the `swift-tdd` skill for every step:

- Be on a `feature/` or `fix/` branch, never `main`.
- Per step: RED (`cd FarmaciaKit && swift test --filter …`, confirm the failure reason) → GREEN (minimum code) → REFACTOR (full `swift test` green).
- After the logic steps: app build for `generic/platform=iOS Simulator`, then the specialist skill review (`swiftui-pro`, `swiftui-performance`, `swift-concurrency-pro`) for what you touched.
- If a critical flow was touched, smoke it in the simulator with the XcodeBuildMCP tools.
- `graphify update .` at the end.

Stop and report after each step if a test fails for a reason you didn't expect. Don't commit unless asked.
