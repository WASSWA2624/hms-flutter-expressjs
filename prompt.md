# Lab Result Report Preview — UI refinements

Refine the **Result Report Preview** dialog (`_LabReportPreviewDialog` in `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`) shown when previewing/printing lab results. Match existing HMS patterns; prefer shared-component fixes over one-off styling.

## Context

The dialog uses `AppDialog` + `AppReportPreviewPanel` + `AppListTable`. The toolbar currently exposes search and **Table settings** only. Patient metadata sits above the table; footer actions are **Reset selection** (tertiary) and **Print report**.

## Requirements

### 1. Typography hierarchy (shared components first)

- **`AppListTable`** (`frontend/lib/shared/components/app_list_table.dart`): Reduce table header weight — column headers and `#` currently use `FontWeight.w700`–`w800`; soften to a lighter emphasis (e.g. `w600`–`w700`) so headers do not overpower row content.
- **`AppDialog`** (`frontend/lib/shared/components/app_dialog.dart`): Make the **dialog title** visually bolder/prominent (e.g. stronger weight on `_DialogHeader` title). Apply at component level so all dialogs benefit consistently.

### 2. Search toolbar — add Filter control

- Beside **Table settings**, show a **Filter** button using existing `AppListTableSearch` / `AppSearchBar` APIs (`filterGroups`, `filterValue`, `onFilterChanged`, or `showAdvancedFilterButton` where appropriate).
- Follow patterns from other workspaces (e.g. pharmacy, reports) for filter UX and l10n.
- Suggested lab report filters: result status/flag (Normal, Abnormal, Pending, Cancelled, Negative, etc.) and/or selection state (selected vs unselected). Keep scope practical for preview/print workflow.

### 3. Search must match all visible cell text

- Typing **"pending"** must surface rows whose **Result** shows the pending placeholder (`labStatusPendingResults`), not only rows with a stored result value.
- Extend `_matchesReportItemSearch` so search covers every user-visible string in the table: test name, reference range, **displayed result** (including pending/cancelled placeholders), and flag label.
- Search and filters should compose (both apply together).

### 4. Patient identity — clearer prominence

- Patient name and Patient ID above the table (`_PreviewMeta`) must be easy to scan at a glance — stronger typography and/or layout (e.g. label/value separation, `titleSmall`/`bodyLarge`, or a compact summary row). Do not rely on small `bodySmall` alone.

### 5. Reset selection — clearer action affordance

- Replace or restyle the plain **Reset selection** tertiary text action so it reads as an intentional reset control (e.g. secondary button with reset/clear icon, consistent with other HMS actions). Keep existing `_resetSelection` behavior.

## Acceptance criteria

- [ ] Dialog title is bolder; table headers are noticeably less bold.
- [ ] Filter button appears next to Table settings and filters rows correctly.
- [ ] Search finds rows by flag, test name, range, result value, **and** pending/cancelled display text.
- [ ] Patient name and ID are clearly visible without squinting.
- [ ] Reset selection looks and behaves like a deliberate reset action.
- [ ] Add/update l10n keys in `app_en.arb` as needed; run codegen if required.
- [ ] No regressions to print flow, row selection, or column visibility.

## Out of scope

- Changing print template/HTML layout.
- New backend fields or lab workflow logic.
