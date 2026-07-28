# Action inventory — `/theater`

Primary surface: `TheaterWorkspacePage` (`frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`).

Write gate: `AppPermissions.clinicalWrite`. Unauthorized write / next-action controls do not render. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (write secondary / read-only primary) | Reload board | **Removed** — board syncs after mutations / realtime / adaptive poll / scaffold **Try again** |
| Detail Quick Action matching row next-action (readiness / start case→stage / anesthesia / post-op / handover) | Same write | **Omitted** from detail via `omitNextActionKind` — next-action is the sole primary for that goal |
| Detail header icon **Reschedule** / **Update stage** vs Quick Actions | Same writes | **Merged** into detail Quick Actions; Update stage omitted when next-action is **Start case** |
| Deep link `panel=` opened empty detail then auto-opened nested dialog | Intermediate shell | **Removed** — panel deep links open the focused mutation dialog directly |
| Advanced filters **Status** / **Stage** on Scheduled / In theater / Recovery | Same pin as tabs | **Removed** on those tabs — tabs own status/stage; **All cases** keeps both |
| Mobile list without next-action trailing | Same stage write as desktop column | **Fixed** — `_TheaterNextActionButton` on `AppListTableMobileItem.trailing` |
| Detail write actions on cancelled / completed cases | No-op chrome | **Removed** — Quick Actions absent for terminal cases |

---

## Theater workspace screen

### Tab strip

- **Scheduled / In theater / Recovery / All cases / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies status/stage filter (or clears on All); Follow-ups shows shared worklist.
  - Condition: Always when workspace loads.
  - Counts: Scheduled / In theater / Recovery / All from board; Follow-ups from scoped follow-up count.

- **Schedule case** (primary)
  - Location: Tab-strip primary on worklist tabs (not Follow-ups).
  - Opens modal: Yes — schedule case dialog.
  - Immediate result: Creates case; snackbar; board refresh.
  - Condition: Write; unauthorized control absent.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads theater workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings dialog.
  - Immediate result: Search / filters / column visibility for the active section.
  - Condition: Always when board is loaded. Advanced filters omit Status / Stage on Scheduled / In theater / Recovery; keep date + room / surgeon / anesthetist; All cases keeps Status / Stage.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; **Schedule case** remains when authorized (non-Follow-ups).
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Case detail dialog (patient context, complementary writes, checklist / records / resources / timeline).
  - Immediate result: Loads detail; omits the stage next-action from Quick Actions.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Matching mutation dialog (update readiness / start case→stage / anesthesia / post-op / handover).
  - Immediate result: Selects case then opens mutation dialog directly (no empty detail shell). Persists via controller; snackbar; board refresh.
  - Condition: Write; unauthorized next-action absent (read-only shows label text). Terminal cancelled / completed show status text only.

### Detail dialog

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (reschedule, update stage when not start-case next-action, assign resource, readiness / anesthesia / post-op / handover when not the row next-action, finalize, cancel)
  - Location: Detail `AppQuickActions` (`detailPanel` presentation).
  - Opens modal: Matching action dialog.
  - Immediate result: Mutates selected case; snackbar; board refresh.
  - Condition: Write; action omitted when it equals `omitNextActionKind`; unauthorized / terminal-case writes absent.

- **Open in IPD / Open in Emergency**
  - Location: Source context panel when linked.
  - Opens modal: No (navigates).
  - Immediate result: Goes to receiving module deep link.
  - Condition: Linked admission or emergency case id present.

### Deep links

- **`?id=`** — opens case detail (next-action omitted).
- **`?id=&panel=checklist|anesthesia|postop|resources`** — opens the focused mutation dialog directly (no empty detail shell); write required.
- **`?section=` / `?search=`** — selects tab / pre-fills search.
- **`?action=schedule&patient_id=&encounter_id=`** — opens schedule dialog when write allowed.

### Manual checks (Req 7)

- [x] Unauthorized user: Schedule case, next-action writes, and detail write actions absent; no Refresh toolbar. *(widget)*
- [x] Not-ready case: only **Update readiness** next-action; detail has no Update readiness duplicate. *(widget)*
- [x] No Refresh control on the tab strip; Schedule case remains the sole primary for writers. *(widget)*
- [x] Advanced filters omit Status / Stage on Scheduled; All cases keeps them. *(widget)*
- [x] Mobile list shows next-action trailing. *(widget)*
- [x] Deep link `/theater?id=…&panel=checklist` opens readiness dialog without an empty detail first. *(widget)*
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths. *(manual — dialog validation / snackbars reuse shared helpers)*

Widget tests in `frontend/test/features/theater/presentation/theater_workspace_page_test.dart` cover toolbar merges, deep-link focused action, next-action omit, read-only absence, advanced-filter omissions, and mobile trailing.
