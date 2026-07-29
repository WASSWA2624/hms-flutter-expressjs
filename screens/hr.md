# Action inventory — `/hr`

Primary surface: `HrWorkspacePage` (`frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`).

Write gates: `hrWriteRequirement` (staff / leave / access mutations; schedule-template **delete**), staff-detail nested roster ∪ helpers `hrRosterWriteRequirement` / `hrRosterApproveRequirement` / `hrRosterPublishRequirement` (`hr:write` | roster key), Shifts tab matrix ∩ helpers `hrShiftsRosterWriteRequirement` / `hrShiftsRosterPublishRequirement` / `hrShiftsRosterApproveRequirement` (`roster:write` / `roster:publish` / `roster:approve`), nested Shifts ∪ `hrRosterNestedWriteRequirement` (`roster:publish` | `roster:approve`), `hrPayrollRequirement` (payroll process; `hr:write` ∩ `financial:approve`). Preview payroll uses `hrPayrollPreviewRequirement` (`hr:read`). Access panel writes use Access helpers (`canCreateHrAccess` / `canUpdateHrAccess` / `canDeleteHrAccess`). Unauthorized controls do not render.

Atom maps: `HrLeaveRequestsAtomPermissions`, `HrShiftsAtomPermissions`, `HrPayrollDraftsAtomPermissions`, `HrManageUsersRolesAtomPermissions` in `hr_access.dart`. Tab strip filters via `hrAllowedSections`.

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
  - Condition: Section visible when `hrAllowedSections` includes it (payroll / leave / shifts / staff need `hr:read`; Access uses Access read ∪).

- **Add staff** (primary, Human resources)
  - Location: Tab-strip primary (`hrAddStaffAction`).
  - Opens modal: Yes — staff onboarding dialog.
  - Immediate result: Creates staff; may open staff detail after onboarding.
  - Condition: `hrWriteRequirement`; omitted when unauthorized.

- **Request leave** (primary, Leave requests)
  - Location: Tab-strip primary (`hrRequestLeaveAction`).
  - Opens modal: Yes — request leave dialog.
  - Immediate result: Creates leave request; snackbar; queue refresh.
  - Condition: `HrLeaveRequestsAtomPermissions.requestLeave`; omitted when unauthorized.

- **Schedule templates** (primary, Shifts)
  - Location: Tab-strip primary (`hrShiftTemplateAction`).
  - Opens modal: Yes — manage schedule templates dialog.
  - Immediate result: Create / edit shift templates (`HrShiftsAtomPermissions.create` / `update`, ∩ `roster:write`); delete uses `HrShiftsAtomPermissions.delete` (∩ `hr:write`) and is omitted when unauthorized.
  - Condition: `HrShiftsAtomPermissions.scheduleTemplates` (∩ `roster:write`) for strip entry; omitted when unauthorized. `hr:write` alone does not unlock create/update on this tab.

### Shifts tab (`?section=shifts`)

| Atom | Kind | Gate |
| --- | --- | --- |
| Shifts tab | navigate | `HrShiftsAtomPermissions.tab` ∩ `hr:read` |
| Schedule templates (strip) | create entry | ∩ `roster:write` |
| HR activity | progressive disclosure | read ∩ |
| Queue switcher / search / filters / columns / pagination | read chrome | read ∩ |
| Empty / loading / error / retry | read chrome | read ∩ |
| Row select → work-item detail | read | read ∩ |
| Next action **Publish roster** | approve | ∩ `roster:publish` |
| Next action **Override shift** | update | ∩ `roster:write` |
| Next action **Approve / Reject swap** | approve | ∩ `roster:approve` |
| Detail Preview / Generate roster | update / create | ∩ `roster:write` |
| Detail Publish / Override / Approve / Reject | as next-action | same ∩ keys |
| Template Create / Edit | create / update | ∩ `roster:write` |
| Template Delete | delete | ∩ `hr:write` |
| Nested publish \| approve row | nested write ∪ | `roster:publish` \| `roster:approve` |

Payroll drafts and Manage users and roles have no tab-strip primary. Access creates (**Create staff** / role / permission) live on the embedded Access panel.

- **HR activity** (secondary)
  - Location: Tab-strip secondary (`hrActivityTitle`).
  - Opens modal: Yes — timeline activity dialog.
  - Immediate result: Progressive disclosure of recent HR timeline items.
  - Condition: Always when workspace loaded with at least one visible section.

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

