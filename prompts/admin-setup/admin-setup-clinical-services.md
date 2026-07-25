# Clinical Services — Complete Catalog Column Settings

Wire the **Settings** (table column settings) control on Admin Setup → Clinical Services so Radiology, Lab, and Diagnoses each expose every catalog field as a togglable column.

## Context

- Route: `/admin/setup?section=clinical-services` (`FacilityCatalogConfigPanel`).
- Nested tabs already pass `columnVisibilityLabel` and storage keys `admin_catalog_radiology`, `admin_catalog_lab`, `admin_catalog_diagnoses`.
- `AppListTable` Settings opens the shared column-settings dialog (**Apply columns** / **Reset columns** / **Close**). Optional fields belong in `columnChoices`; `actions` stays `alwaysVisible`.
- Reuse existing `AppListTable` visibility memory, labels, and lab/radiology catalog column patterns.

## Requirements

1. Keep Settings available on Radiology, Lab, and Diagnoses when more than one column exists; open the shared column-settings dialog for that tab only.
2. Radiology choices: all meaningful `RadiologyCatalogTest` fields (at least name, code, modality, body region, laterality, procedure type, equipment, status/source) with existing l10n labels.
3. Lab choices: all meaningful `LabCatalogItem` fields (at least name, type, code, category, specimen type, result kind, unit/ranges or test count, description) matching lab catalog table patterns.
4. Diagnoses choices: all meaningful `ClinicalCatalogOption` fields (at least name, code, category, status/secondary text when present on the entity).
5. Default visible columns stay the current defaults; extra fields start hidden until selected. Persist per existing storage keys; Reset restores defaults.
6. Cover loading, empty, error, and authorized/disabled (`enabled`) states without new unauthorized chrome. Keep mobile/tablet/desktop usable in light and dark themes.

## Constraints

- Reuse `AppListTable` column visibility; do not invent a parallel settings UI.
- Do not change Configure, create/edit/delete, or enable-offering flows.
- No unrelated refactors. Prefer existing column builders/labels over new copy.

## Acceptance Criteria

- Each nested tab’s Settings lists every defined data column for that catalog and toggles visibility independently.
- Apply persists; Reset restores defaults; reload keeps the saved set for that storage key.
- `actions` remains visible when the panel is enabled; unauthorized/disabled behavior is unchanged.
- Manual check: toggle columns on all three tabs across desktop and a narrow viewport in light and dark themes.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart` (catalog `columnChoices` pattern)
- `screens/admin-setup-clinical-services.md`
