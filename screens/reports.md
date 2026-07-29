# Action inventory — `/reports`

Primary surface: `ReportsWorkspacePage` (`frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`).

Access helpers: `frontend/lib/features/reports/presentation/reports_access.dart`.

| Atom class | Requirement helper | Keys |
| --- | --- | --- |
| Workspace / catalog panels / schedules / timeline | `reportsCatalogReadRequirement` / `canReadReportsCatalog` | ∪ `reports:read` (+ admin overlay) |
| Compliance panels (audit / PHI / processing) | `reportsComplianceReadRequirement` / `canReadReportsCompliance` | ∪ `compliance:read`, `compliance:review` (+ admin) |
| Route entry | `reportsWorkspaceReadRequirement` / route any-of | ∪ `reports:read`, `compliance:read` |
| Run / Schedule / Retry / Cancel | `reportsWriteRequirement` / `canWriteReports` | ∩ `reports:write` (+ admin overlay per inventory) |
| Download / Print / Export evidence | `reportsExportRequirement` / `canExportEvidence` | ∪ `evidence:export` (+ admin; not `reports:write`) |
| Hard delete (no UI on this tab yet) | `reportsDeleteRequirement` / `canDeleteReports` | ∩ `reports:delete` (+ admin overlay) |

Write gate (client): `canWriteReports` for run / schedule / retry / cancel. Export gate: `canExportEvidence`. Unauthorized write/export controls do not render. Backend auth remains authoritative. Module: `reporting-analytics`.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Toolbar **Run report** (when definition selected) | Same as row **Next action** Run | **Removed** — next-action is the sole Run entry |
| Toolbar **Refresh** | Reload workspace | **Removed** — mutations refresh; load failures use scaffold / inline **Try again** |
| Toolbar summary chips (Catalog / Audit / queue counts) | Same as Filters → Panel | **Removed** — Filters → Panel is the sole panel entry |
| Side **detail** rail (`AppWorkspace.detail`) mirroring dialog preview + actions | Same as row-select dialog | **Removed** — detail dialog is the sole preview / complementary-action surface |
| Detail action matching row **Next action** (Run / Schedule / Retry / Cancel / Download / Export evidence) | Same write / export | **Omitted** from detail; next-action remains primary |
| Next-action **Report preview** button (no mutation) | Same as row select | **Removed** — preview-only rows show no next-action button; row select opens detail |
| Schedules table **Search** sharing primary search controller | Same workspace search | **Removed** — primary worklist Search / Filters own search |

---

## Reports workspace screen

### Page chrome

- No screen-specific toolbar (no Run, Refresh, or summary chips).

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` / `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (panel / status / format / dataset / date), **Settings** (columns), pagination
  - Location: Primary `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Server search / filters / column visibility for the active panel.
  - Condition: Always when workspace is loaded.
  - Panel focus: Filters → Panel is the sole labeled panel entry.

### Empty / no-results

- **Empty worklist / schedules / compliance**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy for current panel / filters.
  - Condition: No rows after panel / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item (items, schedules, compliance).
  - Opens modal: Report preview or Compliance detail dialog.
  - Immediate result: Selects item and opens detail; sole open path into detail.
  - Condition: Always when rows exist.

- **Next action** (capability-aware label)
  - Location: `next_action` column (always visible on desktop).
  - Opens modal: Run / Schedule / Retry / Cancel confirm / Download / Export evidence when that is next; absent when preview-only.
  - Immediate result: Sole primary mutation / export for the row.
  - Condition: Matching write or export gate; unauthorized next-actions absent.

### Detail dialog (report)

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Complementary actions** (Schedule when next is Run; Print; other non-next writes)
  - Location: Detail action wrap.
  - Opens modal: Matching action dialog / print flow.
  - Immediate result: Mutates via controller or prints; snackbar where applicable.
  - Condition: Write / export gates; action omitted when it equals the row next-action; unauthorized controls absent.

### Detail dialog (compliance)

- **Print** (when export authorized)
  - Location: Detail actions.
  - Immediate result: Prints compliance evidence.
  - Condition: Export gate; Export evidence omitted when it is the row next-action.

### Nested dialogs

- **Run / Retry** — format, retention days.
- **Schedule** — name, cron/frequency, format, recipients.
- **Cancel run** — confirm destructive cancel.
- **Export evidence** — confirm then print compliance item.

### Schedules panel

- Lists delivery schedules under non-compliance panels; row select and next-action follow the same rules; no duplicate search bar.

### Timeline

- Progressive disclosure of recent activity (non-compliance panels); read-only.

---

## Manual checks (Req 7)

- [ ] Workspace has no Refresh, no toolbar Run, and no summary Catalog/Audit chips.
- [ ] Filters → Panel still switches Catalog / Delivery / Audit / etc.
- [ ] Next action on a definition opens Run report (not detail first).
- [ ] Row select opens Report preview; detail does not also show Run report when that is next-action.
- [ ] Preview-only rows have no Next action button; row select still opens detail.
- [ ] Schedules panel has no second Search field.
- [ ] Without write capability, Run / Schedule next-actions are absent; without export, Print / Export evidence are absent.
- [ ] After mutations, snackbar + refreshed workspace; loading / empty / error-retry / validation still render.

Automated: `frontend/test/features/reports/presentation/reports_workspace_page_test.dart`, `frontend/test/features/reports/presentation/reports_workspace_ux_simplify_test.dart`, `frontend/test/features/reports/presentation/reports_access_test.dart`, `frontend/test/features/reports/presentation/reports_workspace_permissions_test.dart`.
