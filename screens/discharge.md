# Action inventory — `/discharge`

Primary surface: `DischargeWorkspacePage` (`frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`).

Write gate: `dischargeClinicalWriteRequirement` (source: role pack ∪ + `clinical:write` + `inpatient-bed-management`; matrix create/update/delete ∩ `clinical:write`). Planning / finalize / request mutations use this gate. Print and detail browse remain available without write when the tab read ∪ allows.

Atom maps: `DischargeAllPatientsAtomPermissions`, `DischargePlannedAtomPermissions`, `DischargePendingClearanceAtomPermissions`, `DischargeCompletedAtomPermissions`, `DischargeFollowUpsAtomPermissions` in `discharge_access.dart`. Tab strip uses `dischargeAllowedSections` / `dischargeSectionTabRequirement`.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload queue | **Removed** — queue refreshes after mutations / realtime / scaffold retry |
| Tab-strip **Start plan** / **Manage clearance** / **Print** (first-or-selected row) | Open detail and/or planning / print | **Removed** — **Next action** is the labeled minimal path; row select opens detail |
| Tab primary → detail dialog → planning (`openClearance`) | Same planning dialog | **Removed** intermediate detail shell — next-action opens planning directly |
| Detail **Start/Edit summary** + **Manage clearance** + **Complete discharge** | All opened the same planning dialog | **Merged** — one status-primary continue action (+ billing / pharmacy requests) |
| Clearance **stepper** + **tile grid** (detail + planning) | Same checklist state | **Merged** — stepper only |
| Row **WorkflowActionButton** routing back to `/discharge` | Deep-link to detail | **Replaced** — in-page next-action opens planning (or print when completed) |

---

## Discharge workspace screen

### Tab strip

- **All patients / Planned / Pending clearance / Completed / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, filters rows.
  - Condition: Each tab mounts only when its `*AtomPermissions.tab` read requirement allows; unauthorized tabs omitted. Empty strip when no section is allowed.

Tab-strip toolbar actions were removed. Queue work refreshes after mutations, realtime sync, and scaffold **Try again**.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure; same as active section read ∪.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (status); Table Settings dialog.
  - Immediate result: Search / status filter / column visibility for the active section.
  - Condition: Queue sections only (not Follow-ups); section read ∪ (e.g. Planned → `DischargePlannedAtomPermissions.listChrome`).

### Row activation

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Discharge detail dialog (context, checklist, summary, meds, billing, timeline, print).
  - Immediate result: Loads detail; shows status-primary continue when permitted.
  - Condition: Section read ∪; rows exist.

- **Next action** (labeled primary row control)
  - Location: Next-action column / mobile trailing.
  - Opens modal: Planning dialog (incomplete) or print flow (completed with summary).
  - Immediate result: Opens planning without an empty detail shell; completed prints when summary exists else opens detail.
  - Condition: Section-aware atom map — All → `DischargeAllPatientsAtomPermissions.nextAction*`; Planned → `nextActionClearance`; pending → `nextActionPlan`; completed → `nextActionPrint`. Unauthorized write control absent (no disabled stub).

### Detail dialog

- **Continue discharge** (Start plan / Finalize label by state)
  - Location: Detail patient actions (sole planning entry).
  - Opens modal: Shared `DischargePlanningDialog`.
  - Immediate result: Plans or finalizes discharge; snackbar; queue refresh.
  - Condition: Write source ∩ (`continueDischarge`); omitted when completed or unauthorized.

- **Request billing** / **Request pharmacy**
  - Location: Detail patient actions.
  - Opens modal: Billing amount form / pharmacy prescription form.
  - Immediate result: Creates billing or pharmacy request; snackbar; queue refresh.
  - Condition: Write source ∩ (`requestBilling` / `requestPharmacy`); unauthorized actions absent.

- **Print discharge summary**
  - Location: Detail dialog actions.
  - Opens modal: Print flow.
  - Immediate result: Prints summary document.
  - Condition: Section read ∪ (`printSummary`); enabled when `detail.hasSummary`.

- **Clearance checklist / meds / bills panels**
  - Location: Detail body (stepper + related records).
  - Opens modal: No.
  - Immediate result: Shows permission-filtered clearance steps and nested panels.
  - Condition: Union across sections, ∩ within section — pharmacy:read (meds), billing:read (bills), operations:read (room turnover); clinical/last_office steps use workspace read ∪. Empty filtered checklist collapses.

- **Cross-module links** (IPD / Nursing / Pharmacy / Billing / Housekeeping)
  - Location: Detail quick actions (navigation only).
  - Opens modal: No — routes to linked workspace.
  - Immediate result: Leaves discharge for the linked module.
  - Condition: Per-link navigate gates (`openIpd` ∪ / `openNursing` ∩ last_office / `openPharmacy` ∩ pharmacy / `openBilling` ∩ billing / `openHousekeeping` ∩ operations). Section collapses when all links filtered.

### Planning dialog (from next-action or detail primary)

