# Action Button Inventory — `/reception`

Source of truth: Dart presentation widgets. English labels from `app_localizations_en.dart`.
Primary page: `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
Route: `AppRoutes.reception` → `/reception`

Dismiss-only title-bar close is noted once per dialog; barrier dismissal is disabled on these hubs unless stated otherwise.

---

## Screen: `/reception` (`ReceptionWorkspacePage`)

### Page chrome — tab strip

| Button / control | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Appointments | Tab strip | none | Switches section; updates URL |
| Desk queue | Tab strip | none | Switches section; updates URL |
| Active visits | Tab strip | none | Switches section; updates URL |
| Payment gate | Tab strip | none | Switches section; updates URL |

### Toolbar — Appointments tab

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Schedule appointment | Primary toolbar | `_ReceptionPatientPickerDialog` → then `PatientAppointmentQuickDialog` | Requires `receptionFrontDeskWriteRequirement`; disabled while refreshing |
| Register patient | Secondary toolbar | `RegisterNewPatientDialog` | Same write gate; disabled while refreshing |
| Refresh | Secondary toolbar | none | Refreshes OPD workspace; disabled/loading while refreshing |
| Full registry | Secondary toolbar | none | Navigates to `/patients` |

### Toolbar — Desk queue / Active visits tabs

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Register patient | Primary toolbar | `RegisterNewPatientDialog` | Write gate; disabled while refreshing |
| Refresh | Secondary toolbar | none | Disabled/loading while refreshing |
| Full OPD | Secondary toolbar | none | Navigates to `/opd` |

### Toolbar — Payment gate tab

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Billing | Primary toolbar | none | Navigates to `/billing` |
| Refresh | Secondary toolbar | none | Disabled/loading while refreshing |
| Full OPD | Secondary toolbar | none | Navigates to `/opd` |

### Search / table chrome (all tabs)

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Filters | Search toolbar | Shared advanced-filters modal | Status filter (Appointments/Queue) or stage filter (Active visits/Payment gate) |
| Search clear (icon) | Search control | none | Clears query when present |
| Clear filters | Search control | none | Resets filter value when filters active |
| Settings | Table toolbar | Shared column-visibility modal | Label: `commonTableSettingsActionLabel` |

#### Nested: Advanced filters modal

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Apply filters | Footer | none | Commits selected filter values |
| Clear filters | Footer | none | Resets filters |
| Cancel / close | Footer / title bar | none | Dismiss only |

#### Nested: Column settings modal

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Apply / reset column visibility | Shared `AppListTable` settings | none | Labels from shared table component |
| Close | Title bar | none | Dismiss only |

### Row actions — Appointments

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Start OPD encounter | Next-action column / mobile action | `ReceptionAppointmentActionsDialog` | Shown for non-terminal appointments where status is not `IN_PROGRESS`/`COMPLETED` |
| Row / card tap | Appointment row | `ReceptionAppointmentActionsDialog` | Same hub as next-action button |
| (fallback labels) Queue / Reschedule | Next-action column | `ReceptionAppointmentActionsDialog` | Rare fallbacks when check-in label path does not apply |

Terminal appointments (`COMPLETED`, `CANCELLED`, `NO_SHOW`, `DISCHARGED`, `ADMITTED`, `CLOSED`) are excluded from the table.

### Row actions — Desk queue

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Start consultation (`WorkflowActionButton`) | Next-action column / mobile | none (unsupported workflow) | Used when queue entry ID is present. `START_CONSULTATION` has **no** `WorkflowActionDefinition` in the registry, so the control resolves as an unsupported/disabled workflow action and does **not** open the queue dialog |
| Start consultation (`AppButton.secondary`) | Next-action column | `ReceptionQueueActionsDialog` via `_openRowDetail` | Only when queue entry ID is blank |
| Row / card tap | Queue row | `ReceptionAppointmentActionsDialog` if linked appointment found; else `ReceptionQueueActionsDialog` | |

Terminal queue rows are excluded from next-action rendering.

### Row actions — Active visits / Payment gate

Visible label comes from `flow.displayNextStep` / registered workflow action for `flow.nextStep`.

| Button (typical label) | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Pay consultation | Workflow next-action | none | `PAY_CONSULTATION` is dialog-mode but falls back to routing `/billing?...&action=pay` when no dialog opener resolves from this compact button path |
| Record vitals | Workflow next-action | none | Routes toward Nursing vitals |
| Assign doctor / Change doctor | Workflow next-action | `AssignDoctorDialog` | When registry dialog opener is wired for assignment codes |
| Doctor review | Workflow next-action | none | Routes to Clinical |
| Collect sample / diagnostic handoff | Workflow next-action | none | Routes to Laboratory / related module |
| Perform imaging | Workflow next-action | none | Routes to Radiology |
| Dispense medicine | Workflow next-action | none | Routes to Pharmacy |
| Disposition label | Workflow next-action | none | Routes to Clinical disposition |
| Fallback Assign doctor / Change doctor | Workflow next-action | `AssignDoctorDialog` | May replace a denied clinical-owned action when front-desk assignment is allowed |
| Unsupported action code | Workflow next-action | none | Visible but disabled; title-cased generated label |
| Row / card tap | Active visit / Payment gate row | `FlowActionsDialog` | Full flow hub |

Workflow sources:
- `frontend/lib/shared/workflow_actions/workflow_action_button.dart`
- `frontend/lib/shared/workflow_actions/workflow_action_registry.dart`
- `frontend/lib/shared/workflow_actions/workflow_action_dialog_openers.dart`

---

## Dialog: `_ReceptionPatientPickerDialog`

Source: `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`  
Opened by: Schedule appointment

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Select | Footer | none (returns patient; caller opens next dialog) | Enabled only when loading finished and a patient is selected |
| Close | Title bar | none | Disabled while loading; dismiss only |

### Nested: `PatientAppointmentQuickDialog`

Source: `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart`  
Opened after picker returns a patient via `openReceptionScheduleAppointment`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Select date | Date field | System date picker | |
| Select time | Time field | System time picker | |
| Cancel | Footer | none | |
| Schedule appointment | Footer | none | Creates appointment; disabled while providers load or saving |
| Close | Title bar | none | Disabled while busy; dismiss only |

---

## Dialog: `RegisterNewPatientDialog`

Source: `frontend/lib/shared/patient_actions/register_new_patient_dialog.dart`  
Opened by: Register patient toolbar actions

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Date-of-birth picker (icon) | Form field | System date picker | |
| Cancel | Footer | none | |
| Register patient | Footer | none | Runs duplicate detection then creates patient |
| Save anyway | Same primary footer after duplicates found | none | Submits despite duplicate warning |
| Close | Title bar | none | Disabled during duplicate lookup/save; dismiss only |

Conditional fields (tenant/facility) depend on `PatientRegistrationScope` and access policy.

---

## Dialog: `ReceptionAppointmentActionsDialog` → `OpdAppointmentActionsDialog`

Sources:
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_appointment_actions_dialog.dart`

