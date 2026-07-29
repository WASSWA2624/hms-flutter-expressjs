# App Menu Permission Access — Shell Destinations, Routes, and Screens

Enforce **permission-based** visibility on every app menu item so users only see and open routes/screens their **effective permissions** allow—including **custom roles**. Do **not** gate shell menus on canonical `AppRole` membership. **Each screen/route must have its own unique entry permission**; a single permission must unlock **at most one** shell route. Unauthorized destinations must not appear; unauthorized deep links must not render the target screen.

## Context

- Surface: shell navigation in `app_router.dart` via `_localizedShellDestinations` filtered by `canAccessShellRoute`.
- Catalog: `AppRoutes` / `AppRouteData`, `AppPermissions`, `backend/src/config/permissions.js`. Prefer one dedicated entry key per route via `requiredPermissions` (∩). Treat `requiredAnyRoles` as legacy: **must not deny** when permission + module requirements are met.
- **Anti-pattern to remove:** broad shared entry lists (e.g. OPD unlocked by `patient:read` \| `clinical:read` \| `billing:read` \| `operations:read` \| `emergency:read`). Billing and operations grants must **not** open OPD (or any other non-billing/operations route).
- Custom roles: `isPermissionScopedShellUser` + `permissionScopedDomainsFor` must follow the **unique route-entry domain** (e.g. `opd` → OPD only), not empty `{}` denials and not shared domains that leak across menus.
- Focused packs may narrow default chrome; expanded grants unlock only destinations whose **own** entry permission is granted.
- Secondary entries (Settings, Home shortcuts/metrics, `context.go`) use the same unique route-entry permission as the target route.
- Effective access = union(permission grants) ∩ subscription ∩ plan caps ∩ ABAC (`prompts/ui-permissions/_shared-rules.md`, `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`).
- Backend authoritative. Follow `prompts/.cursor/prompt.mdc`.

## Unique route-entry permission matrix

**Rule:** one shell route ↔ one dedicated entry permission. Never reuse that key as another route’s entry gate. Register missing keys in backend + `AppPermissions`, assign them in role/custom-role catalogs, keep module ∩. In-screen CRUD may use module verbs; **menu/route entry must not share them across routes**.

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

Keep an existing key only if it already uniquely maps to that one workspace; otherwise add the dedicated key and migrate packs.

## Requirements

1. Inventory every shell destination and secondary navigator; flag any entry permission used by more than one route as a defect.
2. Give each route a **unique** entry permission per the matrix; remove shared ∪ entry lists. OPD requires only `opd:read`—billing/operations/patient/clinical/emergency must not open it.
3. Add missing keys to `backend/src/config/permissions.js` and `AppPermissions`; update default/custom-role catalogs. Neutralize `requiredAnyRoles` hard denies when permissions are present.
4. Align `permissionScopedDomainsFor` to each route’s unique entry domain (no empty `{}` blank-denies; no domain that unlocks a second route).
5. Filter with `canAccessShellRoute`; collapse empty groups; no disabled stubs. Guard deep links; redirect denied to forbidden; never paint denied bodies.
6. Gate secondary links and badges with the **target route’s unique entry permission**.
7. Preserve authorized UI states; rebuild destinations after permission refresh without relaunch.
8. Tests: (a) route appears only with its unique key; (b) `billing:read` or `operations:read` alone does **not** show OPD; (c) one route’s key does not open another; (d) custom role with only `opd:read` (+ modules) sees OPD only; (e) missing key ⇒ absent + forbidden deep link; (f) module denial hides; (g) secondary links/badges follow unique keys. Cover guards, reuse, one mobile + one desktop viewport, light + dark.

## Constraints

- Scope: shell destinations, route guards, unique entry permissions (backend + frontend catalog + role packs), domain scoping, badges, secondary navigators. Do not redesign in-screen tab atoms (`prompts/ui-permissions/**`) beyond entry gates.
- Reuse `AppAccessPolicy`, `AccessRequirement`, `canAccessShellRoute`, `AppRouteGuards`, `AppRoutes`; extend the shared permission vocabulary—**do not** add role-only gates or shared multi-route entry ∪ lists.
- Theme tokens; responsive without clipping, overflow, duplication, or invalid selected indices.
- Backend authoritative; no exploit/PoC; no secrets—use permission fixtures (include custom-role and billing/operations≠OPD cases).
- Optional enhancements: none.

## Acceptance Criteria

- AC1 (Req 1-3): Every non-core shell/secondary route has a unique entry permission; no permission unlocks more than one route; OPD is not reachable via billing or operations grants.
- AC2 (Req 5-6): Unauthorized destinations, secondary links, and badges do not render; no disabled unauthorized stubs.
- AC3 (Req 5): Denied deep links redirect to forbidden and never show the restricted screen.
- AC4 (Req 3-4): Custom roles with a route’s unique key (+ modules/scope) can open that route only; domain scoping does not leak or blank-deny entitled custom roles.
- AC5 (Req 7): Loading, empty, error, success, and forbidden-feedback states remain observable; destinations refresh when permissions change.
- AC6 (Req 8): Tests prove one-permission↔one-route, billing/operations≠OPD, custom-role isolation, unauthorized absence / authorized presence, badges, viewports, and themes.

## Relevant Files

- `frontend/lib/app/router/app_router.dart`, `app_routes.dart`, `shell_route_access.dart`, `route_guards.dart`, `shell_badge_counts.dart`
- `frontend/lib/core/permissions/app_permission.dart`, `access_policy.dart`, `access_requirement.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`, `frontend/lib/features/home/`
- `frontend/test/app/router/shell_route_access_test.dart`
- `backend/src/config/permissions.js`
- `prompts/ui-permissions/_shared-rules.md`, `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`
