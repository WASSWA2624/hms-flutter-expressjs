# Reception tab — Desk queue

## 1. Tab strip

- Label: `receptionSectionQueue`
- Icon: `Icons.queue_outlined`
- Count source: non-terminal `state.queueEntries.items` length
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `desk-queue` (aliases `queue`, `desk_queue`)
- Tab gate: `ReceptionDeskQueueAtomPermissions.tab` = ∩ `patient:read` + modules
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Search hint: `receptionSearchHint`
- Filters / Settings / Export: present (same shared labels as Appointments)
- Print (toolbar): **absent**
- Schedule / Register: present when ∩ `patient:write`
- Date filter: **enabled** — `receptionQueuedAtLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.queue(OpdQueueEntry, flow?)` — non-terminal queue entries; prioritized rows sort first
- Row select:
  - If linked active flow → **reused** Flow Actions
  - Else → Queue Actions hub
- Default columns:
  1. Patient (alwaysVisible) — high-priority badge when `isPrioritized`
  2. Queued at (`receptionQueuedAtLabel`)
  3. Current step (`receptionCurrentStepLabel`)
  4. Next action label (`opdNextActionFilterLabel`) — if tab readable (`nextActionLabel`); **read-only text**, not a button
- Column choices:
  - Patient ID, Phone, Queue ID (`receptionQueueIdLabel`), Payment status (`receptionPaymentStatusLabel`), Provider, Reason

## 4. Advanced filters / search fields

- Groups: Current step (`receptionCurrentStepLabel`), Next action, Provider, Payment status (`receptionPaymentStatusLabel`)
- Search fields: patient, record, staff, reason, status
- Date range on queued-at

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: open Queue Actions or Flow Actions (no separate next-action buttons)
- Deep-link walk-in (`action=route|walk_in|…`): encounter dialog gated by front-desk

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Queue Actions (`opdQueueActionsTitle`) | Reception wrapper → **reused** `QueueActionsDialog` |
| Flow Actions (linked visit) | **reused** |
| Schedule / Register | Reception / **reused** (shared) |
| Walk-in encounter | **reused** `showOpdEncounterDialog` |

## 7. Nested / follow-on (Queue Actions)

Front-desk requirement `ReceptionDeskQueueAtomPermissions.frontDesk`:

1. Prioritize (`opdPrioritizeAction`) → `AppTextActionDialog` (`opdPrioritizeQueueTitle`, optional reason)
2. Change status / Move (`opdMoveQueueAction`) → `_ChangeQueueStatusDialog` (`opdMoveQueueTitle`)
3. Assign / Change doctor → `_AssignQueueDoctorDialog`
4. Footer Cancel (`commonCancelActionLabel`)

From Flow Actions: Assign doctor, Follow up, Print summary, … (billing/vitals/clinical off).

## 8. Forms (summary)

- Prioritize: optional reason
- Move/change status: queue status selection (shared dialog body)
- Assign doctor: provider select
- Schedule / register / encounter: see shared chrome

## 9. Print / labels / preview

- Table Print: **absent**
- Via Flow Actions: `opdPrintSummaryAction` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Success: `opdSavedMessage` after hub mutations
- Loading / retry: workspace scaffold

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label | ∩ `patient:read` |
| Register / Schedule | ∩ `patient:write` |
| Prioritize / Move / Assign doctor | source front-desk write |
| Delete control | not mounted (matrix ∩ `patient:delete` documented only) |
| Nested billing/clinical from hub | stripped |