Title: Appointment actions. Mutations gated by `receptionFrontDeskWriteRequirement`.

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Queue | Action grid | none | Assigns appointment to queue; non-terminal, not `IN_PROGRESS`, has patient+tenant, no active linked queue entry |
| Reschedule | Action grid | `OpdRescheduleAppointmentDialog` | Non-terminal only |
| Cancel appointment | Action grid | `OpdCancelAppointmentDialog` | Non-terminal and not already cancelled; destructive |
| Start OPD encounter | Action grid (primary) | `OpdEncounterDialog` | Non-terminal and not `IN_PROGRESS`/`COMPLETED`; reception passes `workspaceState` so encounter dialog is used |
| Cancel | Footer | none | |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `OpdRescheduleAppointmentDialog`

Source: `frontend/lib/shared/opd_actions/opd_reschedule_appointment_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Select date | Date field | System date picker | |
| Select time | Start-time field | System time picker | |
| Select time | End-time field | System time picker | |
| Cancel | Footer | none | |
| Edit | Footer | none | Persists new schedule |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `OpdCancelAppointmentDialog`

Source: cancel path in `opd_appointment_actions_dialog.dart` / related cancel dialog

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | Dismiss |
| Cancel appointment | Destructive footer | none | Confirms cancellation; optional reason |
| Close | Title bar | none | Dismiss only |

### Nested: `OpdEncounterDialog`

Source: `frontend/lib/shared/components/opd_encounter_dialog.dart`  
Reception appointment path: patient/appointment pinned; `includeEncounterLifecycleCallbacks: false` (no Close/Cancel encounter actions from this path).

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Start encounter | Primary footer | none | Submits new encounter when none active |
| Edit encounter | Primary footer | none | When active encounter already exists |
| Start new encounter | Footer | Start-new confirmation | When active encounter exists |
| Continue encounter | Footer | none | Returns continue-workflow result when active encounter exists |
| Close | Title bar | none | Disabled while busy; dismiss only |

#### Nested: Start-new confirmation

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Cancel old and start new | Destructive footer | none | Forces new encounter creation |
| Close | Title bar | none | Dismiss only |

---

## Dialog: `ReceptionQueueActionsDialog` → `QueueActionsDialog`

Sources:
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_queue_actions_dialog.dart`

