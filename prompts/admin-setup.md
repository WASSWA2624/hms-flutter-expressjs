# Populate Clinical Services nested catalog on `/admin/setup`

When a facility is selected on Clinical Services (`?section=clinical-services`), show nested category tabs and searchable offering tables that match other Admin Setup desk patterns.

## Context

- Desk tab Clinical Services → `FacilityCatalogConfigPanel`; no facility/tenant keeps the empty “Select or create a facility…” state.
- Nested tabs: **Lab** (tests/panels), **Diagnostics** (imaging/diagnostic offerings), **Budget** (offering prices/charges).
- Reference: `screens/admin-setup.md`. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. Keep the no-facility empty state; with facility + tenant, show nested `AppTabStrip`: Lab, Diagnostics, Budget.
2. Each tab uses `AppListTable` populated from existing catalog APIs for that category.
3. Each search bar includes search, Filter, Settings, and a context Add/Enable/Configure action that opens the matching catalog dialog.
4. Active rows expose Edit and Delete (or remove/disable); mutations reload the current tab.
5. Cover permission, loading, empty, error, success, and validation states; unauthorized mutate controls must not render.

## Constraints

- Reuse `FacilityCatalogConfigPanel`, `AppListTable`, and existing clinical/lab/radiology catalog dialogs and APIs.
- Map Diagnostics → diagnostic/radiology offerings; Budget → price/charge config from current catalog data.
- No drive-by refactors outside Clinical Services.

## Acceptance Criteria

- No facility → empty prompt only.
- Facility selected → Lab / Diagnostics / Budget tables with search, Filter, Settings, Add/Configure.
- Row Edit/Delete work and refresh; dialogs match tab context.
- Unauthorized users never see mutate actions; UI works on mobile/tablet/desktop in light and dark themes.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `screens/admin-setup.md`
