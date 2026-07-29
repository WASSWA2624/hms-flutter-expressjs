# Action inventory — `/ipd`

Primary surface: `IpdWorkspacePage` (`frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`).

Write gates: `ipdOperationalWriteRequirement` (approve / assign bed / transfer / start admission), `ipdClinicalWriteRequirement` (nursing note / discharge / clinical orders / Follow-ups mutations), `_ipdBedManageRequirement` (Manage beds → rooms-beds). Per-tab atom maps: `IpdAdmissionQueueAtomPermissions`, `IpdActivePatientsAtomPermissions`, `IpdTransfersAtomPermissions`, `IpdDischargeAtomPermissions`, `IpdBedBoardAtomPermissions`, `IpdFollowUpsAtomPermissions`. Unauthorized write controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload workspace | **Removed** — list refreshes after mutations / scaffold **Try again** |
| Row **WorkflowActionButton** (route-only back to `/ipd` or other modules for IPD-owned steps) | Same admission mutation | **Replaced** — stage-aware **Next action** opens the mutation dialog directly |
| Detail Quick Action matching row next-action (approve / assign bed / manage transfer / nursing note / plan-manage discharge) | Same write | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Bed-board next-action **Open admission** + row tap | Open admission detail | **Removed** from next-action — row select is the sole open path |
| Deep link `panel=` / `action=` opened empty detail then required hunting for the action | Intermediate shell | **Removed** — focused deep links open the mutation dialog directly |

---

## IPD workspace screen

### Tab strip

- **Admission Queue / Active Patients / Transfers / Discharge / Bed board / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies queue scope or loads bed board.
  - Condition: Always when workspace loads.

- **Start admission** (primary on queue tabs; secondary on bed board when Manage beds is primary)
  - Location: Tab-strip toolbar.
  - Opens modal: Yes — start admission dialog.
  - Immediate result: Creates admission; snackbar; workspace refresh.
  - Condition: Operational write; absent on Follow-ups; unauthorized control absent.

- **Manage beds** (primary on bed board when bed-manage gate allows)
  - Location: Tab-strip primary.
  - Opens modal: No — navigates to `/rooms-beds`.
  - Immediate result: Leaves IPD for rooms & beds admin.
  - Condition: Bed-manage gate.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (ward), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / ward filter / column visibility for the active section.
  - Condition: Queue sections and bed board (bed board also filters status).

### Row activation / next-action (queue tabs)

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Admission detail dialog (context, records, complementary writes).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column (`IpdBoardNextActionCell`).
  - Opens modal: Matching mutation dialog (approve / assign bed / manage transfer / nursing note / discharge planning) or navigates to Theater for theatre handover.
  - Immediate result: Persists via controller; snackbar; refresh where needed. No empty detail shell. Continue-care shows plain label (row select opens detail).
  - Condition: Matching write gate; unauthorized next-action absent.

### Bed board

- **Row select** (occupied bed)
  - Location: Table row.
  - Opens modal: Admission detail.
  - Immediate result: Loads occupant admission.
  - Condition: Occupant present.

- **Next action** (status mutation)
  - Location: `next_action` column.
  - Opens modal: No — applies bed status (or shows no-action label).
  - Immediate result: Updates bed status when manage gate allows. Single status action is a direct tap (no menu).
  - Condition: Bed-manage gate for mutations; open-admission removed (use row select).

### Detail dialog

- **Complementary writes** (orders, ICU, release bed, reject, medication, ward round, …)
  - Location: Detail `AppQuickActions`.
  - Opens modal: Matching action dialog (or navigates to linked module).
  - Immediate result: Mutates selected admission; snackbar.
  - Condition: Write gates; action omitted when it equals `omitNextActionKind`; unauthorized writes absent.

### Deep links

- **`?id=` / `?admissionId=`** — opens admission detail (next-action omitted).
- **`?id=&panel=beds|transfers|discharge|nursing`** / **`?id=&action=approve`** — opens the focused mutation dialog directly (no empty detail shell).
- **`?section=`** — selects tab.

### Transfers tab

Ward/bed transfers (`?section=transfers`). Write gates:
`IpdTransfersAtomPermissions` → board read ∪, operational write ∪ for transfer
mutations / Start admission (source keeps ∪ `clinical:write` | `operations:write`
rather than matrix ∩ `clinical:write` alone), clinical write ∩ for nursing /
discharge / orders, billing panel ∩ `billing:read`. Unauthorized write controls
do not render. Nested cross-module matrix _(n/a)_ except billing.

- **Transfers** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to transfer-pending queue; loads scoped list.
  - Condition: Board read ∪ (`clinical:read` | `operations:read` + module); tab
    hidden when gate fails.

- **Start admission**
  - Location: Tab-strip toolbar.
  - Opens modal: Yes — start admission dialog.
  - Immediate result: Creates admission; snackbar; workspace refresh.
  - Condition: Operational write ∪; unauthorized control absent.

