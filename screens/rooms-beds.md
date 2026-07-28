# Action inventory — `/rooms-beds`

Primary surface: `RoomsBedsWorkspacePage` (`frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`).

Write gates: bed catalog / status admin via elevated or tenant/facility/system admin (`_canAdminBeds`); assign / release / transfer via `clinicalWrite`. Unauthorized write controls do not render (`roomsBedsNextActionShouldRender` / conditional toolbar & detail actions). Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary when read-only; secondary when admin) | Reload board | **Removed** — mutations / realtime / scaffold **Try again** |
| Occupied **IPD** / Turnover **Open housekeeping** / OOS **Open operations** strip primaries | Leave screen | **Removed** — board next-action (or app nav) owns cross-module jumps; strip keeps catalog writes only |
| Turnover secondary **Open operations** | Leave screen | **Removed** with strip nav cleanup |
| Detail action matching row **Next action** (Assign / Release / Manage transfer / Mark available / Open operations) | Same write or jump | **Omitted** via `omitNextActionKind` — next-action is the sole primary |
| Detail **Readiness** tile restating status | Same info | **Removed** — status tile remains |
| Status advanced filter on section tabs that already scope status | Restate tab scope | **Removed** from non–All tabs — status filter only on **All beds** |
| Release / transfer **Admission number** when admission already known | Restate prior choice | **Removed** field — confirm / destination ward only |
| Deep link `bedId` only selected bed | Intermediate shell; hunt for row | **Removed** — deep link opens bed detail dialog |
| Unauthorized next-action shown disabled with lock | No access chrome | **Omitted** — control absent; row select opens detail |

---

## Rooms & beds workspace screen

### Tab strip

- **All beds / Available / Occupied / Turnover / Out of service**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, client-filters board counts/rows.
  - Condition: Always when workspace loads.
  - Counts: Aggregate status counts per section.

- **Create room** (primary on All beds)
  - Location: Tab-strip primary.
  - Opens modal: Yes — tenant facility room form.
  - Immediate result: Creates room; board refresh.
  - Condition: Bed admin; unauthorized control absent.

- **Create bed** (primary on Available)
  - Location: Tab-strip primary.
  - Opens modal: Yes — tenant facility bed form.
  - Immediate result: Creates bed; board refresh.
  - Condition: Bed admin; unauthorized control absent.

- **Create bed** (secondary on All) / **Create room** (secondary on Available)
  - Location: Tab-strip secondary.
  - Opens modal: Matching catalog form.
  - Immediate result: Creates room or bed; board refresh.
  - Condition: Bed admin.

- **Manage catalog** (secondary on every tab)
  - Location: Tab-strip secondary.
  - Opens modal: No — navigates to tenant facility setup.
  - Immediate result: Leaves board for full catalog admin.
  - Condition: Bed admin; unauthorized control absent.

Occupied / Turnover / Out of service have no strip primary (board next-action is the work entry).

Tab-strip **Refresh** was removed.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` / `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Reloads rooms & beds workspace.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (facility / ward / room; status on All only), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Filters / search / columns / page for the active tab.
  - Condition: Always when board is loaded.

### Empty / no-results

- **Empty board**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; section primary remains when authorized.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Bed detail dialog (history + complementary writes).
  - Immediate result: Loads assignments / admission context; omits the board next-action from detail actions.
  - Condition: Always when rows exist.

- **Next action** (status-aware label)
  - Location: `next_action` column (always visible).
  - Opens modal: Assign / Release / Manage transfer dialogs, or mutates Mark available, or navigates to Operations; no empty detail shell.
  - Immediate result: Sole labeled row path for the stage primary. Unauthorized writes absent (row select still opens detail).
  - Condition: Authorized for that kind; otherwise control omitted.

### Deep link

- **`?bed=` / `bedId=`**
  - Location: Route query via `RoomsBedsQuery`.
  - Opens modal: Bed detail dialog after load.
  - Immediate result: No intermediate “selected only” shell.

### Bed detail dialog

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Open IPD admission**
  - Location: Detail body when admission linked.
  - Opens modal: No — navigates to `/ipd?admission=…`.
  - Immediate result: Leaves board for admission workspace.
  - Condition: Current admission present.

- **Complementary status / IPD writes** (Reserve, Mark cleaning / maintenance / blocked, Request transfer, Open housekeeping when cleaning, Open operations when not the next-action, etc.)
  - Location: Detail action wrap.
  - Opens modal: Status mutates directly; transfer / assign / release as matching dialogs.
  - Immediate result: Complementary work that is not the board next-action primary.
  - Condition: Matching write gate; next-action twin omitted.

- **Assignment history**
  - Location: Detail progressive-disclosure panel.
  - Opens modal: No.
  - Immediate result: Lists assignment records or empty copy.

### Dialogs (assign / release / transfer / transfer update)

- **Assign bed** — requires admission number (+ optional ward suitability hint).
- **Release bed** — confirm body; admission field only when unknown.
- **Request transfer** — destination ward required; admission field only when unknown.
- **Manage transfer** — shared transfer update dialog (approve / start / complete / cancel + destination bed when needed).

Loading / saving / success snackbar / validation / failure surfaces remain on these dialogs and the board.
