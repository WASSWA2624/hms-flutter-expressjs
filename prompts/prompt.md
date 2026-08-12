# Full-query table export, print, and infinite scroll

## Context

`AppListTable` list surfaces paginate the matching dataset. Export and Print currently serialize **loaded rows** (the current `AppPage.items` slice, or rows accumulated so far in infinite scroll). That is incorrect: operators must export and print every row that matches the **applied query**, even when those rows are not yet painted.

Infinite scroll is the default pagination mode. Some tables stop requesting further pages after a small batch even when the backend still has matching rows (`AppPage.hasNextPage` is true, or `totalItemCount` exceeds loaded length).

Follow [tables.mdc](/.cursor/tables.mdc) for toolbar/export chrome, [printing.mdc](/.cursor/printing.mdc) for preview-first Print, [tabs.mdc](/.cursor/tabs.mdc) for tab–filter–count sync, and [prompt.mdc](/.cursor/prompt.mdc) for RBAC and UI states. Do not restate those files.

### Terms

- **Applied query:** the committed search text, Advanced filters, active tab/scope, and sort that already drive the table and tab counts. Not draft filter-dialog edits that were never applied.
- **Loaded rows:** rows currently held by the table widget (one page, or pages accumulated by infinite scroll).
- **Matching dataset:** every backend (or in-memory) row that satisfies the applied query, regardless of page size or how far the user has scrolled.
- **Export-dialog filters:** extra column/date/field filters inside `AppListTableExportDialog`. They further narrow the matching dataset for the Excel file only; they must not shrink the source to loaded rows first.
- **Print options:** preview section/column choices from [printing.mdc](/.cursor/printing.mdc). They shape the document; they must not limit rows to loaded rows.

## Requirements

1. **Export uses the matching dataset.** When the user confirms Export, resolve every row in the matching dataset, then apply export-dialog filters and selected columns. Do not export only loaded rows. Reuse `AppListTableExportDialog`, `AppListTableExportConfig`, and `buildAppListTableExcelBytes`.

2. **Print uses the matching dataset.** When Print opens preview, pass every matching-dataset row (mapped through existing `*print_helpers` / `PrintDocumentTemplates`). Preview row counts (`commonPrintRowCountLabel`) must equal the matching-dataset size after print options, not `AppPage.items.length`. Keep preview-first Print; do not print silently.

3. **Applied query is the only row limiter for the source set.** Search, Advanced filters, and the active tab/scope bound the matching dataset. Column visibility, viewport height, `maxVisibleItems`, progressive reveal, and current scroll position must not bound export or print source rows.

4. **Paged backends page through the same query.** For tables backed by `AppPage` / `AppPageRequest`, fetch remaining pages with the same applied query until `hasNextPage` is false. Use `AppPageRequest.maxPageSize` (`appListTablePreferredPageSize`, 100). Do not add an unfiltered dump endpoint. Do not raise `limit` above the backend max.

5. **In-memory tables already holding the full filtered set** (for example Reception desk lists, OPD `exportItems`) must export and print that full filtered membership, not a visible page slice.

6. **Table UI stays paged.** Do not load the entire matching dataset into the on-screen table solely to support export/print. Fetch the matching dataset in the export/print path (or via a shared resolver the table can call). Infinite scroll continues to append into the table independently.

7. **Infinite scroll continues while more matching rows exist.** For `AppListTablePaginationMode.infinite` with `page` + `onPageChanged`, request `page.request.next()` whenever the user scrolls near the end and `page.hasNextPage` is true. Keep requesting after each successful append until `hasNextPage` is false. Do not stop after the first page, a fixed row cap, or a single reveal batch when more pages exist.

8. **`hasNextPage` must stay truthful.** Controllers and repositories must set `AppPage.totalItemCount` to the applied-query total (same meaning as tab counts in [tabs.mdc](/.cursor/tabs.mdc)). Do not treat a full first page as the entire dataset when a total is available and is larger.

9. **`onPageChanged` must load the next page.** Do not pass a no-op `onPageChanged` on paged tables that still have more matching rows. Client-side full lists may keep a no-op only when the table already holds the entire matching dataset and `hasNextPage` is false.

10. **Permissions.** Omit Export and Print when the existing feature `canExport*` / `canPrint*` (or equivalent AccessRequirement) is false. Do not render disabled Export/Print. Do not fetch matching-dataset rows for unauthorized users.

11. **Export states.** While resolving the matching dataset or writing the file: show loading on the export dialog (disable Export, keep Close). Empty matching dataset or empty post-dialog-filter set: existing empty-rows message; do not write a file. Failure: existing failure message; dialog stays open. Success: existing success snackbar and close. Validation: existing empty-columns and invalid-date messages.

12. **Print states.** While resolving the matching dataset: show loading before or inside preview; do not open a preview that implies a complete document until rows are resolved (or show an explicit loading preview). Empty matching dataset: existing empty print copy. Failure: visible error; do not send to the printer. Success: existing preview then Print. Disable final Print when print options cannot produce a document ([printing.mdc](/.cursor/printing.mdc)).

13. **Infinite-scroll states.** While the next page is in flight: `commonLoadingMoreLabel`. When `hasNextPage` is false and at least one row is loaded: `commonAllRowsLoadedLabel`. On load-more failure: surface the existing workspace/table error path; keep already-loaded rows; allow retry by scrolling again or using the existing retry control. Do not clear accumulated rows on a failed next-page fetch.

14. **Sync.** After mutations, refresh, search submit, filter apply, or tab change, reset accumulation to page 0 of the new applied query. Export/print started after that change must use the new matching dataset, not a stale previous-tab page.

