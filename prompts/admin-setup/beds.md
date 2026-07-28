# Align Beds Setup With Departments

Fix the false ward gate on `/admin/setup?section=beds`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Beds still read `FacilitySetupSnapshot` wards/beds/rooms, so Platform Admin can see wards elsewhere while Beds shows **"Create at least one ward before adding beds."** Hierarchy: **Tenant → Facility → Ward → Room (optional) → Bed**. Fields: label, required ward, optional room, status. Search: "Search beds by label, ward, room, or status".

**Accessible ward:** non-deleted ward visible under RBAC/ABAC. Room, when set, must belong to the selected ward.

## Requirements

1. Load/filter Beds independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.wards` alone.
2. Show ward-gate copy only when **no accessible ward** exists. When wards exist and beds are empty, show only **"No beds have been added."** Enable **+ Create bed** when write access and ≥1 accessible ward exist.
3. **Platform Admin:** all beds; filters Tenant / Facility / Ward / Room / Status; create Tenant → Facility → Ward → Room (optional).
4. **Tenant Admin:** tenant beds; filters Facility / Ward / Room / Status; tenant preselected; create Facility → Ward → Room (optional).
5. **Facility Admin:** facility beds; filters Ward / Room / Status; tenant/facility preselected; create Ward → Room (optional).
6. Table parity with Departments: `#`, label, ward, room, status, facility (in scope), tenant (platform), Edit / soft-Delete (Restore). Backend authoritative for rows/actions.
7. Before create/edit persist, always open bed similarity dialog (even if no matches), scoped like create, excluding edited bed; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Beds list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation. On ward change, revalidate room to stay ward-scoped.
9. In create/edit bed dialogs, while loading options, checking similarity, or other in-dialog async, show centered `AppLoadingIndicator` as a full-content overlay that blocks the form (OPD encounter Stack + AbsorbPointer + `Positioned.fill`). Replace the inline top-of-form row spinner.
10. On successful create/edit, close the form and open the bed details dialog for the saved entity (same flow as `_openDepartmentDialog` → `_openDepartmentDetails`).

## Constraints

- Reuse Departments/Units scope helpers, chrome, soft-delete/restore, form layout, theme tokens, dialog loading overlay, and post-save details-dialog flow.
- No parallel beds auth model; unauthorized controls must not render.
- Soft delete only from list Delete (no hard-delete unless shared by structure CRUD).

## Acceptance Criteria

- Wards present, no beds: empty state has no ward-gate sentence; Create bed works (Req 1–2).
- Zero accessible wards: gate copy; create blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, selectors (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; room ward-scoped; unauthorized UI absent (Req 6, 8).
- Dialog loading/updating: centered `AppLoadingIndicator` overlays form; fields/actions not interactable (Req 9).
- Successful create/edit opens the bed details dialog for the saved bed (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_BedSetupSection`, `_BedFormDialog`, `_openDepartmentDialog`)
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart` (post-save details pattern)
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart` (overlay reference)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/bed/`
- `frontend/test/features/tenant_facility/presentation/`
