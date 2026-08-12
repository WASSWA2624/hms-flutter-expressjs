# Accounts tab — Close books

## 1. Tab strip

- Label: `AccountsStrings.closeBooksLabel` (`Close books`)
- Icon: `Icons.menu_book_outlined`
- Count source: `accountsSectionTabCount` → `accountsOpenPeriodsCountProvider` ?? `AccountsSummary.openPeriods`; active + narrowed (search / Open / Overdue filters) → panel pushes filtered total
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `books` (aliases `periods`, `period-close`, `close`); may pass `periodId`/`id`, `action`, `search`
- Tab gate: `AccountsCloseBooksAtomPermissions.tab` = entry
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Open period → Close period** (plus Open / Overdue chips above table)

- Search hint: `Period, facility, status…`
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close**
  - Groups: Open only / Overdue only — synced with FilterChips
  - Date filter: **omitted** (justified — status chips / Open–Overdue groups cover the scope)
- Quick filters: FilterChips `Open` / `Overdue close` (counts from current page membership; mutually exclusive)
- Settings: Table Settings; key `accounts_books_v1`; exposes defaults + Facility / By; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsCloseBooksAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable`
- Context: `Open period`, `Close period` — omitted without ∩ `accounts:write`

## 3. Table

- Row model: `AccountsFiscalPeriod`
- Row select: `showAccountsBooksDetailDialog` — generic title `Period` (identity in body)
- Default columns (**5**):
  1. Period (alwaysVisible)
  2. Status
  3. Opened
  4. Closed
  5. Next (`Close` / `Approve` / `Books`) — alwaysVisible / not exportable
- Column choices (Settings extras): Facility, By
- Mobile: trailing next label

## 4. Advanced filters / search fields

- Advanced Filters groups: Open only / Overdue only (synced with chips)
- Chips: Open only / Overdue only (mutually exclusive)
- Free-text search
- Same panel filter model drives table rows and active tab badge

## 5. Primary / secondary / row actions

- Strip Open period / Close period
- Next Close → close dialog; Approve → approval decision; Books → detail

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Open period | Accounts-owned `showAccountsOpenPeriodDialog` | Action title |
| Period similarity / overlap | Accounts-owned | Similarity review |
| Close period | Accounts-owned `showAccountsClosePeriodDialog` | Action title |
| Books detail (+ checklist / Print) | Accounts-owned `showAccountsBooksDetailDialog` | Generic `Period` |
| Approve (pending close) | Accounts-owned approval dialog | Action label |

## 7. Nested / follow-on

Open → similarity → select existing / continue open. Detail → View unposted (may navigate journals), Print packet, Close. Stays in-desk except allowed journals handoff.

## 8. Forms (summary)

- Open: label, start date, end date
- Close: notes / checklist confirmation fields
- Approve: notes/reason
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- Detail Print → `printAccountsBooksPacket` → `claimStatement` template reuse with books section options

## 10. Loading / empty / error / success

- Hard failure empty list: `AppFailureStateView` + retry
- Empty: `No periods match.`
- Success: mutation snackbars; count refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings / Books next | entry / read |
| Open period / Close period / Close next | ∩ `accounts:write` |
| Approve next | approval decision requirement |
| List Export / Print | ∩ `evidence:export` |
