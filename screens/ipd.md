# Action inventory — `/ipd`

Primary surface: `IpdWorkspacePage` (`frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`).

Write gates: `ipdOperationalWriteRequirement` (approve / assign bed / transfer / start admission), `ipdClinicalWriteRequirement` (nursing note / discharge / clinical orders), `_ipdBedManageRequirement` (Manage beds → rooms-beds). Unauthorized write controls do not render.

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

### Follow-ups tab

- Follow-up worklist panel (`FollowUpWorklistPanel`, IPD scope)
  - Location: Follow-ups section body.
  - Condition: Follow-ups tab selected.

---

## Manual checks (Req 7)

- [ ] Tab strip has no Refresh control; queue still updates after a successful mutation / Try again.
- [ ] Pending-bed row: **Assign bed** next-action opens assign dialog directly; detail omits Assign bed.
- [ ] Transfer-pending row: **Manage transfer** next-action opens transfer dialog; detail omits Manage transfer.
- [ ] Deep link `/ipd?id=…&panel=transfers` opens transfer dialog without an empty detail first.
- [ ] Bed board: occupied row has no **Open admission** in next-action; row tap opens detail.
- [ ] Without operational/clinical write, matching next-action and detail writes are absent.
- [ ] Loading / empty / error-retry / validation states still render on workspace and dialogs.
- [ ] Mobile and desktop keep next-action and row select reachable; theme tokens only.

Automated: `frontend/test/features/ipd/presentation/ipd_workspace_page_test.dart`, `frontend/test/features/ipd/presentation/ipd_workspace_ux_simplify_test.dart`.
