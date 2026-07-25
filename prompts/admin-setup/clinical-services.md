# Admin Setup — Clinical Services Radiology Edit Procedure

Verify and fix Edit procedure on Admin Setup Clinical Services Radiology: edit dialog, single-field updates, similarity excluding the edited row, sync, permissions.

## Context

- Route: `/admin/setup?section=clinical-services`, Radiology tab (`FacilityCatalogConfigPanel`).
- Row Edit / row select opens `RadiologyCatalogMutationDialog` (edit); persist via `updateRadiologyCatalogProcedure`.
- Similarity mirrors create but excludes the current procedure id/apiId; exact clashes with another procedure must block without a proceed path.
- Radiology procedures means global catalog procedures (not order priority).

## Requirements

1. Confirm every Radiology row Edit (and row select) opens the edit dialog prefilled.
2. Confirm saving one changed field updates without requiring other fields to change.
3. Confirm similarity excludes the edited procedure so unchanged values never self-match.
4. Confirm near-match flow matches create; exact conflicts block with clear field errors.
5. Confirm update persists via API, refreshes the table immediately, with localized loading/error/validation/success.
6. Gate Edit to update-capable roles; hide unauthorized Edit; enforce on backend.

## Constraints

- Reuse mutation dialog, similarity helpers (`excludeProcedureId`), repositories, routes, and design-system.
- Follow `.cursor/mandatories.mdc` and access rules; backend RBAC authoritative.
- Skip Create, Lab, Diagnoses, and Configure wizards unless shared edit code needs them.

## Acceptance Criteria

- Authorized: edit opens prefilled; single-field save persists; table updates immediately.
- Similarity: current row excluded; near-duplicates surface; exact conflicts block clearly.
- Unauthorized: Edit absent; API rejects.
- Localized loading, error, validation, and success states stay visible.

## Relevant Files

- `screens/admin-setup/clinical-services.md`, `facility_catalog_config_panel.dart`, `clinical_catalog_admin_dialogs.dart`, radiology similarity/update API, permissions, `.cursor/mandatories.mdc`
