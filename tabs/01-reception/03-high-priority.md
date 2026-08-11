# Reception tab — High priority

## 1. Tab strip

- Label: `receptionSectionHighPriority`
- Icon: `Icons.priority_high_outlined`
- Count source: non-terminal queue entries with `isPrioritized`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `high-priority` (aliases `high_priority`, `priority`)
- Tab gate: `ReceptionHighPriorityAtomPermissions.tab` = ∩ `patient:read` (+ modules) — **same as desk queue read**, not emergency read
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same toolbar pattern as Desk queue (Filters, Settings, Export, Schedule, Register)
- Print (toolbar): **absent**
- Date filter: **enabled** — `receptionQueuedAtLabel`

## 3. Table

- Row model: prioritized non-terminal queue rows (`_ReceptionDeskRow.queue`)
- Row select:
  - Linked **emergency** flow + ∪ `emergency:read` → Flow Actions (emergency nested chrome)
  - Linked flow without emergency grant → fall through to Queue Actions (emergency Flow Actions not mounted)
  - No linked flow → Queue Actions (`ReceptionHighPriorityAtomPermissions.frontDesk`)
- Default columns: Patient, Queued at, Current step, Next action label (if allowed)
- Patient cell badges:
  - High priority badge (`receptionHighPriorityBadgeLabel`) when prioritized
  - Emergency badge (`opdTriageScopeEmergency`) when nested emergency read allowed + `isReceptionEmergencyFlow`
- Column choices: same as Desk queue (Patient ID, Phone, Queue ID, Payment status, Provider, Reason)

## 4. Advanced filters / search fields

- Same as Desk queue: Current step, Next action, Provider, Payment status; date on queued-at; search fields patient/record/staff/reason/status

## 5. Primary / secondary / row actions

- Strip: Schedule, Register
- Row: Queue Actions and/or Flow Actions as above
- Next-action column: read-only guidance

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Queue Actions | Reception → **reused** `QueueActionsDialog` |
| Flow Actions (esp. emergency-linked) | **reused** |
| Schedule / Register | shared |

## 7. Nested / follow-on

- Queue hub: Prioritize, Move/change status, Assign/Change doctor (same as Desk queue)
- Flow Actions: front-desk subset; clinical/vitals/billing off
- Emergency nested read gate: `receptionHighPriorityEmergencyNestedReadRequirement` = ∪ `emergency:read` + `scheduling-queue`

## 8. Forms (summary)

- Same nested form groups as Desk queue hubs + shared Schedule/Register

## 9. Print / labels / preview

- Table Print: **absent**
- Flow Actions Print summary when that hub opens

## 10. Loading / empty / error / success

- Empty: `receptionHighPriorityEmptyTitle` / `receptionHighPriorityEmptyBody`
- Success / loading / error: shared workspace patterns + `opdSavedMessage`

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / next-action label | ∩ `patient:read` |
| Register / Schedule | ∩ `patient:write` |
| Hub prioritize / status / assign | source front-desk |
| Emergency Flow Actions / emergency badge | ∪ `emergency:read` (nested; does **not** unlock tab) |
| Hard delete | not mounted |
| Nested write matrix | n/a — front-desk hub only |
