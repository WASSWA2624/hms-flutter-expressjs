# App Menu Permission Access — Shell Destinations, Routes, and Screens

Enforce **permission-based** visibility on every app menu item so users only see and open routes/screens their **effective permissions** allow—including **custom roles**. Do **not** gate on canonical `AppRole`. **Atomize every route:** one catalog atom per screen/route with its **own unique entry permission**; one permission unlocks **at most one** route. Centralize all entry gates in **one catalog**. Unauthorized destinations must not appear; unauthorized deep links must not render the target screen.

## Context

- Surface: shell nav in `app_router.dart` (`_localizedShellDestinations` → `canAccessShellRoute`).
- **Central catalog:** e.g. `frontend/lib/core/permissions/route_access_catalog.dart` — one atom per authenticated route (`AppRoutes` name/path → unique entry `AccessRequirement`: permission ∩ modules ∩ context). Shell, guards, badges, Settings/Home links, and feature `routeEntry` **read only from this catalog**.
- Vocabulary: `backend/src/config/permissions.js` + `AppPermissions`. Neutralize `requiredAnyRoles` hard denies when catalog permissions are met.
- **Anti-patterns:** shared ∪ entry lists; grouped/non-atomic route gates; OPD via `billing:read`/`operations:read`/…; duplicate entry defs in feature `*_access.dart`.
- Custom roles: domain scope = each atom’s unique entry domain. Focused packs may narrow chrome; expanded grants unlock only atoms whose own key is granted.
- Effective access = union(permission grants) ∩ subscription ∩ plan ∩ ABAC (`prompts/ui-permissions/_shared-rules.md`, `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`). Backend authoritative. Follow `prompts/.cursor/prompt.mdc`.

## Route atoms (central catalog — one row = one atom)

**Rule:** declare each atom separately; never merge rows or share an entry key. In-screen CRUD may use other module verbs; **entry atoms must not**.

| Atom (`AppRoutes`) | Path | Entry permission | Module (plan ∩) |
| --- | --- | --- | --- |
| `home` | `/` | authenticated core | — |
| `settings` | `/settings` | authenticated core | — |
| `profile` | `/profile` | authenticated core | — |
| `reception` | `/reception` | `reception:read` | patient-registry, scheduling-queue |
| `patients` | `/patients` | `patients:read` | patient-registry |
| `opd` | `/opd` | `opd:read` only | scheduling-queue |
| `emergency` | `/emergency` | `emergency:read` | scheduling-queue |
| `ipd` | `/ipd` | `ipd:read` | inpatient-bed-management |
| `roomsBeds` | `/rooms-beds` | `rooms_beds:read` | inpatient-bed-management |
| `icu` | `/icu` | `icu:read` | icu-critical-care |
| `nursing` | `/nursing` | `nursing:read` | inpatient-bed-management |
| `clinical` | `/clinical` | `clinical:read` | encounters-vitals |
| `physiotherapy` | `/physiotherapy` | `physiotherapy:read` | physiotherapy |
| `theater` | `/theater` | `theater:read` | theatre-anesthesia |
| `discharge` | `/discharge` | `discharge:read` | encounters-vitals |
| `lab` | `/lab` | `lab:read` | lab-workflows |
| `radiology` | `/radiology` | `radiology:read` | radiology-workflows |
| `pharmacy` | `/pharmacy` | `pharmacy:read` | pharmacy-dispensing |
| `billing` | `/billing` | `billing:read` | billing-payments |
| `claims` | `/claims` | `claims:read` | insurance-claims |
| `subscriptions` | `/subscriptions` | `subscriptions:read` | subscription-controls |
| `operations` | `/operations` | `operations:read` | facilities-maintenance |
| `housekeeping` | `/housekeeping` | `housekeeping:read` | facilities-maintenance |
| `biomedical` | `/biomedical` | `biomed:read` | biomedical-engineering-suite |
| `mortuary` | `/mortuary` | `mortuary:read` | mortuary |
| `hr` | `/hr` | `hr:read` | hr-rosters |
| `communications` | `/communications` | `communications:read` | notifications-communications |
| `integrations` | `/integrations` | `integration:read` | integrations-core |
| `reports` | `/reports` | `reports:read` | reporting-analytics |
| `tenantFacilitySetup` | `/admin/setup` | `setup:read` | — |
| `accessAdmin` | `/admin/access` | `access_admin:read` | — |

