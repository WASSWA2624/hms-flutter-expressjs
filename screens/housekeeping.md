# Action inventory — `/housekeeping`

Primary surface: `HousekeepingWorkspacePage` (`frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`).

Write gates (client): `canManage` (operations write / operations / housekeeping manager) for create task/schedule, assign, cancel, triage; `canUpdateTasks` (`canManage` or housekeeper roles) for start/complete and request maintenance; `canReport` (reports or operations read) for summary. Unauthorized controls do not render. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Detail **Assign / Start / Complete / Triage** matching row **Next action** | Same write | **Removed** from detail when it equals next-action; next-action is the sole primary |
| Disabled **Mark ready** (backend gap) | No-op | **Removed** — dead control |
| Detail **Readiness** preview (status badge + static copy) | Restate status | **Removed** — status tile on detail; badge remains in the table |
| Report dialog empty **preview** shell | Placeholder only | **Removed** — summary metrics grid only |
| Start / Complete / Complete-request **confirm** dialogs | Restate choice; no required input | **Removed** — mutate directly; keep confirm for cancel / cancel-request |
| Unauthorized create / write actions shown disabled | No access | **Omitted** — controls absent when unauthorized |
| Unused compact next-action chrome | Same next-action | **Removed** |

---

## Housekeeping workspace screen

### Tab strip

- **Tasks / Schedules / Maintenance requests**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, loads resource via controller.
  - Condition: Always when workspace loads.
  - Counts: pending tasks / active schedules / open requests.

- **Create task** (primary on Tasks)
  - Location: Tab-strip primary.
  - Opens modal: Yes — task form.
  - Immediate result: Creates task; snackbar; worklist refresh.
  - Condition: `canManage`; omitted when unauthorized.

- **Create schedule** (primary on Schedules)
  - Location: Tab-strip primary.
  - Opens modal: Yes — schedule form.
  - Immediate result: Creates schedule; snackbar; worklist refresh.
  - Condition: `canManage`; omitted when unauthorized.

- **Request maintenance** (primary on Maintenance)
  - Location: Tab-strip primary.
  - Opens modal: Yes — maintenance request form.
  - Immediate result: Creates request; snackbar; worklist refresh.
  - Condition: `canUpdateTasks`; omitted when unauthorized.

- **Report summary** (secondary)
  - Location: Tab-strip secondary.
  - Opens modal: Yes — summary metrics (pending, completed today, open/overdue requests).
  - Immediate result: Read-only summary dialog.
  - Condition: `canReport`; omitted when unauthorized.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` / `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (queue/status/facility/room/assignee/date by section); Table Settings.
  - Immediate result: Filters/search/columns/pagination for the active section (resource via tabs, not filter).
  - Condition: Always when worklist is loaded.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; section primary remains when authorized.
  - Condition: Empty page.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Detail dialog (identity tiles + complementary writes).
  - Immediate result: Selects item and opens detail.
  - Condition: Always when rows exist.

- **Next action** (status/capability-aware label)
  - Location: `next_action` column (always visible).
  - Opens modal: Assign or triage form when that is next; otherwise mutates start/complete directly; review/view opens detail.
  - Immediate result: Sole primary write for the row, or opens detail when read-only.
  - Condition: Write next-actions require matching capability; unauthorized write next-actions become **View details** (opens detail). Terminal rows show non-button **No action needed**.

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (Assign / Start / Complete / Cancel / Complete request / Cancel request)
  - Location: `AppQuickActions` on detail.
  - Opens modal: Assign form; cancel confirms; start/complete/complete-request mutate directly.
  - Immediate result: Mutates via controller; snackbar; worklist refresh.
  - Condition: Capability + status; action omitted when it equals the row next-action; unauthorized / terminal writes absent. Triage is next-action-only when `canManage`.

### Nested dialogs (from next-action or detail)

- **Assign** — assignee select; required for unassigned pending when managing.
- **Triage** — status / summary / SLA for open maintenance (`HousekeepingTriageForm`).
- **Cancel / Cancel request** — confirm then mutate.
- **Create task / schedule / maintenance** — forms with validation.

---

## Manual checks (Req 7)

- [ ] Next action on unassigned pending task opens Assign (not detail first).
- [ ] Next action on assigned pending task starts cleaning with no confirm dialog.
- [ ] Next action on in-progress task completes with no confirm dialog.
- [ ] Next action on open maintenance opens Triage; detail does not also show Triage.
- [ ] Row select opens detail; detail omits the label that matches that row’s next-action.
- [ ] Detail has no Mark ready and no Readiness preview panel.
- [ ] Report summary has metrics only (no empty preview shell).
- [ ] Without manage/update capability, create primary and write next-actions are absent (view/review only).
- [ ] Cancel still confirms; after mutations, snackbar + refreshed queue.
- [ ] Loading / empty / error-retry / validation still render; mobile keeps next-action + row select reachable.
