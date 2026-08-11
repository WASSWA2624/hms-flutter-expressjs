# Reports tab — Dashboards

## 1. Tab strip

- Label: `reportsPanelDashboards`
- Icon: `Icons.dashboard_customize_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Resource: `dashboard-widgets`
- Tab gate: catalog read + pack includes `dashboards` (e.g. admin/finance/general; **omitted** for pharmacy-only pack)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same `_ReportItemsPanel` chrome as Catalog/Delivery
- Storage: `reports_items_dashboards` / `reports_items_cw_dashboards`
- Export ungated; Print table off

## 3. Table

- Shared items table; row kinds typically widgets
- Default 4 columns + optional next_action
- Next-action often none → row select opens preview only
- No dashboard-specific create chrome

## 4. Advanced filters / search fields

- Panel / status / format / dataset; date UI unused

## 5. Primary / secondary / row actions

- Row select → preview detail; write/export actions when item kind supports them

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Preview detail | Reports-owned |

## 7. Nested / follow-on

- Print / Download when entitled from detail

## 8. Forms (summary)

- None specific beyond shared run/schedule if reachable for item kind

## 9. Print / labels / preview

- Detail Print when export-entitled; table Export ungated

## 10. Loading / empty / error / success

- Shared items empty/loading keys

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab/list | catalog read + pack |
| Write / export detail actions | write / evidence export |
| Table Export | ungated |
