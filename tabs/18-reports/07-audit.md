# Reports tab — Audit

## 1. Tab strip

- Label: `reportsPanelAudit`
- Icon: `Icons.manage_search_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Tab gate: `reportsComplianceReadRequirement` (∪ `compliance:read` \| `compliance:review` + admin)
- Kind: audit compliance logs
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `reportsComplianceSearchHint`
- Filters: panel + type (`reportsComplianceTypeFilterLabel`) — audit actions `CREATE|UPDATE|DELETE|ACCESS|EXPORT|LOGIN|LOGOUT`
- Settings: `reports_compliance_audit` / `reports_compliance_cw_audit`
- Export table: ungated default; row Export evidence / Print need `evidence:export`
- Print table: off
- No schedules/timeline for compliance panels

## 3. Table

- `AppListTable<ComplianceLogItem>`
- Defaults: Event (`reportsEventColumnLabel`), User (`reportsUserColumnLabel`), Record (`reportsRecordColumnLabel`), Timestamp (`reportsTimestampColumnLabel`); + next_action Export if export
- Choices: patient, action, entity, scope, purpose, legal_basis, facility, ip, details
- Empty: `reportsNoComplianceLogsTitle` / `reportsNoComplianceLogsBody`

## 4. Advanced filters / search fields

- Status filter maps to API `action` query param
- Date labels present; `query.from`/`to` → API `date_from`/`date_to` **if set**, but UI does not set them

## 5. Primary / secondary / row actions

- Next-action: `reportsExportEvidenceAction` → confirm then print path
- Detail: Print; Export omitted when it is the row primary

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Compliance detail `reportsComplianceDetailTitle` | Reports-owned |
| Export confirm `reportsExportEvidenceDialogTitle` / `Body` | Reports-owned |

## 7. Nested / follow-on

- Confirm → registry print path

## 8. Forms (summary)

- No edit forms; confirm-only

## 9. Print / labels / preview

- Print/export evidence → `PrintDocumentTemplates.registry` + `reportsEvidenceSubtitle` / `reportsEvidenceFooter`

## 10. Loading / empty / error / success

- Scaffold loading; compliance empty keys; no success snackbar on print path (unless download elsewhere)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings | compliance read/review |
| Export evidence / Print | `evidence:export` / admin |
| Catalog panels in filter choices | only if also catalog-entitled |
| Write mutations | n/a on compliance |
| Table Export | ungated |
