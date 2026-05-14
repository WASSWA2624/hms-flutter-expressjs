# 01 - Execution Policy

## Goal
Apply the HOSSPI HMS root development plan without damaging the existing backend, frontend foundation, frontend planner, or backend planner.

## Hard Boundaries
1. Only app-specific implementation should be added during future implementation tasks.
2. Do not modify backend source code unless a future task explicitly permits backend changes.
3. Do not modify frontend `app-planner/app-rules` or frontend `app-planner/dev-plan`.
4. Do not modify backend `app-planner/app-rules` or backend `app-planner/dev-plan` unless a future task explicitly asks for backend documentation updates.
5. Preserve existing folder paths unless a future implementation task explicitly approves restructuring.
6. Use existing frontend architecture, shared components, shell, theme, localization, routing, networking, state management, and permissions utilities before creating new patterns.
7. Keep features self-contained under their module/feature folders.
8. Keep screens simple and permission-aware.
9. Use modal-based actions for short forms, quick edits, approvals, status changes, and confirmations.
10. Use full-page flows only for long, risky, multi-step, or deep-linkable workflows.

## Required Implementation Method
For every future feature task:
1. Read this root plan step.
2. Read the relevant frontend and backend rules.
3. Inspect current frontend source files.
4. Inspect backend route, schema, permission, and response contracts.
5. Reuse existing correct work.
6. Implement only the missing pieces.
7. Add loading, empty, error, forbidden, offline, and success states.
8. Confirm responsive behavior on mobile, tablet, desktop, and web.
9. Localize user-facing text.
10. Run quality checks and document blockers.

## Small-Module Delivery Rule
Each module should be delivered in this order:
1. route and menu entry;
2. permission guard and entitlement guard;
3. empty state and dashboard/list shell;
4. list/table view with search and filters;
5. detail drawer/panel/page;
6. create/edit modal or focused form;
7. workflow actions and status updates;
8. exports/reports after the core workflow works.

## Quality Commands
Use the applicable frontend checks after source changes:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Backend checks are required only when a future task explicitly allows backend changes.

## Done Criteria
A step is done when:
- existing correct work is reused;
- missing app-specific behavior is implemented;
- routes, labels, permissions, module entitlements, and API endpoints align;
- UI remains clean and module-focused;
- tests/static checks pass or blockers are documented.

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
- `frontend/app-planner/app-rules/error_handling.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`
- `backend/app-planner/app-rules/testing.md`
- `backend/app-planner/app-rules/error-logging.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
