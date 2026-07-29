# Action inventory — `/lab`

Primary surface: `LabWorkspacePage` (`frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`).

Write gate: `labWrite` with active module `lab-workflows` (`_mutationRequirement` / `Lab*AtomPermissions.write`). Unauthorized write controls do not render (`AppAccessActionGate` / `canMutate`). Per-tab atom maps include `LabAllAtomPermissions`, `LabAwaitingResultsAtomPermissions`, `LabFollowUpsAtomPermissions`. Backend auth remains authoritative.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload worklist | **Removed** — mutations / realtime / adaptive poll / scaffold **Try again** |
| Rotating primary (**Create** vs **Lab Configurations** by tab) | Same goals | **Merged** — stable **Create Lab Order** primary + **Lab Configurations** secondary on every worklist tab |
| Row **WorkflowActionButton** (route-only back to `/lab`) | Select order without opening work | **Removed** — stage-labeled **Next action** opens result entry directly |
| Deep link `orderId` / `encounterId` only selected order | Intermediate shell; hunt for row | **Removed** — deep link opens result entry dialog |
| Detail footer **Edit** / **Delete** + order-section **Edit** / **Delete** | Same writes | **Removed** from footer — order section is the sole edit/delete entry |
| Collect / Receive **confirm** dialogs | Restate choice; no required input | **Removed** — mutate directly; reverse still requires reason |
| Disabled **billing gate** stepper action | No-op chrome | **Removed** — help text already states await payment |
| Unused `_ReverseWorkflowDialog` parallel to `AppTextActionDialog` | Same reverse write | **Removed** — progress section dialog only |

---

## Lab workspace screen

### Tab strip

- **All / Awaiting results / Processing / Pending verification / Critical / Verified / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, applies queue scope (non–Follow-ups). Follow-ups shows `FollowUpWorklistPanel`.
  - Condition: Always when workspace loads.
  - Counts: Summary counts per section / Follow-ups from `followUpTabCountProvider`.

- **Create Lab Order** (primary)
  - Location: Tab-strip primary on every non–Follow-ups tab.
  - Opens modal: Yes — create lab order dialog.
  - Immediate result: Creates order; worklist refresh.
  - Condition: Write; unauthorized control absent; Follow-ups has no strip primary.

- **Orders view / Patients view** (secondary)
  - Location: Tab-strip secondary.
  - Opens modal: No.
  - Immediate result: Toggles `LabWorkbenchView`.
  - Condition: Non–Follow-ups tabs.

- **Lab Configurations** (secondary)
  - Location: Tab-strip secondary on every non–Follow-ups tab.
  - Opens modal: Yes — facility catalog / reference ranges dialog.
  - Immediate result: Browse/enable catalog tests & panels; optional QC log.
  - Condition: Write; unauthorized control absent.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads lab workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (payment / status), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters; Table Settings.
  - Immediate result: Client filters / search / column visibility for the active tab.
  - Condition: Worklist sections (not Follow-ups).

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; **Create Lab Order** remains when authorized.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: **Lab result entry** (`LabResultEntryDialog`).
  - Immediate result: Loads workflow(s); complementary writes + result entry.
  - Condition: Always when rows exist.

- **Next action** (status-aware label)
  - Location: `next_action` column (always visible).
  - Opens modal: Same result entry dialog (no empty intermediate shell).
  - Immediate result: Sole labeled row path into collect / receive / enter / verify work.
  - Condition: Activatable for non-terminal statuses; **Cancelled** / **Completed** show text only.

### Result entry dialog

- **Close**
  - Location: Dialog chrome.
  - Opens modal: No.
  - Immediate result: Dismisses detail.

- **Preview report**
  - Location: Dialog footer.
  - Opens modal: Print preview / print flow.
  - Immediate result: Preview/print released results when eligible.
  - Condition: When workflows loaded.

- **Create Lab Order** (additional for same patient)
  - Location: Dialog footer when a single workflow is selected and write allowed.
  - Opens modal: Additional order dialog prefilled from the open order.
  - Immediate result: Creates another order for the patient.
  - Condition: Write; single-workflow selection.

- **Edit order** / **Delete order**
  - Location: Order section panel actions only (not footer).
  - Opens modal: Edit form / delete confirm.
  - Immediate result: Updates or deletes the order; syncs selection.
  - Condition: Write.

- **Workflow stepper** (Collect / Receive / Verify / Reverse)
  - Location: `LabWorkflowProgressSection` when one workflow is open.
  - Opens modal: Reverse requires reason; Collect/Receive mutate directly.
  - Immediate result: Advances sample/result workflow; snackbar on failure.
  - Condition: Write + backend `nextActions` capabilities; unauthorized / unavailable actions absent.

