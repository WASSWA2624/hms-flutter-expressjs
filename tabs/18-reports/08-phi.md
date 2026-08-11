# Reports tab — PHI

## 1. Tab strip

- Label: `reportsPanelPhi`
- Icon: `Icons.privacy_tip_outlined`
- Count source: **none**
- Count tone: n/a
- Deep-link: Filters panel only
- Tab gate: `reportsComplianceReadRequirement`
- Kind: `ComplianceLogKind.phiAccess`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same compliance shell as Audit
- Search hint: `reportsComplianceSearchHint`
- Settings storage: `reports_compliance_phi` / `reports_compliance_cw_phi`
- Export table ungated; Print table off

## 3. Table

- Same `AppListTable<ComplianceLogItem>` defaults/choices as Audit
- Empty: `reportsNoComplianceLogsTitle` / `reportsNoComplianceLogsBody`

## 4. Advanced filters / search fields

- Type choices: `TENANT|FACILITY|DEPARTMENT|PATIENT` → API `access_scope`
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

- Evidence registry templates (`reportsEvidenceSubtitle` / `reportsEvidenceFooter`)

## 10. Loading / empty / error / success

- Same compliance shell feedback

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | compliance read/review |
| Export evidence / Print | `evidence:export` / admin |
| Table Export | ungated |
