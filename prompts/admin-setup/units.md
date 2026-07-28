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
6. Use `AppListTable` with ≤5 default-visible columns (`#`, name, department, status, actions). Nest facility, tenant, and other secondary fields via column visibility and/or name subtitle. Backend authoritative for rows/actions.
7. Before create/edit persist, always open unit similarity dialog (even if no matches), scoped like create, excluding edited unit; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Units list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit dialogs, while loading options, checking similarity, or other in-dialog async, show centered `AppLoadingIndicator` overlay (OPD encounter Stack + AbsorbPointer + `Positioned.fill`) with contextual `title`/`body` per state. Same for list/section loaders. Replace inline form spinners.
10. On successful create/edit, open unit details (`_openDepartmentDialog` → `_openDepartmentDetails`). Show all available fields and related names (department, facility, tenant, status, human-friendly id, timestamps). Never show raw UUIDs/opaque ids in list, forms, filters, or details.

## Constraints

- Reuse Departments scope helpers, chrome, soft-delete/restore, form layout, theme tokens, dialog loading overlay, and post-save details flow.
- No parallel units auth model; unauthorized controls must not render.
- Soft delete only from list Delete.
- Never expose raw UUIDs; use display names and `human_friendly_id` only.

## Acceptance Criteria

- Departments present, no units: empty state has no department-gate sentence; Create unit works (Req 1–2).
- Zero accessible departments: gate copy; create blocked (Req 2).
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
- `backend/src/modules/unit/`
- `frontend/test/features/tenant_facility/presentation/`
