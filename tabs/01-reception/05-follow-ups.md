# Reception tab — Follow-ups

## 1. Tab strip

- Label: `receptionSectionFollowUps`
- Icon: `Icons.phone_callback_outlined`
- Count source: `ReceptionFollowUpState.totalCount` (server total; falls back to loaded `entries.length`). When this tab is active and status/date/search narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.info` — non-urgent callback worklist (not warning unless product-justified)
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`, `follow-up`, `no_show_pressure`)
- Tab gate: `ReceptionFollowUpsAtomPermissions.tab` = ∪ `patient:read` | `clinical:read` + modules
- Note: `last_office:read` alone may enter shell but **cannot** list follow-ups
- **Omitted when unauthorized** (controller not watched)

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionFollowUpsSearchHint`
- Clear: `receptionClearFiltersAction`
- Filters / Settings: shared labels
- Export: gated by `ReceptionFollowUpsAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Schedule / Register: ∩ `patient:write`
- Date filter: **enabled** — `opdFollowUpDateLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.followUp(ReceptionFollowUpEntry)` from `receptionFollowUpControllerProvider`
- Row select → Reception follow-up detail
- Default columns (prefer **5** data columns):
  1. Patient (name + identifier subtitle only — atomic identity cell)
  2. Phone (`patientsPhoneIdentifierColumnLabel`)
  3. Follow-up date (`opdFollowUpDateLabel`)
  4. Follow-up time (`opdFollowUpTimeLabel`)
  5. Status (`receptionStatusLabel` / `opdStageDisplayLabel`)
- Column choices (Settings):
  - Patient ID (`opdPatientIdLabel`)
- Reset restores the five defaults
- Notes stay in follow-up detail dialog (not a table cell — `tables.mdc` no body prose)

## 4. Advanced filters / search fields

Same filter model as the table and active tab count:

- Groups: Status (`receptionStatusLabel` via `_statusFilterKey`) — follow-up lifecycle values from loaded rows
- Search fields (domain-present only): patient, record, reason→notes (`opdNotesLabel`), status — **no** provider/staff field
- Date range on follow-up scheduled date (`opdFollowUpDateLabel`)

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
3. Read-only users: Close only (`commonCloseActionLabel`; may be icon-only on compact viewports)

No hard-delete control.

## 8. Forms (summary)

- Detail body (read): `AppPatientDetails` + schedule date/time tiles + notes + next-step banner (`receptionFollowUpNextStepTitle` / `receptionFollowUpDetailBody`)
- Reschedule nested: scheduled_at + notes (`ClinicalFollowUpActionDialog`)

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print; options aligned to exportable fields
- Detail dialogs: no separate print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Controller failure with no data: error `AppStateView` + Retry (`commonRetryActionLabel`) refreshing follow-up controller
- Detail failure: `AppFormInformationBanner.failure`
- Success: pop(true) → workspace refresh (no dedicated success snackbar on complete path from page; schedule strip still uses `opdSavedMessage`)
- After complete/reschedule: refresh table + all visible tab counts

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / search / filters / settings / detail / close | ∪ `patient:read` \| `clinical:read` |
| Export / Print | ∩ `evidence:export` |
| Register / Schedule strip | ∩ `patient:write` |
| Reschedule / Mark completed / Save follow-up | ∩ `patient:write` (`receptionFollowUpsWriteRequirement`) |
| Hard delete | ∩ `patient:delete` documented — **not mounted** |
| Nested cross-module | n/a |
