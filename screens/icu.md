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

Tab-strip toolbar actions were removed. Board work refreshes after mutations, realtime sync, adaptive polling, and scaffold **Try again**.

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

### Deep links

- **`?id=`** — opens stay detail (next-action omitted).
- **`?id=&panel=vitals|alerts|observations|orders|transfer|discharge`** — opens the focused mutation dialog directly (no empty detail shell).
- **`?section=` / `?search=`** — selects tab / pre-fills search.

### Manual checks (Req 7)

- [ ] Unauthorized user: next-action writes and detail write actions absent; Open IPD / print still available when applicable.
- [ ] Active tab patient without bed: only **Assign bed** next-action; detail has no Assign bed duplicate.
- [ ] Critical tab alerted patient: only **Acknowledge alert** next-action; detail omits Acknowledge.
- [ ] Deep link `/icu?id=…&panel=vitals` opens vitals dialog without an empty detail first.
- [ ] No Refresh or Start ICU stay control on the tab strip; board still updates after a successful mutation.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.
