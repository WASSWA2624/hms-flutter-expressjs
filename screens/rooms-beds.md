# Action inventory — `/rooms-beds`

Primary surface: `RoomsBedsWorkspacePage` (`frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`).

Write gates (client): `canAdminBeds` (elevated / tenant / facility / system admin) for catalog add room/bed, status mutations, manage catalog; `canIpdWrite` (`clinicalWrite`) for assign / release / transfer. Module navigation (IPD / housekeeping / operations) does not require bed admin. Unauthorized write controls do not render. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary fallback + secondary) | Reload board | **Removed** — board syncs after mutations / realtime / scaffold **Try again** |
| Turnover secondary **Open operations** | Navigate to operations | **Removed** — out-of-service tab primary + maintenance next-action are the entries |
| Detail action matching row **Next action** (assign / release / mark available / manage transfer / open operations) | Same write / navigation | **Omitted** from detail — next-action is the sole primary for that goal |
| Detail **Readiness** tile | Restate status | **Removed** — status tile remains |
| Advanced **Status** filter on Available / Occupied / Turnover / Out of service | Same scope as tab | **Removed** on status-scoped tabs — All beds keeps status filter |
| Unauthorized write next-actions shown disabled with lock | No access | **Omitted** — write next-actions absent; row select opens detail |
| Release / transfer **admission** field when admission already known | Restate linked admission | **Removed** — confirm / destination ward only; admission still required when unknown |
| Mobile list without next-action trailing | Same stage write as desktop | **Fixed** — `RoomsBedsNextActionButton` on mobile `trailing` |
| Reserved next-action **Assign** (disabled until available) | Dead primary | **Fixed** — reserved next-action is **Mark available** (release hold) |

---

## Rooms & beds workspace screen

### Tab strip

- **All beds / Available / Occupied / Turnover / Out of service**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, client-filters board.
  - Condition: Always when workspace loads.
  - Counts: total / available / occupied / turnover / blocked aggregates.

- **Add room** (primary on All when authorized)
  - Location: Tab-strip primary.
  - Opens modal: Yes — tenant facility room form.
  - Immediate result: Creates room; board refresh.
  - Condition: `canAdminBeds`; omitted when unauthorized.

- **Add bed** (primary on Available when authorized; secondary on All)
  - Location: Tab-strip toolbar.
  - Opens modal: Yes — tenant facility bed form.
  - Immediate result: Creates bed; board refresh.
  - Condition: `canAdminBeds`; omitted when unauthorized.

- **IPD** (primary on Occupied)
  - Location: Tab-strip primary.
  - Opens modal: No — navigates to `/ipd`.
  - Immediate result: Leaves rooms-beds for IPD workspace.

- **Open housekeeping** (primary on Turnover)
  - Location: Tab-strip primary.
  - Opens modal: No — navigates to `/housekeeping`.

- **Open operations** (primary on Out of service)
  - Location: Tab-strip primary.
  - Opens modal: No — navigates to `/operations`.

- **Manage catalog** (secondary when authorized)
  - Location: Tab-strip secondary.
  - Opens modal: No — navigates to tenant facility setup.
  - Condition: `canAdminBeds`; omitted when unauthorized.

Tab-strip **Refresh** was removed.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` / `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (facility / ward / room; **status only on All beds**); Table Settings.
  - Immediate result: Filters/search/columns/pagination for the active section.
  - Condition: Always when board is loaded.

### Empty / no-results

- **Empty board**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; section primary remains when authorized.
  - Condition: Empty page.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Bed detail (identity tiles, complementary writes, assignment history).
  - Immediate result: Selects bed and opens detail; omits the row next-action from detail actions.
  - Condition: Always when rows exist.

- **Next action** (status/capability-aware label)
  - Location: `next_action` column (always visible on desktop); mobile list item `trailing`.
  - Opens modal: Assign / release confirm / manage transfer when that is next; mark available mutates directly; housekeeping / operations navigate.
  - Immediate result: Sole primary write/navigation for the row.
  - Condition: Write next-actions require matching capability; unauthorized write next-actions absent (use row select). Navigation next-actions always available.

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Open IPD admission**
  - Location: Detail body (when admission linked).
  - Opens modal: No — navigates to `/ipd?admission=…`.
  - Immediate result: Opens the linked admission in IPD.

- **Complementary writes** (reserve, status marks, assign / release / transfer / manage transfer, housekeeping / operations links)
  - Location: Detail action wrap.
  - Opens modal: Assign / release / transfer / manage-transfer forms when applicable; status mutates directly.
  - Immediate result: Mutates via controller; snackbar; board refresh.
  - Condition: Capability + status; action omitted when it equals the row next-action; ineligible / unauthorized writes absent.

### Nested dialogs (from next-action or detail)

- **Assign** — admission number required.
- **Release** — confirm body when admission known; admission field only when unknown.
- **Request transfer** — destination ward required; admission field only when unknown.
- **Manage transfer** — shared transfer update dialog (approve / start / complete / cancel + destination bed).
- **Add room / Add bed** — tenant facility forms.

---

## Manual checks (Req 7)

- [x] Next action on available bed opens Assign (not detail first).
- [x] Next action on occupied opens Release confirm without re-asking admission when linked.
- [x] Next action on cleaning / reserved / blocked is Mark available; detail omits Mark available.
- [x] Next action on maintenance / out-of-service opens Operations; detail omits Open operations.
- [x] Row select opens detail; detail omits the label that matches that row’s next-action.
- [x] Detail has no readiness tile; no toolbar Refresh; no turnover Open operations secondary.
- [x] Status filter only on All beds.
- [x] Without write capability, write next-actions and unauthorized catalog actions are absent.
- [x] Mobile trailing exposes the same next-action as the desktop column.

Automated: `frontend/test/features/rooms_beds/presentation/rooms_beds_ux_simplify_test.dart`, `rooms_beds_status_helpers_test.dart`.
