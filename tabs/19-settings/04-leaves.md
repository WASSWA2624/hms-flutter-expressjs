# Settings section — Leaves

## 1. Section chrome

- Label: `settingsLeavesSectionTitle` / body `settingsLeavesSectionBody`
- Icon: `event_busy_outlined`
- Deep-link `tab`: `leaves`
- Gate: `SettingsLeavesAtomPermissions.tab` = `profileReadRequirement`
- API: `/staff-leaves/me` via `settingsStaffSelfRepository`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- No search / table Settings / Export / Print
- Status **FilterChips** (not `commonAdvancedFilters*`): All / Pending / Approved / Rejected / Cancelled
  Keys: `settingsLeaveStatusAll`, `Requested`, `Approved`, `Rejected`, `Cancelled`
- Context primary: `hrRequestLeaveAction`

## 3. Inner surfaces

- Leave tiles: type (`hrReferenceLeaveTypeLabel`), status badge, date range, half-day summary, reason
- No `AppListTable`

## 4. Advanced filters / search fields

- Status chip only (server `status` query)

## 5. Primary / secondary / row actions

- Primary: `hrRequestLeaveAction` — `SettingsLeavesAtomPermissions.request` = `profile:read` (not `hr:write`)
- Delete: ∩ `facility:admin` — not mounted

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| Request leave (`hrLeaveDialogTitle`) via `showAppWorkspaceMutationDialog` | **Settings-owned** fields; HR l10n / patterns |

## 7. Nested / follow-on

- Date pickers inside dialog only

## 8. Forms (summary)

- `_SettingsRequestLeaveFields`: leave type, start date, half-day checkbox + period, end date, reason
- Types: ANNUAL, SICK, MATERNITY, PATERNITY, COMPASSIONATE, UNPAID, STUDY, EMERGENCY, OTHER
- Submit `hrRequestLeaveAction`; cancel `commonCancelActionLabel`

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Loading: `settingsLeavesLoadingTitle`/`Body`
- Empty: `settingsLeavesEmptyTitle`/`Body`
- NotFound (no staff): `settingsStaffProfileMissingTitle`/`Body`
- Error: `settingsLeavesUnavailableTitle` + retry
- Success: `settingsLeaveRequestSuccessMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / request / create | ∩ `profile:read` |
| Delete | ∩ `facility:admin` — not mounted |
