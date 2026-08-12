# Accounts tab — Account chart

## 1. Tab strip

- Label: `Account chart`
- Icon: `Icons.list_alt_outlined`
- Count source: `accountsSectionTabCount` → `accountsChartActiveCountProvider` ?? `AccountsSummary.chartActive` (panel pushes filtered / scope totals; strip wired to chart count provider)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `chart` (aliases `chart-of-accounts`, `coa`)
- Tab gate: `AccountsChartAtomPermissions.tab` = entry
- **Omitted when unauthorized**
- No work-queue Next column (`accountsSectionShowsNextActionColumn` → false)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Add**

- Search hint: chart-specific (`AccountsStrings.chartSearchHint`)
- Filters: present; **no date filter**
- Settings: `accounts_chart_v1`
- Export / table Print: ∩ `evidence:export` — omit when unauthorized (`AccountsChartAtomPermissions.export` / `print`); Print lives in the table toolbar slot (not a trailing search action)
- Context: `commonAddActionLabel` — omitted without chart write

## 3. Table

- Row model: `AccountsChartAccount`
- Row select: opens create/edit **only if** chart write; otherwise no select handler
- Default columns: Account, Type, Code, Status, Actions (Edit / Deactivate when write)
- Column choices: Parent, Currency, Effective, Updated, …
- Actions column omitted without chart write

## 4. Advanced filters / search fields

- Text: Parent, Currency
- Groups: Status (Active / Inactive), Type (Asset…Expense), Effective (current / other)

## 5. Primary / secondary / row actions

- Strip Add → create dialog
- Actions: Edit, Deactivate (active rows)
- Row select → edit when write

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Chart account create/edit | Accounts-owned `showAccountsChartAccountDialog` |
| Chart similarity | Accounts-owned |
| Deactivate confirm path | Accounts-owned (via dialog/actions) |

## 7. Nested / follow-on

Create/edit → similarity review → proceed / use existing / cancel

## 8. Forms (summary)

- Code, name, type, parent, currency, effective dates/status fields (chart dialog groups)

## 9. Print / labels / preview

- Table Print → `printAccountsListTable` → `PrintDocumentTemplates.registry` (preview-first; toolbar slot)
- No label print

## 10. Loading / empty / error / success

- Empty: `No accounts match.` (+ empty body string)
- Success: mutation snackbars; reload

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings | entry |
| Add / Edit / Deactivate / row select edit | `accountsChartWriteRequirement` (∪ `accounts:write` \| tenant/facility admin ∩ module) |
| List Export / Print | ∩ `evidence:export` |
