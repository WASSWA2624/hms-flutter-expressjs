# Settings section — Rosters

## 1. Section chrome

- Label: `settingsRostersSectionTitle` / body `settingsRostersSectionBody`
- Icon: `calendar_month_outlined`
- Deep-link `tab`: `rosters`
- Gate: `SettingsRostersAtomPermissions.tab` = `profileReadRequirement`
- API: `/shift-assignments/me`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Period chips: Today…Custom (`settingsRosterPeriod*`)
- Header: `settingsRostersPeriodHeader`
- No Export / Print / table Settings

## 3. Inner surfaces

- **Reused** `HrRosterCalendarPreview` day grid
- Empty can still show empty calendar days when range built

## 4. Advanced filters / search fields

- Period presets + custom range dialog (not advanced-filters sheet)

## 5. Primary / secondary / row actions

- Read-only calendar; create/delete ∩ `facility:admin` — **not mounted**
- Day/period tap → details dialog

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| Custom range (`settingsRosterPeriodCustom`) | Settings-owned `AppDialog` |
| Period details | **reused** `showHrRosterPeriodDetailsDialog` (HR) |

## 7. Nested / follow-on

- Date fields inside custom-range dialog; Apply `appDateRangeApplyAction`

## 8. Forms (summary)

- Custom: `hrStartDateLabel` / `hrEndDateLabel` only

## 9. Print / labels / preview

- Absent (HR preview is on-screen only)

## 10. Loading / empty / error / success

- Loading / empty / missing staff / unavailable keys parallel Leaves (`settingsRosters*`)
- No mutation success path

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters | ∩ `profile:read` |
| Create / delete | ∩ `facility:admin` — not mounted |
