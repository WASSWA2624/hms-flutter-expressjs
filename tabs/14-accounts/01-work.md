# Accounts tab — Open work

## 1. Tab strip

- Label: `AccountsStrings.openWorkLabel` (`Open work`)
- Icon: `Icons.inventory_2_outlined`
- Count source: `accountsSectionTabCount` → `AccountsSummary.openWork`; active + narrowed (search / Filters / date) → `workItems.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `work` (aliases `all`, `inbox`)
- Tab gate: `AccountsOpenWorkAtomPermissions.tab` = `accountsWorkspaceEntryRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Journal**

- Search hint: `Account, journal, reference…`
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close** (`AccountsStrings.clearFilters` / `opdApplyFiltersAction` / `commonCloseActionLabel`)
- Settings: Table Settings (`commonTableSettings*`); key `accounts_work_v1`; exposes defaults + optional columns; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsOpenWorkAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable`
- Context: `Journal` (`AccountsStrings.journalAction`) — omitted without ∩ `accounts:write`
- Date filter: **enabled** — label `Posted date`

## 3. Table

- Row model: `AccountsWorkItem` (`state.workItems`)
- Row select: `showAccountsWorkItemDetailDialog` — generic title `Journal` / `Approval` / `Period` (no identity in title)
- Default columns (**5**):
  1. Journal (alwaysVisible)
  2. Source
  3. Amount
  4. Status
  5. Next — if `accountsSectionShowsNextActionColumn` (write ∪ approve ∪ enter); alwaysVisible when present; not exportable
- Column choices (Settings extras): Account, Patient, Period
- Mobile: title journal id; trailing `AccountsNextActionButton`

## 4. Advanced filters / search fields

- Text filters: Account, Journal, Period
- Groups: Source (Manual / Billing), Status (Draft / Pending / Posted)
- Date range on posted date
- Same `AccountsWorkspaceQuery` model drives table rows and active tab badge

## 5. Primary / secondary / row actions

- Strip: Journal → create draft
- Next: Approve → Post → Reverse → Void → Close → GL → Ledger (permission-gated labels)
- Row select → detail hub

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Work-item detail | Accounts-owned | Generic `Journal` / `Approval` / `Period` |
| Journal create / edit | Accounts-owned `showAccountsJournalDialog` | `Journal` / `Edit journal` |
| Journal similarity | Accounts-owned | `Exact draft journal found` / `Similar draft journals` / `No similar drafts` |
| Post / Approve / Reject / Reverse / Void / Close | Accounts-owned | Action labels |
| GL dialog / Patient ledger | Accounts-owned | Generic surface titles; identity in body |

## 7. Nested / follow-on

From detail: Post, Approve, Reject, Edit draft, Reverse, Void, Close period, Open GL, Open patient ledger, Print packet.  
From Journal create: similarity → use existing detail / proceed create → in-desk URL to `section=journals`.

## 8. Forms (summary)

- Journal: date, memo, balanced debit/credit lines (account per line)
- Approve/Reject/Reverse/Void/Close: notes/reason fields as applicable
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- Detail Print → `printAccountsWorkItem` → journal packet or approval packet (`PrintDocumentTemplates.claimStatement` template reuse)

## 10. Loading / empty / error / success

- Loading: workspace + table `isRefreshing`
- Empty: `No open work.`
- Error: table error string / snackbars
- Success: `AccountsStrings.saved` / mutation snackbars; refresh table + tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings | entry ∪ |
| Journal create | ∩ `accounts:write` |
| Next Approve | ∩ `accounts:write` + `financial:approve` (+ modules) |
| Next Post / Reverse / Void / Close | ∩ `accounts:write` |
| Pay (via ledger next elsewhere) | billing write |
| List Export / Print | ∩ `evidence:export` |
