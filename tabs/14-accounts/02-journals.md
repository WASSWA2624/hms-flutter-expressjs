# Accounts tab — To post (journals)

## 1. Tab strip

- Label: `AccountsStrings.toPostLabel` (`To post`)
- Icon: `Icons.post_add_outlined`
- Count source: `accountsSectionTabCount` → `AccountsSummary.toPost`; active + narrowed (search / Filters / date) → `workItems.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `journals` (aliases `journal-entries`, `unposted`, `ready-to-post`)
- Tab gate: `AccountsToPostAtomPermissions.tab` = entry requirement
- Deep-link: `action` / `id` may auto-open Post dialog for matching draft
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Post all**

- Search hint: `Account, journal, reference…`
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close**
- Settings: Table Settings (`commonTableSettings*`); key `accounts_journals_v1`; exposes defaults + optional columns; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsToPostAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable`
- Context: `Post all` — omitted without ∩ `accounts:write`; enabled only when page has postable drafts
- Date filter: **enabled** — `Posted date`

## 3. Table

- Row model: `AccountsWorkItem` (drafts ready to post)
- Row select: `showAccountsWorkItemDetailDialog` — generic title `Journal` (no identity)
- Default columns (**5** when write):
  1. Journal (alwaysVisible)
  2. Period
  3. Amount
  4. Status
  5. Next (Post-only) — **omitted** without ∩ `accounts:write` (justified → 4 defaults)
- Column choices (Settings extras): Source, Account, Patient, …
- Mobile: trailing Next = Post when allowed

## 4. Advanced filters / search fields

- Text: Account, Journal, Period
- Groups: Source (Manual / Billing), Status (**Draft** only choice listed)
- Date range on posted date
- Same `AccountsWorkspaceQuery` model drives table rows and active tab badge

## 5. Primary / secondary / row actions

- Strip: Post all → confirm dialog
- Next / deep-link: Post single journal
- Row select → detail (Edit / Post / …)

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Work-item detail | Accounts-owned | Generic `Journal` |
| Post journal | Accounts-owned `showAccountsPostDialog` | Action label |
| Post all confirm | Accounts-owned `AppConfirmActionDialog` | Confirm title |
| Edit draft journal | Accounts-owned | `Edit journal` |

## 7. Nested / follow-on

Detail → Edit draft → journal dialog (+ similarity). Post → success snackbar `Posted.` — stays in-desk.

## 8. Forms (summary)

- Post: confirmation / notes as dialog provides
- Edit journal: same line-balance form as create
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- Detail Print → journal packet (`PrintDocumentTemplates.claimStatement` template reuse)

## 10. Loading / empty / error / success

- Loading: workspace + table `isRefreshing`
- Empty: `No drafts to post.`
- Error: table error string / snackbars
- Success: `Posted.` after post / post-all; refresh table + tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings | entry / list chrome |
| Post / Post all / Edit / Next column | ∩ `accounts:write` (`AccountsToPostAtomPermissions.post` / `postAll`) |
| Approve actions in detail | approval decision requirement |
| List Export / Print | ∩ `evidence:export` |
