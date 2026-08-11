# OPD tab — Follow-ups

## 1. Tab strip

- Label: `receptionSectionFollowUps`
- Icon: `Icons.event_repeat_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'OPD'))`; filtered membership when Follow-ups is active + search/advanced filters narrow (`onNarrowedCountChanged`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `OpdFollowUpsAtomPermissions.tab` = board read ∪
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Hosted by **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'opd_follow_ups'`):

Order: **Filters → Settings → Export → Print** (Start OPD **absent** by design)

- Search: `receptionFollowUpsSearchHint` / Clear `receptionClearFiltersAction`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply/Clear/Close common labels; date filter enabled (`opdArrivalDateFilterLabel`); status group (`follow_up_status`: pending/completed)
- Settings: `commonTableSettings*` (Apply/Reset reception column keys; Close `commonCloseActionLabel`)
- Export / Print gated by ∩ `evidence:export` (`OpdFollowUpsAtomPermissions.export` / `print`)
- Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList`

## 3. Table

- Row model: `ReceptionFollowUpEntry` (scoped OPD)
- Row select → Follow-up details (`showReceptionFollowUpDetailDialog`)
- Default columns (5): Patient name, Phone, Status, Follow-up date, Follow-up time
- Column choices: Patient ID, Email, Notes
- No board next-action column

## 4. Advanced filters / search fields

Advanced filters enabled (parity with Reception Follow-ups host): date From/To + status group. Footer: Clear filters → Apply filters → Close.

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

- Table Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList` (follow-up exportable fields)
- Detail dialogs: no separate print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Error/retry via panel + `refreshScopedFollowUps`
- Success after complete/reschedule (write-gated)
- Forbidden: `routeForbiddenTitle` when board read denied

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail / Close | `OpdFollowUpsAtomPermissions.tab` (read ∪) |
| Export / Print | ∩ `evidence:export` |
| Reschedule / Mark completed / Save | ∩ `clinical:write` + module (`opdFollowUpsWriteRequirement`) |
| Start OPD / nested billing/admission | absent / _(n/a)_ |
| Route entry | catalog ∩ `opd:read` |
