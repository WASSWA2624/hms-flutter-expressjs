# Feature: Refine radiology request dialog flow

## Goal

Modernize the **Request radiology** and **Choose imaging study** dialogs so they match the Lab request pattern: patient context in the toolbar, table-based selection, facility-scoped catalog browsing, and minimal instructional chrome. Apply this flow **everywhere** radiology is ordered (patients quick actions, OPD/IPD/ICU/nursing/clinical/radiology workspaces).

## Problem (current UI)

Screenshots show two friction points:

1. **Request radiology** — redundant help text, a separate “No items / Price not set” summary bar, a dropdown for selected studies, and a Cancel button that duplicates the dialog close control.
2. **Choose imaging study** — cramped filter layout, a single-select dropdown catalog, and an immediate “+ Add” pattern that does not scale for multi-study orders.

## Reference implementation

Mirror the Lab request flow:

| Concern | Lab reference |
|--------|----------------|
| Main request dialog | `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart` |
| Catalog picker | `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_request_catalog_dialog.dart` |
| Shared toolbar / patient strip / selected table | `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart` (`ClinicalRequestFlowToolbar`, `ClinicalRequestPatientContextStrip`, `ClinicalRequestSelectedCatalogTable`) |
| Table primitives | `frontend/lib/shared/components/app_list_table.dart`, `app_search_bar.dart` |

**Radiology files to update:**

- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_radiology_catalog_helpers.dart`
- All call sites that open `ClinicalRadiologyOrderActionDialog` (patients, OPD, IPD, ICU, nursing, clinical, radiology workspaces)

## Dialog 1 — Request radiology

### Remove

- Instructional body text (`clinicalRequestMainPanelHelp`).
- `ClinicalRequestFlowSummaryBar` (“No items”, “Price not set”).
- `ClinicalRequestSelectionManager` dropdown for selected studies.
- Footer **Cancel** button (dialog **X** / backdrop dismiss is sufficient).

### Add / change

**Toolbar (single row)**

- **Leading:** `ClinicalRequestPatientContextStrip` with patient name, patient ID, and encounter ID (pass `ClinicalRequestPatientContext` from every entry point, same as Lab). When the caller has encounter context (OPD, ED, IPD, etc.), surface the encounter identifier the order will be attached to.
- **Trailing:** `+ Add study` and **Review billing** (keep existing billing dialog wiring).

**Selected studies area**

Replace the dropdown with `ClinicalRequestSelectedCatalogTable` (or an equivalent built on `AppListTable`):

| Column | Content |
|--------|---------|
| Select | Row checkbox; support multi-select for bulk remove |
| Name | Imaging test / procedure name |
| Modality | Resolved modality label |
| Price | Facility price from catalog option |
| Actions | Per-row delete icon (`Icons.delete_outline`, error color) |

- Toolbar **Remove selected** when one or more rows are checked (reuse `showClinicalRequestRemoveItemsConfirmationDialog`).
- Empty state: centered muted text inside the table (no separate summary bar).
- Table footer shows billing total when items exist (reuse existing catalog table footer pattern).

**Footer**

- Single primary **Request radiology** button with leading icon (`Icons.biotech_outlined` or equivalent).
- Widen dialog (`maxWidth` ~880) and pin actions to bottom, matching Lab.

## Dialog 2 — Choose imaging study

### Filter layout

Use consistent `theme.spacing` between fields (fix cramped rows in screenshot):

| Row | Fields |
|-----|--------|
| 1 | **Modality** · **Laterality** |
| 2 | **Priority** · **Body region** |
| 3 | **Clinical note** (optional, full width) |

### Filter behavior

- **Modality** options must come only from modalities present in the **facility’s offered radiology catalog** (`clinicalRadiologyModalityOptions` on `referenceData.radiologyTests`). Do not show modalities the facility does not offer (e.g. hide Fluoroscopy when unsupported).
- Changing modality narrows laterality, body region, and catalog rows.
- **Laterality** shown when relevant to the filtered catalog (existing helper logic).
- **Body region** uses chip picker when ≤16 options; searchable select when more (keep `_RadiologyBodyRegionPicker` behavior).
- **Clinical note** is optional and applies to confirmed selections (same semantics as today).

### Catalog area

Remove `ClinicalCatalogSelectPanel` (dropdown + “+ Add”). Replace with an `AppListTable` of facility catalog items, modeled on the Lab catalog picker:

- Built-in **search bar**, **filters** (at minimum modality; reuse `AppSearchBar` filter groups where practical), and **Table settings** for column visibility.
- Default columns: **Select** (checkbox), **Name**, **Modality**, **Body region**, **Price** (optional columns via Table settings).
- Table rows respect active filters: modality, priority, body region (and search tokens).
- **Multi-select** via checkboxes; staged selections highlighted like Lab.
- Selected rows that are already in the parent request (or staged duplicates) are disabled or show duplicate feedback—**no duplicate test IDs** in the final request.
- Show selected count above the table.

### Footer

- Replace **Done** with primary **Confirm** + leading icon (`Icons.playlist_add_check`, matching Lab).
- Dialog returns the staged selections (list of `ClinicalRadiologyCatalogSelection`) on Confirm; parent dialog merges them into the request table.
- Support edit flow: when opened for a single existing row, pre-fill filters and selection.

## Business rules

- Catalog is **facility-scoped**: users only see radiology procedures offered by their facility (existing `referenceData.radiologyTests` / facility catalog APIs).
- Selections are **unique by radiology test ID** across the request.
- Per-study metadata (modality, laterality, body region, priority, clinical note) is preserved on each line item.
- Billing review remains optional before submit; do not block submit solely on billing unless existing validation requires it.

## Implementation rules

- **Reuse shared components** — do not fork table/search/toolbar markup; extend `ClinicalRequestSelectedCatalogTable` or shared column builders if Radiology needs a modality column instead of Lab’s type column.
- **Pass `ClinicalRequestPatientContext`** at every `ClinicalRadiologyOrderActionDialog` call site (follow Lab call sites in `patient_clinical_quick_actions.dart`, `opd_flow_actions_dialog.dart`, etc.).
- **Localization:** add/adjust keys in `frontend/lib/l10n/app_en.arb` (Confirm label, empty table text, column titles, selected count).
- **Tests:** update `frontend/test/shared/clinical_actions/clinical_radiology_order_action_dialog_test.dart` and add catalog dialog coverage for filter + multi-select behavior.
- **Scope:** UX and dialog flow only; do not change backend order APIs unless required for duplicate prevention already enforced client-side.

## Acceptance criteria

- [ ] Request radiology dialog shows patient name, patient ID, and encounter on the toolbar row with Add study / Review billing.
- [ ] Help text, summary bar, selection dropdown, and Cancel button are removed.
- [ ] Selected studies render in a searchable table with checkbox bulk-select, modality and price columns, and red delete actions.
- [ ] Request radiology submit button includes a leading icon.
- [ ] Choose imaging study uses the filter layout above with corrected spacing.
- [ ] Modality dropdown lists only modalities supported by the facility catalog.
- [ ] Catalog browse is table-based with search, filters, Table settings, and multi-select checkboxes.
- [ ] Confirm returns staged selections; duplicates are prevented.
- [ ] Flow works identically from all radiology entry points (patients, OPD, IPD, ICU, nursing, clinical, radiology workspace).
- [ ] Lab request patterns and `frontend/lib/shared/` components are reused—not forked markup.
