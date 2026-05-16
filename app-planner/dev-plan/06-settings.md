# 06 - General Settings and App Bar Experience

## Goal
Complete general settings and app bar indicators for HOSSPI HMS without mixing personal settings with tenant/facility administration.

## Source of Truth
- Use `app-write-up.md` for app shell, general settings, tenant settings, facility settings, and access expectations.
- Use `03-brand-shell.md` for app shell and brand behavior.
- Use `07-tenant-facility.md` for organization/facility setup.
- Use `08-access-control.md` for permission-aware settings visibility.

## Current State
- The frontend settings page already supports theme mode and English language selection.
- Theme and locale controllers already exist.
- The shell already has online/offline status support.

## Scope
1. Keep existing theme switching: system, light, dark.
2. Keep language switching foundation and extend it only when more locales are added.
3. Add HMS-specific personal settings groups without congesting the settings screen.
4. Add account settings entry points after auth is implemented.
5. Add notification badge and unread indicators after notifications data is wired.
6. Show module/license/subscription warnings in the shell only when relevant.
7. Keep settings separated from facility/tenant administration.
8. Persist only safe, non-sensitive preferences.

## Settings Boundaries
| Area | Owned By | Examples |
| --- | --- | --- |
| General settings | User preference area | Theme, language, display preferences, accessibility-friendly choices |
| Tenant settings | Tenant/facility admin setup | Tenant profile, subscription relationship, tenant modules, tenant-wide rules |
| Facility settings | Facility admin setup | Facility profile, logo, contacts, address, departments, units, rooms, wards, beds |
| User/security settings | Account/session workflows | Profile, password, active sessions, MFA where enabled |
| Workflow settings | Module setup screens | Payment methods, service catalogs, lab tests, radiology tests, formulary, wards, beds |

## UI Contract
- Keep settings clean and grouped.
- Use modals for quick preference changes when appropriate.
- Do not place technical configuration names in staff-facing settings labels.
- Role-gate admin settings and module setup entries.
- Updating a setting should refresh only the changed setting, theme/locale, shell indicator, or affected module state.

## Done Criteria
- Existing theme and language behavior remains intact.
- Settings screen is clean and not overloaded with admin setup forms.
- App bar shows only useful state: user, notifications, online/offline, and relevant system indicators.
- Settings, facility setup, and module setup remain clearly separated.

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
- `frontend/app-planner/app-rules/theming.md`
- `frontend/app-planner/app-rules/storage_strategy.md`
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`
- `backend/src/modules/settings-workspace/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
