# 07 - Tenant and Facility Setup

## Goal
Allow admins to configure the organization and facility before daily hospital operations begin, while keeping facility setup synchronized with reports, patient flows, rooms/beds, users, and module access.

## Source of Truth
- Use `app-write-up.md` for setup flow and facility/module boundaries.
- Use `ipd-flow.md` for ward, room, bed, and inpatient readiness.
- Use `35-reports-audit.md` for facility identity on generated print/report templates.
- Use backend routes and rules for storage, validation, tenancy, and authorization.

## Backend Routes
Use the existing route families:
- `/api/v1/tenants`
- `/api/v1/facilities`
- `/api/v1/branches`
- `/api/v1/departments`
- `/api/v1/units`
- `/api/v1/addresses`
- `/api/v1/contacts`
- `/api/v1/rooms`
- `/api/v1/wards`
- `/api/v1/beds`

## Scope
1. Tenant profile view/edit.
2. Facility profile view/edit: name, logo, contacts, address, type, active state.
3. Branch setup where facilities have branches.
4. Department and unit setup.
5. Room, ward, and bed setup entry points.
6. Facility logo upload only through the approved storage strategy.
7. First-run setup checklist for tenant/facility admins.
8. Clear permission gates for tenant admin and facility admin actions.
9. Setup readiness indicators for OPD/IPD flow dependencies.

## UX Flow
After account creation or first admin login:
1. show tenant/facility setup status;
2. guide admin to configure facility identity;
3. guide admin to departments and units;
4. guide admin to users and permissions;
5. guide admin to rooms, wards, and beds;
6. guide admin to service catalogs such as lab tests, radiology tests, medicines, services, payment methods, and insurance where modules require them;
7. guide admin to subscriptions/modules if required.

## UI and Workflow Rules
- Keep setup in an admin workspace, not inside daily OPD/IPD screens.
- Use modals for quick edits: contact, address, logo metadata, department, unit, room, ward, bed status.
- Use full pages only for multi-section facility setup or first-run setup checklist.
- Do not duplicate room/ward/bed logic outside `29-rooms-beds.md`.
- Facility logo/name/contact details must feed report templates and relevant shell/screen headers.
- After setup changes, refresh only affected setup rows, shell facility identity, report template preview, or dependent catalogs.

## Done Criteria
- Facility setup can be completed without leaving the admin setup area unnecessarily.
- Facility name/logo/contact details appear in the shell and report templates where appropriate.
- Departments, units, wards, rooms, and beds are available for OPD/IPD routing.
- Forms validate required fields and show friendly errors.

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
- `frontend/app-planner/app-rules/storage_strategy.md`
- `backend/src/modules/tenant/`
- `backend/src/modules/facility/`
- `backend/src/modules/department/`
- `backend/src/modules/unit/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
