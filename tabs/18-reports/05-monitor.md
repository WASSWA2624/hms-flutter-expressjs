# Reports tab — Monitor

## 1. Tab strip

- Label: `reportsPanelMonitor`
- Icon: `Icons.bar_chart_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Resource: `kpi-snapshots`
- Tab gate: catalog read + pack (admin/general; not finance-only / pharmacy / reception packs)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Shared items table chrome
- Storage: `reports_items_monitor` / `reports_items_cw_monitor`

## 3. Table

- Shared `_ReportItemsPanel`; KPI `value` via Settings column `reportsValueLabel`
- No dedicated monitor actions beyond detail preview

## 4. Advanced filters / search fields

- Shared panel/status/format/dataset; date unused

## 5. Primary / secondary / row actions

- Row select → preview

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Preview detail | Reports-owned |

## 7. Nested / follow-on

- Print / Download when entitled

## 8. Forms (summary)

- None monitor-specific

## 9. Print / labels / preview

- Detail only when export-entitled

## 10. Loading / empty / error / success

- Shared items keys

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab/list | catalog read + pack |
| Detail Print / Download | `evidence:export` / admin |
| Table Export | ungated |
