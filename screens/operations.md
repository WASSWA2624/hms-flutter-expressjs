# Action inventory — `/operations`

Primary surface: `OperationsWorkspacePage` (`frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`).

Write gate (client): `operationsWriteRequirement` / `operationsMutationRequirement` (`operations:write` ∩ + `facilities-maintenance` module) for create, assign, status update, service logs, and notes. Unauthorized write controls do not render. Backend auth remains authoritative.

Read gate (client): `operationsReadRequirement` (`operations:read` ∩ + module) for tab strip sections, list chrome, detail, and Report. Tabs omitted when the section read gate fails. Route entry is ∪ `operations:read` | `operations:write` (see `operations_access.dart`).

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
| Unauthorized create / write next-actions shown disabled | No access | **Omitted** — create and write next-actions absent |
| Next-action **Review request** (read-only / unknown status) | Same as row select → detail | **Removed** — row select is the sole open-detail path |
| Next-action **detail fetch** before Assign / status / service log / closeout | Intermediate shell | **Removed** — `focusItem` selects locally; form opens immediately; `selectItem` remains for detail |
| Mobile list without next-action trailing (detail omitted matching write) | Primary write unreachable on phone | **Fixed** — same next-action control as desktop column, trailing on mobile rows (icon-only + tooltip under 600px) |

---

## Operations workspace screen

### Tab strip

- **All requests / Open / In progress / Completed / Assets**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies status filter (except Assets / All).
  - Condition: Section visible when `operationsSectionTabRequirement` (read ∩) allows; omitted from strip otherwise.

- **Create request** (primary)
  - Location: Tab-strip primary on every section.
  - Opens modal: Yes — create-request form.
  - Immediate result: Creates request; snackbar; worklist refresh.
  - Condition: `operationsWriteRequirement`; omitted when unauthorized.

- **Report** (secondary)
  - Location: Tab-strip secondary.
  - Opens modal: Yes — summary metrics (all, open, in progress, assets).
  - Immediate result: Read-only summary dialog.
  - Condition: `operationsReportRequirement` (read ∩; Assets matrix narrows source “Always”).

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
  - Location: `next_action` column (always visible on desktop); mobile list item **trailing** (same control; icon-only with tooltip under 600px).
  - Opens modal: Assign / service log / status / closeout form when that is next; absent when read-only / unauthorized / unknown; cancelled shows non-button copy.
  - Immediate result: Sole primary write for the row when a stage write applies (no detail-fetch shell).
  - Condition: Write next-actions require `operationsWriteRequirement`; unauthorized and review-only rows show no next-action control (use row select).

### Detail dialog (request)

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (Assign / Update status / Add service log / note kinds)
  - Location: `AppQuickActions` on detail.
  - Opens modal: Matching action dialog.
  - Immediate result: Mutates via controller; snackbar; worklist refresh.
  - Condition: `operationsWriteRequirement`; action omitted when it equals the row next-action; unauthorized writes absent.

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
- Create / update / delete asset UI is not present; matrix create/update/delete ∩ `operations:write` is reserved for request create on this tab and future asset mutations (`OperationsAssetsAtomPermissions`).

---

## Manual checks (Req 7)

- [x] Next action on open request opens Assign (not detail first).
- [x] Next action on in-progress without asset opens Update status; with asset opens Add service log.
- [x] Next action on completed opens Closeout note; detail does not also show Closeout note.
- [x] Row select opens detail; detail omits the label that matches that row’s next-action.
- [x] Detail has no status banner and no Report shortcut.
- [x] Report summary has metrics only (no preview shell).
- [x] Create is primary on Completed; Report is secondary; no toolbar Refresh.
- [x] Without write capability, create primary and write next-actions are absent; no Review request button.
- [x] Status filter is absent on Open / In progress / Completed advanced filters (present on All requests).
- [x] Mobile list exposes next-action trailing; tap opens Assign without detail first.
- [x] After mutations, snackbar + refreshed queue; loading / empty / error-retry / validation still render.
- [x] Assets tab: read ∩ shows list/detail/Report; write ∩ shows Create request; write-only ∪ entry without read omits Assets; module/ABAC strip as documented in `operations_assets_permissions_test.dart`.
