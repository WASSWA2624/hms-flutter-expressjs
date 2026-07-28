# Align Rooms Setup With Departments

Fix the false prerequisite gate on `/admin/setup?section=rooms`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Rooms still read `FacilitySetupSnapshot`, so Platform Admin can see structure elsewhere while Rooms shows **"Create at least one department or ward before adding rooms."** Hierarchy: **Tenant → Facility → Ward (optional) → Room**. Fields: name, optional ward, optional floor. Soft-delete only. Search: "Search rooms by name, ward, floor, or status".

**Accessible facility:** non-deleted facility visible under RBAC/ABAC. Ward optional; rooms do not require a department.

## Requirements

1. Load/filter Rooms independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.departments` / `snapshot.wards` alone.
2. Show gate copy only when **no accessible facility** exists. When facilities exist and rooms are empty, show only **"No rooms have been added."** Enable **+ Create room** when write access and ≥1 accessible facility exist.
3. **Platform Admin:** all rooms; filters Tenant / Facility / Ward / Status; create Tenant → Facility → Ward (optional).
4. **Tenant Admin:** tenant rooms; filters Facility / Ward / Status; tenant preselected; create Facility → Ward (optional).
5. **Facility Admin:** facility rooms; filters Ward / Status; tenant/facility preselected; create Ward (optional) only.
6. Use `AppListTable` with ≤5 default-visible columns (`#`, name, ward, status, actions). Nest floor, facility, tenant, and other secondary fields via column visibility and/or name subtitle. Backend authoritative for rows/actions.
7. Before create/edit persist, always open room similarity dialog (even if no matches), scoped like create, excluding edited room; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Rooms list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit dialogs, show centered `AppLoadingIndicator` overlay (OPD Stack + AbsorbPointer + `Positioned.fill`) with contextual `title`/`body` per async state; same for list loaders. Replace inline form spinners.
10. On successful create/edit, open room details (`_openDepartmentDialog` → `_openDepartmentDetails`). Show all available fields and related names (ward, facility, tenant, floor, status, human-friendly id, timestamps). Never show raw UUIDs/opaque ids in list, forms, filters, or details.

## Constraints

- Reuse Departments/Units helpers, chrome, soft-delete/restore, form layout, theme tokens, loading overlay, and post-save details flow.
- No parallel rooms auth model; unauthorized controls must not render.
- Soft delete only from list Delete. Drop department-or-ward gate.
- Never expose raw UUIDs; use display names and `human_friendly_id` only.

## Acceptance Criteria

- Accessible facility, no rooms: empty state has no false gate; Create room works (Req 1–2).
- Zero accessible facilities: gate copy; create blocked (Req 2).
- In-scope rows only; ≤5 default columns with nested extras (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; unauthorized UI absent (Req 6, 8).
- Loaders use contextual `AppLoadingIndicator` messages; overlay blocks form (Req 9).
- Post-save details show full available info with no UUIDs (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart`
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/room/`
- `frontend/test/features/tenant_facility/presentation/`