Title: Queue actions. Action grid hidden for terminal entries. Mutations gated by `receptionFrontDeskWriteRequirement`.

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Prioritize | Action grid | `AppTextActionDialog` (prioritize) | |
| Move | Action grid | `_MoveQueueDialog` | |
| Start consultation | Action grid (primary) | `AppConfirmActionDialog` | |
| Cancel | Footer | none | |
| Close | Title bar | none | Dismiss only |

### Nested: Prioritize (`AppTextActionDialog`)

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Prioritize | Footer | none | Optional reason submitted |
| Close | Title bar | none | Dismiss only |

### Nested: `_MoveQueueDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Move | Footer | none | Changes queue status/provider |
| Close | Title bar | none | Disabled while saving/loading providers; dismiss only |

### Nested: Start consultation (`AppConfirmActionDialog`)

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Start consultation | Footer | none | Starts OPD from queue |
| Close | Title bar | none | Dismiss only |

---

## Dialog: `FlowActionsDialog`

Source: `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`  
Opened by: Active visits / Payment gate row tap

Visibility is stage-, record-, module-, role-, and permission-dependent.

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Pay consultation / Edit consultation billing / Manage consultation billing | Action grid | `ConsultationPaymentDialog` | Billing-write + `billing-payments`; non-terminal |
| Record vitals / Edit vitals | Action grid | `RecordVitalsDialog` | Doctor/nurse/admin; non-terminal; edit label when vitals exist |
| Assign doctor / Change doctor | Action grid | `AssignDoctorDialog` | Reception/nurse/admin; active encounter |
| Doctor review | Action grid | `ClinicalFreeTextActionDialog` | Doctor/admin; clinical stages |
| Diagnostic/service handoff (dynamic) | Action grid | none | Routes to Lab, Radiology, or Pharmacy by stage |
| Add diagnosis | Action grid | `ClinicalDiagnosisActionDialog` | Doctor/admin; clinical stages |
| Request lab | Action grid | `ClinicalLabOrderActionDialog` | Doctor/admin; clinical stages |
| Request radiology | Action grid | `ClinicalRadiologyOrderActionDialog` | Doctor/admin; clinical stages |
| Prescribe | Action grid | `ClinicalPrescriptionActionDialog` | Doctor/admin; clinical stages |
| Record procedure | Action grid | `ClinicalProcedureActionDialog` | Doctor/admin; clinical stages |
| Refer | Action grid | `ReferralDialog` | Doctor/admin; clinical stages |
| Follow up | Action grid | `FollowUpDialog` | Doctor/admin; clinical stages |
| Disposition (dynamic label) | Action grid | `OpdDispositionDialog` | Doctor/admin; disposition-ready stages |
| Open inpatient admission | Action grid | none | Routes to IPD; pending admission + IPD access |
| Correct stage | Action grid | `CorrectStageDialog` | Admin roles only |
| Print summary | Action grid | `PrintOpdSummaryDialog` | Front-desk/admin; always eligible |
| Cancel | Footer | none | |
| Close | Title bar | none | Disabled while loading/saving; dismiss only |

### Nested: `ConsultationPaymentDialog`

