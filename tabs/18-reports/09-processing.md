# Reports tab — Processing

## 1. Tab strip

- Label: `reportsPanelProcessing`
- Icon: `Icons.policy_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Tab gate: `reportsComplianceReadRequirement`
- Kind: `dataProcessing`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same compliance shell as Audit
- Settings storage: `reports_compliance_processing` / `reports_compliance_cw_processing`

## 3. Table

- Same compliance log table surface
- Empty: `reportsNoComplianceLogsTitle` / `reportsNoComplianceLogsBody`

## 4. Advanced filters / search fields

- Type choices: `TREATMENT|BILLING|OPERATIONS|RESEARCH|MARKETING` → API `purpose`
- Date UI present; not set by Filters apply

## 5. Primary / secondary / row actions

- Next-action Export evidence; detail Print

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Compliance detail | Reports-owned |
| Export evidence confirm | Reports-owned |

## 7. Nested / follow-on

- Confirm → registry evidence print

## 8. Forms (summary)

- Confirm-only

## 9. Print / labels / preview

- Evidence registry templates

## 10. Loading / empty / error / success

- Same compliance shell feedback

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | compliance read/review |
| Export evidence / Print | `evidence:export` / admin |
| Table Export | ungated |
