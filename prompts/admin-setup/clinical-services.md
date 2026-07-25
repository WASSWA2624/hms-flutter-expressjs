# Radiology procedure catalog delete lifecycle

Clarify delete scope and add soft-delete → permanent-delete for radiology procedures on Clinical Services → Radiology.

## Context

Row **Delete** uses facility-removal copy but calls `deleteRadiologyCatalogProcedure`, soft-deleting the tenant catalog procedure—not a facility offering. Soft-deleted rows are hidden; no permanent purge or status column. Mirror Tenants/Facilities soft-delete → restore → permanent-delete.

## Requirements

1. Rewrite delete confirm copy to state the procedure’s real catalog ownership/scope (tenant), not “remove from facility.”
2. Soft-delete first; keep soft-deleted rows visible with a **Deletion status** column (`Active` / `Soft deleted`).
3. Soft-deleted rows expose **Permanent delete** (and **Restore** if that shared pattern applies); permanent delete removes the row after confirm.
4. Gate soft delete, restore, and permanent delete with existing catalog-mutation permissions; hide unauthorized actions.
5. Button loading on submit; immediate table patch on success; l10n for empty, error, validation (required reason), and success.

## Constraints

- Reuse Admin Setup delete/restore/permanent-delete dialogs; follow `.cursor/mandatories.mdc` and related UI/RBAC/sync/prisma rules.
- Do not conflate facility offering disable with catalog delete; no invented ownership; no unrelated refactors.

## Acceptance Criteria

- Delete dialog names true catalog scope; never implies facility-only removal for catalog delete.
- Soft-deleted rows stay Soft deleted; active as Active; permanent delete only after soft delete, then row gone.
- Unauthorized delete/restore/permanent-delete controls absent; loading, validation, error, success feedback localized.
- Tests cover status visibility, permanent-delete gate, scope copy, permission absence; manual check across viewports and themes.

## Relevant Files

- `screens/admin-setup/clinical-services.md`
- `facility_catalog_config_panel.dart`, `clinical_catalog_admin_dialogs.dart`, `radiology_entities.dart`
- `backend/src/modules/radiology-test/`
