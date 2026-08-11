# Reception tab — Follow-ups

## 1. Tab strip

- Label: `receptionSectionFollowUps`
- Icon: `Icons.phone_callback_outlined`
- Count source: `ReceptionFollowUpState.totalCount` (falls back to loaded `entries.length`) — prefers server page total
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`, `follow-up`, `no_show_pressure`)
- Tab gate: `ReceptionFollowUpsAtomPermissions.tab` = ∪ `patient:read` | `clinical:read` + modules
- Note: `last_office:read` alone may enter shell but **cannot** list follow-ups
- **Omitted when unauthorized** (controller not watched)

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionFollowUpsSearchHint`
- Clear: `receptionClearFiltersAction`
- **Filters / Advanced filters: intentionally omitted** (`showAdvancedFilterButton: false`, empty `searchFields`, `onFilterChanged: null`)
- **Date filter: intentionally omitted**
- Settings: present (column visibility)
- Export: present
- Print (toolbar): **absent**
- Schedule / Register: ∩ `patient:write`

## 3. Table

- Row model: `_ReceptionDeskRow.followUp(ReceptionFollowUpEntry)` from `receptionFollowUpControllerProvider`
- Row select → Reception follow-up detail
- Default columns:
  1. Patient
  2. Phone (`patientsPhoneIdentifierColumnLabel`)
  3. Follow-up date (`opdFollowUpDateLabel`)
  4. Follow-up time (`opdFollowUpTimeLabel`)
- Column choices:
  - Patient ID only (`opdPatientIdLabel`)

## 4. Advanced filters / search fields

- **None** — free-text search only (matches all fields via row matcher; no field picker)

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: open detail dialog (mutations inside detail when write allowed)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail (`opdFollowUpsTitle`) | Reception-owned `ReceptionFollowUpDetailDialog` |
| Schedule / Register | shared |

## 7. Nested / follow-on

From detail when write ∩ allowed:

1. Mark completed (`receptionMarkFollowUpCompletedAction`) → repository `completeFollowUp` (no nested dialog)
2. Schedule another / reschedule (`receptionScheduleAnotherFollowUpAction`) → **reused** `ClinicalFollowUpActionDialog` (title = same action label; submit `opdSaveFollowUpAction`)
3. Read-only users: Close only (`commonCloseActionLabel`)

No hard-delete control.

## 8. Forms (summary)

- Detail body (read): `AppPatientDetails` + schedule date/time tiles + notes + next-step banner (`receptionFollowUpNextStepTitle` / `receptionFollowUpDetailBody`)
- Reschedule nested: scheduled_at + notes (`ClinicalFollowUpActionDialog`)

## 9. Print / labels / preview

- **Absent** on this tab and its dialogs

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Controller failure with no data: error `AppStateView` + Retry (`commonRetryActionLabel`) refreshing follow-up controller
- Detail failure: `AppFormInformationBanner.failure`
- Success: pop(true) → workspace refresh (no dedicated success snackbar on complete path from page; schedule strip still uses `opdSavedMessage`)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / search / settings / detail / close | ∪ `patient:read` \| `clinical:read` |
| Register / Schedule strip | ∩ `patient:write` |
| Reschedule / Mark completed / Save follow-up | ∩ `patient:write` (`receptionFollowUpsWriteRequirement`) |
| Hard delete | ∩ `patient:delete` documented — **not mounted** |
| Nested cross-module | n/a |
