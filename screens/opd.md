# Action inventory — `/opd`

Primary surface: `OpdWorkspacePage` (`frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`).

Write gates: `opdEncounterPermissionRequirement` (start walk-in), `opdFrontDeskActionRequirement` / `opdReceptionActionRequirement` (front-desk), `opdVitalsActionRequirement`, `opdDoctorActionRequirement`, `opdBillingActionRequirement`, `opdAdmissionHandoffRequirement`. Unauthorized write controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload worklist | **Removed** — lists refresh after mutations / scaffold **Try again** |
| Row **WorkflowActionButton** (route/dialog to other modules for OPD-owned steps) | Same stage mutation | **Replaced** — stage-aware **Next action** opens the OPD mutation dialog (or department handoff) directly |
| Parallel `_OpdPatientActionsDialog` appointment hub vs shared `OpdAppointmentActionsDialog` | Check-in / reschedule / cancel | **Merged** — shared appointment hub only |
| Arrival next-action opened appointment hub then required start again | Start encounter | **Removed** intermediate hub — next-action opens encounter dialog directly |
| Continue-encounter next-action opened Flow Actions with stage primary omitted | Continue visit stage | **Removed** hub shell — next-action runs the stage mutation / handoff directly |
| Post-start Flow Actions omitted the stage primary (same as worklist omit) | Continue visit stage | **Fixed** — omit applies only to row-select hubs; post-start continuation keeps the primary |
| Queue next-action labeled **Start OPD encounter** (same as toolbar / arrivals) | Misleading parallel start | **Removed** — queue next-action is empty; row select is the sole queue-hub entry |
| Detail Quick Action matching row next-action (pay / vitals / assign doctor / review / disposition / …) | Same write | **Omitted** from Flow Actions / appointment hub via `omitNextActionKey` / `omitPrimaryAction` |
| Deep link `flowId` + `panel=` opened Flow Actions then required hunting for the action | Intermediate shell | **Removed** — focused panel opens the mutation dialog directly |
| Queue next-action button opening the same hub as row tap | Open queue actions | **Removed** — next-action is empty; row select is the sole hub entry |

---

## OPD workspace screen

### Tab strip

- **All worklist / Arrivals / Queue / Triage / Active / Follow-ups**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, clears filters/search.
  - Condition: Always when workspace loads.

- **Start OPD encounter** (primary)
  - Location: Tab-strip primary (`opdStartWalkInAction`).
  - Opens modal: Yes — encounter dialog, then Flow Actions when a visit continues.
  - Immediate result: Creates/continues OPD encounter; snackbar; workspace refresh.
  - Condition: Encounter permission; absent on Follow-ups; unauthorized control absent.

Tab-strip **Refresh** was removed.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads OPD workspace.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Client filters / search / column visibility for the active tab.
  - Condition: Worklist tabs (not Follow-ups free-text panel).

### Empty / no-results

- **Empty worklist**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; Start OPD encounter remains when authorized.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Flow Actions / Queue Actions / Appointment Actions (complementary writes).
  - Immediate result: Opens hub with stage next-action omitted when applicable.
  - Condition: Always when rows exist.

- **Next action** (stage label)
  - Location: `next_action` column (and mobile row trailing).
  - Opens modal: Matching mutation (start encounter, pay, vitals, assign doctor, doctor review, disposition, admission handoff, correct stage) or navigates for department handoff.
  - Immediate result: Persists via controller / navigates; snackbar; refresh where needed. No empty hub shell for the primary goal.
  - Condition: Matching write gate; unauthorized next-action absent. Queue rows have no next-action control (use row select).

### Arrivals tab

Check-in / arrival processing (`?section=arrivals`). Gates: `OpdArrivalsAtomPermissions` — read ∪ `patient:read` | `clinical:read`; matrix create/update/delete ∩ `clinical:write`. Start OPD keeps source `opdEncounterPermissionRequirement`; appointment hub / check-in next-action keep source `opdFrontDeskActionRequirement`. Nested cross-module rows _(n/a)_.

- **Arrivals** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to Arrivals section.
  - Condition: Read ∪; tab hidden when denied.

- **Start OPD encounter** (toolbar)
  - Location: Tab-strip primary.
  - Opens modal: Yes — encounter dialog.
  - Immediate result: Creates/continues encounter; snackbar; refresh.
  - Condition: Source encounter gate; unauthorized control absent.

