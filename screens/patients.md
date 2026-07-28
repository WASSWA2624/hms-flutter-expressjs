# Action inventory — `/patients`

Primary surface: `PatientRegistryPage` (`frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`).

Write gates: `patientWrite` (register / edit / complete record / schedule), `patientDelete` (delete), `opdEncounterPermissionRequirement` (start / continue OPD), clinical write + module flags (admit / orders / therapy / theater), `reportsRead` (report). Unauthorized controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab-strip **Refresh** | Reload registry | **Absent** — lists refresh after mutations / scaffold **Try again** / realtime |
| Next-action **Open record** button vs row select | Open patient detail | **Removed** button — label-only guidance; row select is sole opener |
| Next-action **Complete record** opened detail then Edit | Complete registration | **Merged** — next-action opens edit form directly |
| Quick Actions **Triage** / **Billing** vs **Start OPD encounter** | Parallel OPD starts | **Removed** Triage and Billing chips — Start OPD is sole OPD start |
| Quick Action **Continue OPD flow** / Active Work Continue → empty Flow Actions hub | Continue OPD stage | **Removed** intermediate hub — runs stage next-action via `runOpdBoardNextAction` |
| Quick Action discharge vs Active Work admission Continue | Discharge planning | **Omitted** from Quick Actions when Active Work lists the admission; Active Work is sole continue |
| Active Work lab / imaging / theater / therapy Continue reopened create dialogs | Re-create order vs continue work | **Replaced** — Continue navigates to the department module |
| Physiotherapy Quick Action without eligibility → silent OPD check-in hop | Intermediate start shell | **Removed** hop — physio only when OPD or admission is already active |
| Active Work appointment Continue opened schedule-new dialog | Manage vs create | **Replaced** — opens shared appointment actions hub |

---

## Patients registry screen

### Tab strip

- **All patients / Active / Admitted / Balance due**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches `_section`, updates URL `?section=…`, clears search, reloads list.
  - Condition: Always when registry loads.

- **Register patient** (primary)
  - Location: Tab-strip primary.
  - Opens modal: Yes — register-new-patient dialog (duplicate warning), then patient detail.
  - Immediate result: Creates patient; snackbar; opens detail editor path.
  - Condition: `patientWrite`; unauthorized control absent.

- **Duplicate review** (secondary, when overview has candidates)
  - Location: Tab-strip secondary.
  - Opens modal: Yes — duplicate review / merge / dismiss.
  - Immediate result: Merge or dismiss candidates; overview refresh.
  - Condition: `patientWrite` and non-empty duplicates; otherwise absent.

Tab-strip **Refresh** is absent.

- **Try again** (page load failure)
  - Location: `AsyncStateScaffold`.
  - Opens modal: No.
  - Immediate result: Reloads registry.
  - Condition: Load failure.

### Search / filters / table chrome

- **Search**, **Clear**, **Filters** (advanced), **Settings** (columns)
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/column visibility for the active tab.
  - Condition: Always when list chrome is shown.

### Empty / no-results

- **Empty registry**
  - Location: `AppWorkspaceStatePanel.empty`.
  - Opens modal: No.
  - Immediate result: Empty copy; Register patient remains when authorized.
  - Condition: No rows after tab / search / filters.

### Row activation / next-action

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Patient detail dialog.
  - Immediate result: Loads detail; shows Active Work, Quick Actions, demographics sections.
  - Condition: Always when rows exist.

- **Next action**
  - Location: `next_action` column.
  - Opens modal: Edit form when registration incomplete; otherwise label-only (**Open record**).
  - Immediate result: Incomplete → `showPatientEditDialog` (skips detail shell). Complete → guidance only; use row select.
  - Condition: Complete-record button gated by `patientWrite`; unauthorized users see label only.

### Patient detail dialog

#### Footer

- **Edit** / **Delete**
  - Location: Dialog actions.
  - Opens modal: Edit form; delete confirm.
  - Immediate result: Updates or deletes patient; list sync.
  - Condition: `patientWrite` / `patientDelete`; unauthorized controls absent.

#### Active Work panel

- **Continue** (per in-flight item)
  - Location: Active Work rows.
  - Opens modal / navigates: Appointment actions hub; OPD stage mutation (or Flow Actions only when no stage action); admission handoff / discharge; department module for lab / imaging / theater / therapy.
  - Immediate result: Persists or navigates; detail refresh / snackbar where applicable.
  - Condition: Items from appointments, encounters, queues, admissions (including visit-only), and pending timeline orders.

#### Quick Actions (new work only)

- **Schedule appointment**, **Start OPD encounter** / **Continue OPD flow** (when no Active Work OPD item), **Request admission**, **Lab / Radiology / Theater / Physiotherapy** (create when none pending; physio only with active OPD or admission), **Enroll insurance**, **Report**
  - Location: Quick Actions strip.
  - Opens modal: Matching quick dialog / encounter / report preview.
  - Immediate result: Creates work or opens print preview; snackbar + detail refresh on save.
  - Condition: Permission and module gates; chips that duplicate Active Work continues are omitted.

#### Record sections / role panels

- Expandable demographics / clinical record sections; pharmacy or billing context panels for those readers.
  - Progressive disclosure only; not alternate entry points for the same writes above.

---

## Verification (Req 7)

- Widget tests in `frontend/test/features/patients/presentation/patient_registry_page_test.dart` prove:
  - **Open record** is label-only (not an `AppButton`); row select opens detail.
  - **Complete record** opens the edit form without an intermediate detail shell.
  - **Register patient** remains the sole labeled create entry when authorized; absent when unauthorized.
  - Tab strip has no **Refresh** control.
  - Idle detail shows **Start OPD encounter** only — no **Triage** / **Billing** parallel starts.
  - Active OPD **Continue OPD flow** opens Record vitals (stage next-action) without a Flow Actions hub.
  - Active admission shows a single **Discharge planning** Active Work continue (Quick Action discharge omitted).

- `patient_active_work_helpers_test.dart` proves visit-only admissions appear in Active Work and admitted continue label is discharge planning.