- **Save plan** / **Finalize discharge** (+ Cancel / Refresh)
  - Location: Planning dialog actions.
  - Opens modal: N/A (already open).
  - Immediate result: Persists plan or finalizes after clearance sync; closes on success; snackbar; queue refresh.
  - Condition: Write source ∩ (`DischargeAllPatientsAtomPermissions.create` / `update` ≡ `dischargeClinicalWriteRequirement`); validation + blockers / override; nested clearance panels use same ∩ reads as detail. Unauthorized save/finalize absent.

### Planned tab

Reachable when Planned strip tab is selected (`?section=planned`). Rows are planned discharges; next-action is **Manage clearance**. Nested detail / planning / billing / pharmacy UI opens from this tab only via row select or next-action.

- **Planned** (strip tab + count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Filters queue to planned discharges.
  - Condition: Read ∪ `clinical:read` | `last_office:read` + `inpatient-bed-management` (`DischargePlannedAtomPermissions.tab`); omitted otherwise.

- **Search / Filters / Settings (columns)** / empty / loading / error / **Try again**
  - Location: Planned `AppListTable` chrome / scaffold.
  - Condition: Same read ∪ as the tab.

- **Row select** → detail; **Manage clearance** next-action → planning
  - Condition: Read ∪ for detail; write source ∩ for Manage clearance / Continue / Request billing|pharmacy / Save|Finalize. Nested meds/bills/room-turnover and cross-links as above. Route entry keeps catalog ∩ `discharge:read` (not prompt module-read ∪).

Helpers: `DischargePlannedAtomPermissions`, `canViewDischargePlanned`. Widget tests: `frontend/test/features/discharge/presentation/discharge_planned_permissions_test.dart`.

### All patients tab (`?section=all`)

Reachable when All patients strip tab is selected (default). Nested planning /
clearance / billing / pharmacy / print UI is opened from this tab via row next-
action or detail.

- **All patients** (strip tab + count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Filters queue to all discharge candidates.
  - Condition: Read ∪ `clinical:read` | `last_office:read` + `inpatient-bed-management`; tab omitted otherwise.

- **Search / Clear / Filters / Settings (columns)**
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Search / status filter / column visibility.
  - Condition: Same read ∪ as the tab.

- **Empty / loading / error / Try again**
  - Location: Table / `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Authorized chrome states; retry reloads queue.
  - Condition: Same read ∪.

- **Row select** → Discharge detail
  - Location: Table row / mobile list item.
  - Opens modal: Detail dialog.
  - Immediate result: Context, checklist (permission-filtered steps), summary, gated meds/bills panels, timeline, print.
  - Condition: Same read ∪.

- **Next action** (Start plan / Manage clearance / Print)
  - Location: Next-action column / mobile trailing.
  - Opens modal: Planning (incomplete) or print (completed with summary).
  - Immediate result: Opens planning without empty detail shell; completed prints when summary exists else opens detail.
  - Condition: Write source ∩ for plan/clearance (`clinical:write` + roles + module); print uses read ∪; unauthorized write control absent.

- **Detail Continue / Request billing / Request pharmacy**
  - Location: Detail patient actions.
  - Opens modal: Planning / billing amount / pharmacy prescription.
  - Immediate result: Mutates; snackbar; queue refresh.
  - Condition: Write source ∩; Continue omitted when completed or unauthorized.

- **Detail Print / cross-module links / clearance panels**
  - Location: Detail chrome.
  - Opens modal: Print flow (print); navigation only for links.
  - Immediate result: Print summary; leave to linked module; show meds/bills only with pharmacy:read / billing:read ∩; room-turnover steps need operations:read ∩.
  - Condition: Print = read ∪; Open Nursing = last_office:read ∩; Open Pharmacy/Billing/Housekeeping = domain read ∩; Open IPD = read ∪.

Helpers: `DischargeAllPatientsAtomPermissions`, `canViewDischargeAll`. Widget tests: `frontend/test/features/discharge/presentation/discharge_all_patients_permissions_test.dart`.

### Pending clearance tab

Reachable when Pending clearance strip tab is selected (`?section=pending` / `pending-clearance`). Multi-department clearance desk.

- **Pending clearance** (strip tab + count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Filters queue to non-planned, non-completed rows; mounts list chrome.
  - Condition: Read ∪ `clinical:read` | `pharmacy:read` | `billing:read` | `operations:read` | `last_office:read` + `inpatient-bed-management`; tab omitted otherwise.

- **Search / Filters / Settings (columns)**
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Search / status filter / column visibility for pending clearance.
  - Condition: Same pending read ∪.

- **Empty / loading / error / Try again**
  - Location: Table body / `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Authorized chrome states; retry reloads queue.
  - Condition: Same pending read ∪.

- **Row select** → Discharge detail
  - Location: Table row / mobile list item.
  - Opens modal: Discharge detail (checklist, summary, meds, billing, timeline, print).
  - Immediate result: Loads detail; status-primary continue when write permitted.
  - Condition: Same pending read ∪.

- **Next action Start plan**
  - Location: Next-action column.
  - Opens modal: `DischargePlanningDialog`.
  - Immediate result: Opens planning without empty detail shell.
  - Condition: Write source ∩ roles + `clinical:write` + module; unauthorized control absent.

- **Detail Continue / Request billing / Request pharmacy / Print**
  - Location: Detail patient actions / dialog actions.
  - Opens modal: Planning / billing amount / pharmacy form / print flow.
  - Immediate result: Mutates or prints; snackbar; queue refresh after mutations.
  - Condition: Continue + requests use write source ∩; Print uses pending read ∪ (no write).

- **Detail clearance checklist sections**
  - Location: Detail stepper (and planning checklist).
  - Opens modal: No.
  - Immediate result: Shows only domain steps the user may read; panel collapses when empty.
  - Condition: ∩ within section — `pharmacy:read` meds, `billing:read` bills, `operations:read` bed/housekeeping; doctor/nursing/documents use workspace read ∪ `clinical:read` | `last_office:read`.

- **Detail cross-module links**
  - Location: Detail quick actions.
  - Opens modal: No — routes away.
  - Immediate result: Opens linked workspace when permitted.
  - Condition: IPD → workspace read ∪; Nursing → `last_office:read`; Pharmacy → `pharmacy:read`; Billing → `billing:read`; Housekeeping → `operations:read`.

- **Planning Save plan / Finalize**
  - Location: Planning dialog actions (from next-action or detail continue).
  - Opens modal: N/A (already open).
  - Immediate result: Persists plan or finalizes; closes on success; queue refresh.
  - Condition: Write source ∩; Cancel / Refresh remain for authorized dialog openers.

Helpers: `DischargePendingClearanceAtomPermissions`, `canViewDischargePendingClearance`, `dischargeDetailPrintRequirement`. Widget tests: `frontend/test/features/discharge/presentation/discharge_pending_clearance_permissions_test.dart`.

### Follow-ups tab

Reachable only when Follow-ups strip tab is selected (`?section=follow-ups`). Nested planning / clearance / billing / pharmacy UI is **not** opened from this tab.

- **Follow-ups** (strip tab + count)
  - Location: `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Mounts IPD-scoped `FollowUpWorklistPanel`.
  - Condition: Read ∪ `clinical:read` | `last_office:read` + `inpatient-bed-management`; tab omitted otherwise.

- **Search / Clear / Settings (columns)**
  - Location: Follow-ups `AppListTable` chrome.
  - Opens modal: Table Settings.
  - Immediate result: Filters / column visibility for scheduled follow-ups.
  - Condition: Same read ∪ as the tab.

- **Empty / loading / error / Try again**
  - Location: Panel body / `AppStateView`.
  - Opens modal: No.
  - Immediate result: Authorized chrome states; retry reloads list.
  - Condition: Same read ∪.

- **Row select** → Follow-up details
  - Location: Table row / mobile item.
  - Opens modal: Shared reception follow-up detail dialog (write requirement overridden by discharge).
  - Immediate result: Shows patient + schedule; Close only when write denied.
  - Condition: Same read ∪.

- **Reschedule follow-up** / **Mark completed**
  - Location: Detail dialog actions.
  - Opens modal: Reschedule opens Save follow-up dialog; complete mutates then closes.
  - Immediate result: Updates follow-up; list refresh; empty state when none remain.
  - Condition: Write ∩ `clinical:write` + module; unauthorized actions absent (no disabled stubs).

- **Save follow-up** (nested reschedule dialog)
  - Location: Reschedule dialog actions.
  - Opens modal: N/A (already open).
  - Immediate result: Persists new schedule; closes on success.
  - Condition: Same write ∩.

---

## Manual checks (Req 7)

- [ ] Tab strip has no Refresh / Start plan / Manage clearance / Print toolbar controls.
- [ ] Next action on an unplanned row opens planning directly (no prior detail shell).
- [ ] Next action on a planned row opens planning (clearance / finalize) directly.
- [ ] Next action on a completed row with summary starts print.
- [ ] Row select opens detail; detail shows one continue primary (not three planning buttons).
- [ ] Without clinical write, next-action plan/clearance and detail continue / request billing|pharmacy are absent; print still available when read ∪ allows.
- [ ] Without pharmacy/billing/operations read, nested meds/bills/room-turnover panels and matching cross-links are absent on Planned detail.
- [ ] Planned tab omitted without `clinical:read` | `last_office:read` (or without inpatient module).
- [ ] Pending clearance: pharmacy/billing/operations-only users see the tab and their nested sections only; All/Planned/Completed omitted without clinical|last_office read.
- [ ] Pending clearance: without clinical write, Start plan and detail mutations are absent; print uses pending read ∪ via `dischargeDetailPrintRequirement`.
- [ ] After save/finalize / request billing, queue refreshes and success snackbar appears.
- [ ] Loading / empty / error-retry / validation states still render on workspace and planning dialog.
- [ ] Mobile and desktop layouts keep next-action and row select reachable; light + dark; theme tokens only.
- [x] Planned permission widget tests: `discharge_planned_permissions_test.dart` (∩ denial, ∪ allowance, nested, subscription, sync, viewports, themes).
- [x] Pending clearance permission widget tests: `discharge_pending_clearance_permissions_test.dart` (∩ denial, ∪ allowance, nested, subscription, sync, viewports, themes).