### Human resources tab (`?section=staff`)

| Atom | Kind | Gate |
| --- | --- | --- |
| Human resources tab | navigate | `HrHumanResourcesAtomPermissions.tab` ∩ `hr:read` |
| Add staff (strip primary) | create | `addStaff` ∩ `hr:write` |
| HR activity | progressive disclosure | `activity` ∩ `hr:read` |
| Search / filters / columns / pagination | read chrome | `listChrome` ∩ |
| Empty / loading / error / retry | read chrome | read ∩ |
| Success snackbar / form validation | feedback | write ∩ |
| Row select → staff detail | read | `rowSelect` / `detail` ∩ |
| Next action Assign department/position | update | `nextActionAssign` ∩ `hr:write` |
| Next action Review profile | navigate | `reviewProfile` ∩ `hr:read` |
| Detail Edit staff | update | `editStaff` ∩ |
| Staff actions Assign dept/position / leave / compensation / role / module access / offboard | create/update/delete | matching write ∩ |
| Staff actions Record availability / Assign shift / Swap shift | update | `nestedRosterWrite` ∪ (`hr:write` \| `roster:write`) |
| Staff actions Run payroll | approve | source `hrPayrollRequirement` (`hr:write` ∩ `financial:approve`) |
| Nested Revoke role / End assignment / Edit compensation rate | delete/update | write ∩ |
| Nested calendar Edit/Add slot | update | roster write ∪ |
| Nested shift Swap from shift detail | update | roster write ∪ |
| Nested cross-module write ∪ | — | _(n/a on this tab — roster publish/approve live on Shifts)_ |
| Matrix nested write ∪ | — | documented via `nestedRosterWrite`; payroll keeps source ∩ |
| Route entry | navigate | catalog ∩ `hr:read` (AppRoutes ∪ noted) |

### Work queues (Leave / Shifts / Payroll)

- **Queue switcher** (Shifts only) — roster drafts / unassigned / overdue / swaps.
- **Row select** — opens work-item detail with info tiles + all authorized actions.
- **Next action** — opens the primary mutation directly (approve leave/swap, publish roster, override shift, process payroll) without the detail shell.
  - Condition: Matching write / approve / publish / payroll gate; unauthorized control absent.

### Leave requests tab (`?section=leave-requests`)

| Atom | Kind | Gate |
| --- | --- | --- |
| Leave requests tab | navigate | `HrLeaveRequestsAtomPermissions.tab` ∩ `hr:read` |
| Request leave (strip primary) | create | `HrLeaveRequestsAtomPermissions.requestLeave` ∩ `hr:write` |
| HR activity | progressive disclosure | read ∩ |
| Search / filters / columns / pagination | read chrome | read ∩ |
| Empty / loading / error / retry | read chrome | read ∩ |
| Success snackbar / form validation | feedback | write ∩ |
| Row select → leave detail | read | read ∩ |
| Next action **Approve leave** | approve | `HrLeaveRequestsAtomPermissions.approveLeave` ∩ `hr:write` |
| Detail **Approve leave** | update | write ∩ |
| Detail **Reject leave** | delete | `HrLeaveRequestsAtomPermissions.rejectLeave` ∩ `hr:write` |
| Nested request / approve / reject dialogs | create / update | write ∩ |
| Nested cross-module read/write | — | _(n/a)_ (`nestedRead` / `nestedWrite` empty sentinels) |
| Route entry (deep link) | navigate | catalog ∩ `hr:read` (prompt ∪ `hr:read` \| `hr:write` noted in tests) |

### Payroll drafts tab (`?section=payroll`)

| Atom | Kind | Gate |
| --- | --- | --- |
| Payroll drafts tab | navigate | `HrPayrollDraftsAtomPermissions.tab` ∩ `hr:read` |
| Strip primary | — | _(none)_ |
| HR activity | progressive disclosure | read ∩ |
| Search / filters / columns / pagination | read chrome | read ∩ |
| Empty / loading / error / retry | read chrome | read ∩ |
| Row select → detail | read | read ∩ |
| Next action **Process payroll** | approve | source `hrPayrollRequirement` (`hr:write` ∩ `financial:approve`) |
| Detail **Preview payroll** | read | `hr:read` (backend preview) |
| Detail **Process payroll** | approve | source `hrPayrollRequirement` |
| Nested preview / process dialogs | read / approve | as above |
| Matrix nested write ∪ | — | documented as `nestedWriteMatrix`; UI process keeps source ∩ |

