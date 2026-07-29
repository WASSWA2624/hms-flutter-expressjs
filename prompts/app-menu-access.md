# App Menu Permission Access — Shell Destinations, Routes, and Screens

Enforce **permission-based** visibility on every app menu item so users only see and open routes/screens their **effective permissions** allow—including **custom roles** that grant those permissions. Do **not** gate shell menus or route entry on canonical `AppRole` membership. Unauthorized destinations must not appear; unauthorized deep links must not render the target screen.

## Context

- Surface: shell navigation (sidebar, rail, drawer, bottom nav) in `app_router.dart` via `_localizedShellDestinations` filtered by `canAccessShellRoute`.
- Catalog: `AppRoutes` / `AppRouteData` — gate with `requiredPermissions` (∩) and/or `requiredAnyPermissions` (∪), `requiredActiveModules`, and tenant/facility flags. Treat `requiredAnyRoles` as legacy: **must not deny** users who already satisfy permission + module requirements (custom roles included).
- Guards: `shell_route_access.dart`, `route_guards.dart`, `AccessRequirement` / `AppAccessPolicy`.
- Custom roles / direct grants: `isPermissionScopedShellUser` + `permissionScopedDomainsFor` must map **permission domains** to workspaces—not empty deny sets that lock entitled custom roles out.
- Focused packs (lab / pharmacist / receptionist / billing) may narrow default chrome for a single canonical role; **expanded grants** must still unlock matching destinations via `isShellRouteUnlockedByExpandedGrant`.
- Secondary entries (Settings → Access admin / Setup / Subscriptions; Home shortcuts/metrics; `context.go` cross-links) use the same permission gate.
- Effective access = union(role/module/user **permission** grants) ∩ subscription ∩ plan caps ∩ ABAC (`prompts/ui-permissions/_shared-rules.md`, `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`). Roles may seed defaults; they are not the menu key.
- Backend authoritative. Follow `prompts/.cursor/prompt.mdc`.

## Menu ↔ route matrix (permission entry gates)

Use exact `AppPermissions` on each `AppRouteData` (add gates where a route is role-only today). Modules remain plan ∩. Domain scoping runs after permission/module checks.

| Menu / route | Semantics | Permission keys / modules |
| --- | --- | --- |
| Home / Settings | authenticated | core |
| Reception | ∪ | `patient:read` \| `last_office:read`; patient-registry, scheduling-queue |
| Patients | ∩ | `patient:read`; patient-registry |
| OPD | ∪ | `patient:read` \| `clinical:read` \| `billing:read` \| `operations:read` \| `emergency:read`; scheduling-queue |
| Emergency / IPD / Rooms & beds / ICU / Nursing / Clinical / Physio / Theater / Discharge | ∪ | matching `*:read` on `AppRoutes.*`; domain-scoped for custom roles |
| Lab / Radiology / Pharmacy | ∪ | `lab:read` / `radiology:read` / `pharmacy:read` + modules |
| Billing / Claims | ∪ | `billing:read` \| `billing:write` (+ `financial:approve` for claims) + modules |
| Subscriptions | ∪ | `subscriptions:read` \| `system:admin` (replace role-only `superAdmin`) |
| Operations / Housekeeping / Biomedical / Mortuary | ∪ | matching `*:read` + modules |
| HR | ∪ | `hr:read` \| `unit:read` \| `roster:read`; hr-rosters |
| Communications / Integrations / Reports | ∪ | `communications:read` / `integration:read` / `reports:read` (+ peers) + modules |
| Setup / Access admin | ∪ | `tenant:admin` \| `facility:admin` \| `system:admin` (not role packs) |

## Requirements

1. Inventory every shell destination plus secondary navigators (Settings, Home metrics/shortcuts, cross-module `context.go`). Map each to permission/module requirements—not canonical role lists.
2. Make entry **permission-first**: every route must have ∩ and/or ∪ `AppPermission` requirements (and modules). Neutralize `requiredAnyRoles` as a hard deny when permissions are present so custom-role users with those grants pass. Replace role-only routes (e.g. Subscriptions) with matrix permission keys.
3. Fix `permissionScopedDomainsFor` empty `{}` denials for workspaces custom roles should reach when they hold matching domain permissions (map IPD/nursing/ICU/etc. to the domains those routes already use).
4. Filter with `canAccessShellRoute` before build; collapse empty groups; no disabled stubs or routine “no access” labels for omitted items.
5. Protect deep links with `AppRouteGuards` using the same permission formula; redirect denied navigations to localized forbidden; never paint a denied screen body.
6. Keep focused-shell narrowing for single canonical roles; always honor expanded grants and permission-scoped custom roles for matching destinations.
7. Gate secondary links and badges the same way (`shell_badge_counts.dart`); never advertise a hidden module.
8. Preserve authorized states: filtered chrome, shell loading, core-only empty shell, session-restore error/retry, success navigation, forbidden feedback. Rebuild destinations after permission refresh without relaunch.
9. Tests in `frontend/test/app/router/`: (a) **custom role / no canonical `AppRole`** + modules + target permissions ⇒ destination present and route opens; (b) same fixture missing those permissions ⇒ absent and deep link forbidden; (c) canonical role name alone does not unlock when permissions are the gate; (d) module/subscription denial hides menu; (e) focused pack + expanded grant unlocks extra destination; (f) secondary links/badges follow permissions. Cover guards, reuse of `canAccessShellRoute`/`AppRouteData`, one mobile and one desktop viewport, light + dark.

## Constraints

- Scope: shell destinations, route guards, permission-first `AppRouteData` fields, domain scoping, badges, secondary navigators. Do not redesign in-screen tab atoms (`prompts/ui-permissions/**`) or IA beyond collapsing empty groups.
- Reuse `AppAccessPolicy`, `AccessRequirement`, `canAccessShellRoute`, `AppRouteGuards`, `AppRoutes`; no second vocabulary; **do not add new role-only gates**.
- Theme tokens; responsive without clipping, overflow, duplication, or invalid selected indices when the filtered list shrinks.
- Backend authoritative; no exploit/PoC; no secrets—use permission fixtures including custom-role cases.
- Optional enhancements: none.

## Acceptance Criteria

- AC1 (Req 1-3): Every shell/secondary entry is gated by permissions (+ modules/scope); custom roles with those grants are allowed; role packs alone do not unlock menus.
- AC2 (Req 4, 7): Unauthorized destinations, secondary links, and badges do not render; no disabled unauthorized stubs.
- AC3 (Req 5): Denied deep links redirect to forbidden and never show the restricted screen.
- AC4 (Req 2-3, 6): ∩ / ∪ / modules / domain scoping / expanded grants behave as specified; empty domain denials do not block entitled custom roles; subscription/ABAC still strip what the plan forbids.
- AC5 (Req 8): Loading, empty, error, success, and forbidden-feedback states remain observable; destinations refresh when effective permissions change.
- AC6 (Req 9): Tests prove custom-role allowance/denial by permissions, unauthorized absence / authorized presence, focused expanded grants, badges, viewports, and themes.

## Relevant Files

- `frontend/lib/app/router/app_router.dart`, `app_routes.dart`, `shell_route_access.dart`, `route_guards.dart`, `shell_badge_counts.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`, `frontend/lib/features/home/`
- `frontend/lib/core/permissions/access_policy.dart`, `access_requirement.dart`
- `frontend/test/app/router/shell_route_access_test.dart`
- `prompts/ui-permissions/_shared-rules.md`, `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`
- `backend/src/config/permissions.js`
