# Align Wards Setup With Departments

Fix the false department prerequisite gate on `/admin/setup?section=wards`, and bring the Wards tab to the same scoped list/CRUD pattern as Departments and Units. Follow `prompts/.cursor/prompt.mdc`.

## Context

Departments and Units list via scoped APIs. Wards still read `FacilitySetupSnapshot.departments` / `snapshot.wards`, so Platform Admin can see departments elsewhere while Wards shows **"Create at least one department before adding wards."** Hierarchy: **Tenant → Facility → Department (optional) → Ward**. Fields: name, type (`GENERAL` | `ICU` | `MATERNITY` | `PEDIATRIC` | `SURGICAL` | `OTHER`), optional department, active. Search hint: "Search wards by name, type, department, or status".

**Accessible department:** a non-deleted department the actor may see under RBAC/ABAC. Department is optional on create; product still gates create until at least one accessible department exists.

## Requirements

1. Load and filter Wards independently (like `_DepartmentSetupSection`), scoped by account type; do not gate on wizard `snapshot.departments` alone.
2. Show the department gate copy only when **no accessible department** exists. When departments exist and wards are empty, show only **"No wards have been added."** Keep **+ Create ward** enabled when write access and at least one accessible department exist.
3. **Platform Admin:** list all wards; filters Tenant / Facility / Department / Type / Status; create selects Tenant → Facility → Department (optional).
4. **Tenant Admin:** list wards in their tenant; filters Facility / Department / Type / Status; tenant preselected; create selects Facility → Department (optional).
5. **Facility Admin:** list wards in their facility; filters Department / Type / Status; tenant and facility preselected; create selects Department (optional) only.
6. Table parity with Departments: `#`, ward name, type, department, facility (when in scope), tenant (platform only), status, Edit / soft-Delete (Restore for soft-deleted). Backend remains authoritative for visible rows and actions.
7. Before create/edit persist, always open a dedicated ward similarity dialog (even when no matches), scoped like create, excluding the edited ward; support cancel / proceed-with-caution per existing structure similarity UX.
8. After mutations, refresh the Wards list (and related setup counts) without a misleading empty/gate flash. Cover loading, empty, no-results, error/retry, success, and validation feedback.

## Constraints

- Reuse Departments/Units list scope helpers, search/filter chrome, structure soft-delete/restore dialogs, form layout, and theme tokens.
- Do not invent a parallel wards authorization model; unauthorized controls must not render.
- Soft delete only from the list Delete action (no hard-delete unless already shared by structure CRUD).

## Acceptance Criteria

- With departments present and no wards, Wards empty state has no department-gate sentence and Create ward works (Req 1–2).
- With zero accessible departments, gate copy appears and create stays blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, and create selectors (Req 3–6).
- Similarity dialog always appears before save on create/edit (Req 7).
- List updates after create/edit/delete/restore; unauthorized UI absent in tests (Req 6, 8).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_WardSetupSection`, `_WardFormDialog`, `_DepartmentSetupSection`)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `backend/src/modules/ward/`
- `frontend/test/features/tenant_facility/presentation/` (mirror departments/units tab gating/similarity tests)
