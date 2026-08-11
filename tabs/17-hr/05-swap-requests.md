# HR tab — Swap requests

## 1. Tab strip

- Label: `hrQueueSwapRequests`
- Icon: `Icons.swap_horiz_outlined`
- Count source: `summary.swapRequests`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `swap-requests` (aliases `swap`, `swaps`)
- Queue: `SWAP_REQUESTS`
- Tab gate: `HrLeaveRequestsAtomPermissions.tab` (same as leave — `hrSectionRequirement`)
- Mutations: `HrShiftsAtomPermissions.approveSwap` / `rejectSwap` (∩ `roster:approve`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Work-queue pattern; **no** strip primary
- Filters status; date UI unwired
- Export ungated; Print off

## 3. Table

- Columns: shift type, staff, period, status, next action (`hrApproveSwapAction`)
- Row select → `_WorkItemActions` hub
- Storage: `hr_work_queue_swapRequests_v2` (queue-keyed pattern)

## 4. Advanced filters / search fields

- Status multi-choice; date UI not applied

## 5. Primary / secondary / row actions

- Next-action Approve (disabled when denied)
- Hub Approve / Reject swap

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Approve / Reject swap reason dialogs | HR-owned |
| Work-item actions hub | HR-owned |

## 7. Nested / follow-on

- Reason fields only

## 8. Forms (summary)

- Approve / reject reason

## 9. Print / labels / preview

- No list print

## 10. Loading / empty / error / success

- Shared queue empty/loading; `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | leave-read requirement |
| Swap approve / reject (hub) | ∩ `roster:approve` — omitted |
| Next-action | disabled when denied |
| Export | ungated |
