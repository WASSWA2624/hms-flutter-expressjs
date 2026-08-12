# Accounts tab — Account chart

## 1. Tab strip

- Label: `AccountsStrings.accountChartLabel` (`Account chart`)
- Icon: `Icons.list_alt_outlined`
- Count source: `accountsSectionTabCount` → `accountsChartActiveCountProvider` ?? `AccountsSummary.chartActive`; active + narrowed (search / Filters) → panel pushes filtered total
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `chart` (aliases `chart-of-accounts`, `coa`)
- Tab gate: `AccountsChartAtomPermissions.tab` = entry
- **Omitted when unauthorized**
- No work-queue Next column (`accountsSectionShowsNextActionColumn` → false)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Add**

- Search hint: `Account, code, type…` (`AccountsStrings.chartSearchHint`)
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close**
  - Date filter: **omitted** (justified — status/type/parent/currency/effective scope only)
- Settings: Table Settings; key `accounts_chart_v1`; exposes defaults + Parent / Currency / Effective; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsChartAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable` (toolbar slot — not a trailing search action)
- Context: `commonAddActionLabel` (`Add`) — omitted without chart write

## 3. Table

- Row model: `AccountsChartAccount`
- Row select: opens create/edit **only if** chart write; otherwise no select handler
- Default columns (**5** when write):
  1. Account (alwaysVisible)
  2. Type
  3. Code
  4. Status
  5. Actions (Edit / Deactivate when active) — alwaysVisible / not exportable; **omitted** without chart write (justified → 4)
- Column choices (Settings extras): Parent, Currency, Effective
- Mobile: caption code; meta type + status

## 4. Advanced filters / search fields

- Text: Parent, Currency
- Groups: Status (Active / Inactive), Type (Asset…Expense), Effective (current / other)
- Parent / Effective applied client-side; badge uses filtered length then
- Same panel filter model drives table rows and active tab badge

## 5. Primary / secondary / row actions

- Strip Add → create dialog
- Actions: Edit, Deactivate (active rows)
- Row select → edit when write

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Chart account create/edit | Accounts-owned `showAccountsChartAccountDialog` | Action titles `Add account` / `Edit account` |
| Chart similarity | Accounts-owned | Similarity review |
| Deactivate confirm | Accounts-owned | `Deactivate account` (+ highlighted identity in body) |

## 7. Nested / follow-on

Create/edit → similarity review → proceed / use existing / cancel. Stays in-desk.

## 8. Forms (summary)

- Code, name, type, parent, currency, effective dates/status fields (chart dialog groups)
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- No label print

## 10. Loading / empty / error / success

- Loading: panel-local `_loading`
- Empty: `No accounts match.` (+ empty body string)
- Error: table error string
- Success: mutation snackbars; list + tab count refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings | entry |
| Add / Edit / Deactivate / row select edit | `accountsChartWriteRequirement` (∪ `accounts:write` \| tenant/facility admin ∩ module) |
| List Export / Print | ∩ `evidence:export` |
