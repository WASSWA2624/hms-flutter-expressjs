# Action inventory — `/hr`

Primary surface: `HrWorkspacePage` (`frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`).

Write gates: `hrWriteRequirement` (staff / leave / access mutations), `hrRosterWriteRequirement` / `hrRosterApproveRequirement` / `hrRosterPublishRequirement` (roster & shifts), `hrPayrollRequirement` (payroll; also needs `financialApprove`). Access panel writes use `canWriteHrAccess` (`hrWrite`). Unauthorized controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Access tab primary **Manage users and roles** → access dialog | Same embedded Access panel | **Removed** — create actions live on the embedded panel |
| Payroll tab primary **Run payroll** (first/selected staff) | Start payroll for a guessed staff | **Removed** — sole path is staff detail **Run payroll** |
| Tab-strip **Refresh** | Reload workspace | **Removed** — mutations / realtime / scaffold **Try again** refresh |
| Tab-strip **Request maintenance** / **Report equipment fault** | Cross-module shortcuts | **Removed** — remain in app navigation |
| Module-access dialog footer **Manage users and roles** | Open Access dialog | **Removed** — Access tab is the labeled entry |
| Staff detail empty-section CTAs (assign dept/shift, compensation, calendar empty) | Same as **Staff actions** | **Removed** — QuickActions are the sole mutation entry points |
| Staff **Next action** opening detail only | Mislabelled assign / review | **Merged** — next-action opens assign dialogs when placement missing; else staff detail |
| Work-queue **Next action** → detail shell → primary mutation | Extra intermediate shell | **Merged** — next-action opens the primary mutation dialog; row select opens full detail |

---

## HR workspace screen

### Tab strip

- **Human resources / Leave requests / Shifts / Payroll drafts / Manage users and roles**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, loads matching queue when needed.
  - Condition: Always when workspace loads; count badges from overview / staff total.

- **Add staff** (primary, Human resources)
  - Location: Tab-strip primary (`hrAddStaffAction`).
  - Opens modal: Yes — staff onboarding dialog.
  - Immediate result: Creates staff; may open staff detail after onboarding.
  - Condition: `hrWriteRequirement`; omitted when unauthorized.

- **Request leave** (primary, Leave requests)
  - Location: Tab-strip primary (`hrRequestLeaveAction`).
  - Opens modal: Yes — request leave dialog.
  - Immediate result: Creates leave request; snackbar; queue refresh.
  - Condition: `hrWriteRequirement`; omitted when unauthorized.

- **Schedule templates** (primary, Shifts)
  - Location: Tab-strip primary (`hrShiftTemplateAction`).
  - Opens modal: Yes — manage schedule templates dialog.
  - Immediate result: Create / edit / delete shift templates.
  - Condition: `hrRosterWriteRequirement`; omitted when unauthorized.

Payroll drafts and Manage users and roles have no tab-strip primary. Access creates (**Create staff** / role / permission) live on the embedded Access panel.

- **HR activity** (secondary)
  - Location: Tab-strip secondary (`hrActivityTitle`).
  - Opens modal: Yes — timeline activity dialog.
  - Immediate result: Progressive disclosure of recent HR timeline items.
  - Condition: Always when workspace loaded.

Tab-strip **Refresh**, housekeeping, and fault shortcuts were removed.

- **Try again** (page load / inline failure)
  - Location: `AsyncStateScaffold` or `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Retries workspace load / refresh.
  - Condition: Load or mutation failure surface.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns), pagination
  - Location: `AppListTable` / `AppSearchBar` on staff directory and work queues.
  - Immediate result: Filters/search/column visibility for the active list.
  - Condition: Staff and queue sections (not Access panel search, which is panel-local).

### Staff directory

- **Row select** — opens staff detail dialog.
- **Next action**
  - Location: Next-action column.
  - Immediate result: **Assign department** / **Assign position** dialog when missing; otherwise **Review profile** (staff detail).
  - Condition: Write-gated for assign labels; review always available.

### Work queues (Leave / Shifts / Payroll)

- **Queue switcher** (Shifts only) — roster drafts / unassigned / overdue / swaps.
- **Row select** — opens work-item detail with info tiles + all authorized actions.
- **Next action** — opens the primary mutation directly (approve leave/swap, publish roster, override shift, process payroll) without the detail shell.
  - Condition: Matching write / approve / publish / payroll gate; unauthorized control absent.

### Staff detail (from row / deep link / review next-action)

- Profile header with **Edit staff** (when not separated).
- **Staff actions** QuickActions: assign department/position, availability, shift, swap, leave, compensation, run payroll, assign role, view module access, offboard (permission-gated).
- Record sections (assignments, leave, availability calendar, shifts, compensation) for browse / row detail; mutations start from Staff actions (or day sheet edit on the calendar).

### Access tab

- Embedded `HrAccessWorkspacePanel`: users / roles / permissions toggle, search, create actions when `hrWrite` + tenant UUID available.
- Row select opens user / role / permission detail dialogs.

### Empty / loading / error / validation

- Empty staff / queue panels via `AppWorkspaceStatePanel`.
- Mutation dialogs keep required-field validation; success/error via snackbar or inline failure.
- Unauthorized primaries and next-actions do not render.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/hr/presentation/hr_workspace_page_test.dart` prove:
  - **Refresh** / housekeeping / fault absent from the tab strip; **Add staff** / **Request leave** / **Schedule templates** present on their tabs.
  - Payroll and Access tabs have no strip primary; Access panel shows **Create staff**.
  - Unauthorized write hides strip primaries and next-actions.
  - Staff **Assign department** next-action opens the assign dialog without Staff actions.
  - Leave **Approve leave** next-action opens approve without Quick actions detail shell.
  - **Review profile** still opens staff detail with Staff actions (including **Run payroll**).
