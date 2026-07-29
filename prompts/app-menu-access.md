# App Menu Permission Access — Shell Destinations, Routes, and Screens

Enforce permission-based visibility on every app menu item so users only see and open routes/screens their **effective** permissions allow. Unauthorized destinations must not appear in navigation; unauthorized deep links must not render the target screen.

## Context

- Surface: shell navigation (sidebar, rail, drawer, bottom nav) in `app_router.dart` via `_localizedShellDestinations` filtered by `canAccessShellRoute`.
- Catalog: `AppRoutes` / `AppRouteData` (`requiredPermissions` ∩, `requiredAnyPermissions` ∪, `requiredAnyRoles`, `requiredActiveModules`, tenant/facility flags).
- Guards: `shell_route_access.dart`, `route_guards.dart`, `AccessRequirement` / `AppAccessPolicy`.
- Focused packs: lab / pharmacist / receptionist / billing allowlists; custom-role domains via `permissionScopedDomainsFor`.
- Secondary entries (Settings → Access admin / Setup / Subscriptions; Home shortcuts/metrics; workspace `context.go` cross-links) must use the same gate.
- Effective access = union(role/module/user grants) ∩ subscription ∩ plan caps ∩ ABAC (`prompts/ui-permissions/_shared-rules.md`, `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`).
- Backend remains authoritative. Follow `prompts/.cursor/prompt.mdc`.

## Menu ↔ route matrix (entry gates)

Align code to exact keys already on each `AppRouteData`; do not invent a second vocabulary.

| Menu / route | Path | Semantics | Typical keys / modules |
| --- | --- | --- | --- |
| Home | `/` | authenticated | core |
| Reception | `/reception` | ∪ | `patient:read` \| `last_office:read`; `patient-registry`, `scheduling-queue` |
| Patients | `/patients` | ∩ | `patient:read`; `patient-registry` |
| OPD | `/opd` | ∪ | `patient:read` \| `clinical:read` \| `billing:read` \| `operations:read` \| `emergency:read`; `scheduling-queue` |
| Emergency | `/emergency` | ∪ | per `AppRoutes.emergency` |
| IPD / Rooms & beds / ICU / Nursing | workspace paths | ∪ | per matching `AppRoutes.*` |
| Clinical | `/clinical` | ∪ | `clinical:read` (+ roles/modules) |
| Physiotherapy / Theater / Discharge | workspace paths | ∪ | per matching `AppRoutes.*` |
| Lab / Radiology / Pharmacy | workspace paths | ∪ | `lab:read` / `radiology:read` / `pharmacy:read` + modules |
| Billing | `/billing` | ∪ | `billing:read` \| `billing:write`; `billing-payments` |
| Claims | `/claims` | ∪ | `billing:read` \| `billing:write` \| `financial:approve`; `insurance-claims` |
| Subscriptions | `/subscriptions` | role | `superAdmin` unless source already differs |
| Operations / Housekeeping / Biomedical / Mortuary | workspace paths | ∪ | per matching `AppRoutes.*` |
| HR | `/hr` | ∪ | `hr:read` \| `unit:read` \| `roster:read`; `hr-rosters` |
| Communications / Integrations / Reports | workspace paths | ∪ | `communications:read` / `integration:read` / `reports:read` + modules |
| Settings | `/settings` | authenticated | core |
| Setup | setup path | admin/setup pack | `AppRoutes.tenantFacilitySetup` |
| Access admin | via Settings | admin pack | `AppRoutes.accessAdmin` |

Focused-shell allowlists and permission-domain scoping apply **after** `AccessRequirement.isAllowed`.

## Requirements

