# Align Beds Setup With Departments

Fix the false ward gate on `/admin/setup?section=beds`, and bring the Beds tab to the same scoped list/CRUD pattern as Departments and Units. Follow `prompts/.cursor/prompt.mdc`.

## Context

Departments and Units list via scoped APIs. Beds still read `FacilitySetupSnapshot.wards` / `snapshot.beds` / `snapshot.rooms`, so Platform Admin can see wards elsewhere while Beds shows **"Create at least one ward before adding beds."** Hierarchy: **Tenant → Facility → Ward → Room (optional) → Bed**. Fields: label, required ward, optional room, status. Search hint: "Search beds by label, ward, room, or status".

**Accessible ward:** a non-deleted ward the actor may see under RBAC/ABAC. Ward is required; room is optional and must belong to the selected ward when set.

## Requirements

1. Load and filter Beds independently (like `_DepartmentSetupSection`), scoped by account type; do not gate on wizard `snapshot.wards` alone.
2. Show the ward gate copy only when **no accessible ward** exists. When wards exist and beds are empty, show only **"No beds have been added."** Keep **+ Create bed** enabled when write access and at least one accessible ward exist.
3. **Platform Admin:** list all beds; filters Tenant / Facility / Ward / Room / Status; create selects Tenant → Facility → Ward → Room (optional).
4. **Tenant Admin:** list beds in their tenant; filters Facility / Ward / Room / Status; tenant preselected; create selects Facility → Ward → Room (optional).
5. **Facility Admin:** list beds in their facility; filters Ward / Room / Status; tenant and facility preselected; create selects Ward → Room (optional).
6. Table parity with Departments: `#`, bed label, ward, room, status, facility (when in scope), tenant (platform only), Edit / soft-Delete (Restore for soft-deleted). Backend remains authoritative for visible rows and actions.
7. Before create/edit persist, always open a dedicated bed similarity dialog (even when no matches), scoped like create, excluding the edited bed; support cancel / proceed-with-caution per existing structure similarity UX.
8. After mutations, refresh the Beds list (and related setup counts) without a misleading empty/gate flash. Cover loading, empty, no-results, error/retry, success, and validation feedback. When ward changes, revalidate room so options stay ward-scoped.

## Constraints

- Reuse Departments/Units list scope helpers, search/filter chrome, structure soft-delete/restore dialogs, form layout, and theme tokens.
- Do not invent a parallel beds auth model; unauthorized controls must not render.
- Soft delete only from the list Delete action (no hard-delete unless shared by structure CRUD).

## Acceptance Criteria

- With wards present and no beds, Beds empty state has no ward-gate sentence and Create bed works (Req 1–2).
- With zero accessible wards, gate copy appears and create stays blocked (Req 2).
- Each account type sees only in-scope rows, columns, filters, and create selectors (Req 3–6).
- Similarity dialog always appears before save (Req 7).
- List updates after mutations; room stays ward-scoped; unauthorized UI absent (Req 6, 8).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` (`_BedSetupSection`, `_BedFormDialog`, `_DepartmentSetupSection`)
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `backend/src/modules/bed/`
- `frontend/test/features/tenant_facility/presentation/` (mirror departments/units gating/similarity tests)
