# ICU tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'ICU'))`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `IcuFollowUpsAtomPermissions.tab` = `icuFollowUpsRequirement` (= read ∪)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search: `receptionFollowUpsSearchHint`
- Filters: **omitted** on ICU host (`showAdvancedFilterButton: false`)
- Settings: shared follow-up table settings
- Export / Print (toolbar): **absent**
- Context: **none**

## 3. Table

- Panel: **reused** `FollowUpWorklistPanel`
- Columns: patient (`opdPatientNameLabel`), phone (`patientsPhoneLabel`), email (`patientsEmailLabel`), date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- Row select → **reused** `showReceptionFollowUpDetailDialog`
- Storage: `'icu_follow_ups_cols'` / `'icu_follow_ups_cw'`

## 4. Advanced filters / search fields

- ICU host does not pass filter groups / date; Filters control off

## 5. Primary / secondary / row actions

- Detail: Reschedule / Mark completed (write); Close (read)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** Reception (`showReceptionFollowUpDetailDialog`) |

## 7. Nested / follow-on

- Reschedule nested in shared dialog
- `refreshScopedFollowUps` after change

## 8. Forms (summary)

- Shared follow-up reschedule / complete fields (Reception dialog)

## 9. Print / labels / preview

- **Absent** on this tab

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Loading / retry / error via shared panel + AccessGate
- Success via follow-up controller / snackbars after mutations

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / listChrome / search / settings / empty / loading / retry / rowSelect / detail / close / nestedRead | `icuFollowUpsRequirement` |
| success / validation / create / update / delete / reschedule / markCompleted / saveFollowUp / write / nestedWrite | `icuFollowUpsWriteRequirement` |
| routeEntry / catalogEntry | `RouteAccessCatalog.icuEntry` |
| filters / printSummary / nextAction | **n/a** (not mounted) |
