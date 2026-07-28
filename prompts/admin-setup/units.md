# Align Units Setup With Departments

Fix the false department gate on `/admin/setup?section=units`, and match Departments scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Units still read `FacilitySetupSnapshot.departments` / `snapshot.units`, so Platform Admin sees departments elsewhere while Units shows **"No units have been added. Create at least one department before adding units."** Hierarchy: **Tenant → Facility → Department → Unit**. Search: "Search units by name, department, or status".

**Accessible department:** non-deleted department visible under RBAC/ABAC for the actor’s account scope.

## Requirements

1. Load/filter Units independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.departments` alone.
2. Show department-gate copy only when **no accessible department** exists. When departments exist and units are empty, show only **"No units have been added."** Enable **+ Create unit** when write access and ≥1 accessible department exist.
3. **Platform Admin:** all units; filters Tenant / Facility / Department / Status; create Tenant → Facility → Department.
4. **Tenant Admin:** tenant units; filters Facility / Department / Status; tenant preselected; create Facility → Department.
5. **Facility Admin:** facility units; filters Department / Status; tenant/facility preselected; create Department only.
6. Table parity with Departments: `#`, name, department, facility (in scope), tenant (platform), status, Edit / soft-Delete (Restore). Backend authoritative for rows/actions.
7. Before create/edit persist, always open unit similarity dialog (even if no matches), scoped like create, excluding edited unit; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Units list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit unit dialogs, while loading options, checking similarity, or other in-dialog async, show centered `AppLoadingIndicator` as a full-content overlay that blocks the form (OPD encounter Stack + AbsorbPointer + `Positioned.fill`). Replace the inline top-of-form row spinner.
10. On successful create/edit, close the form and open the unit details dialog for the saved entity (same flow as `_openDepartmentDialog` → `_openDepartmentDetails`).

## Constraints

- Reuse Departments scope helpers, chrome, soft-delete/restore, form layout, theme tokens, dialog loading overlay, and post-save details-dialog flow.
- No parallel units auth model; unauthorized controls must not render.
- Soft delete only from list Delete (no hard-delete unless shared by structure CRUD).

## Acceptance Criteria

- Departments present, no units: empty state has no department-gate sentence; Create unit works (Req 1–2).
- Zero accessible departments: gate copy; create blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, selectors (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; unauthorized UI absent (Req 6, 8).
- Dialog loading/updating: centered `AppLoadingIndicator` overlays form; fields/actions not interactable (Req 9).
- Successful create/edit opens the unit details dialog for the saved unit (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_UnitSetupSection`, `_UnitFormDialog`, `_openDepartmentDialog`)
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart` (post-save details pattern)
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart` (overlay reference)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/unit/`
- `frontend/test/features/tenant_facility/presentation/`
