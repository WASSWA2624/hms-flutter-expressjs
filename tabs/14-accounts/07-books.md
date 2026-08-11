# Accounts tab — Close books

## 1. Tab strip

- Label: `Close books`
- Icon: `Icons.menu_book_outlined`
- Count source: `accountsOpenPeriodsCountProvider` ?? `openPeriods`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `books` (aliases `periods`, `period-close`, `close`); may pass `periodId`/`id`, `action`, `search`
- Tab gate: `AccountsCloseBooksAtomPermissions.tab` = entry
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Settings → Open period → Close period** (plus Open / Overdue chips above table)

- Search hint: `Period, facility, status…`
- Advanced Filters button: **intentionally omitted**
- Quick filters: FilterChips `Open` / `Overdue close` (counts from current page membership)
- Settings: `accounts_books_v1`
- Export / table Print: **absent**
- Context: `Open period`, `Close period` — omitted without ∩ `accounts:write`

## 3. Table

- Row model: `AccountsFiscalPeriod`
- Row select: books detail dialog
- Default columns: Period, Status, Opened, Closed, Next (`Close` / `Approve` / `Books`)
- Column choices: Facility, By
- Mobile: trailing next label

## 4. Advanced filters / search fields

- No advanced filter sheet
- Chips: Open only / Overdue only (mutually exclusive)
- Free-text search only

## 5. Primary / secondary / row actions

- Strip Open period / Close period
- Next Close → close dialog; Approve → approval decision; Books → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Open period | Accounts-owned `showAccountsOpenPeriodDialog` |
| Period similarity / overlap | Accounts-owned |
| Close period | Accounts-owned `showAccountsClosePeriodDialog` |
| Books detail (+ checklist / Print) | Accounts-owned `showAccountsBooksDetailDialog` |
| Approve (pending close) | Accounts-owned approval dialog |

## 7. Nested / follow-on

Open → similarity → select existing / continue open. Detail → View unposted (may navigate journals), Print packet, Close.

## 8. Forms (summary)

- Open: label, start date, end date
- Close: notes / checklist confirmation fields
- Approve: notes/reason

## 9. Print / labels / preview

- Detail Print → `printAccountsBooksPacket` → `claimStatement` with books section options
- Table Print: absent

## 10. Loading / empty / error / success

- Hard failure empty list: `AppFailureStateView` + retry
- Empty: `No periods match.`
- Success: mutation snackbars; count refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Books next | entry / read |
| Open period / Close period / Close next | ∩ `accounts:write` |
| Approve next | approval decision requirement |
