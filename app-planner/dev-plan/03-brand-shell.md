# 03 - Brand, App Identity, and Shell

## Goal
Convert the Flutter starter identity into **HOSSPI HMS** without rebuilding the existing shell foundation.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for official product name, product scope, setup flow, modules, and UX expectations.
- Use `10-workspace-ui.md` for module workspace consistency.
- Use frontend app-rules for assets, theming, localization, navigation, responsiveness, and accessibility.

## Current State
- The frontend shell, responsive scaffold, router, theme, app logo component, and settings page should be reused where present.
- Starter app naming may still exist in `pubspec.yaml`, localization labels, and starter home copy.

## Scope
Implement app identity in this order:
1. Set product label to **HOSSPI HMS**.
2. Set full name to **HOSSPI Hospital Management System**.
3. Replace starter home text with HMS-specific overview and role-aware entry points.
4. Add or wire the official app logo using existing asset and logo rules.
5. Keep the existing responsive shell behavior.
6. Customize the app bar for HMS needs: logged-in avatar, user dropdown, notification badge, online/offline status, and relevant system indicators.
7. Keep mobile, tablet, desktop, web, and large desktop behavior consistent.

## Frontend Anchors
- `frontend/pubspec.yaml`
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/shared/components/app_logo.dart`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/app/router/app_router.dart`
- `frontend/lib/features/home/`

## UI Contract
| Area | Requirement |
| --- | --- |
| Shell | Reuse existing responsive shell; do not create a second app shell. |
| Navigation | Show only routes allowed by role, facility scope, and module entitlements. |
| App bar | Keep controls compact: user, notifications, online/offline, useful warnings only. |
| Home | Show simple role-aware starting points, not a crowded module dashboard. |
| Branding | Facility logo/name may appear where useful, but app identity remains HOSSPI HMS. |
| Responsiveness | Use existing breakpoints and avoid stretched forms or dense cards on large screens. |

## Implementation Notes
- Do not hard-code user-facing text in widgets; update localization keys.
- Do not create duplicate logo, shell, menu, or navigation components.
- User menu actions should include profile, settings, change password, and logout after auth is implemented.
- Notification indicators should be wired after notification data access is available.
- When app bar state changes, update only the relevant avatar, badge, status chip, or indicator.

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: app logo/identity display, responsive app shell, screen shell, navigation item, user menu, notification badge, facility identity header, and app status indicator.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: brand labels, shell navigation, user/facility context, notification count, and entitlement visibility must come from authenticated backend-backed state and stay consistent across routes.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Shell and navigation | Extend the existing router, guards, responsive shell, theme, localization, and destination model; do not create a second app shell. |
| Authorized destinations | Hide or disable menu destinations using `AppRouteData.accessRequirement`, `AppAccessPolicy`, module entitlements, tenant/facility context, and backend forbidden responses. |
| Header/actions | Use existing shared buttons, icon buttons, status badges, and shell components. Avoid crowded app bars; show only the current role's useful actions. |
| Badges/indicators | Workload counts must come from module controllers or backend summary endpoints and update only the affected badge/count. |
| Branding | HOSSPI HMS name, logo, facility identity, and generated report branding must stay consistent across shell, auth pages, settings, and print templates. |


## Done Criteria
- App title and short title display as HOSSPI HMS.
- Home screen no longer reads like a generic starter template.
- Shell remains responsive, accessible, and role-aware.
- Brand assets are loaded from the correct asset folders.
- No unrelated source files are changed.

## Rule References

### Product and flow references
- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

### Frontend rules
- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/state_management.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

### Additional references
- `frontend/app-planner/app-rules/assets_branding.md`
- `frontend/app-planner/app-rules/theming.md`
- `frontend/lib/shared/layout/responsive_shell_scaffold.dart`
- `frontend/lib/shared/components/app_logo.dart`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
