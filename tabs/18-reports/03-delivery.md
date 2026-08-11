# Reports tab — Delivery

## 1. Tab strip

- Label: `reportsPanelDelivery`
- Icon: `Icons.outbox_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Resource: `report-runs`
- Tab gate: catalog read + pack includes `delivery`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same Filters model as Catalog (panel/status/format/dataset)
- Settings storage: `reports_items_delivery` / `reports_items_cw_delivery`
- Export table ungated; Print table off
- Date UI not wired

## 3. Table

- Same `_ReportItemsPanel` surface as Catalog (`AppListTable<ReportsWorkspaceItem>`)
- Default 4 columns + optional next_action
- Row select → run detail
- Empty: `reportsNoItemsTitle` / `reportsNoItemsBody`
- Schedules sibling still visible (non-domain)

## 4. Advanced filters / search fields

- Panel / status / format / dataset; date UI unused

## 5. Primary / secondary / row actions

- Run rows: Retry (`reportsRetryAction`) if FAILED+write; Cancel (`reportsCancelRunAction`) if QUEUED\|PROCESSING+write; Download if `downloadAvailable`+export
- Cancel confirm: `reportsCancelRunDialogTitle` / `reportsCancelRunDialogBody`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Preview / run detail | Reports-owned |
| Cancel confirm | Reports-owned |
| Retry / Download / Print paths | Reports-owned |

## 7. Nested / follow-on

- Same print/download nested paths as Catalog detail

## 8. Forms (summary)

- Cancel confirm only (no edit forms on list)

## 9. Print / labels / preview

- Detail Print / Download when export-entitled; table Export ungated

## 10. Loading / empty / error / success

- Shared items loading/empty; `reportsSavedMessage` / `reportsDownloadRequestedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab/list | catalog read + pack |
| Retry / Cancel | `reportsWriteRequirement` / admin |
| Download / Print | `reportsExportRequirement` / admin |
| Table Export | ungated |
