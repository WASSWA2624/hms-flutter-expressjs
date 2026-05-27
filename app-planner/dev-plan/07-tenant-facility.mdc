# 07 - Tenant and Facility Setup

## Goal
Allow admins to configure the organization and facility before daily hospital operations begin, while keeping facility setup synchronized with reports, patient flows, rooms/beds, users, and module access.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for setup flow and facility/module boundaries.
- Use `ipd-flow.md` for ward, room, bed, and inpatient readiness.
- Use `35-reports-audit.md` for facility identity on generated print/report templates.
- Use backend routes and rules for storage, validation, tenancy, and authorization.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/tenant_facility/` already has DTOs, repository, entity, controller, and `tenant_facility_setup_page.dart` using the shared workspace/dialog/state foundation.
- Required adjustment: extend the existing setup workflow for organization, facility, branch, department, unit, room, ward, bed, and setup actions; do not create a duplicate admin setup feature.
- UI similarity rule: use `AppWorkspace`, summary cards, shared dialogs, shared form fields, `AsyncStateScaffold`, and targeted section refresh for all setup additions.

## Backend Routes

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/tenants`
- `/api/v1/facilities`
- `/api/v1/branches`
- `/api/v1/departments`
- `/api/v1/units`
- `/api/v1/rooms`
- `/api/v1/wards`
- `/api/v1/beds`

## Scope
- Store address/contact details through tenant/facility payload fields or dedicated backend routes only when those routes exist; do not invent `/addresses` or `/contacts` calls.
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

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: tenant/facility profile forms, contact/address field groups, logo upload field, department/unit/branch setup forms, setup checklist cards, and room/ward/bed entry-point cards.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: facility identity, departments, units, rooms, wards, beds, report headers, OPD/IPD routing options, and permission scopes must update together from backend-backed setup data.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Setup lists | Tenants, facilities, branches, departments, units, rooms, wards, and beds must render through `AppListTable` and `AppSearchBar`. |
| Setup forms | Create/edit actions must use `AppDialog`, shared form fields, and catalog-backed selects; avoid separate form styling per entity. |
| Catalog sync | Facility structure changes must invalidate only affected setup catalogs, dropdowns, room/ward/bed rows, and dependent module filters. |
| Access | Gate setup routes/actions with tenant/facility/system admin permissions and backend authorization. |
| Backend boundary | Edit backend only if a required setup relation, status, or validation response blocks the UI contract. |


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
