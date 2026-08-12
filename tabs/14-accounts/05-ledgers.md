# Accounts tab — Patient ledgers

## 1. Tab strip

- Label: `AccountsStrings.patientLedgersLabel` (`Patient ledgers`)
- Icon: `Icons.person_outline`
- Count source: `accountsSectionTabCount` → `accountsPatientLedgersBalanceCountProvider` ?? `AccountsSummary.ledgersWithBalance`; active + narrowed (search / Filters) → panel pushes filtered total
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `ledgers` (alias `patient-ledgers`); may pass `patientId`, `search`
- Tab gate: `AccountsPatientLedgersAtomPermissions.tab` = ∩ `accounts:read` + `facility-accounts`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (no strip context actions)

- Search hint: `Patient…`
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close**
  - Date filter: **omitted** (justified — clearance/patient scope only; no updated-date query on this list)
- Settings: Table Settings; key `accounts_ledgers_v1`; exposes defaults + Clearance / Updated; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsPatientLedgersAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable`
- Context trailing actions: **none**

## 3. Table

- Row model: `AccountsPatientBalance`
- Row select: `showAccountsPatientLedgerDialog` — generic title `Patient ledger` (identity in body)
- Default columns (**5** when Next allowed):
  1. Patient (alwaysVisible)
  2. Invoiced
  3. Paid
  4. Balance
  5. Next (`Pay` if balance + billing write, else `Ledger`) — alwaysVisible / not exportable; **omitted** without pay ∨ ledgers read (justified → 4)
- Column choices (Settings extras): Clearance, Updated
- Mobile: trailing Pay / Ledger

## 4. Advanced filters / search fields

- Text: Patient
- Groups: Clearance (Cleared / Partial / Outstanding)
- Same panel filter model drives table rows and active tab badge

## 5. Primary / secondary / row actions

- Next Pay → **reused** Billing Collect due deep-link (`section=collect&action=pay&patientId=`)
- Next Ledger / row → Accounts patient ledger dialog

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Patient ledger | Accounts-owned `showAccountsPatientLedgerDialog` | Generic `Patient ledger` |
| Billing collect (Pay) | **reused** route navigation | Billing-owned |

## 7. Nested / follow-on

Ledger dialog → Print packet options. Pay leaves Accounts for Billing (allowed ownership handoff).

## 8. Forms (summary)

- No create form on this tab; Pay uses Billing forms after navigation
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- Dialog Print → `printAccountsPatientLedgerPacket` → `claimStatement` template reuse

## 10. Loading / empty / error / success

- Loading: panel-local `_loading`
- Empty: `No patients match.`
- Error: table error string
- Success: dialog mutations / Billing handoff

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings / Ledger | `accountsPatientLedgersReadRequirement` |
| Pay | `accountsPayDeepLinkRequirement` (billing write ∩ `billing-payments`) |
| List Export / Print | ∩ `evidence:export` |
