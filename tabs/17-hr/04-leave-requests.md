# HR tab — Leave requests

## 1. Tab strip

- Label: `hrLeaveRequestsSummaryLabel`
- Icon: `Icons.event_busy_outlined`
- Count source: `summary.leaveRequests`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `leave-requests` (aliases `leave`, `leaves`)
- Queue: `LEAVE_REQUESTS`
- Tab gate: `HrLeaveRequestsAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Same work-queue chrome as shift roster
- Context: `hrRequestLeaveAction` if `requestLeave` (∩ `hr:write`)
- Date UI present but not wired from Filters apply

## 3. Table

- Defaults: leave type, staff, period, status, next action
- Row select → generic `_showWorkItemDialog` (Approve/Reject), **not** `showHrLeaveDetailDialog`
- Storage: `hr_work_queue_leaveRequests_v2`

## 4. Advanced filters / search fields

- Status group; date UI present but not applied

## 5. Primary / secondary / row actions

- Next action: `hrApproveLeaveAction` — `AppAccessActionGate` with **`hideWhenDenied: false`** → **disabled**, not omitted
- Detail: Approve / Reject (`approveLeave` / `rejectLeave`)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Approve / Reject reason (`hrApproveLeaveDialogTitle` / `hrRejectLeaveDialogTitle`) | HR-owned |
| Request leave (`hrLeaveDialogTitle`) | HR-owned |

## 7. Nested / follow-on

- None beyond reason / leave form fields

## 8. Forms (summary)

- Leave request: type, dates, covering, reason, handover
- Approve / reject reason fields

## 9. Print / labels / preview

- No list print; leave calendar print lives under staff leave detail path

## 10. Loading / empty / error / success

- Shared queue empty/loading; `hrSavedMessage`

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list | `HrLeaveRequestsAtomPermissions.tab` |
| Request leave | ∩ `hr:write` — omitted |
| Approve / Reject in hub | omitted (`hideWhenDenied` true) |
| Next-action button | **disabled** when denied (convention gap) |
| Export | ungated |
