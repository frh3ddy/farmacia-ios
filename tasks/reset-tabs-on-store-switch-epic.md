# Reset Tabs on Store Switch Epic

**Status**: ✅ DONE (uncommitted on the branch)
**Branch**: `fix/reset-tabs-on-store-switch` (farmacia-ios only; no API change)
**Goal**: After a store switch, no tab still shows a screen loaded for the previous store or role.

## Overview

Finding #2 of the 2026-10-31 simulator review:
- As a manager at Sucursal Prueba, Más → Reportes → Valuación de Inventario showed $8.00, 1 unit.
- Test then switched, from Inicio, to farmacia dev ops, where they're a cashier.
- Back in Más, the report was still open. Its reload was refused ("Acceso no autorizado"), and the previous store's valuation stayed on screen with no sign it was stale.
- The Reportes list also stayed open, offering six reports a cashier can't load.

`MainTabView` keeps every tab's `NavigationStack` and `@StateObject`s across a switch; nothing rebuilds them. Only the Productos list (`ProductsView.swift:270`) and the Inicio dashboard (`DashboardView.swift:80`) react to the store.

## What decides the design

- **The role only changes with the store.** `AuthManager.switchLocation` (`AuthManager.swift:244–252`) is the only place it changes mid-session. Login and logout tear `MainTabView` down. So "the store changed" is the one trigger.
- **The switch screen lives in a tab.** It's either a sheet on the Inicio root (`DashboardView.swift:75`) or pushed in Más → Ajustes (`SettingsView.swift:80`). It sets the new store, shows a 0.8 s success animation, then dismisses (`LocationSwitchView.swift:327–342`). Rebuilding *every* tab on the change would destroy it mid-animation.
- **The selected tab is already safe.** At the moment of a switch, the selected tab is either:
  - **Inicio at its root.** Inicio has no pushed screens at all, and its load is keyed on the store.
  - **Más → Ajustes.** The other Más screens (Reportes, Gastos, …) are its siblings, so they're already off the stack, and Ajustes reads the role live.
- **The other tabs are where stale screens hide.** Nobody is looking at them, so they can be rebuilt immediately with no visible jump.

**Decision:** when the store changes, rebuild every tab **except the selected one**, by changing an identity token on each tab's root view. A rebuilt tab starts at its root with fresh view models, so the next visit loads for the new store and role.

**Dropped from the review's suggestion:** clearing a report's data when its reload is refused. With the tabs rebuilt, a report can't survive a switch, and a refused reload can't happen any other way, because the role only changes with the store. Revisit only if that changes.

**Behaviour changes, accepted:**
- Productos loses its search text and filter chip on a switch; the list already reloads per store.
- Alertas and Más return to their root screens.

## Logic / UI split

- **FarmaciaKit:** `TabReset.tabsToReset(all:selected:)`, which picks the tabs to rebuild after a store change. It's generic over the tab type, so `MainTabView.Tab` stays in the app.
- **FarmaciaApp:** `MainTabView` keeps one token per tab, applies `.id(token)` to each tab's root view, and refreshes the tokens of the tabs to reset when `authManager.currentLocation?.id` changes.

**Migrate as touched:** nothing has to move. `MainTabView` has no logic today beyond `refreshTrigger`.

---

## Steps

1. **Logic — which tabs to rebuild.** `TabReset.tabsToReset(all:selected:)` in FarmaciaKit.
   First failing test: *given a store change while Más is selected, should rebuild Inicio, Productos and Alertas but not Más.*
   Then: *given Inicio selected, should rebuild the other three.*

2. **UI — rebuild the tabs in `MainTabView`.**
   - Add `@State private var tabTokens: [Tab: UUID]` and apply `.id(tabTokens[tab])` to each of the four root views.
   - Add `.onChange(of: authManager.currentLocation?.id)` that gives a new UUID to each tab from step 1.
   - Keep `.tag` and `selectedTab` unchanged, so the selection survives.

   Smoke in the simulator — **location switch** (critical flow), with the local test data:
   - As Test, a manager at Sucursal Prueba, open Más → Reportes → Valuación ($8).
   - From Inicio, switch to farmacia dev ops, where Test is a cashier, and watch the success animation finish.
   - Back in Más: it's at its root, showing only Ajustes.
   - Repeat with a product detail open in Productos: Productos is back at its list.
   - Switch from Más → Ajustes: the success animation finishes and Ajustes stays open.

3. **Specialist review.** Run `swiftui-pro` on `MainTabView` for the `.id` reset and state lifetime. Run `swiftui-performance`: four tab roots are rebuilt once per switch, which is rare and acceptable, so check only that nothing rebuilds on ordinary tab changes.

4. **Docs.**
   - README: the store-switch behaviour.
   - Mark review finding #2 done in the follow-ups record.
   - Run `graphify update .`.

## Done

`TabReset.tabsToReset(all:selected:)` (FarmaciaKit, 2 tests, 184 total pass) and per-tab `.id` tokens in `MainTabView`. Simulator smoke with the local test data passed:
- After a manager → cashier switch from Inicio, Más was back at its root showing only Ajustes (the open Valuación report was gone).
- A switch from Más → Ajustes kept Ajustes open, and the switch screen dismissed normally.
- A product detail left open in Productos came back at the list, loaded for the new store.

Noticed in passing and fixed: Ajustes' header showed the role in English ("Cashier" / "Manager", from `role.rawValue.capitalized`); it now uses `EmployeeRole.displayName` ("Cajero" / "Gerente"), checked in the simulator.

## Out of scope

- **Older stores' figures kept by the selected tab:** none, by the reasoning above. If a new pushed screen is ever added to Inicio, or a store switch added outside Inicio and Ajustes, revisit "except the selected tab".