- **Search**, **Clear**, **Filters** (ward), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / ward filter / column visibility.
  - Condition: Transfers read ∪.

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Admission detail dialog (transfers section; next-action omitted).
  - Immediate result: Loads detail; omits Manage transfer from Quick Actions.
  - Condition: Transfers read ∪.

- **Next action Manage transfer**
  - Location: `next_action` column (`IpdBoardNextActionCell`).
  - Opens modal: Transfer update dialog.
  - Immediate result: Persists via controller; snackbar; list refresh.
  - Condition: Operational write ∪; unauthorized next-action absent.

- **Detail complementary writes** / billing panels
  - Location: Detail `AppQuickActions` / nested panels.
  - Condition: Operational / clinical write; billing ∩ `billing:read`; Manage
    beds not mounted on this tab.

- **`?id=&panel=transfers`** deep link
  - Opens transfer update dialog directly when operational write ∪ allows.
  - Condition: Forbidden feedback only when deep-linked without rights / 403.

- **Try again** / empty / loading
  - Location: Board body / `AsyncStateScaffold`.
  - Condition: Authorized Transfers readers; retry reloads scoped list.

Automated: `frontend/test/features/ipd/presentation/ipd_transfers_permissions_test.dart`.

### Discharge tab

Discharge planning handoff (`?section=discharge`). May need billing:read for
clearance panels. Write gates: `IpdDischargeAtomPermissions` → board read ∪,
operational write ∪ for Start admission / Release bed (source keeps ∪
`clinical:write` | `operations:write` rather than matrix ∩ `clinical:write`
alone), clinical write ∩ for plan-manage discharge / nursing / orders, billing
panel ∩ `billing:read` + `billing-payments`. Unauthorized write controls do not
render. Nested cross-module matrix _(n/a)_ except billing. Manage beds is
bed-board chrome — not mounted on this tab.

- **Discharge** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to discharge-planned queue; loads scoped list.
  - Condition: Board read ∪ (`clinical:read` | `operations:read` + module); tab
    hidden when gate fails.

- **Start admission**
  - Location: Tab-strip toolbar.
  - Opens modal: Yes — start admission dialog.
  - Immediate result: Creates admission; snackbar; workspace refresh.
  - Condition: Operational write ∪; unauthorized control absent.

- **Search**, **Clear**, **Filters** (ward), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / ward filter / column visibility.
  - Condition: Discharge read ∪.

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Admission detail dialog (discharge section; next-action omitted).
  - Immediate result: Loads detail; omits Manage discharge from Quick Actions.
  - Condition: Discharge read ∪.

- **Next action Manage discharge** (or Plan discharge when not yet planned)
  - Location: `next_action` column (`IpdBoardNextActionCell`).
  - Opens modal: Discharge planning / clearance dialog.
  - Immediate result: Persists via controller; snackbar; list refresh.
  - Condition: Clinical write ∩; unauthorized next-action absent.

- **Detail complementary writes** / Release bed / billing panels
  - Location: Detail `AppQuickActions` / nested panels.
  - Condition: Operational ∪ (Release bed) / clinical ∩ (orders, nursing);
    billing ∩ `billing:read`; Manage beds not mounted on this tab.

- **`?id=&panel=discharge`** deep link
  - Opens discharge planning dialog directly when clinical write ∩ allows.
  - Condition: Forbidden feedback only when deep-linked without rights / 403.

- **Try again** / empty / loading
  - Location: Board body / `AsyncStateScaffold`.
  - Condition: Authorized Discharge readers; retry reloads scoped list.

Automated: `frontend/test/features/ipd/presentation/ipd_discharge_permissions_test.dart`.

### Admission Queue tab

Pending admissions (`?section=admission-queue` or default). Primary surface for
**Start admission**. Typical next-actions: Approve admission, Assign bed.

- **Admission Queue** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to admission queue; loads pending list.
  - Condition: Board read ∪ (`clinical:read` | `operations:read` + module); tab
    hidden when gate fails.

- **Start admission** (toolbar primary)
  - Location: Tab-strip toolbar.
  - Opens modal: Start admission dialog.
  - Immediate result: Creates admission; snackbar; workspace refresh.
  - Condition: Operational write ∪ (`clinical:write` | `operations:write` +
    roles + module); unauthorized control absent.

- **Search**, **Clear**, **Filters** (ward), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / ward filter / column visibility.
  - Condition: Board read ∪.

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Admission detail dialog (context, records, complementary
    writes; stage next-action omitted from Quick Actions).
  - Immediate result: Loads detail.
  - Condition: Board read ∪ when rows exist.

- **Next action** (Approve / Assign bed / …)
  - Location: `next_action` column (`IpdBoardNextActionCell`).
  - Opens modal: Matching mutation dialog (no empty detail shell).
  - Immediate result: Persists via controller; snackbar; list refresh.
  - Condition: Matching write gate (operational ∪ or clinical ∩); unauthorized
    next-action absent. Continue-care is a plain label (row select opens detail).

