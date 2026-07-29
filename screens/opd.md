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
