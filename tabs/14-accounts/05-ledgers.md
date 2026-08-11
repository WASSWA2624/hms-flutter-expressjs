# Accounts tab — Patient ledgers

## 1. Tab strip

- Label: `Patient ledgers`
- Icon: `Icons.person_outline`
- Count source: `accountsPatientLedgersBalanceCountProvider` ?? `ledgersWithBalance`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `ledgers` (alias `patient-ledgers`); may pass `patientId`, `search`
- Tab gate: `AccountsPatientLedgersAtomPermissions.tab` = ∩ `accounts:read` + `facility-accounts`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Search hint: `Patient…`
- Filters: present; **no date filter**
- Settings: `accounts_ledgers_v1`
- Export: `enableExport: true`
- Print (toolbar): **absent** (print in patient ledger dialog)
- Context trailing: none

## 3. Table

- Row model: `AccountsPatientBalance`
- Row select: open patient ledger dialog
- Default columns: Patient, Invoiced, Paid, Balance, Next (`Pay` if balance + billing write, else `Ledger`)
- Column choices: Clearance, Updated
- Next omitted without pay ∨ ledgers read
- Mobile: trailing Pay / Ledger

## 4. Advanced filters / search fields

- Text: Patient
- Groups: Clearance (Cleared / Partial / Outstanding)
- Date filter: **omitted**

## 5. Primary / secondary / row actions

- Next Pay → **reused** Billing Collect due deep-link (`section=collect&action=pay&patientId=`)
- Next Ledger / row → Accounts patient ledger dialog

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Patient ledger | Accounts-owned `showAccountsPatientLedgerDialog` |
| Billing collect (Pay) | **reused** route navigation |

## 7. Nested / follow-on

Ledger dialog → Print packet options. Pay leaves Accounts for Billing.

## 8. Forms (summary)

- No create form on this tab; Pay uses Billing forms after navigation

## 9. Print / labels / preview

- Dialog Print → `printAccountsPatientLedgerPacket` → `claimStatement`
- Table Print: absent

## 10. Loading / empty / error / success

- Empty: `No patients match.`
- Panel-local loading/error

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Ledger | `accountsPatientLedgersReadRequirement` |
| Pay | `accountsPayDeepLinkRequirement` (billing write ∩ `billing-payments`) |
| Export | mounted with table (entry already required to see desk) |