### Staff detail (from row / deep link / review next-action)

- Profile header with **Edit staff** (when not separated; `hrWriteRequirement`).
- **Staff actions** QuickActions: assign department/position, availability, shift, swap, leave, compensation, run payroll, assign role, view module access, offboard (permission-gated).
- Record sections (assignments, leave, availability calendar, shifts, compensation) for browse / row detail; mutations start from Staff actions (or day sheet edit on the calendar when roster-write allowed).
- Nested write affordances (Edit staff, Revoke role, End assignment, calendar Edit/Add, shift Swap, compensation Add/edit rate) omit when unauthorized.

### Access tab (`?section=access`)

| Atom | Kind | Gate |
| --- | --- | --- |
| Manage users and roles tab | navigate | `HrManageUsersRolesAtomPermissions.tab` (`hr:read` ∩ admin ∪ + `hr-rosters`) |
| Strip primary | — | _(none)_ |
| HR activity | progressive disclosure | workspace read ∩ |
| Panel toggle Staff / Roles / Permissions | progressive disclosure | read |
| Search / filters / columns / pagination / Refresh | read chrome | read |
| Empty / loading / error / retry / tenant-required | read chrome | read |
| Row select → user / role / permission detail | read | read |
| Create staff / role / permission | create | `canCreateHrAccess` (source `hr:write` ∩ matrix `tenant:admin`) |
| Detail Edit user / Edit role / Assign permissions / Add role | update | `canUpdateHrAccess` |
| Detail Remove role / remove direct permission | delete | `canDeleteHrAccess` (∩ `hr:write`) |
| Open staff profile | navigate | read |
| Nested create / edit / assign / remove dialogs | create / update / delete | as above; early-return when gate fails |
| Nested cross-module | — | _(n/a)_ |

Unauthorized create/update/delete controls do not render (no disabled stubs / no-access banners).

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
- Permission scan for Human resources (`staff`): `frontend/test/features/hr/presentation/hr_human_resources_permissions_test.dart` proves ∩ denial / presence, ∪ roster allowance, payroll ∩ without `financial:approve`, subscription strip, write-only entry denial, facility ABAC on route entry, nested write absence, empty chrome, mobile+desktop and light+dark, authorized Add staff validation, and post-mutation sync.
- Leave requests permission suite `frontend/test/features/hr/presentation/hr_leave_requests_permissions_test.dart` proves:
  - ∩ denial: missing `hr:read` / write-only hides tab; read-only hides Request / Approve / Reject (no disabled stubs or “no access” banners).
  - ∩ presence: `hr:read`+`hr:write`+module shows Request leave, Approve next-action, detail Approve/Reject.
  - ∪ note: prompt route ∪ `hr:read`\|`hr:write` kept as catalog ∩ `hr:read`; shared roster ∪ helpers documented (Leave nested ∪ _(n/a)_).
  - Subscription / ABAC: missing `hr-rosters` or facility strips entry; nested cross-module UI absent.
  - Authorized empty / error-retry / validation / post-approve sync; mobile+light and desktop+dark chrome.
- Access tab suite `frontend/test/features/hr/presentation/hr_manage_users_roles_permissions_test.dart` proves ∩ denial (no admin ∪), ∪ allowance (facility/tenant/system admin), create ∩ mapping (source `hr:write` ∩ matrix `tenant:admin`), detail Edit/Remove gates, subscription strip, facility ABAC on route entry, nested n/a, empty/error/retry, post-mutation sync, viewports, light/dark.
- Shifts permission suite `frontend/test/features/hr/presentation/hr_shifts_permissions_test.dart` proves:
  - ∩ denial: `hr:write` alone (no `roster:write`) hides Schedule templates / Override; missing `hr:write` hides template Delete.
  - ∩ presence: `roster:write` shows create/edit templates; full set shows Delete.
  - ∪ allowance: `roster:publish` alone shows Publish; `roster:approve` alone shows Approve swap; nested ∪ row.
  - Module entitlement strips Shifts without `hr-rosters`; facility ABAC fails route entry.
  - Post-mutation publish sync; mobile/desktop and light/dark chrome for authorized readers.
- Payroll drafts permission tests in `frontend/test/features/hr/presentation/hr_payroll_drafts_permissions_test.dart` prove preview/process ∩/∪ mapping, unauthorized absence, authorized presence, sync, viewports, and themes.
