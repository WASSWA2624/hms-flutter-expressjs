# Tenants & Facilities Tabs — Role-Scoped List vs Details

Scope tenant and facility desk tabs on `/admin/setup` by admin role: platform list, tenant-scoped list/details, and facility-scoped details. Tab labels use singular or plural to match the view.

## Context

- Current tenants-tab and facility-tab actions are inventoried in `screens/admin-setup/tenants.md` and `screens/admin-setup/facility.md`.
- Scoped tenant summary already exists when `canManageTenant()` and not `canCreateTenant()` (`tenantFacilityUsesScopedTenantPanel`).
- Facility tab still uses a list-oriented presentation; facility admins need a details panel analogous to the scoped tenant summary.
- Permanently deleted records stay hidden; soft-deleted records remain visible with status.

## Requirements

1. **Platform admin** (`canCreateTenant()` / elevated platform scope):
   - **Tenants** tab (plural): list all tenants that have signed up.
   - **Facilities** tab (plural): list all facilities with columns facility name, tenant, facility type, and status (active / soft-deleted). Permanently deleted facilities are not shown.

2. **Tenant admin** (`canManageTenant()` and not platform create scope):
   - **Tenant** tab (singular): details for the session tenant only (not a tenant table). Show Edit; do not show Delete.
   - **Facilities** tab (plural): list only facilities under that tenant. Columns: facility name, human-friendly facility code/slug (if available), facility type, phone, email, contact person (when column budget allows), and status. Omit the tenant column (session tenant is implied).

3. **Facility admin** (facility manage without tenant-manage / platform create):
   - Hide or omit the tenants tab (session tenant is already known).
   - **Facility** tab (singular): details for the session facility only (not a facility table), modeled after the scoped tenant details pattern. Show Edit; do not show Delete.

4. Use singular or plural tab labels to match the mode (list → plural; single details → singular).

5. Changes apply only to the tenants and facility desk tabs; do not alter departments, units, wards, rooms, beds, roles, permissions, users, or clinical catalog behavior.

## Constraints

- Reuse existing details summaries, edit dialogs (`_SetupProfileDialog`), permissions (`canManageTenant`, `canCreateTenant`, `canManageFacility`), and list infrastructure.
- Soft-deleted rows may appear with status; permanently deleted rows must not.
- Tenant admins and facility admins may edit their scoped entity but must not delete it from these tabs.
- Never display non-human-friendly IDs (UUIDs, Mongo/ObjectIds, opaque primary keys) in list columns, details, or labels; show only human-readable codes, slugs, or names. Omit the ID column when no friendly identifier exists.
- No unrelated refactoring; no new endpoints unless list/details already require an existing fetch.

## Acceptance Criteria

- Platform admin sees plural Tenants and Facilities list tabs with the columns in Req 1.
- Tenant admin sees singular Tenant details (Edit, no Delete) and a tenant-scoped Facilities list without a tenant column (Req 2).
- Facility admin sees no Tenants tab and a singular Facility details view (Edit, no Delete) (Req 3).
- Tab labels switch singular/plural with mode (Req 4).
- Other setup tabs are unchanged (Req 5).
- No list or details UI shows raw/internal IDs; only human-friendly identifiers or names appear.
- Widget or integration coverage for the three role modes; `flutter analyze` passes.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `screens/admin-setup/tenants.md`
- `screens/admin-setup/facility.md`