- **Bulk / per-item result actions** (save draft, submit, verify, reject, remove, delete item/panel)
  - Location: Bulk bar + item row actions.
  - Opens modal: Reject / delete confirm when destructive or reason required.
  - Immediate result: Persists results; validation banners; sync after mutations.
  - Condition: Write + item capabilities.

### Deep links

- **`?orderId=` / `?encounterId=`** — opens result entry for the matching row (no select-only shell).
- **`?section=` / `?search=`** — selects tab / pre-fills search.

### All tab (`?section=all|worklist`)

Default full worklist (`LabQueueScope.all`). Strip **Create Lab Order** /
**Lab Configurations** use `LabAllAtomPermissions.create` / `.configure`
(∩ `lab:write` + `lab-workflows`). Read chrome / row select / next-action use
∩ `lab:read`. Nested result-entry writes reuse `canWriteLab` /
`LabAllAtomPermissions` write atoms; preview is ∪ `lab:read`|`lab:write`.
Readers with only `clinical:read` keep the All strip via route-entry ∪ but
must not see create/config. Tests:
`frontend/test/features/lab/presentation/lab_all_permissions_test.dart`.

### Follow-ups tab (`FollowUpWorklistPanel`)

Reachable only when Follow-ups strip tab is selected (`?section=follow-ups`). Hosted via
`FollowUpWorklistPanel` (hospital-wide scope, `lab_follow_ups_*` storage keys) with
`LabFollowUpsAtomPermissions.tab` / `.write` (`lab:read` ∩ / `lab:write` ∩ + `lab-workflows`).
No Create Lab Order, Lab Configurations, or Orders↔Patients strip actions. Nested result-entry /
configurations / critical-notify UI is **not** opened from this tab. Route entry ∪
(`lab:read` | `clinical:read` | `clinical:write`) may open `/lab` without Follow-ups tab when
`lab:read` is missing. Tests: `frontend/test/features/lab/presentation/lab_follow_ups_permissions_test.dart`.

- **Follow-ups** (strip tab + scoped count)
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to follow-ups section; loads scheduled follow-ups worklist.
  - Condition: `LabFollowUpsAtomPermissions.tab` (∩ `lab:read` + `lab-workflows`); hidden from strip otherwise.

- **Search** / search clear / **Settings** (columns)
  - Location: Follow-ups `AppListTable` chrome.
  - Opens modal: Table Settings when Settings used.
  - Immediate result: Client search / column visibility for scheduled follow-ups.
  - Condition: Follow-ups read ∩; when entries exist.

- **Empty / loading / error / Try again**
  - Location: Follow-ups body / `AppStateView`.
  - Opens modal: No.
  - Immediate result: Empty copy; spinner; retry reloads scoped list.
  - Condition: Authorized Follow-ups readers.

- **Row select**
  - Location: Follow-ups table / mobile row.
  - Opens modal: Yes — **Follow-up details** (`ReceptionFollowUpDetailDialog`).
  - Immediate result: Opens detail; refreshes list if changed.
  - Condition: Follow-ups read ∩.

#### Follow-up details dialog

- **Reschedule follow-up** / **Mark completed**
  - Location: Dialog footer.
  - Opens modal: Reschedule opens nested **Save follow-up** form; Mark completed mutates directly.
  - Immediate result: Updates or completes follow-up; list syncs on success.
  - Condition: Write ∩ `lab:write`; absent when not allowed (not disabled).

- **Close**
  - Location: Dialog footer (read-only path).
  - Opens modal: No.
  - Immediate result: Dismisses detail.
  - Condition: Shown instead of write actions when write is not allowed.

### Manual checks (Req 7)

- [ ] Unauthorized user: Create, Configurations, and dialog write actions absent; view toggle remains.
- [ ] All (`?section=all`): lab:read alone omits create/config/detail writes; full lab:write ∩ mounts them; clinical-only route entry keeps All without create.
- [ ] Every worklist tab: one **Create Lab Order** primary and one **Lab Configurations** secondary; no Refresh.
- [ ] Ordered row **Next action** opens result entry; Collect runs without a confirm shell.
- [ ] Deep link `/lab?orderId=…` opens result entry without hunting the row.
- [ ] Single-order detail: Edit/Delete appear once (order section), not also in the footer.
- [ ] Loading / empty / validation / error snackbars still surface on simplified paths.
- [ ] Follow-ups: without `lab:read` (or without `lab-workflows`), tab and panel absent; with `lab:read` alone, list mounts and Mark completed / Reschedule absent; with `lab:write` ∩, mutations mount and sync the list; clinical-only route entry keeps worklist tabs but omits Follow-ups.
