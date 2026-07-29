# Action inventory — `/biomedical`

Primary surface: `BiomedicalWorkspacePage` (`frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`).

Write gate: `biomedicalWriteRequirement` (`biomedWrite` or `operationsWrite` + `biomedical-engineering-suite`). Print gate: `biomedicalExportRequirement` / `biomedicalPrintRequirement` (`evidenceExport` + biomed/operations read or write + module). Analytics tab gate: `biomedicalAnalyticsTabRequirement` (`biomed:read` ∩ + `reports:read` ∪ + module). Unauthorized write / print / Analytics controls do not render.

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
  - Condition: Workspace entry (`biomed:read` ∪ `biomed:write` + module). **Analytics** additionally requires nested `reports:read` (∪) via `biomedicalAnalyticsTabRequirement`; unauthorized Analytics tab does not mount.
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

Registry permission tests in `frontend/test/features/biomedical/presentation/biomedical_registry_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits Register asset / detail writes / print; Filters/list chrome remain.
- [x] Source write ∪: `operations:write` (+ facilities module) mounts Register / Edit; print needs `evidence:export`.
- [x] Route entry ∪ without tab read ∩ omits Registry chrome; subscription strip without module denies.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; nested writes still mount.
- [x] Authorized Register / Edit mutations sync; Register validation keeps dialog open.
- [x] Empty / loading→success / error-retry, mobile+desktop, light+dark authorized states.

Analytics permission tests in `frontend/test/features/biomedical/presentation/biomedical_analytics_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without `reports:read` omits Analytics tab.
- [x] Nested ∪: `reports:read` (+ module) restores Analytics; subscription strip without biomed/reporting modules denies.
- [x] Write ∪ source gate: `operations:write` (+ facilities module) mounts detail writes/print without `biomed:write`.
- [x] Read-only omits mutation/print atoms; Filters / Location list chrome remain when authorized.
- [x] Nested export: print absent without `evidence:export`; nested writes still mount.
- [x] Route entry ∪ write-only without `biomed:read` omits Analytics chrome (even with `reports:read`).
- [x] Authorized flows, empty/loading/error-retry states, mobile+dark / desktop+light, post-mutation sync.

Support permission tests in `frontend/test/features/biomedical/presentation/biomedical_support_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits **Report fault** and detail mutation/print atoms; Filters/list chrome remain.
- [x] Full write ∩ / source ∪: Report fault, detail writes (Log incident), print mount.
- [x] Write ∪: `operations:write` (+ facilities-maintenance) mounts Report fault / nested writes without `biomed:write`.
- [x] Route entry ∪ write-only omits Support chrome; subscription strip without biomed module omits Support.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; Support writes still mount.
- [x] Authorized Report fault sync; Log incident nested dialog; Report fault validation keeps dialog open.
- [x] Empty (read omits primary / write keeps Report fault) / loading→success / error-retry, mobile+desktop, light+dark.

Work orders permission tests in `frontend/test/features/biomedical/presentation/biomedical_work_orders_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits Create work order / write next-actions / detail writes.
- [x] Full write ∩ / source ∪: Create WO, Work order follow-up next-action, detail writes, print mount.
- [x] Write ∪: `operations:write` (+ facilities-maintenance) mounts write atoms without `biomed:write`.
- [x] Route entry ∪ write-only omits tab chrome; subscription strip without biomed module omits Work orders.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; WO writes still mount.
- [x] IN_PROGRESS: Return to service next-action ∩ denial / write ∪ presence; omitted from detail when next-action.
- [x] Authorized Create WO dialog, validation (required fields), start-WO mutation sync.
- [x] Empty / error-retry / loading→success, mobile+desktop, light+dark.

Overview permission tests in `frontend/test/features/biomedical/presentation/biomedical_overview_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits write next-actions / detail writes / create primaries / print.
- [x] Full write ∩ / source ∪: Work order follow-up next-action, detail writes, print mount; no Overview create primary.
- [x] Write ∪: `operations:write` (+ facilities-maintenance) mounts Overview write atoms without `biomed:write`.
- [x] Route entry ∪ write-only omits Overview chrome; subscription strip without biomed module omits Overview.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; nested writes still mount.
- [x] Authorized next-action mutation sync; empty/loading/error, mobile+desktop, light+dark.

Compliance permission tests in `frontend/test/features/biomedical/presentation/biomedical_compliance_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits **Record calibration** / write next-actions / detail writes / print.
- [x] Full write ∩ / source ∪: Record calibration, Review compliance next-action, detail writes, print mount.
- [x] Write ∪: `operations:write` (+ facilities-maintenance) mounts Compliance write atoms without `biomed:write`.
- [x] Route entry ∪ write-only omits Compliance chrome; subscription strip without biomed module omits Compliance.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; recall/calibration writes still mount.
- [x] Authorized calibration next-action mutation sync; Record calibration validation keeps dialog open.
- [x] Empty / loading→success / error-retry, mobile+desktop, light+dark authorized states.

Preventive permission tests in `frontend/test/features/biomedical/presentation/biomedical_preventive_permissions_test.dart`:

- [x] ∩ denial: `biomed:read` without write omits **Schedule maintenance** / Perform maintenance next-action / detail writes / print; Filters/list chrome remain.
- [x] Full write ∩ / source ∪: Schedule maintenance, Perform maintenance next-action, detail writes, print mount.
- [x] Write ∪: `operations:write` (+ facilities-maintenance) mounts Preventive write atoms without `biomed:write`.
- [x] Route entry ∪ write-only omits Preventive chrome; subscription strip without biomed module omits Preventive.
- [x] Nested cross-module _(n/a)_: print absent without `evidence:export`; PM writes still mount.
- [x] Authorized Perform maintenance mutation sync; Schedule maintenance validation keeps dialog open.
- [x] Empty / loading→success / error-retry, mobile+desktop, light+dark authorized states.
