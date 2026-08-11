# Reports tab — Catalog

## 1. Tab strip

- Label: `reportsPanelCatalog`
- Icon: `Icons.article_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: panel via Filters only; `?dataset=` opens Catalog + dataset filter
- Resource: `report-definitions`
- Tab gate: catalog read + pack includes `catalog`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `reportsSearchHint` / clear `reportsClearSearchLabel`
- Filters: panel + status (`reportsStatusFilterLabel` / `reportsAllStatusesLabel`) + format (`reportsFormatFilterLabel` / `reportsAllFormatsLabel`) + dataset (`reportsDatasetFilterLabel` / `reportsAllDatasetsLabel`, tailored)
- Settings: Table Settings; storage `reports_items_catalog` / `reports_items_cw_catalog`
- Export: table default **ungated**; row Download/Print need evidence export in detail
- Print: table off; detail Print `reportsPrintAction`
- Date UI present but **not** bound to `query.from`/`to`

## 3. Table

- `AppListTable<ReportsWorkspaceItem>` under `AppCollapsibleSection` title = panel label
- Defaults: Name (`reportsNameColumnLabel`), Reference (`reportsReferenceLabel`), Updated (`reportsUpdatedColumnLabel`), Status (`reportsStatusColumnLabel`); + `next_action` (`reportsNextActionColumnLabel`) if write\|export
- Choices: owner, format, dataset, facility, category, description, value, error
- Row select → detail; pagination `reportsPreviousPageLabel` / `reportsNextPageLabel`
- Empty: `reportsNoItemsTitle` / `reportsNoItemsBody`

## 4. Advanced filters / search fields

- Groups: panel / status / format / dataset (lookups)
- Client search matcher covers hidden fields
- Date labels present; not applied

## 5. Primary / secondary / row actions

- Next-action definition: Run (`reportsRunAction`) if write; else Schedule
- Detail omits primary next-action duplicate; keeps Schedule / Print / Download as applicable

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Preview detail `reportsPreviewTitle` | Reports-owned |
| Run `reportsRunDialogTitle` | Reports-owned |
| Schedule `reportsScheduleDialogTitle` | Reports-owned |

## 7. Nested / follow-on

- Run → period day/month/year/custom (`reportsPeriod*`) + format + retention
- Schedule → name, frequency (`DAILY`/`WEEKLY`/`MONTHLY` or lookups), time, format, retention
- Success snackbar `reportsSavedMessage`; run success also switches panel to **delivery**

## 8. Forms (summary)

- Run: format, period (`day|month|year|custom`), retention days
- Schedule: name (required), frequency, time of day, format, retention; timezone = device

## 9. Print / labels / preview

- Detail Print → `PrintDocumentTemplates.registry` + `reportsPrintSubtitle` / `reportsPrintFooter`
- Download run: `reportsDownloadAction` → snackbar `reportsDownloadRequestedMessage`
- Table Export: present by AppListTable default (ungated)

## 10. Loading / empty / error / success

- Table `isRefreshing`; empty keys above; mutation failures in dialogs; success `reportsSavedMessage`
- Preview series: `reportsPreviewLoadingTitle/Body`, `reportsPreviewEmptyBody`, `reportsPreviewSeriesTitle`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab/list/search/filters/settings | catalog read + pack |
| Run / Schedule next-action & dialogs | `reportsWriteRequirement` / admin |
| Download / Print in detail | `reportsExportRequirement` / admin |
| next_action column | write **or** export |
| Dataset filter options | `canAccessReportsDataset` / category permissions |
| Delete | requirement exists; **omitted** |
| Table Export | ungated (gap) |