- **Search**, **Clear**, **Filters**, **Settings** (columns)
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters / Table Settings when used.
  - Immediate result: Client search / filters / column visibility.
  - Condition: Read ∪; Arrivals body mounted.

- **Empty / loading / error / Try again**
  - Location: Table / scaffold body.
  - Opens modal: No.
  - Immediate result: Empty copy / spinner / retry reload.
  - Condition: Authorized read; no write affordances in empty for denied users.

- **Row select** → Appointment Actions
  - Location: Table row / mobile item.
  - Opens modal: Yes — `OpdAppointmentActionsDialog` (primary Start omitted).
  - Immediate result: Shows appointment context; write actions when front-desk allowed.
  - Condition: Read ∪; nested Reschedule / Cancel use front-desk; unauthorized writes absent.

- **Next action** (Start OPD encounter / Continue)
  - Location: `next_action` column (and mobile trailing).
  - Opens modal: Encounter dialog / stage mutation directly (no empty hub).
  - Immediate result: Persists; snackbar; refresh.
  - Condition: Source front-desk; unauthorized next-action absent.

### Queue tab

Waiting queue call-next / requeue (`?section=queue`). Gates: `OpdQueueAtomPermissions` — read ∪ `patient:read` | `clinical:read`; matrix create/update/delete ∩ `clinical:write`. Start OPD keeps source `opdEncounterPermissionRequirement`; queue hub writes (prioritize / change status / assign doctor) keep source `opdFrontDeskActionRequirement`. No row next-action (row select is the sole hub entry). Nested cross-module rows _(n/a)_.

- **Queue** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to Queue section.
  - Condition: Read ∪; tab hidden when denied.

- **Start OPD encounter** (toolbar)
  - Location: Tab-strip primary.
  - Opens modal: Yes — encounter dialog.
  - Immediate result: Creates/continues encounter; snackbar; refresh.
  - Condition: Source encounter gate; unauthorized control absent.

- **Search**, **Clear**, **Filters**, **Settings** (columns)
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters / Table Settings when used.
  - Immediate result: Client search / filters / column visibility.
  - Condition: Read ∪; Queue body mounted.

- **Empty / loading / error / Try again**
  - Location: Table / scaffold body.
  - Opens modal: No.
  - Immediate result: Empty copy / spinner / retry reload.
  - Condition: Authorized read; no write affordances in empty for denied users.

- **Row select** → Queue Actions
  - Location: Table row / mobile item.
  - Opens modal: Yes — `QueueActionsDialog` (shared hub).
  - Immediate result: Shows queue context; write actions when front-desk allowed.
  - Condition: Read ∪; nested Prioritize / Change status / Assign|Change doctor use front-desk; unauthorized writes absent. Cancel / Close only dismiss.

- **Next action**
  - Location: `next_action` column (and mobile trailing).
  - Opens modal: No — column not mounted on Queue.
  - Immediate result: N/A.
  - Condition: Always absent on Queue (inventory: row select is sole hub entry).

- **Nested prioritize / change status / assign doctor**
  - Location: Queue Actions → nested dialogs.
  - Opens modal: Text / radio / doctor-select dialogs.
  - Immediate result: Persists via controller; snackbar; list refresh.
  - Condition: Source front-desk; unauthorized entry points absent.

### Active tab

In-consultation encounters (`?section=active`). Gates: `OpdActiveAtomPermissions` — read ∪ `patient:read` | `clinical:read`; matrix create/update/delete ∩ `clinical:write`. Start OPD keeps source `opdEncounterPermissionRequirement`. Stage next-actions keep source gates (vitals / billing / reception / doctor / admission handoff). Nested cross-module matrix rows _(n/a)_ — billing payment keeps `opdBillingActionRequirement`; admission keeps `opdAdmissionHandoffRequirement`.

- **Active** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to Active section.
  - Condition: Read ∪; tab hidden when denied.

- **Start OPD encounter** (toolbar)
  - Location: Tab-strip primary.
  - Opens modal: Yes — encounter dialog, then Flow Actions when a visit continues.
  - Immediate result: Creates/continues encounter; snackbar; refresh.
  - Condition: Source encounter gate; unauthorized control absent.

- **Search**, **Clear**, **Filters**, **Settings** (columns)
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters / Table Settings when used.
  - Immediate result: Client search / filters / column visibility.
  - Condition: Read ∪; Active body mounted.

