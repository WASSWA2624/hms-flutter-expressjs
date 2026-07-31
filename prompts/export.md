# Shared AppListTable Excel export

Add a reusable Export action on `AppListTable` search bars so users can choose columns and optional filters, then download the matching rows as an Excel (`.xlsx`) workbook—defaulting to the table’s current Settings visibility, with the option to include or exclude any available column.

## Context

- Primary surface: `frontend/lib/shared/components/app_list_table.dart` (`AppListTable`, column visibility Settings, search-bar trailing actions).
- Search / filter chrome: `frontend/lib/shared/components/app_search_bar.dart` (`AppSearchBar`, advanced Filters dialog with date from/to, field choices, text filters, and `AppSearchBarFilterGroup`s).
- Column Settings already live in the search-bar trailing actions (`Icons.settings_outlined`) and use `_ColumnVisibilityDialog` / `AppListTableColumnVisibilityController` + `AppListTableColumnVisibilityMemory`.
- Trailing-action order today: Filters (in `AppSearchBar`) → Settings (table) → caller actions (e.g. Create). Place **Export** in that trailing cluster (typically immediately before Settings, or immediately after Filters) so it stays with table tooling rather than primary create actions.
- No shared Excel export package or table-export dialog exists yet in the frontend; module-specific “export” flows (reports evidence, mortuary, biomedical) are separate and must not be conflated with this table export.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppDialog` / `AppButton` / search-bar action patterns.

## Requirements

1. **Export search-bar action:** When export is enabled for an `AppListTable`, show an **Export** `AppSearchBarAction` (download/share-style icon, localized label/tooltip) in the search-bar trailing actions alongside Filters and Settings. Support an explicit opt-in/opt-out (e.g. `enableExport` / caller-supplied `onExport` config) so tables that must not export stay unchanged.
2. **Export dialog:** Tapping Export opens an `AppDialog` that lets the user:
   - Select which **columns** to include in the export (checkbox list of available table columns, respecting `alwaysVisible` the same way Settings does).
   - Optionally apply **export-scoped filters** without permanently rewriting the live table filter unless product wiring intentionally shares state:
     - Date range (**From** / **To**), reusing the same date-filter UX patterns as `AppSearchBar`.
     - Column / field filters with conditions (reuse or mirror `AppSearchBar` filter groups / text filters / field choices where the table already exposes them).
   - Confirm with a primary **Export** action and a dismiss/cancel path.
3. **Sync with Settings:** On open, pre-select export columns from the table’s **current visible columns** (Settings / visibility controller / memory). Users may then add hidden columns or remove visible ones for this export only. Changing export checkboxes must **not** mutate live table Settings unless the user separately applies Settings. Always-visible columns stay included and non-toggleable, matching Settings behavior.
4. **Default row set:** By default, export uses the rows the table currently presents after its active search/sort/filters (or the caller-supplied export dataset). Export-dialog filters further narrow that set for the file only. Empty selection (no columns, or no matching rows) must block export with clear localized feedback—no empty silent download.
5. **Excel output:** Produce a single-sheet `.xlsx` file whose header row uses the selected column labels and whose data cells are plain exportable values derived from each row (prefer stable string/number/date values supplied by the caller or a column export value resolver—not raw widget trees from `cellBuilder`). Trigger a platform-appropriate save/download/share after generation.
6. **Loading & feedback:** While generating/saving, show in-dialog button loading (`AppButton.isLoading`); on success give brief localized confirmation; on failure show a non-silent error (snackbar/dialog pattern already used by shared components). Respect offline / unavailable file APIs with a disabled or failed state and reason.
7. **Permissions:** Gate the Export action with the caller’s access policy when provided (hide or disable when unauthorized). Do not invent a new global “table export” permission; reuse module `:export` / existing screen gates the same way other destructive or sensitive list actions are gated. Backend authorization remains the caller’s responsibility for any server-backed export path.
8. **API shape:** Prefer a shared helper/dialog (e.g. `AppListTableExportDialog` + export value adapters) wired through `AppListTable` / `AppListTableSearchConfig` so feature pages do not fork per-table Excel UI. Allow callers to supply:
   - column export value extractors (or map selected column keys → cell values),
   - optional filter schema already used by the table’s search bar,
   - filename stem,
   - optional permission / enable flags.
9. **l10n + tests:** English strings for Export action, dialog title, column section, filter labels (reuse common date/filter keys where they already exist), empty-selection errors, success/failure, and loading. Widget/unit tests for: Export appears when enabled; dialog prefills from Settings visibility; toggling export columns does not change Settings; filters narrow the exported row set; Excel generation is invoked with selected columns only; disabled/unauthorized hides or disables the action.

Optional enhancements: none.

## Constraints

- Reuse `AppListTable`, `AppSearchBar`, `AppDialog`, `AppButton`, and existing column-visibility / filter models. Do not invent a parallel table chrome or a second Settings dialog that drifts from visibility memory.
- Export column pickers must stay synchronized with Settings **defaults on open**; they are not a second persistence store for live table columns.
- Prefer client-side Excel generation from the in-memory (or caller-fetched) row set for this shared control. Do not build a new backend bulk-export API unless an existing module endpoint is already the source of truth for that list—and then still keep the shared dialog/column UX.
- Do not conflate this with reports evidence export, mortuary export, or biomedical print/export atoms; those remain module-specific.
- No unrelated refactors outside shared list-table export wiring, Excel dependency addition, l10n, and tests.
- Responsive: dialog and trailing actions remain usable on mobile (overflow menu) and desktop dense toolbars.
- Follow `.cursor/mandatories.mdc` for loading, responsive layout, and access gating.

## Acceptance Criteria

- AC1 (Req 1–2): Enabled tables show Export in the search-bar trailing actions; tap opens a dialog with column selection and optional date/column filters plus Export/cancel actions.
- AC2 (Req 3): Dialog opens with columns pre-checked from current Settings visibility; changing export checks does not alter live table columns; always-visible columns stay locked on.
- AC3 (Req 4–5): Export writes an `.xlsx` with only selected columns and filter-matching rows; empty columns/rows are blocked with localized feedback.
- AC4 (Req 6–7): Loading, success, and error feedback work; unauthorized users do not get a working Export control when the caller gates it.
- AC5 (Req 8–9): Shared API is reusable across list tables; English l10n and tests cover prefills, Settings isolation, column/filter selection, and export invocation.

## Relevant Files

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_list_table_column_visibility_memory.dart`
- `frontend/lib/shared/components/app_dialog.dart`
- `frontend/lib/shared/components/app_button.dart`
- `frontend/lib/shared/components/components.dart`
- `frontend/pubspec.yaml` (Excel / file save dependency as needed)
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/components/`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`
