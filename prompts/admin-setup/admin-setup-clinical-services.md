# Clinical Services — Catalog Column Settings

Expose every meaningful catalog field as a togglable column via **Settings** on Clinical Services (Radiology, Lab, Diagnoses).

## Context

- Route: `/admin/setup?section=clinical-services` (`FacilityCatalogConfigPanel`).
- Tabs already set `columnVisibilityLabel` and keys `admin_catalog_radiology`, `admin_catalog_lab`, `admin_catalog_diagnoses`.
- `AppListTable` Settings opens shared column settings. Put optional fields in `columnChoices`; keep `actions` `alwaysVisible`.
- Reuse visibility memory and lab/radiology catalog column patterns.

## Requirements

1. Keep Settings on all three tabs when >1 column exists; scope the dialog to the active tab.
2. Radiology choices: meaningful `RadiologyCatalogTest` fields (name, code, modality, body region, laterality, procedure type, equipment, status/source) with existing l10n.
3. Lab choices: meaningful `LabCatalogItem` fields (name, type, code, category, specimen, result kind, unit/ranges or test count, description) matching lab catalog tables.
4. Diagnoses choices: meaningful `ClinicalCatalogOption` fields (name, code, category, plus status/secondary when present).
5. Keep current defaults visible; extras start hidden. Persist via existing keys; Reset restores defaults.
6. Preserve loading, empty, error, and `enabled`/auth states across mobile–desktop and themes.

## Constraints

- Reuse `AppListTable` visibility only; no parallel settings UI.
- Do not change Configure, CRUD, or enable-offering flows.
- No unrelated refactors; prefer existing builders/labels.

## Acceptance Criteria

- Each tab’s Settings lists every defined data column and toggles independently.
- Apply persists; Reset restores defaults; reload keeps the saved set.
- `actions` stays visible when enabled; unauthorized behavior unchanged.
- Manual: toggle all three tabs on desktop and narrow, light and dark.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
- `screens/admin-setup-clinical-services.md`
