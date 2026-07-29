# Action inventory — `/icu`

Primary surface: `IcuWorkspacePage` (`frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart`).

Write gate: `IcuWorkspaceWriteRequirement.writeRequirement` (`clinicalWrite` or `emergencyWrite` + `icu-critical-care` module). Navigation (Open IPD / billing / discharge clearance) and print remain without write. Unauthorized write controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload board / beds | **Removed** — board syncs after mutations / realtime / adaptive poll / scaffold **Try again** |
| Tab-strip **Start ICU stay** (depends on prior selection) | Start stay | **Removed** — row **Next action** is the labeled minimal path |
| Detail Quick Action matching row next-action (start stay / acknowledge / transfer / readiness / assign bed / observation / open IPD / clearance) | Same write / navigation | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Detail actions shown disabled when ineligible or unauthorized | No-op chrome | **Removed** — `permissionActions` hide when denied; ineligible writes omitted |
| Deep link `panel=` opened detail shell then required hunting for the action | Intermediate shell | **Removed** — panel deep links open the focused mutation dialog directly |
| Mobile list without next-action trailing | Same stage write as desktop column | **Fixed** — `IcuNextActionButton` on `AppListTableMobileItem.trailing` |

---

## ICU workspace screen

### Tab strip

- **Active ICU / Critical alerts / Transfers / Discharge ready / Ended stays / All ICU / Bed board / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies board scope (or loads bed board / follow-ups).
  - Condition: Always when workspace loads.
  - Counts: Active / Critical / Transfers / Discharge / Ended / All / Beds from board state; Follow-ups from scoped follow-up count.

Patient-board strip toolbar actions (**Refresh**, **Start ICU stay**) were removed. Board work refreshes after mutations, realtime sync, adaptive polling, and scaffold **Try again**. Bed board may show **Manage beds** when rooms-beds admin gates pass.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads ICU workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Client filters / search / column visibility for the active section.
  - Condition: Patient board sections only (not Bed board / Follow-ups).

### Bed board (`?section=beds`)

- **Ward ChoiceChip filters** (All ICU wards / per-ward)
  - Location: `IcuBedBoardPanel` chrome.
  - Opens modal: No.
  - Immediate result: Filters visible beds by ward.
  - Condition: Bed board tab with wards; read ∪ `clinical:read` | `emergency:read`.

- **Available / occupied summary badges**
  - Location: `IcuBedBoardPanel` chrome.
  - Opens modal: No.
  - Immediate result: Occupancy counts for the filtered ward set.
  - Condition: Bed board tab; same read ∪.

- **Bed row** (location / occupant / status)
  - Location: `IcuBedBoardPanel` list.
  - Opens modal: No (no stay detail from this tab).
  - Immediate result: Shows occupancy row.
  - Condition: Beds present after ward filter.

- **Open IPD** (occupied row)
  - Location: Occupied bed row trailing action.
  - Opens modal: No — navigates to `/ipd` (optionally `?id=`).
  - Immediate result: Leaves ICU for IPD workspace.
  - Condition: Occupied bed; navigate (no write).

- **Manage beds**
  - Location: Bed board tab-strip primary (`AppTabToolbarPrimary`).
  - Opens modal: No — navigates to `/rooms-beds`.
  - Immediate result: Opens Rooms & beds admin.
  - Condition: Rooms-beds admin ∪ (facility/tenant/system admin roles or perms) + `inpatient-bed-management`. Absent when denied.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy.
  - Condition: No rows after tab / search / filters.

- **Empty bed board**
  - Location: `IcuBedBoardPanel` empty state.
  - Opens modal: No.
  - Immediate result: Empty beds copy.
  - Condition: Bed board tab with no beds.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Stay detail dialog (patient context, complementary writes, timelines, print).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Matching mutation / confirm dialog (or navigates for Open IPD / discharge clearance).
  - Immediate result: Persists via controller; snackbar; board refresh. No empty detail shell.
  - Condition: Write for mutation kinds (absent when unauthorized); Open IPD / discharge clearance remain without write. Critical / Transfers / Discharge / Ended specialize stage; Active / All use eligibility cascade (start stay → acknowledge → manage transfer → clearance → assign bed → observation).

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (vitals, raise alert, round, lab/imaging/prescribe, end stay, and stage actions when not the row next-action)
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: Matching action dialog (or navigates for billing / IPD / clearance).
  - Immediate result: Mutates selected stay; snackbar; board refresh.
  - Condition: Write gate; action omitted when it equals `omitNextActionKind`; unauthorized / ineligible writes absent.

- **Print summary**
  - Location: Detail extra actions.
  - Opens modal: Print flow.
  - Immediate result: Prints ICU stay summary.
  - Condition: Always when detail is open.

### Transfers tab (`?section=transfers`)

Transfer queue on the shared patient board. Stage next-action is **Manage transfer** (open request) or
**Request transfer** (no open request) — both write ∪. Write keeps source ∪ `clinical:write` |
`emergency:write` + `icu-critical-care` (matrix ∩ `clinical:write` alone — keep source). Nested
cross-module matrix rows _(n/a)_. Helpers: `IcuTransfersAtomPermissions`, `canViewIcuTransfers`,
`icuBoardShowsNextActionColumn` (Transfers hides next-action column for read-only). Tests:
`frontend/test/features/icu/presentation/icu_transfers_permissions_test.dart`.

