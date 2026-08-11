# Lab tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle` (not a `labScope*` key)
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope())`
- Sibling tabs: patient-view summary for worklist tabs; this tab uses follow-up provider
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `LabFollowUpsAtomPermissions.tab` = ∩ `lab:read` + `lab-workflows`
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: lab_follow_ups`)
- **Omitted when unauthorized** (also omitted for route-only clinical readers without `lab:read`)

## 2. Search / Filters / Settings / Export / Print / context

- Search: `receptionFollowUpsSearchHint`; Clear `receptionClearFiltersAction`
- Filters: `commonFiltersActionLabel` / `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`
- Date: `labFollowUpDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`
- Settings: opens **Lab desk settings** (worklist column prefs for `lab_followUps`) — **bypasses** follow-up column dialog (`lab_follow_ups_cols`)
- Export: AppListTable default (ungated)
- Print: **not mounted**
- Create: `labCreateAction` via `LabFollowUpsAtomPermissions.create`

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Columns (defaults): `opdPatientNameLabel`, `patientsPhoneLabel`, `patientsEmailLabel`, `opdFollowUpDateLabel`, `opdFollowUpTimeLabel`
- Panel storage keys: `lab_follow_ups_cols` / `lab_follow_ups_cw` (unused when Lab Settings override)
- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`

## 4. Advanced filters / search fields

- Group `follow_up_status`: `labFollowUpStatusFilterLabel` — Pending / Completed (`labFollowUpStatusPending` / `labFollowUpStatusCompleted`)
- Search: `labPatientFilterLabel`, `labPatientIdFilterLabel`, `patientsPhoneLabel`
- Date range on follow-up date

## 5. Primary / secondary / row actions

- Strip: Create Lab Order (when write ∩)
- Row → follow-up detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |
| Create order path | shared / **reused** clinical (same as worklist) |
| Desk settings | Lab-owned |

## 7. Nested / follow-on

When `LabFollowUpsAtomPermissions.write`: Mark completed / Reschedule → Save follow-up (`opdSaveFollowUpAction`). Close for read-only. Hard delete **not mounted** (`delete` atom exists).

## 8. Forms (summary)

Detail read + nested reschedule; create-order forms if Create used.

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: no print surface

## 10. Loading / empty / error / success

- Hard failure: `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`
- Empty: Reception follow-up empty keys

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / empty / loading / retry / detail / close | ∩ `lab:read` |
| create / reschedule / markCompleted / saveFollowUp / write | ∩ `lab:write` |
| createPatient | ∩ `patient:write` |
| Export | ungated |
| Print | n/a |
