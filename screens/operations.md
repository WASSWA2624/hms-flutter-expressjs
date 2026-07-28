# Action inventory — `/operations`

Primary surface: `OperationsWorkspacePage` (`frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`).

Write gate (client): `_mutationRequirement` (`operationsWrite` + `facilities-maintenance` module) for create, assign, status update, service logs, and notes. Unauthorized write controls do not render. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Completed-tab **Report** primary + **Create request** secondary | Same create / report goals | **Merged** — Create always primary (when authorized); Report always secondary |
| Tab-strip **Refresh** | Reload worklist | **Removed** — realtime/polling sync; load failures use scaffold / inline **Try again** |
| Detail icon-only **Report** | Open report | **Removed** — toolbar **Report** is the sole entry |
| Report **preview** panel (restates summary + detail tiles) | Read-only text | **Removed** — summary metrics grid only |
| Detail **Assign / Update status / Add service log / Closeout** matching row **Next action** | Same write | **Removed** from detail when it equals next-action; next-action is the sole primary |
| Detail **status banner** restating next-action label | Restate next step | **Removed** — status tile on detail; next-action stays in the table |
| Advanced **Status** filter on Open / In progress / Completed tabs | Same status filter as tab | **Removed** on status-scoped tabs — tabs own status; All requests keeps status filter |
| Unauthorized create / write next-actions shown disabled | No access | **Omitted** — create absent; write next-actions become **Review request** |

---

## Operations workspace screen

### Tab strip

- **All requests / Open / In progress / Completed / Assets**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies status filter (except Assets / All).
  - Condition: Always when workspace loads.
  - Counts: total / open / in progress / completed+cancelled / assets.

- **Create request** (primary)
  - Location: Tab-strip primary on every section.
  - Opens modal: Yes — create-request form.
  - Immediate result: Creates request; snackbar; worklist refresh.
  - Condition: `_mutationRequirement`; omitted when unauthorized.

- **Report** (secondary)
  - Location: Tab-strip secondary.
  - Opens modal: Yes — summary metrics (all, open, in progress, assets).
  - Immediate result: Read-only summary dialog.
  - Condition: Always when workspace is loaded.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` / `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (status only on All requests; priority/facility/asset/date); Table Settings.
  - Immediate result: Filters/search/columns/pagination for the active section.
  - Condition: Always when worklist / assets panel is loaded.

### Empty / no-results

- **Empty worklist / assets**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; Create primary remains when authorized.
  - Condition: Empty page.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Request detail (or asset detail on Assets).
  - Immediate result: Selects item and opens detail.
  - Condition: Always when rows exist.

- **Next action** (status/capability-aware label)
  - Location: `next_action` column (always visible on desktop).
  - Opens modal: Assign / service log / status / closeout form when that is next; **Review request** opens detail; cancelled shows non-button copy.
  - Immediate result: Sole primary write for the row, or opens detail when read-only.
  - Condition: Write next-actions require `_mutationRequirement`; unauthorized writes become **Review request**.

### Detail dialog (request)

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (Assign / Update status / Add service log / note kinds)
  - Location: `AppQuickActions` on detail.
  - Opens modal: Matching action dialog.
  - Immediate result: Mutates via controller; snackbar; worklist refresh.
  - Condition: `_mutationRequirement`; action omitted when it equals the row next-action; unauthorized writes absent.

- **Service logs**
  - Location: Detail body panel.
  - Opens modal: No.
  - Immediate result: Lists logs or empty state.
  - Condition: Always when detail is open.

### Nested dialogs (from next-action or detail)

- **Create request** — category, priority, facility, asset, location, issue (required), notes.
- **Assign** — assignee, SLA hours, triage summary.
- **Update status** — status select, notes; sets resolvedAt when COMPLETED.
- **Add service log** — asset (required), notes (required).
- **Note kinds** — Parts/vendor, Safety, Evidence, Handover, Closeout (required text).

### Asset detail

- Progressive disclosure of asset identity (name, tag, status, location, id); no write actions.

---

## Manual checks (Req 7)

- [ ] Next action on open request opens Assign (not detail first).
- [ ] Next action on in-progress without asset opens Update status; with asset opens Add service log.
- [ ] Next action on completed opens Closeout note; detail does not also show Closeout note.
- [ ] Row select opens detail; detail omits the label that matches that row’s next-action.
- [ ] Detail has no status banner and no Report shortcut.
- [ ] Report summary has metrics only (no preview shell).
- [ ] Create is primary on Completed; Report is secondary; no toolbar Refresh.
- [ ] Without write capability, create primary and write next-actions are absent (Review request only).
- [ ] Status filter is absent on Open / In progress / Completed advanced filters.
- [ ] After mutations, snackbar + refreshed queue; loading / empty / error-retry / validation still render.