1. Inventory every shell destination in `_localizedShellDestinations` plus non-shell navigators that open app screens (Settings rows, Home metric/shortcut navigation, cross-module `context.go`). Map each to its `AppRouteData.accessRequirement`.
2. Align each entry gate with the matrix and the route’s existing ∩ / ∪ / roles / modules / context flags. Fix menu-vs-route drift so both share one source of truth on `AppRouteData`.
3. Filter destinations with `canAccessShellRoute` before build so unauthorized items never mount in any shell chrome. Collapse empty navigation groups. Do not render disabled menu stubs or routine “no access” labels for omitted items.
4. Protect entry with `AppRouteGuards`: require authenticated session; redirect unauthorized deep links / typed navigation to localized forbidden (or documented equivalent). Never paint a denied screen body.
5. Keep focused-shell allowlists and `permissionScopedDomainsFor` so focused and custom-role-only users cannot leak across modules via broad ∪ lists. Extra unlocks only via existing `isShellRouteUnlockedByExpandedGrant`.
6. Gate secondary entry points the same way; omit the control when `canAccessShellRoute` (or equivalent) denies.
7. Compute shell badges only for accessible routes (`shell_badge_counts.dart`); never advertise a hidden module.
8. Preserve authorized states: filtered chrome, shell loading, empty shell (core-only when that is all they have), session-restore error/retry, successful navigation, forbidden feedback for restricted deep links. Rebuild destinations after permission refresh without relaunch.
9. Add/update tests in `frontend/test/app/router/` (and shell/layout as needed) proving: (a) missing ∩ or ∪ rights ⇒ destination absent and deep link forbidden; (b) satisfying grants ⇒ destination present and route opens; (c) module/subscription denial hides menu despite role pack strings; (d) focused/custom-role non-leakage; (e) secondary links omit unauthorized targets; (f) badges only for allowed routes. Cover guard integration, reuse of `canAccessShellRoute`/`AppRouteData`, authorization, sync after permission change, one mobile and one desktop viewport, light + dark themes.

## Constraints

- Scope: shell destinations, route guards, `AppRouteData` access fields, badge gating, and secondary navigators into those routes. Do not redesign in-screen tab atoms (`prompts/ui-permissions/**`) or navigation IA beyond collapsing empty groups.
- Reuse `AppAccessPolicy`, `AccessRequirement`, `canAccessShellRoute`, `AppRouteGuards`, `AppRoutes`, and existing shell widgets; no second permission vocabulary.
- Theme tokens; responsive mobile/tablet/desktop without clipping, overflow, duplication, or invalid selected indices when the filtered list shrinks.
- Backend RBAC/ABAC authoritative; no exploit/PoC code; no secrets in tests—use policy fixtures.
- Optional enhancements: none.

## Acceptance Criteria

- AC1 (Req 1-2): Every shell and secondary menu entry maps to one `AppRouteData` gate aligned with the matrix.
- AC2 (Req 3, 6-7): Unauthorized destinations, secondary links, and badges do not render; no disabled unauthorized stubs.
- AC3 (Req 4): Denied deep links redirect to forbidden (or documented equivalent) and never show the restricted screen.
- AC4 (Req 2, 5): ∩ / ∪ / roles / modules / focused packs / domain scoping behave as specified; subscription/ABAC strips menus role packs alone would allow.
- AC5 (Req 8): Loading, empty, error, success, and forbidden-feedback states remain observable; destinations refresh when effective permissions change.
- AC6 (Req 9): Tests prove unauthorized absence and authorized presence (including ∩ denial and ∪ allowance), focused/custom-role non-leakage, secondary-link gating, badges, viewports, and themes.

## Relevant Files

- `frontend/lib/app/router/app_router.dart`
- `frontend/lib/app/router/app_routes.dart`
- `frontend/lib/app/router/shell_route_access.dart`
- `frontend/lib/app/router/route_guards.dart`
- `frontend/lib/app/router/shell_badge_counts.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`
- `frontend/lib/features/home/` (metric/shortcut navigation)
- `frontend/lib/core/permissions/access_policy.dart`
- `frontend/lib/core/permissions/access_requirement.dart`
- `frontend/test/app/router/shell_route_access_test.dart`
- `prompts/ui-permissions/_shared-rules.md`
- `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`
- `frontend/.cursor/permissions.mdc`
- `frontend/.cursor/navigation.mdc`
- `backend/src/config/permissions.js`
