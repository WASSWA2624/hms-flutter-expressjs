# Clinical tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope())`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `ClinicalFollowUpsAtomPermissions.tab` = `clinicalFollowUpsRequirement`
- **Omitted when unauthorized** (AccessGate → shrink)

## 2. Search / Filters / Settings / Export / Print / context

- Search: `receptionFollowUpsSearchHint`; clear `receptionClearFiltersAction`
- Settings: `commonTableSettings*` with Apply/Reset `receptionApplyColumnsAction` / `receptionResetColumnsAction`
- Filters / Export / Print / create: **not enabled** on Clinical host

## 3. Table

- Panel: **reused** `FollowUpWorklistPanel`
- Columns: patient (`opdPatientNameLabel`), phone, email, date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- Row select → **reused** `showReceptionFollowUpDetailDialog`
- Storage: `clinical_follow_ups_cols` / `clinical_follow_ups_cw`

## 4. Advanced filters / search fields

- Advanced filters **not** mounted by Clinical host

## 5. Primary / secondary / row actions

- Detail: Reschedule (`receptionScheduleAnotherFollowUpAction`) / Mark completed (`receptionMarkFollowUpCompletedAction`) / Save (`opdSaveFollowUpAction`) / Close (`commonCloseActionLabel`)
- Titles: `clinicalFollowUpDetailsTitle`, `receptionFollowUpNextStepTitle`, body `receptionFollowUpDetailBody`

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** Reception |

## 7. Nested / follow-on

- Nested reschedule only
- No encounter clinical action bar from this tab

## 8. Forms (summary)

- Shared Reception follow-up reschedule / complete fields

## 9. Print / labels / preview

- **Absent** on this tab

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `Body`
- Error: `errorUnexpectedTitle` / `Message` + `commonRetryActionLabel`
- Success via follow-up mutations / Clinical RW overrides

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / listChrome / search / settings / empty / loading / retry / rowSelect / detail / close / nestedRead | `clinicalFollowUpsRequirement` |
| success / validation / create / update / delete / reschedule / markCompleted / saveFollowUp / write / nestedWrite | `clinicalFollowUpsWriteRequirement` |
| entry / routeEntry | catalog entry |
| Lab / radiology / pharmacy / admission atoms | **n/a** on this tab |
