# Align Rooms Setup With Departments

Fix the false prerequisite gate on `/admin/setup?section=rooms`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Rooms still read `FacilitySetupSnapshot` (departments, wards, rooms), so Platform Admin can see structure elsewhere while Rooms shows **"Create at least one department or ward before adding rooms."** Hierarchy: **Tenant → Facility → Ward (optional) → Room**. Fields: name, optional ward, optional floor. Soft-delete only. Search: "Search rooms by name, ward, floor, or status".

**Accessible facility:** non-deleted facility visible under RBAC/ABAC. Ward optional; rooms do not require a department.

## Requirements

1. Load/filter Rooms independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.departments` / `snapshot.wards` alone.
2. Show gate copy only when **no accessible facility** exists. When facilities exist and rooms are empty, show only **"No rooms have been added."** Enable **+ Create room** when write access and ≥1 accessible facility exist.
3. **Platform Admin:** all rooms; filters Tenant / Facility / Ward / Status; create Tenant → Facility → Ward (optional).
4. **Tenant Admin:** tenant rooms; filters Facility / Ward / Status; tenant preselected; create Facility → Ward (optional).
5. **Facility Admin:** facility rooms; filters Ward / Status; tenant/facility preselected; create Ward (optional) only.
6. Table parity with Departments: `#`, name, ward, floor, facility (in scope), tenant (platform), status, Edit / soft-Delete (Restore). Backend authoritative for rows/actions.
7. Before create/edit persist, always open room similarity dialog (even if no matches), scoped like create, excluding edited room; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Rooms list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit room dialogs, while loading options, checking similarity, or other in-dialog async, show centered `AppLoadingIndicator` as a full-content overlay that blocks the form (OPD encounter Stack + AbsorbPointer + `Positioned.fill`). Replace the inline top-of-form row spinner.
10. On successful create/edit, close the form and open the room details dialog for the saved entity (same flow as `_openDepartmentDialog` → `_openDepartmentDetails`).

## Constraints

- Reuse Departments/Units scope helpers, chrome, soft-delete/restore, form layout, theme tokens, dialog loading overlay, and post-save details-dialog flow.
- No parallel rooms auth model; unauthorized controls must not render.
- Soft delete only from list Delete (no hard-delete unless shared by structure CRUD).
- Drop department-or-ward gate; rooms do not require a department.

## Acceptance Criteria

- Accessible facility, no rooms: empty state has no false gate; Create room works (Req 1–2).
- Zero accessible facilities: gate copy; create blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, selectors (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; unauthorized UI absent (Req 6, 8).
- Dialog loading/updating: centered `AppLoadingIndicator` overlays form; fields/actions not interactable (Req 9).
- Successful create/edit opens the room details dialog for the saved room (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_RoomSetupSection`, `_RoomFormDialog`, `_openDepartmentDialog`)
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart` (post-save details pattern)
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart` (overlay reference)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/room/`
- `frontend/test/features/tenant_facility/presentation/`
