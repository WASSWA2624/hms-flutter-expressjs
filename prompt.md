# Lab — Result Report Preview UI Simplification

## Context
Refactor the **Result Report Preview** dialog in the Lab module (`_LabReportPreviewDialog` / `_LabReportPreview` in `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`). The dialog lets users choose which test results to include before printing. Keep the dialog title **"Result Report Preview"** unchanged.

## Goal
Replace the current multi-section layout with a single, clean, searchable table that doubles as both the selection UI and the print preview. The preview must accurately reflect what appears on the printed report.

## Remove
- The options header (`_reportOptionsHeader`): selection title, hint text, "Include order details" toggle, selected-count label, and **Select all** / **Clear selection** actions.
- Per-order section headers (`_PreviewOrderSectionHeader`) and order metadata blocks (order ID, ordered-at, order status) from the preview body.
- The **Close** footer action (dialog already has a close control in the top-right).
- The custom `_PreviewResultsTable` / Flutter `Table` implementation.

## Keep
- Dialog title and print icon.
- **Reset selection** and **Print report** footer actions.
- Existing selection state (`_selectedItemIds`, `_toggleReportItem`, `_resetSelection`, `_printSelectedReport`).
- Patient name and patient ID in the report header (above the table).
- Signature / stamp placeholder below the table.

## Replace with `AppListTable`
Use the shared `AppListTable` component (`frontend/lib/shared/components/app_list_table.dart`), following patterns from `lab_workspace_page.dart`.

### Columns
| # | Column | Notes |
|---|--------|-------|
| 1 | *(selection)* | Row checkbox per test. **Header checkbox** selects/deselects all visible rows (respecting active search filter). No "Include" column label — checkbox only. |
| 2 | Tests | `item.displayTitle` |
| 3 | Reference range | `item.displayReferenceRange` |
| 4 | Result | `item.displayResultValue` |
| 5 | Flag | `_resolveItemResultFlagLabel` |

Wire `AppListTableColumnVisibilityController` so users can show/hide data columns (Tests, Reference range, Result, Flag) via the table's column-settings control. **Selection checkbox column is always visible.** Only visible columns should appear in the printed report.

### Search
Enable `AppListTableSearch` so users can filter tests by name, result value, flag, etc.

### Abnormal result highlighting
Reuse existing abnormal-detection logic (`_isAbnormalStatus`, `_computedNumericFlagToken`, `_resolveItemResultFlagLabel`). In the preview table:
- Color-code abnormal rows/flags (e.g. error tone for High, Low, Critical, Abnormal).
- Apply the same styling in the **printed HTML** (`_labReportTableHtml` / `_labReportPrintStyle`) so abnormal results remain visually distinct on paper.

## Print behavior
- Print only **selected** rows.
- Print only **visible** (column-settings-enabled) columns — exclude the selection checkbox from print output.
- Remove order-details branching (`showOrderDetails`); always render a flat results table.
- Ensure preview and print output stay in sync.

## Acceptance criteria
- [ ] Dialog shows only: patient info, searchable `AppListTable` with column settings, signature placeholder, and footer actions (**Reset selection**, **Print report**).
- [ ] Header checkbox toggles all filtered rows; per-row checkboxes toggle individual tests.
- [ ] Abnormal results are flagged and color-coded in preview and print.
- [ ] Column visibility preferences control which data columns appear in preview and print.
- [ ] No redundant Close button, selection hints, order-detail toggles, or separate select-all/clear controls outside the table.
- [ ] Existing print flow and selection reset continue to work.
