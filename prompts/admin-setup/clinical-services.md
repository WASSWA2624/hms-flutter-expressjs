# Lab table row opens details, not edit

On Admin Setup → Clinical Services → Lab, open the existing details dialog on row select; keep edit/delete on explicit actions and wire those from details into existing mutate flows.

## Context

- Route: `/admin/setup?section=clinical-services`, Lab tab in `FacilityCatalogConfigPanel`.
- Inventory: `screens/admin-setup/clinical-services.md`.
- Today `onRowSelected` opens `_openLabEditDialog` for non-standard mutable rows; `showLabCatalogItemDetailsDialog` exists with Close only.
- Reuse handlers, `canMutateLabCatalog`, dialogs, design-system. Follow `.cursor/mandatories.mdc`.

## Requirements

1. Row select on a test opens test details; on a panel opens panel details (`showLabCatalogItemDetailsDialog`).
2. Row select must not open `LabCatalogItemMutationDialog`.
3. Row **Edit** still opens edit (same gates: no standard edit; mutate permission required).
4. Details exposes **Edit** and **Delete** when mutable; call the same edit/delete paths as the table.
5. Omit Edit/Delete when unauthorized or non-mutable (e.g. standard); keep Close. No disabled unauthorized controls.
6. Keep existing edit/delete loading, validation, error, success feedback; details open needs no full-region loader.

## Constraints

- Lab nested-tab row interaction and details actions only.
- No new mutate APIs; no Radiology/Diagnoses refactor.

## Acceptance Criteria

- Test/panel row select opens matching details (1).
- Row select never opens edit mutation (2).
- Table Edit/Delete unchanged (3).
- Details Edit/Delete reuse table flows and feedback when allowed (4–6).
- Unauthorized/standard items show no Edit/Delete on details (5).
- Tests: row→details vs Edit→mutation; details visibility by permission/standard; smoke Lab xs/desktop, light/dark.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_details_dialog.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/facility_catalog/lab_catalog_mutate_visibility.dart`
- `screens/admin-setup/clinical-services.md`
- `frontend/test/shared/lab_catalog/`, facility-catalog visibility tests