- **Detail complementary writes** / **billing / insurance panel**
  - Location: Detail `AppQuickActions` / nested sections.
  - Condition: Operational / clinical write gates; billing panels need
    `billing:read` + `billing-payments`. Unauthorized panels/actions absent.

- **Manage beds**
  - Condition: Not primary on this tab (bed-board chrome); bed-manage gate when
    present elsewhere.

- **Try again** / empty / loading
  - Location: Workspace / list body.
  - Condition: Authorized Admission Queue readers; retry reloads list.

Write gates: `IpdAdmissionQueueAtomPermissions` → `ipdWorkspaceReadRequirement`
(read ∪), `ipdOperationalWriteRequirement` (Start admission / approve / assign /
reject — source ∪, not matrix ∩ `clinical:write` alone),
`ipdClinicalWriteRequirement` (clinical detail writes),
`ipdBillingPanelReadRequirement` (billing panels). Nested cross-module matrix
_(n/a)_ except billing. Unauthorized write controls do not render.

### Follow-ups tab

Shared follow-up worklist (`FollowUpWorklistPanel`, IPD scope). No Start
admission / Manage beds / admission detail / next-action on this tab.

- **Follow-ups** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to follow-ups section; loads IPD-scoped worklist.
  - Condition: Board read ∪ (`clinical:read` | `operations:read` + module); tab
    hidden when gate fails.

- **Search**, **Clear**, **Settings** (columns)
  - Location: `FollowUpWorklistPanel` / `AppListTable` chrome.
  - Opens modal: Table Settings dialog.
  - Immediate result: Search / column visibility for scheduled follow-ups.
  - Condition: Follow-ups read ∪.

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Follow-up details dialog.
  - Immediate result: Loads call details; Close always available.
  - Condition: Follow-ups read ∪.

- **Mark completed** / **Reschedule follow-up**
  - Location: Follow-up details footer (write-gated).
  - Opens modal: Reschedule opens Save follow-up dialog; complete mutates inline.
  - Immediate result: Persists via follow-up repository; snackbar; list refresh.
  - Condition: Clinical write ∩ (`clinical:write` + roles + module); unauthorized
    controls absent (no disabled stubs).

- **Save follow-up** (nested reschedule)
  - Location: Clinical follow-up action dialog.
  - Opens modal: Nested from Reschedule.
  - Immediate result: Updates schedule; closes; list sync.
  - Condition: Same clinical write ∩.

- **Try again** / empty / loading
  - Location: Panel body.
  - Condition: Authorized Follow-ups readers; retry reloads scoped list.

- **Start admission** / **Manage beds** / admission billing panels
  - Condition: Not mounted on Follow-ups (inventory).

Write gates: `IpdFollowUpsAtomPermissions` → `ipdFollowUpsRequirement` (read ∪),
`ipdFollowUpsWriteRequirement` (= `ipdClinicalWriteRequirement`, write ∩).
Unauthorized write controls do not render. Nested cross-module matrix _(n/a)_.

---

## Manual checks (Req 7)

- [ ] Tab strip has no Refresh control; queue still updates after a successful mutation / Try again.
- [ ] Pending-bed row: **Assign bed** next-action opens assign dialog directly; detail omits Assign bed.
- [ ] Transfer-pending row: **Manage transfer** next-action opens transfer dialog; detail omits Manage transfer.
- [ ] Deep link `/ipd?id=…&panel=transfers` opens transfer dialog without an empty detail first.
- [ ] Bed board: occupied row has no **Open admission** in next-action; row tap opens detail.
- [ ] Without operational/clinical write, matching next-action and detail writes are absent.
- [ ] Admission Queue: without clinical|operations read, tab absent; with clinical:read alone, list mounts and Start admission / Assign bed / Approve absent; with operational write ∪, mutations mount and sync; billing panel absent without billing:read.
- [ ] Transfers: without clinical|operations read, tab and panel absent; with clinical:read alone, list mounts and Manage transfer / Start admission absent; with operational write ∪, mutations mount and sync the list.
- [ ] Follow-ups: without clinical|operations read, tab and panel absent; with clinical:read alone, list mounts and Mark completed / Reschedule absent; with clinical:write ∩, mutations mount and sync the list.
- [ ] Loading / empty / error-retry / validation states still render on workspace and dialogs.
- [ ] Mobile and desktop keep next-action and row select reachable; theme tokens only.

Automated: `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart`, `frontend/test/features/ipd/presentation/ipd_workspace_ux_simplify_test.dart`, `frontend/test/features/ipd/presentation/ipd_admission_queue_permissions_test.dart`, `frontend/test/features/ipd/presentation/ipd_follow_ups_permissions_test.dart`, `frontend/test/features/ipd/presentation/ipd_transfers_permissions_test.dart`.