- **Empty / loading / error / Try again**
  - Location: Table / scaffold body.
  - Opens modal: No.
  - Immediate result: Empty copy / spinner / retry reload.
  - Condition: Authorized read; no write affordances in empty for denied users.

- **Row select** → Flow Actions
  - Location: Table row / mobile item.
  - Opens modal: Yes — `FlowActionsDialog` (stage next-action omitted).
  - Immediate result: Shows flow context; write actions when stage gates allow.
  - Condition: Read ∪; nested writes use source stage gates; unauthorized writes absent.

- **Next action** (Record vitals / Pay / Assign doctor / Doctor review / Disposition / Admission / Correct stage / …)
  - Location: `next_action` column (and mobile trailing).
  - Opens modal: Matching mutation dialog directly (no empty hub).
  - Immediate result: Persists via controller / navigates; snackbar; refresh.
  - Condition: Matching source write gate; unauthorized next-action absent; next-action column hidden when no stage write is allowed.

- **Deep link** `flowId` + `panel=vitals|payment|doctor|disposition|…`
  - Location: Route query on Active.
  - Opens modal: Focused mutation dialog directly.
  - Immediate result: Same as next-action; blocked silently when panel write denied.
  - Condition: Panel-specific source gate via `opdFocusedPanelRequirement`.

### Triage tab

Triage vitals/acuity (`?section=triage`). Gates: `OpdTriageAtomPermissions` — read ∪ `patient:read` | `clinical:read`; matrix create/update/delete ∩ `clinical:write`. Start OPD keeps source `opdEncounterPermissionRequirement`; Record vitals keeps source `opdVitalsActionRequirement`; Assign doctor / Correct stage keep source `opdReceptionActionRequirement`. Nested cross-module rows _(n/a)_ (billing / admission not on triage queue stages).

- **Triage** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to Triage section.
  - Condition: Read ∪; tab hidden when denied.

- **Start OPD encounter** (toolbar)
  - Location: Tab-strip primary.
  - Opens modal: Yes — encounter dialog.
  - Immediate result: Creates/continues encounter; snackbar; refresh.
  - Condition: Source encounter gate; unauthorized control absent.

- **Search**, **Clear**, **Filters** (incl. triage scope), **Settings** (columns)
  - Location: `AppListTable` chrome.
  - Opens modal: Advanced filters / Table Settings when used.
  - Immediate result: Client search / filters / column visibility.
  - Condition: Read ∪; Triage body mounted.

- **Empty / loading / error / Try again**
  - Location: Table / scaffold body.
  - Opens modal: No.
  - Immediate result: Empty copy / spinner / retry reload.
  - Condition: Authorized read; no write affordances in empty for denied users.

- **Row select** → Flow Actions
  - Location: Table row / mobile item.
  - Opens modal: Yes — `FlowActionsDialog` (stage next-action omitted).
  - Immediate result: Shows visit context; write actions when stage gates allow.
  - Condition: Read ∪; nested vitals / assign / correct-stage use source gates; unauthorized writes absent.

- **Next action** (Record vitals / Assign doctor / …)
  - Location: `next_action` column (and mobile trailing).
  - Opens modal: Matching mutation dialog directly (no empty hub).
  - Immediate result: Persists; snackbar; refresh.
  - Condition: Source vitals / reception; unauthorized next-action absent.

- **Deep link** `flowId` + `panel=vitals|doctor|…`
  - Location: Route query on Triage.
  - Opens modal: Focused mutation dialog when stage gate allows.
  - Immediate result: Opens dialog or no-ops when denied.
  - Condition: Matching source stage gate; denied panel does not mount.

### Follow-ups tab

Shared follow-up worklist (`FollowUpWorklistPanel`, OPD scope). No **Start OPD encounter** primary. Gates: `OpdFollowUpsAtomPermissions` — read ∪ `patient:read` | `clinical:read`; complete / reschedule ∩ `clinical:write`.

- **Follow-ups** strip tab / count badge
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches to Follow-ups section.
  - Condition: Read ∪; tab hidden when denied.

- **Search**, **Clear**, **Settings** (columns)
  - Location: `FollowUpWorklistPanel` / `AppListTable` chrome.
  - Opens modal: Table Settings when used.
  - Immediate result: Client search / column visibility.
  - Condition: Read ∪; Follow-ups body mounted.

- **Empty / loading / error / Try again**
  - Location: Panel body.
  - Opens modal: No.
  - Immediate result: Empty copy / spinner / retry reload.
  - Condition: Authorized read; no write affordances in empty.

