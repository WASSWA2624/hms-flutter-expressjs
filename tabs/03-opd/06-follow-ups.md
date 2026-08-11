# OPD tab — Follow-ups

## 1. Tab strip

- Label: `receptionSectionFollowUps`
- Icon: `Icons.event_repeat_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'OPD'))`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `OpdFollowUpsAtomPermissions.tab` = board read ∪
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Hosted by **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'opd_follow_ups'`):

- Search: `receptionFollowUpsSearchHint` / Clear `receptionClearFiltersAction`
- Filters: **omitted** (`showAdvancedFilterButton: false` default)
- Settings: `commonTableSettings*` (Apply/Reset reception column keys)
- Export / Print / Start OPD: **absent** on this tab
- Date filter: **disabled** by default

## 3. Table

- Row model: `ReceptionFollowUpEntry` (scoped OPD)
- Row select → Follow-up details (`showReceptionFollowUpDetailDialog`)
- Default columns (panel): Patient, Phone, Status, Follow-up date, Follow-up time (panel-defined set)
- No board next-action column

## 4. Advanced filters / search fields

Intentionally omitted on OPD Follow-ups host (no advanced filter button / groups passed).

## 5. Primary / secondary / row actions

- No Start OPD
- Row → detail; detail footer Close (read-only) plus Reschedule / Mark completed when write allowed

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up details | **reused** Reception `reception_follow_up_detail_dialog.dart` |
| Nested reschedule follow-up | **reused** Reception / shared follow-up save |

## 7. Nested / follow-on

Reschedule → save follow-up form; Mark completed. Hard delete/void **not mounted**. Billing/admission/Start OPD **not reachable**.

## 8. Forms (summary)

Follow-up reschedule date/time/notes; complete confirmation.

## 9. Print / labels / preview

- Absent on this tab

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Error/retry via panel + `refreshScopedFollowUps`
- Success after complete/reschedule (write-gated)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / settings / detail / Close | `OpdFollowUpsAtomPermissions.tab` (read ∪) |
| Reschedule / Mark completed / Save | ∩ `clinical:write` + module (`opdFollowUpsWriteRequirement`) |
| Start OPD / nested billing/admission | absent / _(n/a)_ |
| Route entry | catalog ∩ `opd:read` |