Public/status routes (`login`, `forbidden`, …) are non-menu atoms—keep auth/session behavior; do not reuse workspace entry keys. Register missing keys; migrate role packs. Align modules to existing `AppRouteData.requiredActiveModules` when present.

## Requirements

1. Build the central catalog with **one atom per matrix row**; wire `AppRouteData`/shell/guards to resolve entry from that atom only.
2. Split any grouped or shared entry gates into distinct atoms; replace feature-local `routeEntry` redefs with catalog aliases.
3. Apply unique keys; OPD atom = `opd:read` only (billing/operations/patient/clinical/emergency must not open it). Register keys; update role/custom-role catalogs.
4. Align `permissionScopedDomainsFor` per atom domain.
5. Filter shell with `canAccessShellRoute`; collapse empty groups; no disabled stubs. Guard deep links → forbidden; never paint denied bodies.
6. Secondary links/badges use the **target atom’s** catalog entry.
7. Preserve authorized UI states; rebuild after permission refresh.
8. Tests: (a) every matrix atom present in catalog; (b) sole source for shell+guard; (c) each atom only with its key; (d) billing/operations ≠ OPD; (e) one key ≠ another atom; (f) custom role with only `opd:read` (+ modules) sees OPD only; (g) missing key ⇒ absent + forbidden; (h) module denial; (i) secondary links/badges. Cover guards, reuse, mobile+desktop, light+dark.

## Constraints

- Scope: central catalog atoms, shell, guards, unique entry keys, domain scoping, badges, secondary navigators. In-screen tab atoms stay in `prompts/ui-permissions/**` (alias `routeEntry` to catalog only).
- Reuse `AppAccessPolicy`, `AccessRequirement`, `canAccessShellRoute`, `AppRouteGuards`, `AppRoutes`; one catalog; no role-only or shared multi-route entry ∪ lists.
- Theme tokens; responsive without clipping/overflow/duplication/invalid selected indices.
- Backend authoritative; no exploit/PoC; permission fixtures (custom-role; billing/operations≠OPD). Optional enhancements: none.

## Acceptance Criteria

- AC1 (Req 1-3): Catalog declares every matrix atom separately with a unique entry permission; no shared keys; OPD not via billing/operations.
- AC2 (Req 2, 5-6): Shell, guards, badges, secondary links consume catalog atoms only; unauthorized UI absent.
- AC3 (Req 5): Denied deep links → forbidden; restricted body never shown.
- AC4 (Req 3-4): Custom roles open only atoms whose unique key (+ modules/scope) they hold.
- AC5 (Req 7): Loading/empty/error/success/forbidden-feedback remain observable; destinations refresh on permission change.
- AC6 (Req 8): Tests prove atomization, catalog ownership, one-permission↔one-route, OPD isolation, badges, viewports, themes.

## Relevant Files

- `frontend/lib/core/permissions/route_access_catalog.dart` (or equivalent), `app_permission.dart`, `access_policy.dart`, `access_requirement.dart`
- `frontend/lib/app/router/app_router.dart`, `app_routes.dart`, `shell_route_access.dart`, `route_guards.dart`, `shell_badge_counts.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/features/settings/…/settings_page.dart`, `frontend/lib/features/home/`
- Feature `*_access.dart` (aliases only); `frontend/test/app/router/` (+ catalog atom tests)
- `backend/src/config/permissions.js`
- `prompts/ui-permissions/_shared-rules.md`, `prompts/.cursor/prompt.mdc`
- `.cursor/access/permissions.mdc`, `frontend/.cursor/permissions.mdc`, `frontend/.cursor/navigation.mdc`
