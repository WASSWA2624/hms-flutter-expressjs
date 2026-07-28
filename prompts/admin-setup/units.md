# Align Units Setup With Departments

Fix the false department prerequisite gate on `/admin/setup?section=units`, and bring the Units tab to the same scoped list/CRUD pattern as Departments. Follow `prompts/.cursor/prompt.mdc`.

## Context

Departments already lists via its own scoped API and shows rows for the signed-in admin. Units still reads `FacilitySetupSnapshot.departments` / `snapshot.units`, so Platform Admin sees departments on the Departments tab but Units shows **"No units have been added. Create at least one department before adding units."** Hierarchy: **Tenant → Facility → Department → Unit**. Search hint today: "Search units by name, department, or status".

**Accessible department:** a non-deleted department the actor may see under RBAC/ABAC for their account scope.

## Requirements

1. Load and filter Units independently (like `_DepartmentSetupSection`), scoped by account type; do not gate on wizard `snapshot.departments` alone.
2. Show the department gate copy only when **no accessible department** exists. When departments exist and units are empty, show only **"No units have been added."** Keep **+ Create unit** enabled when write access and at least one accessible department exist.
3. **Platform Admin:** list all units; filters Tenant / Facility / Department / Status; create selects Tenant → Facility → Department.
4. **Tenant Admin:** list units in their tenant; filters Facility / Department / Status; tenant preselected; create selects Facility → Department.
5. **Facility Admin:** list units in their facility; filters Department / Status; tenant and facility preselected; create selects Department only.
6. Table parity with Departments: `#`, unit name, department, facility (when in scope), tenant (platform only), status, Edit / soft-Delete (Restore for soft-deleted). Backend remains authoritative for visible rows and actions.
7. Before create/edit persist, always open a dedicated unit similarity dialog (even when no matches), scoped like create, excluding the edited unit; support cancel / proceed-with-caution per existing structure similarity UX.
8. After mutations, refresh the Units list (and related setup counts) without a misleading empty/gate flash. Cover loading, empty, no-results, error/retry, success, and validation feedback.

## Constraints

- Reuse Departments list scope helpers, search/filter chrome, structure soft-delete/restore dialogs, form layout, and theme tokens.
- Do not invent a parallel units authorization model; unauthorized controls must not render.
- Soft delete only from the list Delete action (no hard-delete unless already shared by structure CRUD).

## Acceptance Criteria

- With departments present and no units, Units empty state has no department-gate sentence and Create unit works (Req 1–2).
- With zero accessible departments, gate copy appears and create stays blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, and create selectors (Req 3–6).
- Similarity dialog always appears before save on create/edit (Req 7).
- List updates after create/edit/delete/restore; unauthorized UI absent in tests (Req 6, 8).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_UnitSetupSection`, `_UnitFormDialog`, `_DepartmentSetupSection`)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `backend/src/modules/unit/`
- `frontend/test/features/tenant_facility/presentation/` (mirror departments tab gating/similarity tests)
