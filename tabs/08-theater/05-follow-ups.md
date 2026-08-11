# Theater tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'THEATRE'))`
- Sibling tabs: board page counts; this tab uses dedicated follow-up provider
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `TheaterFollowUpsAtomPermissions.tab`
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: theater_follow_ups`, Theater read/write overrides)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionFollowUpsSearchHint`
- Clear: `receptionClearFiltersAction`
- Filters: **off** (`showAdvancedFilterButton: false`)
- Date filter: **off**
- Settings: `commonTableSettings*` + Apply/Reset `receptionApplyColumnsAction` / `receptionResetColumnsAction`
- Export: AppListTable default (ungated)
- Print: **not mounted**
- Schedule case: **not mounted** on this tab

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Row select → **reused** follow-up detail
- Default columns: patient (`opdPatientNameLabel`), phone (`patientsPhoneLabel`), email (`patientsEmailLabel`), date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- No Theater next-action column (`theaterBoardShowsNextActionColumn` false for follow-ups)
- Storage: `theater_follow_ups_cols` / `theater_follow_ups_cw`

## 4. Advanced filters / search fields

- Advanced filters: **not enabled** by Theater host
- Panel search only (Reception follow-up matcher)

## 5. Primary / secondary / row actions

- Strip: none Theater-specific
- Row: open detail; mutations inside detail when write ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |

## 7. Nested / follow-on

From detail when write ∩:

1. Mark completed (`receptionMarkFollowUpCompletedAction`)
2. Schedule another / reschedule (`receptionScheduleAnotherFollowUpAction`) → clinical follow-up save (`opdSaveFollowUpAction`)
3. Read-only: Close (`commonCloseActionLabel`)

No hard-delete control.

## 8. Forms (summary)

- Detail read: patient + schedule tiles + notes
- Reschedule nested: scheduled_at + notes

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: no separate print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Hard failure: `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`
- Success: detail pop → refresh; no Theater-specific snackbar on complete path

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / settings / detail / close | `TheaterFollowUpsAtomPermissions.*` → board read ∪ |
| Export | ungated |
| Reschedule / Mark completed / Save follow-up | follow-ups write ∩ (`theaterFollowUpsWriteRequirement` / clinical write) |
| Schedule case strip | n/a (not mounted) |
| Print | n/a |
