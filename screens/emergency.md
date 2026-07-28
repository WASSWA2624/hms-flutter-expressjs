# Action inventory — `/emergency`

Primary surface: `EmergencyWorkspacePage` (`frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart`).

Write gate: `_writeRequirement` (`emergencyWrite`). Handoff gate: emergency / patient / clinical / operations write (any). Unauthorized write / handoff controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload board | **Removed** — board syncs after mutations / realtime / adaptive poll / scaffold **Try again** |
| Row **WorkflowActionButton** (route-only triage/stabilize) | Same case as row tap / detail | **Removed** — replaced by stage-aware **Next action** that opens the mutation dialog directly |
| Parallel handoff / ambulance next-action cells vs generic next-action | Same writes | **Merged** — one `EmergencyCaseNextActionCell` for all workflow tabs |
| Detail Quick Action matching row next-action (triage / response / handoff / dispatch / start trip / complete trip) | Same write | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Detail actions shown disabled when unauthorized or case closed | No-op chrome | **Removed** — `permissionActions` hide when denied; closed cases omit write actions |
| Deep link `panel=` opened empty detail then required hunting for the action | Intermediate shell | **Removed** — panel deep links open the focused mutation dialog directly |
| Workflow `encounterId` ignored by query parser | Broken deep link | **Fixed** — `encounterId` / `encounter` map to `caseId` |

---

## Emergency workspace screen

### Tab strip

- **Active cases / Critical / Ambulance / Handoff ready / Closed / All**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_currentTab`, updates URL `?scope=…`, applies board scope, clears advanced filters.
  - Condition: Always when workspace loads.
  - Counts: Active / Critical / Ambulance / Handoff / Closed / All from board state.

- **Quick arrival** (primary)
  - Location: Tab-strip primary (`emergencyQuickArrivalAction`).
  - Opens modal: Yes — quick emergency arrival dialog.
  - Immediate result: Creates case (optional initial triage); snackbar; board refresh.
  - Condition: Write; absent on Closed tab; unauthorized control absent.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads emergency workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Client filters / search / column visibility for the active tab.
  - Condition: Always when board is loaded.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; Quick arrival remains when authorized (non-Closed tabs).
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Case detail dialog (patient context, complementary writes, timelines, print).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column on Active / Critical / Ambulance / Handoff / All.
  - Opens modal: Matching mutation dialog (triage / response / dispatch / start trip / complete trip / handoff).
  - Immediate result: Persists via controller; snackbar; board refresh. No empty detail shell.
  - Condition: Write (or handoff gate for handoff); unauthorized next-action absent. Closed has no next-action column.
  - Ambulance specializes dispatch → start trip after clinical readiness; other tabs use triage → response → complete trip → handoff.

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (Update priority, triage/response/dispatch/status/trip/handoff when not the row next-action, Schedule in Theater)
  - Location: Detail `AppQuickActions` (`permissionActions`).
  - Opens modal: Matching action dialog (or navigates to Theater for schedule).
  - Immediate result: Mutates selected case; snackbar; board refresh.
  - Condition: Write / handoff gates; action omitted when it equals `omitNextActionKind`; unauthorized / closed-case writes absent.

- **Print summary**
  - Location: Detail extra actions.
  - Opens modal: Print flow.
  - Immediate result: Prints emergency summary.
  - Condition: Always when detail is open.

- **Open in {module}** (handoff outcome)
  - Location: Handoff outcome panel when receiving work exists.
  - Opens modal: No (closes detail then navigates).
  - Immediate result: Goes to receiving module deep link.
  - Condition: Non-terminal handoff with receiving reference.

### Deep links

- **`?id=` / `?encounterId=`** — opens case detail (next-action omitted).
- **`?id=&panel=triage|response|ambulance|handoff`** — opens the focused mutation dialog directly (no empty detail shell).
- **`?scope=` / `?search=`** — selects tab / pre-fills search.

### Manual checks (Req 7)

- [ ] Unauthorized user: Quick arrival, next-action, and detail write actions absent.
- [ ] Active tab untreated case: only **Record triage** next-action; detail has no Triage duplicate.
- [ ] Handoff-ready case: **Record handoff** next-action; detail omits Handoff.
- [ ] Ambulance ready without dispatch: **Dispatch** next-action; detail omits Dispatch.
- [ ] Deep link `/emergency?encounterId=…&panel=triage` opens triage dialog without an empty detail first.
- [ ] No Refresh control on the tab strip; board still updates after a successful mutation.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.
