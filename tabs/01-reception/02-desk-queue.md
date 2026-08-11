# Reception tab — Desk queue

## 1. Tab strip

- Label: `receptionSectionQueue`
- Icon: `Icons.queue_outlined`
- Count source: authoritative non-terminal queue scope total from `state.queueEntries.items`; when this tab is active and search/advanced filters/date narrow the list, badge uses the filtered membership total
- Sibling tabs: dedicated unfiltered scope totals (shared chrome sibling model)
- Count tone: `AppTabCountTone.warning` (attention queue)
- Deep-link `section`: `desk-queue` (aliases `queue`, `desk_queue`)
- Tab gate: `ReceptionDeskQueueAtomPermissions.tab` = ∩ `patient:read` + modules
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule → Register**

- Search hint: `receptionSearchHint`
- Filters: `commonFiltersActionLabel` → Advanced filters; Apply / Clear / Close shared labels
- Settings: Table Settings (`commonTableSettings*`)
- Export: gated by `ReceptionDeskQueueAtomPermissions.export` / `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` → preview-first `printReceptionDeskList` / `PrintDocumentTemplates.registry`; omitted without export/print gate
- Schedule / Register: present when ∩ `patient:write`
- Date filter: **enabled** — `receptionQueuedAtLabel`

## 3. Table

- Row model: `_ReceptionDeskRow.queue(OpdQueueEntry, flow?)` — non-terminal queue entries; prioritized rows sort first
- Row select:
  - If linked active flow → **reused** Flow Actions (`printActionLabel: Print`; clinical/vitals/billing off)
  - Else → Queue Actions hub
- Default columns (prefer **5** data columns; next-action is read-only guidance chrome):
  1. Patient (alwaysVisible) — high-priority badge when `isPrioritized`
  2. Phone (`patientsPhoneIdentifierColumnLabel`)
  3. Queued at (`receptionQueuedAtLabel`)
  4. Current step (`receptionCurrentStepLabel`)
  5. Provider / Doctor (`opdProviderColumnLabel`)
  6. Next action label (`opdNextActionFilterLabel`) — if tab readable (`nextActionLabel`); **read-only text**, not a mutation button
- Column choices (Settings; every available column):
  - Patient ID, Queue ID (`receptionQueueIdLabel`), Payment status (`receptionPaymentStatusLabel`), Reason
- Reset columns restores the five defaults (+ next-action guidance when readable)
- Mobile: `_ReceptionDeskMobileRow`

## 4. Advanced filters / search fields

Same filter model as the table and active tab count:

- Groups: Current step (`receptionCurrentStepLabel`), Next action, Provider, Payment status (`receptionPaymentStatusLabel`)
- Search fields: patient, record, staff, reason, status
- Date range on queued-at

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: open Queue Actions or Flow Actions (no separate next-action mutation buttons)
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

Hard-delete is **not mounted**.

From Flow Actions: Assign doctor, Follow up, Print (`Print`), … (billing/vitals/clinical off).

## 8. Forms (summary)

- Prioritize: optional reason
- Move/change status: queue status selection (shared dialog body)
- Assign doctor: provider select
- Schedule / register / encounter: see shared chrome

## 9. Print / labels / preview

- Table Print: present when authorized; preview before device print; section/column options aligned to exportable fields
- Via Flow Actions: trigger `Print` → `showPrintOpdSummaryDialog` → `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Empty: `receptionEmptyTitle` / `receptionEmptyBody`
- Success: `opdSavedMessage` after hub mutations
- Loading / retry: workspace scaffold
- After prioritize / status / assign / schedule / register: refresh table + all visible tab counts

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label | ∩ `patient:read` |
| Export / Print | ∩ `evidence:export` (`receptionDeskExportRequirement`) |
| Register / Schedule | ∩ `patient:write` |
| Prioritize / Move / Assign doctor | source front-desk write |
| Delete control | not mounted (matrix ∩ `patient:delete` documented only) |
| Nested billing/clinical from hub | stripped |
| Deep-link workspace entry | ∪ `patient:read` \| `last_office:read` |
