# Reports tab — Activity

## 1. Tab strip

- Label: `reportsPanelActivity`
- Icon: `Icons.insights_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Resource: `analytics-events`
- Tab gate: catalog read + pack (admin/operations/general)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Shared items table chrome
- Storage: `reports_items_activity` / `reports_items_cw_activity`

## 3. Table

- Shared items table
- Timeline rail may also show `reportsTimelineTitle` / `reportsTimelineDescription` (up to 6 items) when non-empty (sibling chrome)

## 4. Advanced filters / search fields

- Shared groups; date unused

## 5. Primary / secondary / row actions

- Row select → preview

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Preview detail | Reports-owned |

## 7. Nested / follow-on

- Print / Download when entitled

## 8. Forms (summary)

- None activity-specific

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
