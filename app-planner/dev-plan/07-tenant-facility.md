# 07 - Tenant and Facility Setup

## Goal
Allow admins to configure the organization and facility before daily hospital operations begin.

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

## UX Flow
After account creation or first login:
1. show tenant/facility setup status;
2. guide admin to configure facility identity;
3. guide admin to departments and units;
4. guide admin to users and permissions;
5. guide admin to rooms, wards, and beds;
6. guide admin to subscriptions/modules if required.

## Done Criteria
- Facility setup can be completed without leaving the admin setup area unnecessarily.
- Facility name/logo/contact details appear in the shell and relevant screens where appropriate.
- Forms validate required fields and show friendly errors.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/storage_strategy.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/storage.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/prisma.md`
### Additional references
- `backend/src/modules/tenant/`
- `backend/src/modules/facility/`
- `backend/src/modules/department/`
- `backend/src/modules/unit/`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