Source: `frontend/lib/shared/opd_actions/opd_consultation_payment_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Coverage verified (checkbox) | Insurance verification panel | none | Required before insurance payment |
| Cancel | Footer | none | |
| Pay consultation | Footer (unpaid) | none | |
| Edit consultation billing | Footer (already paid) | none | |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `RecordVitalsDialog`

Source: `frontend/lib/shared/opd_actions/record_vitals_dialog.dart`

| Button / control | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Emergency / risk / urgency / route / provider controls | Form body | may open `RoutingDecisionDialog` when routing captured | Interactive triage controls |
| Cancel | Footer | none | |
| Record vitals / Edit vitals | Footer | none | Saves vitals; may route patient |
| Close | Title bar | none | Disabled while loading/saving; dismiss only |

#### Nested: `RoutingDecisionDialog`

Source: `frontend/lib/shared/opd_actions/opd_routing_decision_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Save routing decision | Footer | none | |
| Close | Title bar | none | Dismiss only |

### Nested: `AssignDoctorDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Assign doctor / Change doctor | Footer | none | Persists selected provider |
| Close | Title bar | none | Disabled while loading/saving; dismiss only |

### Nested: `ClinicalFreeTextActionDialog` (Doctor review)

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Doctor review | Footer | none | Submits required clinical note |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `OpdDispositionDialog`

Source: `frontend/lib/shared/opd_actions/opd_disposition_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Save disposition | Footer | none | Decisions: Discharge; Send to pharmacy (with pharmacy order); Refer physiotherapy; Admit |
| Close | Title bar | none | Disabled while saving; dismiss only |

#### Nested after Admit: `_OpdAdmissionHandoffDialog`

Source: `frontend/lib/shared/opd_actions/opd_admission_handoff_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Open inpatient admission | Footer | none | Routes to IPD |
| Close | Title bar | none | Dismiss only |

#### Nested after Refer physiotherapy: physiotherapy handoff

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Open physiotherapy | Footer | none | Routes to Physiotherapy |
| Close | Title bar | none | Dismiss only |

### Nested: `CorrectStageDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Correct stage | Footer | none | Reason required for some transitions |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `ReferralDialog`

Source: `frontend/lib/shared/opd_actions/opd_referral_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Save referral | Footer | none | |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `FollowUpDialog`

Source: `frontend/lib/shared/opd_actions/opd_follow_up_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Select date | Date field | System date picker | |
| Select time | Time field | System time picker | |
| Cancel | Footer | none | |
| Save follow-up | Footer | none | |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `PrintOpdSummaryDialog`

Source: `frontend/lib/shared/opd_actions/opd_print_summary_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Copy summary | Footer | none | Copies locally |
| Cancel | Footer | none | |
| Print | Footer | none | Native/browser print workflow |
| Close | Title bar | none | Disabled during copy/print; dismiss only |

### Nested: `ClinicalDiagnosisActionDialog`

Source: `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add | Catalog selection | none | Adds selected diagnosis |
| Delete (icon) | Selected diagnosis manager | none | Removes focused diagnosis |
| Cancel | Footer | none | |
| Add diagnosis | Footer | none | Submits selected diagnoses |
| Close | Title bar | none | Disabled while saving; dismiss only |

### Nested: `ClinicalLabOrderActionDialog`

Source: `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add items | Toolbar | `ClinicalLabRequestCatalogDialog` | |
| Remove selected | Toolbar | Remove-items confirmation | Shown when rows selected |
| Review billing | Toolbar | `_ClinicalRequestBillingDialog` | Enabled when items exist |
| Remove item | Row action | Remove-items confirmation | |
| Request lab | Footer | none | Enabled when requests exist |
| Close | Title bar | none | Disabled while saving; dismiss only |

#### Nested: `ClinicalLabRequestCatalogDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Favorite test chips (dynamic names) | Favorites | none | Stages that test |
| Row checkbox / selection | Catalog table | none | Stages or unstages item |
| Filters | Table search | Advanced-filter modal | |
| Settings | Table columns | Column settings | |
| Cancel | Footer | none | |
| Confirm selected tests or panels | Footer | none | Returns staged selection |
| Close | Title bar | none | Dismiss only |

#### Nested: Remove-items confirmation

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Remove / Remove selected | Destructive footer | none | One item vs multiple |

#### Nested: `_ClinicalRequestBillingDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Done | Footer | none | Returns billing selections |
| Close | Title bar | none | Dismiss only |

### Nested: `ClinicalRadiologyOrderActionDialog`

