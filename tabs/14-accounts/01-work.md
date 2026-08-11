# Accounts tab — Open work

## 1. Tab strip

- Label: `AccountsStrings.openWorkLabel` (`Open work`)
- Icon: `Icons.inventory_2_outlined`
- Count source: `AccountsSummary.openWork`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `work` (aliases `all`, `inbox`)
- Tab gate: `AccountsOpenWorkAtomPermissions.tab` = `accountsWorkspaceEntryRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Journal** (no table Export/Print)

- Search hint: `Account, journal, reference…`
- Filters: `Filters` → Advanced filters; Apply `opdApplyFiltersAction`; Clear `Clear filters`
- Settings: Table Settings (`commonTableSettings*`); key `accounts_work_v1`
- Export: **absent** (`enableExport` not set)
- Print (toolbar): **absent**
- Context: `Journal` (`AccountsStrings.journalAction`) — omitted without ∩ `accounts:write`
- Date filter: **enabled** — label `Posted date`

## 3. Table

- Row model: `AccountsWorkItem` (`state.workItems`)
- Row select: `showAccountsWorkItemDetailDialog`
- Default columns:
  1. Journal (alwaysVisible)
  2. Source
  3. Amount
  4. Status
  5. Next — if `accountsSectionShowsNextActionColumn` (write ∪ approve ∪ enter)
- Column choices: Account, Patient, Period (and other non-default builders excluding Next)
- Mobile: title journal id; trailing `AccountsNextActionButton`

## 4. Advanced filters / search fields

- Text filters: Account, Journal, Period
- Groups: Source (Manual / Billing), Status (Draft / Pending / Posted)
- Date range on posted date

## 5. Primary / secondary / row actions

- Strip: Journal → create draft
- Next: Approve → Post → Reverse → Void → Close → GL → Ledger (permission-gated labels)
- Row select → detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Work-item detail | Accounts-owned |
| Journal create | Accounts-owned `showAccountsJournalDialog` |
| Journal similarity | Accounts-owned |
| Post / Approve / Reject / Reverse / Void / Close | Accounts-owned |
| GL dialog / Patient ledger | Accounts-owned |

## 7. Nested / follow-on

From detail: Post, Approve, Reject, Edit draft, Reverse, Void, Close period, Open GL, Open patient ledger, Print packet.  
From Journal create: similarity → use existing detail / proceed create → navigates URL to `section=journals`.

## 8. Forms (summary)

- Journal: date, memo, balanced debit/credit lines (account per line)
- Approve/Reject/Reverse/Void/Close: notes/reason fields as applicable

## 9. Print / labels / preview

- Detail Print → `printAccountsWorkItem` → journal packet or approval packet (`PrintDocumentTemplates.claimStatement`)
- No table-level Print

## 10. Loading / empty / error / success

- Loading: workspace + table `isRefreshing`
- Empty: `No open work.`
- Error: table error string / snackbars
- Success: `AccountsStrings.saved` / mutation snackbars; refresh counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings | entry ∪ |
| Journal create | ∩ `accounts:write` |
| Next Approve | ∩ `accounts:write` + `financial:approve` (+ modules) |
| Next Post / Reverse / Void / Close | ∩ `accounts:write` |
| Pay (via ledger next elsewhere) | billing write |
| Export / table Print | n/a (not mounted) |
