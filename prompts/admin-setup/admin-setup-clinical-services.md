# Admin Setup — Clinical Services Radiology Create Procedure

Verify and fix Create procedure on Admin Setup Clinical Services Radiology: mutation dialog, create path, similarity check, sync, and permission-gated create/edit/delete.

## Context

- Route: `/admin/setup?section=clinical-services`, Radiology tab (`FacilityCatalogConfigPanel`).
- Create procedure opens `RadiologyCatalogMutationDialog` and persists via `createRadiologyCatalogProcedure`.
- Similarity runs against catalog candidates before create/edit.
- Radiology procedures means global catalog procedures (not order priority).

## Requirements

1. Confirm Create procedure (search trailing and empty state) opens the create dialog; open the scope picker first when `tenantId` is missing.
2. Confirm create persists via the API, refreshes the Radiology table, and shows success without stale rows.
3. Confirm similarity on create/edit covers loading, match review, and proceed/cancel, aligned with backend uniqueness.
4. Gate Create, Edit, and Delete to roles that may create, edit/update, and delete radiology catalog procedures; hide unauthorized controls; enforce the same on backend mutations.
5. Align payloads and post-mutation UI sync with backend responses and refresh patterns.

## Constraints

- Reuse existing catalog dialogs, similarity helpers, repositories, routes, and design-system components.
- Follow `.cursor/mandatories.mdc` and access rules; backend RBAC is authoritative.
- Skip Lab, Diagnoses, and Configure enable wizards unless needed for gating.

## Acceptance Criteria

- Authorized: create dialog opens; create persists; table updates immediately.
- Similarity: near-duplicates surface; cancel/proceed match UX; backend rejects true conflicts.
- Unauthorized: Create/Edit/Delete absent; API rejects those mutations.
- Loading, empty, error, validation, and success states stay localized.

## Relevant Files

- `screens/admin-setup-clinical-services.md`, `facility_catalog_config_panel.dart`, radiology catalog dialogs/similarity, API, permissions, `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`
