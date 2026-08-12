# Reception — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.reception` under app `ShellRoute`
- Workspace gate: `receptionWorkspaceRequirement` — ∪ `patient:read` | `last_office:read` + modules `patient-registry`, `scheduling-queue` (+ role pack)
- Catalog entry: `RouteAccessCatalog.receptionEntry`
- If no desk tabs are allowed: `AppFailureStateView` forbidden (no disabled placeholders)

## Page chrome

- `AsyncStateScaffold<OpdWorkspaceState>` over `opdWorkspaceControllerProvider`
  - Loading: `receptionLoadingTitle` / `receptionLoadingBody`
  - Retry refreshes OPD reception data + payment-gate + follow-ups when those tabs are readable
  - `keepPreviousDataDuringRefresh: true`
- Body: `ResponsivePage(scrollable: false)` + `AppTabStrip` + `Expanded` + `AppListTable<_ReceptionDeskRow>` (bounded main-tab viewport: horizontal scroll, pinned footer, empty-row padding; no `shrinkWrap`)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-link query (`ReceptionWorkspaceQuery`): `section`, `search`, `patientId`, `flowId`, `action`
  - `action=register|register_patient|new_patient` → Register patient
  - `action=schedule|book|book_appointment` → Schedule appointment
  - `action=route|route_patient|walk_in|walk-in|start` → walk-in encounter (**reused** `showOpdEncounterDialog`)
  - `flowId=` → opens Flow Actions when Active visits row-select allowed
  - One-shot `action` cleared from URL after open (`_replaceUrlForSection`)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized (`receptionDeskSectionRequirement(section)`) — not disabled
- Every visible tab shows authoritative `count`:
  - Sibling model: dedicated unfiltered scope totals (Follow-ups / Payment gate prefer controller `totalCount`; Appointments / Queue / High priority / Active visits use in-scope board membership)
  - Active tab with search/advanced filters: filtered membership total for that query
- Count tones (`AppTabCountTone`): `warning` for Desk queue, High priority, Active visits (in-facility turnaround pressure), and Payment gate (outstanding clearance pressure); `info` for Appointments and Follow-ups
- Icons per section (leading): event / queue / priority / pending / phone / payments

## Table toolbar (shared pattern)

Order on search bar: **Filters → Settings → Export → Print → Schedule → Register**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | section hint (`receptionSearchHint` / payment / follow-ups variants) | mic via `AppSearchBar` default |
| Clear | `receptionClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → title `commonAdvancedFiltersTitle` | all tabs including Follow-ups; date filter on all tabs (Payment gate uses `billingIssuedDateFilterLabel`) |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | Apply `receptionApplyColumnsAction`, Reset `receptionResetColumnsAction`, Close `commonCloseActionLabel` |
| Export | `commonTableExport*` labels via `AppListTable` + `canExport` + `exportValue` / `AppListTableExportConfig` | gated by `receptionDeskExportRequirement` (∩ `evidence:export`); omitted when denied |
| Print (table) | `commonPrintActionLabel` → `Print` | `AppListTable.enablePrint` + `canPrint`; opens `printReceptionDeskList` → `PrintDocumentTemplates.registry` preview-first; section labels via `commonPrint*` |
| Schedule | `receptionScheduleAppointmentAction` | omitted when ∩ `patient:write` denied |
| Register | `receptionRegisterPatientAction` | omitted when ∩ `patient:write` denied |
| Footer | `commonGoToTopActionLabel` / `commonLoadingMoreLabel` / `commonAllRowsLoadedLabel` | |

Column visibility storage: `reception_${section.name}` / widths `reception_cw_${section.name}`.
Default visible columns prefer **5** data columns (+ optional next-action when authorized).
Patient cells are atomic (`AppListItemText` name + identifier); no nested badges or body-prose notes/complaints in table cells.

## Shared strip actions → dialogs

### Schedule appointment — Reception-owned shell

- Entry: `openReceptionScheduleAppointment` (`reception_patient_actions.dart`)
- Dialog title: `patientsAppointmentDialogTitle`
- Nested tabs: Existing patient / New patient / Visitor (`receptionScheduleExistingPatientTab`, `receptionScheduleNewPatientTab`, `receptionScheduleVisitorTab`)
- Existing → embedded patient picker → **reused** `PatientAppointmentQuickDialog` (`allowClinicalActions: false`, `allowVitalsActions: false`)
- New → **reused** `RegisterNewPatientForm` + similarity / use-existing
- Visitor → Reception-owned `ReceptionVisitorAppointmentDialog` (name, phone, organization, host, date/time, duration, reason)
- Success: `opdSavedMessage` snackbar + workspace refresh
- Gate: strip schedule/register ∩ `patient:write`

### Register patient — **reused**

- `showRegisterNewPatientDialog` (patients) → on create success `patientsSavedMessage` → `openReceptionPatientEditor` → **reused** `showPatientDetailDialog` (`allowBillingNavigation: false`)

## Shared row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Appointment Actions | Reception wrapper → **reused** `OpdAppointmentActionsDialog` | `reception_appointment_actions_dialog.dart` |
| Queue Actions | Reception wrapper → **reused** `QueueActionsDialog` | `reception_queue_actions_dialog.dart` |
| Flow Actions | **reused** `showFlowActionsDialog` | `opd_flow_actions_dialog.dart` |
| Follow-up detail | Reception-owned | `reception_follow_up_detail_dialog.dart` |
| Payment-gate detail | Reception-owned (+ billing tiles) | `reception_payment_gate_detail_dialog.dart` |
| Encounter / check-in | **reused** `showOpdEncounterDialog` | `opd_actions` |
| Reschedule appointment | **reused** `showOpdRescheduleAppointmentDialog` | |
| Cancel appointment | **reused** `showOpdCancelAppointmentDialog` | |
| Print OPD summary | **reused** `showPrintOpdSummaryDialog` → `PrintDocumentTemplates.clinicalSummary` | from Flow Actions; Reception passes `printActionLabel: Print` |

## Flow Actions from Reception (flags)

Opened with:

- `allowBillingActions: false`
- `allowVitalsActions: false`
- `allowClinicalActions: false`
- `printActionLabel: commonPrintActionLabel` (`Print`)

Still reachable when stage/permission allows (front-desk gates): Assign/Change doctor, Follow up, Print (`Print`), Correct stage / other front-desk stage actions per hub. Clinical / vitals / billing panels stripped.

## Feedback patterns (cross-tab)

- Success snackbars: `opdSavedMessage`, `patientsSavedMessage`
- Failures: `showAppFailureSnackBar` / form banners
- Empty: section-specific `AppStateView` empty titles/bodies
- Payment-gate / Follow-ups controller hard failure (no prior data): error `AppStateView` + `commonRetryActionLabel`
