# 37 - Quality, Validation, and Release Readiness

## Goal
Confirm HOSSPI HMS is safe, usable, consistent, responsive, permission-aware, and ready for staged release.

## Validation Areas
1. App identity: HOSSPI HMS branding, logo, titles, and shell labels.
2. Auth: login, logout, registration policy, change password, session restoration, and route guards.
3. Tenant/facility setup: organization, facility profile, departments, units, rooms, wards, beds, users, roles, and permissions.
4. Demo data: tenant, facility, admins, department users, subscriptions, modules, sample patients, clinical data, operations data, biomedical data, mortuary data, reports, notifications, and audit samples.
5. Access control: routes, menus, buttons, modals, exports, reports, and actions.
6. Module workflows: patient registry, OPD, triage, clinical, nursing, inpatient, ICU, theater, discharge, emergency, lab, radiology, physiotherapy, mortuary, pharmacy, billing, claims, HR, rooms/beds, biomedical, operations, housekeeping, subscriptions, notifications, reports, audit, and integrations.
7. UX: simple screens, clear forms, modal actions where appropriate, no congested dashboards.
8. Responsiveness: mobile, tablet, desktop, web, and large desktop layouts.
9. Accessibility: labels, keyboard navigation, focus, readable contrast, tap/click targets.
10. Security: no secrets, no sensitive logs, secure session cleanup, safe error display.
11. Offline/connectivity: clear online/offline indicators and safe retry states.
12. Performance: paginated lists, debounced search, no heavy build work.
13. Localization: no hard-coded user-facing text in feature widgets.
14. Testing: unit, widget, and integration coverage for core flows.

## Required Frontend Commands
Run from `frontend/` after implementation work:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Add platform-specific build checks when release work begins.

## Backend Validation
Backend validation is required only when a future task explicitly permits backend changes. For the current root planner scope, backend is read-only.

## Release Checklist
- Feature flags and subscription entitlements are configured.
- Default/demo accounts are not exposed in production builds.
- Production secrets are not committed.
- Error messages are safe and localized.
- Audit-sensitive workflows are traceable.
- Reports and exports are permission-gated.
- User documentation and setup notes are updated.

## Done Criteria
- All implemented modules pass static checks and tests.
- Known backend gaps, such as dedicated physiotherapy API support if still missing, are documented.
- The app can be demonstrated using safe demo data.
- Production release blockers are listed clearly.

## Rule References
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
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/testing.md`
- `frontend/app-planner/app-rules/ci_cd_quality_gates.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/observability.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`
- `backend/app-planner/app-rules/testing.md`
- `backend/app-planner/app-rules/performance.md`
- `backend/app-planner/app-rules/compliance.md`
- `backend/app-planner/app-rules/error-logging.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