- **Row select** → Follow-up details
  - Location: Table row / mobile item.
  - Opens modal: Yes — `ReceptionFollowUpDetailDialog`.
  - Immediate result: Shows patient / schedule; write actions when ∩ allowed.
  - Condition: Read ∪.

- **Mark completed** / **Reschedule follow-up** / **Save follow-up**
  - Location: Detail dialog (and nested reschedule dialog).
  - Opens modal: Reschedule opens save dialog.
  - Immediate result: Completes or updates follow-up; snackbar; list refresh.
  - Condition: Write ∩ `clinical:write`; unauthorized controls absent.

- Follow-up worklist panel (`FollowUpWorklistPanel`, OPD scope)
  - Location: Follow-ups section body.
  - Condition: Follow-ups tab selected and read ∪ allowed.

### Deep links

- **`?id=` / `?flowId=` / `?encounterId=`** — opens Flow Actions (stage next-action omitted).
- **`?id=&panel=vitals|doctor|payment|disposition|…`** — opens the focused mutation dialog directly (no empty Flow Actions shell).
- **`?section=` / `?panel=` (alone) / `?search=`** — selects tab / filters / pre-fills search.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/opd/presentation/opd_workspace_page_test.dart` prove:
  - **Refresh** is absent from the tab strip on desktop/mobile.
  - **Start OPD encounter** remains the labeled create entry (toolbar + arrival next-action); queue rows have no next-action control.
  - Arrival **Start OPD encounter** next-action skips the appointment hub; row select hub omits that primary.
  - Active **Record vitals** next-action opens the vitals dialog; Flow Actions omits that duplicate.
  - Deep link `flowId` + `panel=vitals` opens the vitals dialog without a Flow Actions shell.
  - Unauthorized users see no Start OPD encounter / Record vitals.
  - Queue row still opens the shared queue hub; cancel performs no mutation.
- Arrivals permission tests in `frontend/test/features/opd/presentation/opd_arrivals_permissions_test.dart` prove:
  - ∪ read (`patient:read` | `clinical:read`) shows Arrivals chrome; ∩ denial hides Start / next-action / hub writes.
  - Full writer presence; subscription strip without `scheduling-queue`; nested billing/admission absent without those modules.
  - Authorized empty / error-retry; mobile + desktop dark; post-mutation Start dialog; row-select hub omits Start duplicate.
- Active permission tests in `frontend/test/features/opd/presentation/opd_active_permissions_test.dart` prove:
  - ∪ read (`patient:read` | `clinical:read`) shows Active chrome; ∩ denial hides Start / Record vitals / next-action column.
  - Full writer presence; pay next-action needs billing:write + `billing-payments`; subscription strip without `scheduling-queue`; admission handoff needs inpatient module.
  - Deep link `panel=vitals` blocked for readers / opens for writers; authorized empty / error-retry; mobile + desktop dark; post-mutation vitals dialog.
- Triage permission tests in `frontend/test/features/opd/presentation/opd_triage_permissions_test.dart` prove:
  - ∪ read (`patient:read` | `clinical:read`) shows Triage chrome; ∩ / source denial hides Start / Record vitals.
  - Full writer presence; subscription strip without `scheduling-queue`; nested billing/admission absent without those modules.
  - Authorized empty / error-retry; mobile + desktop dark; post-mutation vitals dialog; deep-link `panel=vitals` gated.
- Queue permission tests in `frontend/test/features/opd/presentation/opd_queue_permissions_test.dart` prove:
  - ∪ read shows Queue chrome; ∩ denial / read-only hides Start / hub writes (Prioritize / Change status / Assign doctor).
  - Full writer presence; no next-action column; subscription strip without `scheduling-queue`; nested billing/admission absent without those modules.
  - Authorized empty / error-retry; mobile + desktop dark; post-mutation Start dialog; row-select opens Queue Actions.
- Follow-ups permission tests in `frontend/test/features/opd/presentation/opd_follow_ups_permissions_test.dart` prove:
  - ∪ read (`patient:read` | `clinical:read`) shows Follow-ups chrome; Start OPD absent; ∩ denial hides Mark completed / Reschedule / Save follow-up.
  - Full write ∩ presence; complete syncs list; subscription strip without `scheduling-queue`; nested billing/admission absent without those rights.
  - Authorized loading / empty / error-retry / validation; mobile + desktop; light + dark; deep-link without read falls off Follow-ups.
