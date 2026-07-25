# Verify radiology procedure delete lifecycle

Confirm Clinical Services → Radiology soft-delete → restore → permanent-delete; fix gaps.

## Context

Radiology table shows **Deletion status**. Active: **Edit** + **Delete**. Soft-deleted: **Restore** + **Permanent delete**. Delete must open soft-delete confirm (tenant catalog scope, not facility offering removal) and soft-delete only. Restore returns **Active**. Permanent delete erases the DB row after soft-delete + type-name confirm. Mirror Tenants/Facilities patterns in this panel.

## Requirements

1. Confirm **Delete** on Active opens soft-delete `AppConfirmActionDialog` and soft-deletes only; row stays Soft deleted.
2. Confirm soft-deleted rows expose Restore + Permanent delete only; Active rows expose Edit + Delete only.
3. Confirm **Restore** clears soft-delete and sets status to Active.
4. Confirm **Permanent delete** requires soft-delete first, type-name validation, then hard-deletes and removes the row.
5. Confirm unauthorized users see no lifecycle actions; loading, error, success, validation feedback stay localized.
6. If checks fail, fix contracts/UI per `.cursor/mandatories.mdc` and related UI/RBAC/sync rules.

## Constraints

- Reuse existing dialogs, routes, permissions, status column; no invented ownership; no unrelated refactors.

## Acceptance Criteria

- Active Delete opens soft-delete dialog and marks Soft deleted without removing the row.
- Soft-deleted rows show Restore + Permanent delete only; Active rows show Edit + Delete only.
- Restore returns Active; permanent delete removes the DB row and table entry.
- Unauthorized lifecycle actions absent; loading/error/success/validation works.
- Tests/manual checks cover dialog open, status transitions, permanent-delete gate, permission absence; spot-check viewports and themes.

## Relevant Files

- `screens/admin-setup/clinical-services.md`
- `facility_catalog_config_panel.dart`, `radiology_entities.dart`
- `backend/src/modules/radiology-procedure/`