Source: `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add study | Toolbar | `ClinicalRadiologyRequestCatalogDialog` | |
| Remove selected | Toolbar | Remove-items confirmation | |
| Review billing | Toolbar | `_ClinicalRequestBillingDialog` | |
| Remove item | Row action | Remove-items confirmation | |
| Request radiology | Footer | none | Enabled when studies exist |
| Close | Title bar | none | Disabled while saving; dismiss only |

#### Nested: `ClinicalRadiologyRequestCatalogDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Row checkbox / selection | Catalog table | none | |
| Filters | Table search | Advanced-filter modal | |
| Settings | Table columns | Column settings | |
| Confirm selected studies | Footer | none | |
| Close | Title bar | none | No separate footer Cancel |

### Nested: `ClinicalPrescriptionActionDialog`

Source: `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add medicine | Toolbar | Prescription-line dialog | |
| Review billing | Toolbar | `_ClinicalRequestBillingDialog` | Only when “Pay at prescribe” selected and lines exist |
| Bill on dispense / Pay at prescribe | Billing mode toggles | none | |
| Edit (icon) | Selected medicine | Prescription-line dialog | |
| Remove medicine (icon) | Selected medicine | none | Enabled only when removal allowed |
| Cancel | Footer | none | |
| Prescribe | Footer | none | |
| Close | Title bar | none | Disabled while saving; dismiss only |

#### Nested: Prescription-line dialog

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Cancel | Footer | none | |
| Done | Footer | none | Validates and adds/updates line |
| Close | Title bar | none | Dismiss only |

### Nested: `ClinicalProcedureActionDialog`

Source: `frontend/lib/shared/clinical_actions/dialogs/clinical_procedure_action_dialog.dart`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add items | Toolbar | `ClinicalProcedureCatalogDialog` | |
| Delete (icon) | Selected-procedure manager | none | |
| Cancel | Footer | none | |
| Record procedure | Footer | none | Enabled after a procedure is selected |
| Close | Title bar | none | Dismiss only |

#### Nested: `ClinicalProcedureCatalogDialog`

| Button | Location | Opens modal | Notes |
| --- | --- | --- | --- |
| Add | Footer | none | Adds focused procedure; keeps picker open |
| Done | Footer | none | Closes picker |
| Close | Title bar | none | Dismiss only |

---

## Reception helpers not reachable from `/reception`

These exist under the reception feature but have **no call site** from `ReceptionWorkspacePage` or any dialog opened from it. Excluded from the reachable inventory:

| Helper | Would open | Source |
| --- | --- | --- |
| `openReceptionPatientEditor` | `showPatientDetailDialog` | `reception_patient_actions.dart` |
| `openReceptionInsuranceCapture` | Claims `openClaimsEnrollmentDialog` | `reception_patient_actions.dart` |
| `ReceptionBillingGuidancePanel` | none (button “Open billing workbench” navigates to billing) | `reception_billing_guidance.dart` |

---

## Reachability map (parent → child)

```
/reception
├── Schedule appointment → Patient picker → PatientAppointmentQuickDialog
├── Register patient → RegisterNewPatientDialog
├── Filters / Settings → shared filter & column modals
├── Appointment row → ReceptionAppointmentActionsDialog
│   ├── Queue (inline)
│   ├── Reschedule → OpdRescheduleAppointmentDialog
│   ├── Cancel appointment → OpdCancelAppointmentDialog
│   └── Start OPD encounter → OpdEncounterDialog → Start-new confirmation
├── Queue row → ReceptionQueueActionsDialog (or Appointment hub if linked)
│   ├── Prioritize → AppTextActionDialog
│   ├── Move → _MoveQueueDialog
│   └── Start consultation → AppConfirmActionDialog
└── Active visit / Payment gate row → FlowActionsDialog
    ├── ConsultationPaymentDialog
    ├── RecordVitalsDialog → RoutingDecisionDialog
    ├── AssignDoctorDialog
    ├── ClinicalFreeTextActionDialog
    ├── ClinicalDiagnosisActionDialog
    ├── ClinicalLabOrderActionDialog → catalog / billing / remove confirm
    ├── ClinicalRadiologyOrderActionDialog → catalog / billing / remove confirm
    ├── ClinicalPrescriptionActionDialog → line dialog / billing
    ├── ClinicalProcedureActionDialog → catalog
    ├── ReferralDialog
    ├── FollowUpDialog
    ├── OpdDispositionDialog → admission / physiotherapy handoff
    ├── CorrectStageDialog
    └── PrintOpdSummaryDialog
```
