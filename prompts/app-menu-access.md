# App Menu Permission Access — Shell Destinations, Routes, and Screens

Enforce **permission-based** visibility on every app menu item so users only see and open routes/screens their **effective permissions** allow—including **custom roles**. Do **not** gate shell menus on canonical `AppRole` membership. **Each screen/route must have its own unique entry permission**; a single permission must unlock **at most one** shell route. Define all route/screen entry gates in **one central catalog**—no scattered per-feature entry vocabularies. Unauthorized destinations must not appear; unauthorized deep links must not render the target screen.

## Context

- Surface: shell navigation in `app_router.dart` via `_localizedShellDestinations` filtered by `canAccessShellRoute`.
- **Central catalog (required):** one frontend module (e.g. `frontend/lib/core/permissions/route_access_catalog.dart`) maps every `AppRouteData` / route name → unique entry `AccessRequirement` (permission ∩ modules ∩ context flags). `AppRoutes`, `canAccessShellRoute`, `AppRouteGuards`, badges, Settings/Home links, and feature `routeEntry` aliases **must read only from this catalog**—never redefine entry keys in feature `*_access.dart`.
- Vocabulary: register keys in `backend/src/config/permissions.js` and `AppPermissions`. Treat `requiredAnyRoles` as legacy: **must not deny** when catalog permission + modules are met.
- **Anti-patterns:** shared entry lists (OPD via `billing:read` / `operations:read` / …); duplicate entry requirements across features. Billing/operations must not open OPD or other non-matching routes.
- Custom roles: `permissionScopedDomainsFor` follows each catalog entry’s unique domain (no empty `{}`; no domain unlocking a second route). Focused packs may narrow chrome; expanded grants unlock only destinations with their own catalog key.
- Effective access = union(permission grants) ∩ subscription ∩ plan caps ∩ ABAC (`prompts/ui-permissions/_shared-rules.md`, `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`). Backend authoritative. Follow `prompts/.cursor/prompt.mdc`.

## Unique route-entry permission matrix

**Rule:** one shell route ↔ one dedicated entry permission, declared **only** in the central catalog. Never reuse that key as another route’s entry gate. In-screen CRUD may use module verbs; **menu/route entry must not share them across routes**.

| Menu / route | Entry permission (unique) | Module (plan ∩) |
| --- | --- | --- |
| Home / Settings | authenticated core only | — |
| Reception | `reception:read` | patient-registry, scheduling-queue |
| Patients | `patients:read` | patient-registry |
| OPD | `opd:read` only — **not** billing/operations/patient/clinical/emergency | scheduling-queue |
| Emergency | `emergency:read` | per route module |
| IPD / Rooms & beds / ICU / Nursing | `ipd:read` / `rooms_beds:read` / `icu:read` / `nursing:read` | per route module |
| Clinical / Physio / Theater / Discharge | `clinical:read` / `physiotherapy:read` / `theater:read` / `discharge:read` | per route module |
| Lab / Radiology / Pharmacy | `lab:read` / `radiology:read` / `pharmacy:read` | matching workflows modules |
| Billing / Claims | `billing:read` / `claims:read` | billing-payments / insurance-claims |
| Subscriptions | `subscriptions:read` | subscription-controls |
| Operations / Housekeeping / Biomedical / Mortuary | `operations:read` / `housekeeping:read` / `biomed:read` / `mortuary:read` | per route module |
| HR / Communications / Integrations / Reports | `hr:read` / `communications:read` / `integration:read` / `reports:read` | matching modules |
| Setup / Access admin | `setup:read` / `access_admin:read` (distinct) | — |

Keep an existing key only if it uniquely maps to that one workspace; otherwise add the dedicated key, register it centrally, and migrate packs.

## Requirements

1. Create/consolidate **one central route/screen access catalog** mapping every authenticated route → unique entry permission, modules, and context flags. Wire `AppRouteData` / shell filtering / guards to resolve from it only.
2. Inventory shell destinations and secondary navigators; replace multi-route keys and feature-local entry redefinitions with catalog lookups/aliases.
3. Apply the matrix: unique entry permission per route; OPD = `opd:read` only. Register missing keys in `backend/src/config/permissions.js` and `AppPermissions`; update role/custom-role catalogs. Neutralize `requiredAnyRoles` hard denies when permissions are present.
4. Align `permissionScopedDomainsFor` to each catalog entry’s unique domain.
5. Filter with `canAccessShellRoute`; collapse empty groups; no disabled stubs. Guard deep links; redirect denied to forbidden; never paint denied bodies.
6. Gate secondary links and badges via the catalog entry for the **target** route.
7. Preserve authorized UI states; rebuild destinations after permission refresh without relaunch.
8. Tests: (a) catalog is sole source for shell + guard entry; (b) route only with its unique key; (c) billing/operations alone ≠ OPD; (d) one key ≠ another route; (e) custom role with only `opd:read` (+ modules) sees OPD only; (f) missing key ⇒ absent + forbidden; (g) module denial hides; (h) secondary links/badges follow catalog. Cover guards, reuse, one mobile + one desktop viewport, light + dark.

## Constraints

- Scope: central route-access catalog, shell destinations, route guards, unique entry permissions (backend + frontend), domain scoping, badges, secondary navigators. Do not redesign in-screen tab atoms (`prompts/ui-permissions/**`) beyond pointing `routeEntry` at the catalog.
- Reuse `AppAccessPolicy`, `AccessRequirement`, `canAccessShellRoute`, `AppRouteGuards`, `AppRoutes`; **one** shared entry catalog—no parallel feature entry vocabularies, no new role-only gates, no shared multi-route entry ∪ lists.
- Theme tokens; responsive without clipping, overflow, duplication, or invalid selected indices.
- Backend authoritative; no exploit/PoC; no secrets—use permission fixtures (custom-role and billing/operations≠OPD cases).
- Optional enhancements: none.

## Acceptance Criteria

- AC1 (Req 1-3): A single central catalog defines every non-core route/screen entry gate; each has a unique permission; no permission unlocks more than one route; OPD is not reachable via billing or operations grants.
- AC2 (Req 2, 5-6): Shell, guards, badges, and secondary links consume the catalog only; unauthorized UI does not render.
- AC3 (Req 5): Denied deep links redirect to forbidden and never show the restricted screen.
- AC4 (Req 3-4): Custom roles with a route’s unique key (+ modules/scope) open that route only; domain scoping does not leak or blank-deny entitled custom roles.
- AC5 (Req 7): Loading, empty, error, success, and forbidden-feedback states remain observable; destinations refresh when permissions change.
- AC6 (Req 8): Tests prove central catalog ownership, one-permission↔one-route, billing/operations≠OPD, custom-role isolation, badges, viewports, and themes.

## Relevant Files

- `frontend/lib/core/permissions/` (**new/central** `route_access_catalog.dart` or equivalent), `app_permission.dart`, `access_policy.dart`, `access_requirement.dart`
- `frontend/lib/app/router/app_router.dart`, `app_routes.dart`, `shell_route_access.dart`, `route_guards.dart`, `shell_badge_counts.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`, `frontend/lib/features/home/`
- Feature `*_access.dart` files (aliases to catalog only)
- `frontend/test/app/router/shell_route_access_test.dart` (+ catalog unit tests)
- `backend/src/config/permissions.js`
- `prompts/ui-permissions/_shared-rules.md`, `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`