- **Transfers** (strip tab + count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Board scope `transfer`; transfer status column + stage next-action.
  - Condition: Read ∪ `clinical:read` | `emergency:read` + `icu-critical-care`; tab omitted otherwise.

- **Search / Clear / Filters / Settings / Transfer column**
  - Location: `AppListTable` chrome; transfer status column.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Client filters / column visibility; shows transfer status for readers.
  - Condition: Same read ∪. Next-action column mounts only when write ∪ passes.

- **Next action Manage transfer / Request transfer**
  - Location: `next_action` column; mobile trailing.
  - Opens modal: Manage transfer dialog or Request transfer dialog.
  - Immediate result: Mutates transfer; snackbar; board refresh.
  - Condition: Write ∪; absent when unauthorized (no disabled stubs).

- **Row select → stay detail** / complementary writes / print / Open billing|IPD|clearance
  - Same gates as shared detail inventory; Manage/Request omitted from Quick Actions when they are the row next-action.
  - Deep link `?id=&panel=transfer`: opens transfer dialog when write ∪; otherwise falls back to read-only detail.

### Follow-ups tab (`?section=follow-ups`)

Reachable only when the Follow-ups strip tab is selected. Hosted via `FollowUpWorklistPanel` (ICU scope) with
`IcuFollowUpsAtomPermissions` read/write overrides (not reception defaults). Nested stay/alert/transfer/bed UI is
**not** opened from this tab. Write keeps source ∪ `clinical:write` | `emergency:write` + `icu-critical-care`
(matrix ∩ `clinical:write` alone — keep source). Helpers: `IcuFollowUpsAtomPermissions`, `canViewIcuFollowUps`,
`canWriteIcuFollowUps`. Tests: `frontend/test/features/icu/presentation/icu_follow_ups_permissions_test.dart`.

- **Follow-ups** (strip tab + scoped count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Mounts ICU-scoped `FollowUpWorklistPanel`.
  - Condition: Read ∪ `clinical:read` | `emergency:read` + `icu-critical-care`; tab omitted otherwise.

- **Search / Clear / Settings (columns)**
  - Location: Follow-ups `AppListTable` chrome.
  - Opens modal: Table Settings.
  - Immediate result: Client search / column visibility for scheduled ICU follow-ups.
  - Condition: Same read ∪ as the tab. No advanced Filters on this tab.

- **Empty / loading / error / Try again**
  - Location: Panel body / `AppStateView` / progress indicator.
  - Opens modal: No.
  - Immediate result: Authorized chrome states; retry reloads the list.
  - Condition: Same read ∪.

- **Row select** → Follow-up details
  - Location: Table row / mobile item.
  - Opens modal: Shared reception follow-up detail dialog (`writeRequirement` = ICU write ∪).
  - Immediate result: Shows patient + schedule; **Close** only when write denied.
  - Condition: Same read ∪. No row next-action column on this tab.

- **Reschedule follow-up** / **Mark completed**
  - Location: Detail dialog actions.
  - Opens modal: Reschedule opens Save follow-up dialog; complete mutates then closes.
  - Immediate result: Updates follow-up; list refresh; empty state when none remain.
  - Condition: Write ∪; unauthorized actions absent (no disabled stubs / routine “no access”).

- **Save follow-up** (nested reschedule dialog)
  - Location: Reschedule dialog actions.
  - Opens modal: N/A (already open).
  - Immediate result: Persists new schedule; closes on success; validation banner on failure.
  - Condition: Same write ∪.

### Deep links

- **`?id=`** — opens stay detail (next-action omitted).
- **`?id=&panel=vitals|alerts|observations|orders|transfer|discharge`** — opens the focused mutation dialog directly (no empty detail shell).
- **`?section=` / `?search=`** — selects tab / pre-fills search.
- **`?section=follow-ups`** — Follow-ups worklist when read ∪ allows; otherwise falls back off the tab.

### Manual checks (Req 7)

- [ ] Unauthorized user: next-action writes and detail write actions absent; Open IPD / print still available when applicable.
- [ ] Active tab patient without bed: only **Assign bed** next-action; detail has no Assign bed duplicate.
- [ ] Critical tab alerted patient: only **Acknowledge alert** next-action; detail omits Acknowledge.
- [ ] Deep link `/icu?id=…&panel=vitals` opens vitals dialog without an empty detail first.
- [ ] Transfers: read-only sees list + Transfer column; Manage/Request absent; writer sees Manage/Request; `panel=transfer` denied falls back to detail.
- [ ] No Refresh or Start ICU stay control on the tab strip; board still updates after a successful mutation.
- [ ] Bed board: read-only staff see ward chips / occupancy / Open IPD; **Manage beds** absent without rooms-beds admin.
- [ ] Bed board: facility admin + inpatient module sees **Manage beds**; clinical writer alone does not.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.
- [ ] Follow-ups: without `clinical:read` | `emergency:read` (or without `icu-critical-care`), tab and panel absent.
- [ ] Follow-ups: read-only staff see list / detail Close; **Reschedule** / **Mark completed** absent.
- [ ] Follow-ups: clinical or emergency writer sees mutation actions; list syncs after complete / reschedule.
