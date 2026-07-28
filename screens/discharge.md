# Action inventory — `/discharge`

Primary surface: `DischargeWorkspacePage` (`frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`).

Write gate: `_dischargeClinicalWriteRequirement` (clinical write + inpatient-bed-management module; doctor/nurse/admin roles). Planning / finalize mutations use this gate. Print and detail browse remain available without write.

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
  - Condition: Always when workspace loads.

Tab-strip toolbar actions were removed. Queue work refreshes after mutations, realtime sync, and scaffold **Try again**.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Retries workspace load.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters (status); Table Settings dialog.
  - Immediate result: Search / status filter / column visibility for the active section.
  - Condition: Queue sections only (not Follow-ups).

### Row activation

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Discharge detail dialog (context, checklist, summary, meds, billing, timeline, print).
  - Immediate result: Loads detail; shows status-primary continue when permitted.
  - Condition: Always when rows exist.

- **Next action** (labeled primary row control)
  - Location: Next-action column.
  - Opens modal: Planning dialog (incomplete) or print flow (completed with summary).
  - Immediate result: Opens planning without an empty detail shell; completed prints when summary exists else opens detail.
  - Condition: Write gate for plan/clearance; print has no write gate; unauthorized write control absent.

### Detail dialog

- **Continue discharge** (Start plan / Finalize label by state)
  - Location: Detail patient actions (sole planning entry).
  - Opens modal: Shared `DischargePlanningDialog`.
  - Immediate result: Plans or finalizes discharge; snackbar; queue refresh.
  - Condition: Write gate; omitted when completed or unauthorized.

- **Request billing** / **Request pharmacy**
  - Location: Detail patient actions.
  - Opens modal: Billing amount form / pharmacy prescription form.
  - Immediate result: Creates billing or pharmacy request; snackbar.
  - Condition: Always when detail is open (backend auth authoritative).

- **Print discharge summary**
  - Location: Detail dialog actions.
  - Opens modal: Print flow.
  - Immediate result: Prints summary document.
  - Condition: Enabled when `detail.hasSummary`.

- **Cross-module links** (IPD / Nursing / Pharmacy / Billing / Housekeeping)
  - Location: Detail quick actions (navigation only).
  - Opens modal: No — routes to linked workspace.
  - Immediate result: Leaves discharge for the linked module.
  - Condition: Always when detail is open.

### Planning dialog (from next-action or detail primary)

- **Save plan** / **Finalize discharge** (+ Cancel / Refresh)
  - Location: Planning dialog actions.
  - Opens modal: N/A (already open).
  - Immediate result: Persists plan or finalizes after clearance sync; closes on success.
  - Condition: Validation + blockers / override; backend auth.

### Follow-ups tab

- Follow-up worklist panel (`FollowUpWorklistPanel`, IPD scope)
  - Location: Follow-ups section body.
  - Condition: Follow-ups tab selected.

---

## Manual checks (Req 7)

- [ ] Tab strip has no Refresh / Start plan / Manage clearance / Print toolbar controls.
- [ ] Next action on an unplanned row opens planning directly (no prior detail shell).
- [ ] Next action on a planned row opens planning (clearance / finalize) directly.
- [ ] Next action on a completed row with summary starts print.
- [ ] Row select opens detail; detail shows one continue primary (not three planning buttons).
- [ ] Without clinical write, next-action plan/clearance and detail continue are absent; print still available on completed.
- [ ] After save/finalize, queue refreshes and success snackbar appears.
- [ ] Loading / empty / error-retry / validation states still render on workspace and planning dialog.
- [ ] Mobile and desktop layouts keep next-action and row select reachable; theme tokens only.
