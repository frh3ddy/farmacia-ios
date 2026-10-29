---
description: Plan a feature or fix as small TDD steps (AIDD /task, Swift-adapted)
argument-hint: <feature or bug description>
---

Plan this work as a task epic: $ARGUMENTS

1. Read what it touches first (`graphify query "<question>"`, then the files). For API changes, check the `farmacia-ops` controller and `prisma/schema.prisma`.
2. Split into the logic part (goes to/stays in `FarmaciaKit`, unit-tested) and the UI part (SwiftUI in `FarmaciaApp`).
3. Write the epic as a numbered list of small steps. Each logic step names its first failing test as `given X, should Y`. Each UI step names the critical flow (if any) to smoke in the simulator.
4. Note what must migrate from the app into FarmaciaKit (migrate-as-touched rule in the `swift-tdd` skill).
5. Name the branch: `feature/{desc}` or `fix/{desc}`.

Output the plan only — don't write code. Ask about anything that changes behavior and can't be inferred.
