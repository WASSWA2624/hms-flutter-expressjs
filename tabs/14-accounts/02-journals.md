# Accounts tab — To post (journals)

## 1. Tab strip

- Label: `To post`
- Icon: `Icons.post_add_outlined`
- Count source: `AccountsSummary.toPost`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `journals` (aliases `journal-entries`, `unposted`, `ready-to-post`)
- Tab gate: `AccountsToPostAtomPermissions.tab` = entry requirement
- Deep-link: `action` / `id` may auto-open Post dialog for matching draft
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Post all**

- Search / Filters / Settings: same pattern as Open work; key `accounts_journals_v1`
- Export: `enableExport: true`
- Print (toolbar): **absent**
- Context: `Post all` — omitted without ∩ `accounts:write`; enabled only when page has postable drafts
- Date filter: **enabled** — `Posted date`

## 3. Table

- Row model: `AccountsWorkItem` (drafts ready to post)
- Row select: work-item detail
- Default columns: Journal, Period, Amount, Status, Next (Post-only when write)
- Column choices: Source, Account, Patient, …
- Next column **omitted** without `accounts:write`
- Mobile: trailing Next = Post when allowed

## 4. Advanced filters / search fields

- Text: Account, Journal, Period
- Groups: Source (Manual / Billing), Status (**Draft** only choice listed)
- Date range on posted date

## 5. Primary / secondary / row actions

- Strip: Post all → confirm dialog
- Next / deep-link: Post single journal
- Row select → detail (Edit / Post / …)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Work-item detail | Accounts-owned |
| Post journal | Accounts-owned `showAccountsPostDialog` |
| Post all confirm | Accounts-owned `AppConfirmActionDialog` |
| Edit draft journal | Accounts-owned |

## 7. Nested / follow-on

Detail → Edit draft → journal dialog (+ similarity). Post → success snackbar `Posted.`

## 8. Forms (summary)

- Post: confirmation / notes as dialog provides
- Edit journal: same line-balance form as create

## 9. Print / labels / preview

- Detail Print → journal packet
- Table Print: absent; Export present

## 10. Loading / empty / error / success

- Empty: `No drafts to post.`
- Success: `Posted.` after post / post-all

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Export | entry / list chrome |
| Post / Post all / Edit / Next column | ∩ `accounts:write` (`AccountsToPostAtomPermissions.post` / `postAll`) |
| Approve actions in detail | approval decision requirement |
