# Align Rooms Setup With Departments

Fix the false prerequisite gate on `/admin/setup?section=rooms`, and bring the Rooms tab to the same scoped list/CRUD pattern as Departments and Units. Follow `prompts/.cursor/prompt.mdc`.

## Context

Departments and Units list via scoped APIs. Rooms still read `FacilitySetupSnapshot` (`departments`, `wards`, `rooms`), so Platform Admin can see structure elsewhere while Rooms shows **"Create at least one department or ward before adding rooms."** Hierarchy: **Tenant → Facility → Ward (optional) → Room**. Fields: name, optional ward, optional floor. Soft-delete only. Search hint: "Search rooms by name, ward, floor, or status".

**Accessible facility:** a non-deleted facility the actor may see under RBAC/ABAC. Ward is optional on create; rooms do not require a department.

## Requirements

1. Load and filter Rooms independently (like `_DepartmentSetupSection`), scoped by account type; do not gate on wizard `snapshot.departments` / `snapshot.wards` alone.
2. Show gate copy only when **no accessible facility** exists. When facilities exist and rooms are empty, show only **"No rooms have been added."** Keep **+ Create room** enabled when write access and at least one accessible facility exist.
3. **Platform Admin:** list all rooms; filters Tenant / Facility / Ward / Status (deleted); create selects Tenant → Facility → Ward (optional).
4. **Tenant Admin:** list rooms in their tenant; filters Facility / Ward / Status; tenant preselected; create selects Facility → Ward (optional).
5. **Facility Admin:** list rooms in their facility; filters Ward / Status; tenant and facility preselected; create selects Ward (optional) only.
6. Table parity with Departments: `#`, room name, ward, floor, facility (when in scope), tenant (platform only), status (active vs soft-deleted), Edit / soft-Delete (Restore for soft-deleted). Backend remains authoritative for visible rows and actions.
7. Before create/edit persist, always open a dedicated room similarity dialog (even when no matches), scoped like create, excluding the edited room; support cancel / proceed-with-caution per existing structure similarity UX.
8. After mutations, refresh the Rooms list (and related setup counts) without a misleading empty/gate flash. Cover loading, empty, no-results, error/retry, success, and validation feedback.

## Constraints

- Reuse Departments/Units list scope helpers, search/filter chrome, structure soft-delete/restore dialogs, form layout, and theme tokens.
- Do not invent a parallel rooms authorization model; unauthorized controls must not render.
- Soft delete only from the list Delete action (no hard-delete unless already shared by structure CRUD).
- Drop the department-or-ward gate; rooms do not require a department.

## Acceptance Criteria

- With accessible facility and no rooms, Rooms empty state has no false gate sentence and Create room works (Req 1–2).
- With zero accessible facilities, gate copy appears and create stays blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, and create selectors (Req 3–6).
- Similarity dialog always appears before save on create/edit (Req 7).
- List updates after create/edit/delete/restore; unauthorized UI absent in tests (Req 6, 8).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_RoomSetupSection`, `_RoomFormDialog`, `_DepartmentSetupSection`)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `backend/src/modules/room/`
- `frontend/test/features/tenant_facility/presentation/` (mirror departments/units tab gating/similarity tests)
