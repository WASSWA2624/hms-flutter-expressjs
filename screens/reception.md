# Action inventory — `/reception`

Primary surface: `ReceptionWorkspacePage` (`frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`).

Write gates: `receptionPatientWriteRequirement` (register / schedule), `receptionFrontDeskWriteRequirement` (appointment / queue / follow-up mutations). Payment gate is read-only guidance (`receptionPaymentGateRequirement`).

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Patient registry** shortcut | Navigate to `/patients` | **Removed** — registry remains in app navigation |
| Tab-strip **Outpatient (OPD)** shortcut | Navigate to `/opd` | **Removed** — OPD remains in app navigation |
| Tab-strip **Refresh** | Reload desk lists | **Removed** — lists refresh after mutations / scaffold retry; no parallel reload control |
| Appointment **Next action** opened the same hub as row select | Start encounter / hub | **Removed** intermediate hub — next-action opens check-in (or reschedule) directly; hub omits that primary via `omitPrimaryAction` |
| Schedule dialog **New patient** tab vs toolbar **Register patient** | Create patient | **Kept** — distinct goals (register alone vs schedule); new-patient is progressive disclosure inside schedule |
| **High priority** tab vs **Desk queue** priority badge | Filtered queue subset | **Kept** — distinct desk focus, same row actions as queue |

---

## Reception workspace screen

### Tab strip

- **Appointments / Desk queue / High priority / Active visits / Follow-ups / Payment gate**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`.
  - Condition: Tabs gated by `receptionDeskSectionRequirement`; unauthorized tabs absent.

- **Register patient** (primary)
  - Location: Tab-strip primary (`receptionRegisterPatientAction`).
  - Opens modal: Yes — register-new-patient dialog, then patient detail editor.
  - Immediate result: Creates (or selects existing) patient; snackbar on create; opens patient editor.
  - Condition: `receptionPatientWriteRequirement`.

- **Schedule appointment** (secondary)
  - Location: Tab-strip secondary (`receptionScheduleAppointmentAction`).
  - Opens modal: Yes — schedule dialog (existing / new patient → appointment quick form).
  - Immediate result: Schedules appointment; snackbar on success; workspace refresh.
  - Condition: `receptionPatientWriteRequirement`.

Tab-strip **Refresh**, **Patient registry**, and **Outpatient (OPD)** shortcuts were removed; those modules remain reachable via app navigation. Desk data refreshes after mutations via `_refreshWorkspace`.

- **Try again** (page load / section failure)
  - Location: `AsyncStateScaffold` or section `AppStateView`.
  - Opens modal: No.
  - Immediate result: Retries OPD / payment-gate / follow-up loads.
  - Condition: Load or section failure.

### Search / filters / table chrome

- **Search**, **Clear filters**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/column visibility for the active section.
  - Condition: Filters hidden on Follow-ups (free-text search only). Payment gate / follow-ups omit date filter as configured.

#### Advanced filters / Table Settings

- **Apply filters** / **Clear filters** / **Close**; **Apply columns** / **Reset columns** / **Close**
  - Location: Panel/dialog footers.
  - Opens modal: No (closes panel/dialog).
  - Immediate result: Applies or resets filters/columns for `reception_{section}`.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Section-specific detail/actions dialog (below).
  - Immediate result: Opens the complementary hub for that row (appointment hub omits Check in).
  - Condition: Always when rows exist.

- **Next action** (appointments)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing`.
  - Opens modal: Encounter dialog for Check in, or reschedule dialog — no empty appointment hub shell.
  - Immediate result: Persists via controller; snackbar; workspace refresh.
  - Condition: `receptionFrontDeskWriteRequirement` (via `OpdBoardNextActionCell`); unauthorized control absent.

- Queue / High priority / Active visits / Payment gate next-action columns are **label-only** (row select opens the hub).

### Appointments section

#### Appointment actions dialog (row select)

Shared OPD appointment hub with `receptionFrontDeskWriteRequirement`, `allowClinicalActions: false`, `allowVitalsActions: false`, `omitPrimaryAction: true`. Complementary actions: Reschedule, Cancel appointment. Unauthorized write controls absent.

### Desk queue / High priority sections

- Row select → if linked flow: **Flow actions** dialog (`showFlowActionsDialog`, billing/vitals/clinical off); else **Queue actions** (`ReceptionQueueActionsDialog` → shared `QueueActionsDialog` with front-desk write gate).
- Next-action column is label-only (not a second control).

### Active visits section

- Row select → **Flow actions** dialog (billing/vitals/clinical actions disabled for reception).
- Next-action column is label-only.

### Payment gate section

- Row select → **Billing guidance** read-only dialog (`ReceptionPaymentGateDetailDialog`).
- Actions: **Close** only (no cashier mutations).
- Next-action column shows guidance label text.
- Mobile cards include services and outstanding amount (same required info as desktop columns).

### Follow-ups section

- Row select → **Follow-up detail** (`ReceptionFollowUpDetailDialog`).
- **Mark completed** / **Schedule another follow-up** (opens nested clinical follow-up schedule dialog) when front-desk write allowed; else **Close**.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/reception/presentation/reception_workspace_page_test.dart` prove:
  - **Patient registry**, **Outpatient (OPD)**, and **Refresh** are absent from the tab strip on desktop/mobile and light/dark.
  - **Register patient** and **Schedule appointment** remain the sole labeled desk entry points when authorized.
  - Appointment **Start OPD encounter** next-action opens the encounter dialog directly (no appointment hub).
  - Row select opens appointment hub without a Check in button (complementary Reschedule / Cancel only).
  - Unauthorized users see no register/schedule/nav shortcuts.
  - Controller-driven refresh still syncs sections without a toolbar Refresh control.
  - Active-visit billing mutations stay unavailable from reception flow actions.

- `reception_appointment_actions_dialog_test.dart` proves the shared hub defaults to `omitPrimaryAction: true`.