## Constraints

- Reuse `AppListTable`, `AppListTableExportConfig` / `AppListTableExportDialog`, `showAppPrintPreviewDialog` / `PrintDocumentTemplates`, existing `changePage` / list repository methods, and feature `*_workspace_print_helpers.dart`. Prefer one shared matching-dataset resolver on the table/export path over per-feature forks.
- Do not change toolbar order, Export/Print labels, Advanced filters chrome, or print preview shell.
- Do not restyle tables or invent a second scroller.
- Do not export or print rows the applied query excludes.
- Do not bypass RBAC/ABAC. Backend remains authoritative.
- Localization, theming, and responsiveness: [localization.mdc](/.cursor/localization.mdc), [theming.mdc](/.cursor/theming.mdc), [responsiveness.mdc](/.cursor/responsiveness.mdc). Add l10n keys only if new user-facing copy is required (for example export/print fetch loading). Prefer existing `commonTableExport*` / `commonLoadingMoreLabel` / `commonAllRowsLoadedLabel` / `printPreviewTitle` keys.
- Out of scope: changing default visible columns, export column catalogs, print document layout, button pagination mode, and unrelated workspace refactors.

## Optional enhancements

- Cancellable matching-dataset fetch with a determinate progress label when many pages remain.
- Shared `AppListTableExportConfig` async items loader so call sites do not pass `state.*.items` into Print.

These are optional. Requirements 1–14 are mandatory.

## Acceptance Criteria

1. **R1.** Given a paged table whose applied query matches N rows and the UI has loaded fewer than N, confirming Export with no extra export-dialog filters writes N data rows (plus header) to the Excel file.

2. **R2.** Given the same table, opening Print preview shows `commonPrintRowCountLabel(N)` (when summary is included) and the rows section lists N records, not the loaded-page length.

3. **R3.** Given Advanced filters or search that reduce the matching dataset to M rows, Export and Print include M rows and exclude rows that fail the applied query, even if those excluded rows exist in the database.

4. **R4.** Matching-dataset fetches for paged tables use `pageSize <= AppPageRequest.maxPageSize` and the same search/filter/scope query parameters as the table list API.

5. **R5.** OPD (and other in-memory full-set tables) still export/print the full filtered tab membership, not only the current `AppPage` slice.

6. **R6.** After Export or Print, the on-screen table still shows only loaded/accumulated pages; it does not jump to an unpaginated full dump.

7. **R7.** Scrolling to the end of a table with `hasNextPage == true` invokes `onPageChanged` with the next `AppPageRequest` and appends the new rows. Repeating this until `hasNextPage == false` loads every matching row into the table.

8. **R8.** When `totalItemCount` is 250 and `pageSize` is 100, the first page does not report end-of-list; the footer does not show `commonAllRowsLoadedLabel` until all 250 matching rows are accumulated.

9. **R9.** Paged workspace tables that still have more matching rows do not use a no-op `onPageChanged`.

10. **R10.** With export/print permission denied, Export and Print are absent; no matching-dataset fetch runs. With permission allowed, both actions remain available on desktop where Print is shown today.

11. **R11.** Export dialog shows loading while pages are fetched; empty matching dataset shows the empty-rows message and writes no file; a thrown fetch/write error shows the failure message and leaves the dialog open; a successful save shows the success snackbar.

12. **R12.** Print does not send a document to the printer if matching-dataset fetch fails. Empty matching dataset uses existing empty print copy. Preview remains the only path to Print.

13. **R13.** Next-page in-flight shows `commonLoadingMoreLabel`. A failed next-page fetch keeps previously accumulated rows and still allows another load attempt.

14. **R14.** Changing tab, applying filters, or submitting search resets to the first page of the new query; a subsequent Export/Print uses that query’s matching dataset.

15. **Verification.** Extend `frontend/test/shared/components/app_list_table_test.dart` so infinite scroll requests page 2+ while `hasNextPage` remains true and does not show all-rows-loaded early. Extend `frontend/test/shared/components/app_list_table_export_test.dart` so export bytes include rows beyond the loaded page when a matching-dataset source is supplied (and, if a fetch resolver is added, that it is invoked on Export). Add or extend a representative workspace test (Claims or Billing queue, plus one in-memory desk such as OPD or Reception) proving Print/Export row counts follow the matching dataset, not `page.items.length`. Keep existing permission tests that assert unauthorized Export/Print are absent and authorized actions remain. Manually check one large paged workspace in light and dark themes at a compact phone width and a desktop width: scroll until all-rows-loaded, then Export and Print and confirm counts match the tab badge / `totalItemCount`.

## Relevant Files

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_list_table_export.dart`
- `frontend/lib/shared/data/app_pagination.dart`
- `frontend/lib/shared/printing/printing.dart`
- `frontend/lib/shared/printing/templates/print_document_templates.dart`
- `frontend/lib/l10n/app_en.arb`
- Feature table call sites that pass `state.*.items` into Print or omit a matching-dataset export source, including:
  - `frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart`
  - `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
  - `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
  - `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
  - `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`
  - `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
  - `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- Feature `*_workspace_print_helpers.dart` under `frontend/lib/features/`
- Workspace `changePage` controllers under `frontend/lib/features/*/presentation/controllers/`
- `frontend/test/shared/components/app_list_table_test.dart`
- `frontend/test/shared/components/app_list_table_export_test.dart`
- `frontend/test/shared/data/app_pagination_test.dart`
- Representative feature permission/workspace tests under `frontend/test/features/`
