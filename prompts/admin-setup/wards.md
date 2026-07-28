# Align Wards Setup With Departments

Fix the false department gate on `/admin/setup?section=wards`, and match Departments/Units scoped list/CRUD. Follow `prompts/.cursor/prompt.mdc`.

## Context

Wards still read `FacilitySetupSnapshot`, so Platform Admin can see departments elsewhere while Wards shows **"Create at least one department before adding wards."** Hierarchy: **Tenant → Facility → Department (optional) → Ward**. Fields: name, type (`GENERAL` | `ICU` | `MATERNITY` | `PEDIATRIC` | `SURGICAL` | `OTHER`), optional department, active. Search: "Search wards by name, type, department, or status".

**Accessible department:** non-deleted department visible under RBAC/ABAC. Department optional on create; create still gated until ≥1 accessible department exists.

## Requirements

1. Load/filter Wards independently (like `_DepartmentSetupSection`); do not gate on wizard `snapshot.departments` alone.
2. Show department-gate copy only when **no accessible department** exists. When departments exist and wards are empty, show only **"No wards have been added."** Enable **+ Create ward** when write access and ≥1 accessible department exist.
3. **Platform Admin:** all wards; filters Tenant / Facility / Department / Type / Status; create Tenant → Facility → Department (optional).
4. **Tenant Admin:** tenant wards; filters Facility / Department / Type / Status; tenant preselected; create Facility → Department (optional).
5. **Facility Admin:** facility wards; filters Department / Type / Status; tenant/facility preselected; create Department (optional) only.
6. Use `AppListTable` with ≤5 default-visible columns (`#`, name, type, status, actions). Nest department, facility, tenant, and other secondary fields via column visibility and/or name subtitle. Backend authoritative for rows/actions.
7. Before create/edit persist, always open ward similarity dialog (even if no matches), scoped like create, excluding edited ward; cancel / proceed-with-caution per structure similarity UX.
8. After mutations, refresh Wards list and setup counts without empty/gate flash. Cover loading, empty, no-results, error/retry, success, validation.
9. In create/edit dialogs, show centered `AppLoadingIndicator` overlay (OPD Stack + AbsorbPointer + `Positioned.fill`) with contextual `title`/`body` per async state; same for list loaders. Replace inline form spinners.
10. On successful create/edit, open ward details (`_openDepartmentDialog` → `_openDepartmentDetails`). Show all available fields and related names (type, department, facility, tenant, status, human-friendly id, timestamps). Never show raw UUIDs/opaque ids in list, forms, filters, or details.

## Constraints

- Reuse Departments/Units helpers, chrome, soft-delete/restore, form layout, theme tokens, loading overlay, and post-save details flow.
- No parallel wards auth model; unauthorized controls must not render.
- Soft delete only from list Delete.
- Never expose raw UUIDs; use display names and `human_friendly_id` only.

## Acceptance Criteria

- Departments present, no wards: empty state has no department-gate sentence; Create ward works (Req 1–2).
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
- `backend/src/modules/ward/`
- `frontend/test/features/tenant_facility/presentation/`
