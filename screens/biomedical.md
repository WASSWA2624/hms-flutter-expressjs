# Action inventory — `/biomedical`

Primary surface: `BiomedicalWorkspacePage` (`frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`).

Write gate: `_writeRequirement` (`biomedWrite` or `operationsWrite` + `biomedical-engineering-suite`). Print gate: `_printRequirement` (`evidenceExport` + biomed/operations read or write + module). Unauthorized write / print controls do not render.

Dialog chrome: each `AppDialog` has a **Close** control that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** (primary on Support/Analytics, secondary elsewhere) | Reload worklist | **Removed** — mutations refresh the workbench; load failures use scaffold **Try again** |
| Queue summary secondaries (overdue PM, open WOs, critical downtime, recalls) | Jump / filter queue | **Removed** from toolbar — counts surface on panel tabs; filters cover overdue / status |
| **Report Fault** secondary on Registry **and** Support | Report fault | **Merged** — Support tab-strip primary only |
| Overview **and** Work Orders **Create work order** primary | Create WO | **Removed** from Overview — Work Orders owns create |
| Detail `_RelatedSection` badge strips (maintenance / compliance / lifecycle) | Restate action labels | **Removed** — non-actionable restatement of quick actions |
| Asset tag in header, expanded fields, and Registry tiles | Show asset tag | **Deduped** — tag stays on header (`patientNumber`); Registry keeps equipment / resource / path |
| Print **preview** dialog + Print button | Print report | **Merged** — single print path via `printFormTemplateDocument`; unauthorized print absent |
| Detail quick action that matches row **next-action** | Same write | **Removed** from detail — next-action is the sole primary write for that goal |
| Start / Return work-order buttons shown for any WO row | Start / return WO | **Gated** to `OPEN`/`PENDING` (start) and `IN_PROGRESS` (return); still omitted when they are the next-action |
| Row tap vs next-action **Review** (no write) | Open detail | **Kept** — one detail dialog; next-action is the labeled row control when write is absent |

---

## Biomedical workspace screen

### Tab strip

- **Registry / Overview / Preventive / Work orders / Compliance / Support / Analytics**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches panel/resource, updates URL `?panel=…` (Registry omits query).
  - Condition: Always for authorized biomedical module users.
  - Counts: Registry (equipment total), Preventive (overdue PM), Work orders (open WOs), Compliance (critical downtime + active recalls) when &gt; 0.

- **Register asset** (primary)
  - Location: Tab-strip primary on Registry.
  - Opens modal: Yes — register-asset dialog.
  - Immediate result: Creates registry asset; snackbar; workbench refresh.
  - Condition: `_writeRequirement`.

- **Create work order** (primary)
  - Location: Tab-strip primary on Work orders only.
  - Opens modal: Yes — work-order dialog.
  - Immediate result: Creates work order; snackbar; workbench refresh.
  - Condition: `_writeRequirement`.

- **Schedule maintenance** (primary)
  - Location: Tab-strip primary on Preventive.
  - Opens modal: Yes — maintenance plan dialog.
  - Immediate result: Schedules plan; snackbar; workbench refresh.
  - Condition: `_writeRequirement`.

- **Record calibration** (primary)
  - Location: Tab-strip primary on Compliance.
  - Opens modal: Yes — calibration dialog.
  - Immediate result: Records calibration; snackbar; workbench refresh.
  - Condition: `_writeRequirement`.

- **Report fault** (primary)
  - Location: Tab-strip primary on Support.
  - Opens modal: Yes — fault report dialog.
  - Immediate result: Creates fault report; snackbar; workbench refresh.
  - Condition: `_writeRequirement`.

Overview and Analytics have no tab-strip primary. Tab-strip **Refresh** and queue secondaries were removed.

- **Try again** (page load / failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Filters** (advanced), **Settings** (columns), **Previous / Next page**
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/columns/pagination for the active panel (status, priority, facility, date preset — not panel).
  - Condition: Always when the workbench is loaded.

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; panel primary remains when authorized.
  - Condition: Empty page.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Asset detail dialog (read + complementary writes).
  - Immediate result: Selects asset and opens detail.
  - Condition: Always when rows exist.

- **Next action** (resource-aware label)
  - Location: `next_action` column.
  - Opens modal: Action dialog when a write next-step exists; otherwise opens detail.
  - Immediate result: Starts the sole primary write for that row (e.g. start WO, close downtime, acknowledge recall) or opens detail for **Review**.
  - Condition: Write next-actions require `_writeRequirement`; unauthorized write next-actions do not render via access gate.

### Detail dialog

- **Close**
  - Location: Dialog actions.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

- **Complementary writes** (Edit asset, Transfer, Schedule maintenance, Create/Update WO, calibration, safety, downtime, incident, disposal, …)
  - Location: `AppQuickActions` on detail.
  - Opens modal: Matching action dialog.
  - Immediate result: Mutates via existing controller methods; snackbar; workbench refresh.
  - Condition: `_writeRequirement`; action omitted when it equals the row next-action kind; Start/Return WO status-gated; resource-gated close-downtime / acknowledge-recall.

- **Print report**
  - Location: Detail quick actions.
  - Opens modal: Shared print pipeline (`printFormTemplateDocument`).
  - Immediate result: Prints asset report HTML.
  - Condition: `_printRequirement` (absent when unauthorized).

Detail identity: header shows title + asset tag; Registry section does not repeat the tag. Decorative related-action badge sections were removed.

---

## Verification (Req 7)

Widget tests in `frontend/test/features/biomedical/presentation/biomedical_workspace_page_test.dart`:

- [x] Registry primary is **Register asset**; Work orders owns **Create work order**; Overview has neither create-WO nor Refresh.
- [x] Support primary is **Report fault**; Analytics has no primary; **Refresh** tooltip absent on all panels.
- [x] Queue summary tooltips (overdue PM / open WOs / critical downtime / active recalls) absent from toolbar.
- [x] Unauthorized write policy: Register / Report fault / Create work order tooltips absent.
- [x] Work-order next-action still opens **Start work order** dialog.
- [x] Row selection opens a single detail dialog without decorative related-section action labels as status badges.
- [x] Detail does not offer a separate print-preview dialog control alongside print.
- [x] Filters exclude Panel; search / deep-link / mobile tab strip still work.
