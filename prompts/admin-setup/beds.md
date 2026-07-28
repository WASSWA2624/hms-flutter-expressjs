# Align Beds Setup With Departments

Fix the false ward gate on `/admin/setup?section=beds`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Beds still read `FacilitySetupSnapshot`, so Platform Admin can see wards elsewhere while Beds shows **"Create at least one ward before adding beds."** Hierarchy: **Tenant → Facility → Ward → Room (optional) → Bed**. Fields: label, required ward, optional room, status. Search: "Search beds by label, ward, room, or status".

**Accessible ward:** non-deleted ward visible under RBAC/ABAC. Room, when set, must belong to the selected ward.

## Requirements

1. Load/filter Beds independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.wards` alone.
2. Show ward-gate copy only when **no accessible ward** exists. When wards exist and beds are empty, show only **"No beds have been added."** Enable **+ Create bed** when write access and ≥1 accessible ward exist.
3. **Platform Admin:** all beds; filters Tenant / Facility / Ward / Room / Status; create Tenant → Facility → Ward → Room (optional).
4. **Tenant Admin:** tenant beds; filters Facility / Ward / Room / Status; tenant preselected; create Facility → Ward → Room (optional).
5. **Facility Admin:** facility beds; filters Ward / Room / Status; tenant/facility preselected; create Ward → Room (optional).
6. Use `AppListTable` with ≤5 default-visible columns (`#`, label, ward, status, actions). Nest room, facility, tenant, and other secondary fields via column visibility and/or name subtitle. Backend authoritative for rows/actions.
7. Before create/edit persist, always open bed similarity dialog (even if no matches), scoped like create, excluding edited bed; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Beds list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation. On ward change, revalidate room to stay ward-scoped.
9. In create/edit dialogs, show centered `AppLoadingIndicator` overlay (OPD Stack + AbsorbPointer + `Positioned.fill`) with contextual `title`/`body` per async state; same for list loaders. Replace inline form spinners.
10. On successful create/edit, open bed details (`_openDepartmentDialog` → `_openDepartmentDetails`). Show all available fields and related names (ward, room, facility, tenant, status, human-friendly id, timestamps). Never show raw UUIDs/opaque ids in list, forms, filters, or details.

## Constraints

- Reuse Departments/Units helpers, chrome, soft-delete/restore, form layout, theme tokens, loading overlay, and post-save details flow.
- No parallel beds auth model; unauthorized controls must not render.
- Soft delete only from list Delete.
- Never expose raw UUIDs; use display names and `human_friendly_id` only.

## Acceptance Criteria

- Wards present, no beds: empty state has no ward-gate sentence; Create bed works (Req 1–2).
- Zero accessible wards: gate copy; create blocked (Req 2).
- In-scope rows only; ≤5 default columns with nested extras (Req 3–6).
- Similarity dialog always before save (Req 7).
- List updates after mutations; room ward-scoped; unauthorized UI absent (Req 6, 8).
- Loaders use contextual `AppLoadingIndicator` messages; overlay blocks form (Req 9).
- Post-save details show full available info with no UUIDs (Req 10).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/department_details_dialog.dart`
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `backend/src/modules/bed/`
- `frontend/test/features/tenant_facility/presentation/`
