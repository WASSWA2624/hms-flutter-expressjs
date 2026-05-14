# 06 - General Settings and App Bar Experience

## Goal
Complete general settings and app bar indicators for HOSSPI HMS.

## Current State
- The frontend settings page already supports theme mode and English language selection.
- Theme and locale controllers already exist.
- The shell already has online/offline status support.

## Scope
1. Keep existing theme switching: system, light, dark.
2. Keep language switching foundation and extend it only when more locales are added.
3. Add HMS-specific settings groups without congesting the settings screen.
4. Add account settings entry points after auth is implemented.
5. Add notification badge and unread indicators after notifications data is wired.
6. Show module/license/subscription warnings in the shell only when relevant.
7. Keep settings separated from facility/tenant administration.

## Settings Boundaries
- General settings: personal app preferences such as theme, language, local display preferences.
- Tenant settings: tenant identity, subscription, tenant modules, tenant-wide rules.
- Facility settings: facility profile, departments, units, rooms, wards, beds.
- User/security settings: profile, password, sessions, MFA where enabled.

## Done Criteria
- Existing theme and language behavior remains intact.
- Settings screen is clean and not overloaded with admin setup forms.
- App bar shows only useful state: user, notifications, online/offline, and relevant system indicators.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/theming.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/accessibility.md`
- `frontend/app-planner/app-rules/storage_strategy.md`
### Backend rules
- `backend/app-planner/app-rules/internationalization.md`
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/response-format.md`
### Additional references
- `frontend/lib/features/settings/presentation/pages/settings_page.dart`
- `backend/src/modules/settings-workspace/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
