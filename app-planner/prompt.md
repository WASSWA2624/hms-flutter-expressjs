You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and attached latest screenshots. Align the work with the existing Flutter/Riverpod implementation, `AppWorkspace`, `AppListTable`, `AppListTableSearch`, `AppSearchBar`, and the current workspace UI patterns.

## Goal

Unify the table layout, table search bar, advanced filters, and table settings controls across the workspace screens.

Every workspace table should follow this order:

1. Table title
2. Short table description
3. The table’s built-in search bar
4. Table content
5. Pagination/footer where applicable

The search bar must be the table’s built-in search bar, not a separate search bar above or outside the table.

## Screens to update

Update these workspace screens:

- Patients: `lib/features/patients/presentation/pages/patient_registry_page.dart`
- Billing: `lib/features/billing/presentation/pages/billing_workspace_page.dart`
- Claims: `lib/features/claims/presentation/pages/claims_workspace_page.dart`
- OPD: `lib/features/opd/presentation/pages/opd_workspace_page.dart`
- Emergency: `lib/features/emergency/presentation/pages/emergency_workspace_page.dart`
- IPD: `lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
- ICU: `lib/features/icu/presentation/pages/icu_workspace_page.dart`
- Nursing: `lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
- Clinical: `lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- Lab: `lib/features/lab/presentation/pages/lab_workspace_page.dart`
- Radiology: `lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- Pharmacy: `lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- Discharge: `lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
- Theater/Theatre: `lib/features/theater/presentation/pages/theater_workspace_page.dart`

Do not update Settings, Setup, or Tenant Facility setup screens.

## Shared component anchors

Use the existing shared table/search components:

- `lib/shared/components/app_list_table.dart`
- `AppListTable`
- `AppListTableSearch`
- `AppListTableColumnVisibilityController`
- `lib/shared/components/app_search_bar.dart`
- `AppSearchBar`
- `AppSearchBarFilterGroup`
- `AppSearchBarTextFilter`
- `AppSearchBarFilterValue`
- `lib/shared/layout/app_workspace.dart`
- `AppWorkspace`
- `AppWorkspaceDetailPanel`

Do not create a new table, search bar, filter bar, or table settings component.

## Required table layout

For each listed screen, the main table/worklist must visually appear as:

```text
Table title
Short description
Built-in table search bar: [search input] [advanced filters icon] [table settings icon]
Table rows / empty state
Pagination/footer
````

Use either:

* `AppListTable(title: ..., description: ..., search: AppListTableSearch(...))`, or
* `AppWorkspaceDetailPanel(title: ..., description: ..., child: AppListTable(search: AppListTableSearch(...)))`

The final visible order must still be title, description, built-in table search bar, then table content.

## Built-in table search requirement

Use `AppListTableSearch` through the `search:` parameter of `AppListTable`.

Do not use a separate `AppWorkspaceFilterBar` or standalone `AppSearchBar` for the main table search/filter controls.

Where a screen currently has a separate search/filter bar above the table, move that search/filter behavior into the table’s `AppListTableSearch`.

## Search bar controls

Each table search bar should contain only:

* Search text input
* One advanced filters button/icon
* One table settings button/icon

Keep the existing advanced filter icon behavior from `AppSearchBar`.

Keep the table settings button tied to the existing `AppListTable` column visibility behavior.

Do not add extra standalone toolbar buttons beside the search bar for:

* clear filters
* resource filters
* secondary filters
* subfilters

Those controls must be inside the advanced filters dialog.

The text-input clear icon may remain when the search text field has text. The separate “clear filters” toolbar action must not remain.

## Advanced filters

All filters for a table must be accessed from one advanced filters button.

Move any separate table subfilters into that advanced filter dialog.

If needed, section the dialog contents, but keep them inside one filter dialog.

Examples:

* Radiology: remove the separate clear-filters button from the search bar. Keep clear/reset behavior inside the advanced filters dialog.
* Theater: merge theater filters and resource filters into one advanced filters dialog. Remove the separate resource-filters toolbar button and the separate clear-filters toolbar button.
* Pharmacy drug/stock table: move the separate stock-status filter into the table’s advanced filters dialog.
* Patients: move the current patient registry search/filter controls into the patient table’s built-in `AppListTableSearch` flow.

Preserve the current filter behavior, values, labels, controller calls, and query updates.

## Current implementation cleanup anchors

### Patients

Current patient registry search/filter controls are outside the table through `_PatientFilters`, `AppWorkspaceFilterBar`, and a standalone `AppSearchBar`.

Update the patient registry so:

* `Patient records` appears above the description.
* The search bar appears below the description.
* The search bar is provided by `AppListTableSearch` on `AppListTable<Patient>`.
* The existing advanced patient filter dialog behavior is preserved.
* The table settings button is provided through the table/search pattern.
* The search/filter bar no longer appears above the table title.

### Radiology

Current radiology search bar includes a separate clear-filters action.

Update it so:

* The search bar has only the search input, advanced filters button, and table settings button.
* The clear/reset filters action is available inside the advanced filters dialog.
* Existing radiology stage, status, modality, and date filtering behavior is preserved.

### Theater/Theatre

Current theater search bar includes separate theater filters, resource filters, and clear filters.

Update it so:

* There is one advanced filters button.
* Theater status, stage, scheduled date, room, surgeon, and anesthetist filters are available from that one advanced filters dialog.
* The separate resource filters toolbar button is removed.
* The separate clear-filters toolbar button is removed.
* Existing theater query/controller behavior is preserved.

### Pharmacy

Current pharmacy drug/stock table uses a separate `AppWorkspaceFilterBar`.

Update that table so:

* Search is provided through `AppListTableSearch`.
* Stock-status filtering is moved into the advanced filters dialog.
* The table settings button appears through the table’s built-in controls.
* Existing drug search, stock-status filtering, and pagination behavior is preserved.

### Other listed screens

Audit the remaining listed screens and ensure they follow the same layout and control pattern.

If a screen already has the correct order and uses `AppListTableSearch`, preserve it.

## Implementation rules

* Do not change backend behavior.
* Do not add backend routes.
* Do not add new API calls.
* Do not change payload shapes.
* Do not change table columns unless required only to keep existing column settings behavior.
* Do not change row selection behavior.
* Do not change row actions.
* Do not change detail dialogs or workflow dialogs.
* Do not change summary-card behavior from the previous update.
* Do not change permissions.
* Do not change search/filter semantics; only move controls into the unified table search/filter pattern.
* Preserve existing labels, icons, localization keys, validation, loading states, success handling, error handling, refresh behavior, and pagination behavior.

## Acceptance criteria

* All listed workspace tables follow the same visual order: title, description, built-in search bar, table content.
* Main table search uses `AppListTableSearch`, not a separate search bar.
* The search bar shows only search input, advanced filters, and table settings.
* Advanced filters are accessed through one button per table.
* Separate clear-filter toolbar buttons are removed.
* Separate resource/subfilter toolbar buttons are moved into the advanced filter dialog.
* Patient registry no longer shows the search bar above the table title.
* Radiology no longer shows a separate clear-filters button beside the search bar.
* Theater no longer shows separate resource-filter or clear-filter buttons beside the search bar.
* Pharmacy drug/stock table no longer uses a separate filter bar.
* Existing table data, filters, pagination, row actions, dialogs, controller calls, and backend behavior remain unchanged.

