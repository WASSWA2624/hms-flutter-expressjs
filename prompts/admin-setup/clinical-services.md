# Expand Clinical Services Lab Create Test dialog

Make Create Lab Test on Clinical Services → Lab comprehensive, chronological, and easy to use.

## Context

- Route: `/admin/setup?section=clinical-services`, Lab tab.
- **Create test** opens `LabCatalogItemMutationDialog` with only name, code, category, specimen, description as plain text.
- Backend create schema already supports `result_kind`, units, options, and age/gender ranges; reuse `LabCatalogTestDialog` patterns.

## Requirements

1. Expand create/edit for lab **tests**: name and code first; searchable known **category** and **specimen type** (not free-text-only).
2. Add result config next: `result_kind` (NUMERIC / QUALITATIVE / TEXT), unit / unit options, qualitative options when needed, description.
3. Support multiple reference ranges (label, unit, gender, age bounds, normal/critical or text); add/remove; prefill one Adult range.
4. Persist full payload via existing create/update APIs; refresh Lab table; localize loading, validation, error, success.
5. Gate Create/Edit with lab-catalog permissions; hide unauthorized actions; backend authoritative.
6. Keep scope picker when `tenantId` missing. Migrate only if needed.

## Constraints

- Reuse lab reference-range widgets, validators, repositories, and form controls from `LabCatalogTestDialog`.
- Progressive disclosure by result kind; no radiology/diagnosis refactors.
- Follow `.cursor/mandatories.mdc` and access rules; responsive; theme tokens.

## Acceptance Criteria

- Ordered form: identity → category/specimen → result kind/units/options → reference ranges.
- Category/specimen use searchable known options; multiple age/gender ranges save and reload.
- Table syncs after save; unauthorized Create/Edit absent.
- Tests/manual checks cover payload, range validation, permissions; spot-check viewports/themes.

## Relevant Files

- `screens/admin-setup/clinical-services.md`, `facility_catalog_config_panel.dart`, `clinical_catalog_admin_dialogs.dart`, `lab_catalog_dialogs.dart`
- `backend/src/modules/lab-test/`, `backend/prisma/schema.prisma`
- `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`
