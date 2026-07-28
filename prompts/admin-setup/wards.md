# Align Wards Setup With Departments

Fix the false department gate on `/admin/setup?section=wards`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Wards still read `FacilitySetupSnapshot.departments` / `snapshot.wards`, so Platform Admin can see departments elsewhere while Wards shows **"Create at least one department before adding wards."** Hierarchy: **Tenant → Facility → Department (optional) → Ward**. Fields: name, type (`GENERAL` | `ICU` | `MATERNITY` | `PEDIATRIC` | `SURGICAL` | `OTHER`), optional department, active. Search: "Search wards by name, type, department, or status".

**Accessible department:** non-deleted department visible under RBAC/ABAC. Department optional on create; create still gated until ≥1 accessible department exists.

## Requirements

1. Load/filter Wards independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.departments` alone.
2. Show department-gate copy only when **no accessible department** exists. When departments exist and wards are empty, show only **"No wards have been added."** Enable **+ Create ward** when write access and ≥1 accessible department exist.
3. **Platform Admin:** all wards; filters Tenant / Facility / Department / Type / Status; create Tenant → Facility → Department (optional).
4. **Tenant Admin:** tenant wards; filters Facility / Department / Type / Status; tenant preselected; create Facility → Department (optional).
5. **Facility Admin:** facility wards; filters Department / Type / Status; tenant/facility preselected; create Department (optional) only.
6. Table parity with Departments: `#`, name, type, department, facility (in scope), tenant (platform), status, Edit / soft-Delete (Restore). Backend authoritative for rows/actions.
7. Before create/edit persist, always open ward similarity dialog (even if no matches), scoped like create, excluding edited ward; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Wards list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit ward dialogs, while loading options, checking similarity, or other in-dialog async, show centered `AppLoadingIndicator` as a full-content overlay that blocks the form (OPD encounter Stack + AbsorbPointer + `Positioned.fill`). Replace the inline top-of-form row spinner.
10. On successful create/edit, close the form and open the ward details dialog for the saved entity (same flow as `_openDepartmentDialog` → `_openDepartmentDetails`).

## Constraints

- Reuse Departments/Units scope helpers, chrome, soft-delete/restore, form layout, theme tokens, dialog loading overlay, and post-save details-dialog flow.
- No parallel wards auth model; unauthorized controls must not render.
- Soft delete only from list Delete (no hard-delete unless shared by structure CRUD).

## Acceptance Criteria

- Departments present, no wards: empty state has no department-gate sentence; Create ward works (Req 1–2).
- Zero accessible departments: gate copy; create blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, selectors (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; unauthorized UI absent (Req 6, 8).
- Dialog loading/updating: centered `AppLoadingIndicator` overlays form; fields/actions not interactable (Req 9).
- Successful create/edit opens the ward details dialog for the saved ward (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_WardSetupSection`, `_WardFormDialog`, `_openDepartmentDialog`)
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart` (post-save details pattern)
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart` (overlay reference)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/ward/`
- `frontend/test/features/tenant_facility/presentation/`
