# HR tab — Unassigned shifts

## 1. Tab strip

- Label: `hrQueueUnassignedShifts`
- Icon: `Icons.pending_actions_outlined`
- Count source: `unassignedShifts + overdueShifts`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `unassigned-shifts` (aliases `unassigned`, `overdue`, `overdue-shifts`)
- Queues: default `UNASSIGNED_SHIFTS`; overdue `OVERDUE_SHIFTS` allowed when selected/deep-linked (facet then shows both)
- Tab gate: `HrShiftsAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- No strip primary
- Filters status (+ overdue queue when active)
- Export ungated; Print off
- Date UI unwired

## 3. Table

- Columns: shift type, shift id, period, status, next action (`hrOverrideShiftAction`)
- Row select → work-item hub
- Storage: queue-keyed `hr_work_queue_*_v2`

## 4. Advanced filters / search fields

- Status; overdue queue facet when active

## 5. Primary / secondary / row actions

- Override shift (next-action / hub)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Override shift (`hrOverrideShiftDialogTitle` + `HrOverrideShiftFields`) | HR-owned |

## 7. Nested / follow-on

- Staff picker + reason only

## 8. Forms (summary)

- Override: staff + reason

## 9. Print / labels / preview

- No list print

## 10. Loading / empty / error / success

- Shared queue feedback; `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | ∩ `hr:read` |
| Override (hub) | ∩ `roster:write` — omitted |
| Next-action | disabled when denied |
| Export | ungated |
