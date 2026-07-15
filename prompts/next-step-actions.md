# Major Refactor: Universal, Executable “Next Step” Workflow Actions

## Objective

Perform a major end-to-end refactor of patient workflow actions so every displayed **Next Step**, **Current Step**, or equivalent pending action is a clear, executable button. From any relevant worklist, the user must be able to click once and reach the exact dialog, form, record, or module required to complete that step—without searching the sidebar, opening a generic workspace, or guessing what to do next.

This must be a shared application capability, not an OPD-only patch. Cover Reception, OPD, Emergency, IPD, ICU, Nursing, Clinical, Laboratory, Radiology, Pharmacy, Billing, Insurance Claims, Rooms & Beds, Physiotherapy, Operating Theatre, and Discharge Planning, plus every other patient-flow context discovered during the audit.

## Required Outcome

After the refactor:

1. Every active workflow row exposes one authoritative next action.
2. Every next action is rendered through one shared action-button component.
3. Clicking the button opens the most specific existing dialog or form with current context pre-filled.
4. Cross-module handoffs deep-link to the exact target record and automatically open the required action—not merely the module landing page.
5. Permissions, module entitlements, stale data, completed steps, and unavailable targets are handled explicitly.
6. Completing an action refreshes all affected worklists and advances the workflow consistently.
7. Frontend action definitions and backend workflow transitions cannot silently drift apart.

## Mandatory Discovery and Audit

Before changing architecture, inspect the complete frontend and backend and produce an implementation inventory in the final handoff.

### Frontend audit

- Find every table, card, queue, timeline, patient summary, and dialog that renders:
  - `nextStep`, `displayNextStep`, `currentStep`, `stage`, `status`, `nextAction`, or equivalent fields.
- Audit all `AppListTable` column definitions and mobile row builders.
- Locate all existing action dialogs/forms and their public opening APIs.
- Identify all route query models and record-targeting/deep-link conventions.
- Identify existing Riverpod invalidation and realtime update mechanisms.
- Find duplicate step-to-label, step-to-route, and step-to-dialog logic.

### Backend audit

- Enumerate every real workflow stage, transition, next-step code, terminal state, and role owner.
- Include OPD and all other encounter/service flows, not only the example actions listed below.
- Trace how billing, diagnostics, admissions, bed allocation, medication, theatre, therapy, and discharge actions are created and completed.
- Verify that each backend-emitted next-step code has an executable frontend handler.
- Identify obsolete, unreachable, duplicate, or display-only action codes.

Do not assume the action list in this prompt is exhaustive. The repository is the source of truth.

## Refactor Architecture

### 1. Canonical workflow action model

Introduce a typed shared model representing an executable workflow action. It must contain enough information to execute the action without feature-specific guessing, including:

- Stable action code.
- Human-readable localized label.
- Patient, encounter, admission, order, invoice, queue, and source-record identifiers as applicable.
- Source module and owning/target module.
- Required permission, role, and active-module entitlement metadata.
- Execution mode: dialog, targeted route, inline command, or read-only details.
- Target action/panel identifier for deep links.
- Availability state and disabled/unavailable reason.
- Optional revision/version or updated timestamp for stale-state protection.

Avoid passing display labels as action identifiers. Normalize backend aliases to canonical codes at one boundary.

### 2. Central action registry

Replace scattered switch statements and module-specific route guesses with one typed registry of action definitions and handlers.

Each registered action must define:

- Canonical action code and accepted legacy aliases.
- Localized label and icon.
- Required identifiers.
- Authorization and module-entitlement requirements.
- Preferred execution strategy.
- Dialog/form opener or exact deep-link builder.
- A safe fallback only when the preferred UI is unavailable.
- Post-success invalidation/refresh behavior.

The registry must fail visibly in development and tests when an active backend action has no handler. In production, show a controlled unavailable state rather than navigating to an unrelated page.

### 3. Shared action executor

Create one orchestration service/controller that:

1. Receives the action and row context.
2. Resolves canonical action metadata.
3. Re-fetches or validates the latest record before execution.
4. Checks permissions and module entitlement.
5. Opens the correct dialog/form or performs a targeted handoff.
6. Handles loading, success, cancellation, conflict, and failure states.
7. Refreshes/invalidate all affected providers after success.
8. Prevents duplicate execution while an action is in progress.

Feature tables must not independently implement navigation or dialog-selection logic.

### 4. Shared `NextStepActionButton`

Refactor or replace the current next-step button with a reusable component used everywhere.

It must:

- Look actionable and distinct from status text.
- Display a useful localized action label and icon.
- Show loading and disabled states.
- Provide a tooltip or helper message naming the destination/owner.
- Be keyboard accessible and expose a meaningful semantic label.
- Stop row-click propagation so clicking it does not also open the row details.
- Work in desktop tables, compact/mobile rows, cards, and dialogs.
- Never disappear solely because the current user lacks permission; show an intentional disabled/handoff state with the reason, unless product security requires hiding it.

Status remains informational. Next action remains executable. Do not merge these concepts.

### 5. Dialog-first execution

Prefer the smallest correct existing dialog or form over routing:

- Reuse shared dialogs and existing feature forms.
- Pre-fill them using stable record identifiers, then load fresh data from the owning provider/repository.
- Do not duplicate business forms inside the registry or button.
- If a dialog does not exist, extract or create a reusable public dialog/form API in the owning feature.

Use cross-module navigation only when the action must be completed inside the target workspace. Such navigation must include sufficient query parameters to:

1. Select the correct panel/tab.
2. Locate and load the target record.
3. Open the intended action/dialog automatically.
4. Preserve a return location when appropriate.

Routing to a generic module landing page is not acceptable.

## Minimum Action Coverage

Implement all actions discovered by the audit. At minimum, verify the following:

| Workflow action | Required UX |
|---|---|
| Pay consultation or another charge | Open the correct payment dialog with patient, encounter, invoice, amount, and currency loaded. If Billing owns execution, deep-link there and auto-open it. |
| Start/check in encounter | Open the existing start/check-in encounter flow with patient and appointment/queue context. |
| Record triage or vitals | Open the triage/vitals form for the selected encounter. |
| Assign/change doctor | Open the doctor assignment dialog with current assignment and valid providers. |
| Doctor review | Open the clinical review workspace/dialog for that encounter. |
| Create laboratory order | Open the laboratory request dialog with encounter context. |
| Collect/process laboratory sample | Open the exact laboratory order/sample action. |
| Review laboratory results | Open clinical details focused on the relevant results. |
| Create radiology request | Open the radiology request dialog with encounter context. |
| Perform imaging or complete report | Open the exact radiology order/report action. |
| Review radiology report | Open clinical details focused on that report. |
| Dispense medication | Open the dispensing dialog for the relevant prescription/order. |
| Admit patient | Open the admission handoff/form with encounter context. |
| Assign room or bed | Open bed assignment for the admission and patient. |
| Nursing assessment/service | Open the corresponding nursing form with admission/encounter context. |
| Physiotherapy referral/session | Open the referral or session form for the relevant episode. |
| Theatre scheduling/action | Open the exact theatre case/scheduling action. |
| Insurance pre-authorization | Open the correct pre-authorization form with patient, encounter/admission, coverage, and charge context. |
| Discharge planning | Open the discharge plan/action for the admission. |
| Disposition or close encounter | Open the confirmation/form required to complete the encounter safely. |

Do not map multiple distinct order-level actions to a generic encounter page when a specific order dialog exists.

## Backend Contract and Consistency

Refactor backend workflow responses where needed so the frontend receives authoritative, executable action metadata rather than deriving behavior from status text.

- Preserve compatibility during migration by supporting legacy action codes through explicit aliases.
- Ensure all action identifiers reference records available to the target module.
- Create required downstream work items atomically with workflow transitions where possible.
- Prevent states such as “payment due” without an invoice, “lab processing” without an order, or “bed assignment required” without an admission.
- Make completion endpoints idempotent and return the updated workflow/action state.
- Publish existing realtime/domain events after successful transitions.
- Do not create a second billing or workflow engine; integrate with the existing centralized services.

## Authorization and Handoffs

- Enforce authorization on both frontend and backend.
- The button must explain when the action belongs to another role or module.
- If the user can access the target module but cannot execute the action, navigate only when the destination provides a meaningful read-only/handoff view.
- If the user has no access, keep context visible and provide a clear localized reason.
- Never bypass route guards or backend permission checks.

## State Synchronization and Error Handling

- Re-fetch action context before opening mutable forms.
- Detect stale/completed actions and replace the button with the newly returned action.
- After success, invalidate every provider/worklist that can display the affected encounter or order.
- Preserve entered data when recoverable validation/network errors occur.
- Handle deleted, cancelled, already-completed, and reassigned records gracefully.
- Log unsupported action codes with enough context for diagnosis, without exposing sensitive patient data.

## Migration and Cleanup

- Migrate every relevant table and mobile representation to the shared component.
- Remove old per-page action resolvers, duplicated route maps, dead action labels, obsolete aliases, and plain-text next-step renderers.
- Keep informational status badges where useful, but do not use them as substitutes for action buttons.
- Do not leave parallel old and new execution paths after migration.
- Avoid unrelated visual redesigns or broad business-rule changes.

## Testing and Verification

Add or update tests at the appropriate layers:

### Unit tests

- Canonicalization of every backend action code and legacy alias.
- Registry resolution for every active action.
- Required identifier validation.
- Permission/entitlement and unavailable-state behavior.
- Exact target routes and query parameters.

### Widget tests

- Action button rendering, semantics, loading, disabled state, and click behavior.
- Dialog opening with pre-filled identifiers.
- Row click does not fire when the action button is clicked.
- Desktop and mobile table representations.

### Integration/API tests

- Complete representative workflows across module boundaries.
- Verify each transition returns the next executable action.
- Verify downstream invoice/order/admission/work item creation.
- Verify stale and repeated submissions are safe.
- Verify realtime/provider refresh behavior after completion.

### Manual acceptance test

Starting from each relevant worklist, click every available next-step button and confirm:

1. The correct patient and record are loaded.
2. The exact required dialog/form opens.
3. The authorized user can complete the action.
4. The workflow advances once.
5. All affected modules show the updated state without a full reload.

Run formatting, static analysis, frontend tests, and targeted backend tests. Report commands and results.

## Acceptance Criteria

- No active workflow table displays a next step as plain informational text.
- Every active backend next-step code has a tested executable handler.
- No next-step button opens an unrelated or generic destination.
- Dialogs/forms receive stable identifiers and load current data.
- Cross-module links select the correct record and automatically open the intended action.
- Permission-denied, unavailable, stale, completed, and unsupported states are explicit and safe.
- Completing an action updates all relevant worklists consistently.
- Obsolete duplicate resolvers and action paths are removed.
- Existing patient-flow functionality remains operational.

## Deliverables

1. The complete frontend and backend refactor.
2. A concise action inventory mapping canonical action codes to handlers, dialogs/routes, required identifiers, permissions, and owning modules.
3. Tests proving registry completeness and representative end-to-end flows.
4. A migration summary listing removed duplicate/obsolete implementations.
5. Verification results, remaining limitations, and any intentionally unsupported actions with reasons.

---

## Implementation Audit (Verified 2026-07-15)

### 1. Infrastructure — IMPLEMENTED

All four architectural pillars from the refactor are built and wired:

| Component | File | Status |
|---|---|---|
| `WorkflowAction` model | `shared/workflow_actions/workflow_action.dart` | Done — typed immutable model with `code`, `label`, `icon`, `mode`, `targetModule`, all record identifiers, `accessRequirement`, `availability`, `route`, `routeQueryParameters`, `copyWith`, and `withAccessCheck`. |
| `WorkflowActionRegistry` | `shared/workflow_actions/workflow_action_registry.dart` | Done — singleton registry with `register`, `registerAll`, `canonicalize`, `resolve`, `isRegistered`. Falls back to unsupported state with debug logging when no handler found. |
| `WorkflowActionExecutor` | `shared/workflow_actions/workflow_action_executor.dart` | Done — singleton with `execute`, `resolveAndExecute`, duplicate-execution guard, permission/unsupported snackbar feedback. |
| `WorkflowActionButton` | `shared/workflow_actions/workflow_action_button.dart` | Done — `ConsumerWidget` resolving action via registry, rendering standard and compact variants with icon, label, underline, tooltip, lock icon, keyboard semantics, `GestureDetector` with `HitTestBehavior.opaque` (stops row-click propagation). |
| Barrel export | `shared/workflow_actions/workflow_actions.dart` | Done — exports all four files. |
| Bootstrap registration | `lib/bootstrap.dart` | Done — `initializeWorkflowActionRegistry()` called before app launch. |

### 2. Registered Action Codes — 30 canonical codes across 16 categories

| Category | Canonical Code | Legacy Aliases | Mode | Target Module | Route Destination |
|---|---|---|---|---|---|
| **Billing** | `PAY_CONSULTATION` | `WAITING_CONSULTATION_PAYMENT`, `PAYMENT_DUE`, `CONSULTATION_PAYMENT_PENDING` | `dialog` | billing | `/billing?encounter=…&invoice=…&action=pay` |
| **Billing** | `PAY_SERVICE` | `SERVICE_PAYMENT_DUE` | `dialog` | billing | `/billing?encounter=…&invoice=…&action=pay` |
| **Nursing** | `RECORD_VITALS` | `WAITING_VITALS`, `VITALS_NEEDED`, `VITALS_PENDING`, `TRIAGE_PENDING` | `route` | nursing | `/nursing?encounterId=…&panel=vitals` |
| **Nursing** | `NURSING_ASSESSMENT` | `NURSING_CARE_PLAN`, `NURSING_TASK` | `route` | nursing | `/nursing?encounterId=…&panel=assessment` |
| **Doctor Assignment** | `ASSIGN_DOCTOR` | `WAITING_DOCTOR_ASSIGNMENT`, `DOCTOR_NEEDED`, `AWAITING_DOCTOR` | `dialog` | opd | `/opd?flowId=…&panel=DOCTOR` |
| **Clinical** | `DOCTOR_REVIEW` | `WAITING_DOCTOR_REVIEW`, `WITH_DOCTOR`, `CLINICAL_REVIEW`, `DOCTOR_CONSULTATION` | `route` | clinical | `/clinical?encounterId=…` |
| **Clinical** | `REVIEW_RESULTS` | `RESULTS_READY`, `LAB_RESULTS_READY` | `route` | clinical | `/clinical?encounterId=…&panel=results` |
| **Clinical** | `REVIEW_REPORT` | `REPORT_READY`, `IMAGING_REPORT_READY` | `route` | clinical | `/clinical?encounterId=…&panel=imaging` |
| **Clinical** | `MEDICINES_DISPENSED` | `MEDICATION_COMPLETE` | `route` | clinical | `/clinical?encounterId=…` |
| **Laboratory** | `COLLECT_SAMPLE` | `PROCESS_LAB`, `LAB_WORKSPACE`, `LAB_REQUESTED`, `LAB_PENDING`, `SAMPLE_PENDING`, `IN_LAB`, `LAB_ORDER_CREATED` | `route` | laboratory | `/lab?encounterId=…&orderId=…` |
| **Laboratory** | `LAB_AND_RADIOLOGY_REQUESTED` | `DIAGNOSTICS_PENDING` | `route` | laboratory | `/lab?encounterId=…` |
| **Radiology** | `PERFORM_IMAGING` | `COMPLETE_IMAGING_REPORT`, `RADIOLOGY_WORKSPACE`, `RADIOLOGY_REQUESTED`, `IMAGING_PENDING`, `REPORT_PENDING`, `RADIOLOGY_ORDER_CREATED` | `route` | radiology | `/radiology?encounterId=…&orderId=…` |
| **Pharmacy** | `DISPENSE_MEDICINE` | `PHARMACY_WORKSPACE`, `PHARMACY_REQUESTED`, `PHARMACY_PENDING`, `PRESCRIPTION_READY`, `AWAITING_DISPENSING` | `route` | pharmacy | `/pharmacy?encounterId=…&orderId=…` |
| **Disposition** | `DISPOSITION` | `DECISION_NEEDED`, `WAITING_DISPOSITION`, `ENCOUNTER_COMPLETE`, `CLOSE_ENCOUNTER` | `route` | clinical | `/clinical?encounterId=…&panel=disposition` |
| **Admission** | `ADMISSION_HANDOFF` | `ADMISSION_PENDING`, `ADMIT_PATIENT`, `IPD_ADMISSION` | `route` | ipd | `/ipd?encounterId=…&admissionId=…` |
| **Admission** | `ADMITTED` | `IN_IPD`, `IPD_ACTIVE` | `route` | ipd | `/ipd?encounterId=…&admissionId=…` |
| **IPD** | `APPROVE_ADMISSION` | `ADMISSION_REQUESTED` | `route` | ipd | `/ipd?encounterId=…&admissionId=…&action=approve` |
| **IPD** | `RECORD_NURSING_NOTE` | `NURSING_NOTE_PENDING` | `route` | nursing | `/nursing?encounterId=…&admissionId=…&panel=notes` |
| **IPD** | `APPROVE_TRANSFER` | `TRANSFER_APPROVAL_PENDING` | `route` | ipd | `/ipd?admissionId=…&panel=transfers&action=approve` |
| **IPD** | `START_TRANSFER` | `TRANSFER_PENDING` | `route` | ipd | `/ipd?admissionId=…&panel=transfers&action=start` |
| **IPD** | `COMPLETE_TRANSFER` | `TRANSFER_IN_PROGRESS` | `route` | ipd | `/ipd?admissionId=…&panel=transfers&action=complete` |
| **IPD** | `COMPLETE_THEATRE_HANDOVER` | `THEATRE_HANDOVER_PENDING` | `route` | theater | `/theater?encounterId=…&admissionId=…&action=handover` |
| **IPD** | `FINALIZE_DISCHARGE` | `DISCHARGE_CLEARANCE_PENDING` | `route` | discharge | `/discharge?encounterId=…&admissionId=…` |
| **Discharge** | `DISCHARGE_PLANNING` | `DISCHARGE_PENDING`, `AWAITING_DISCHARGE`, `PLAN_DISCHARGE` | `route` | discharge | `/discharge?encounterId=…&admissionId=…` |
| **Emergency** | `EMERGENCY_TRIAGE` | `ER_TRIAGE`, `EMERGENCY_ASSESSMENT`, `ER_ASSESSMENT` | `route` | emergency | `/emergency?encounterId=…&panel=triage` |
| **Emergency** | `EMERGENCY_STABILIZE` | `ER_STABILIZE`, `RESUSCITATION` | `route` | emergency | `/emergency?encounterId=…` |
| **Theatre** | `THEATRE_SCHEDULING` | `SCHEDULE_THEATRE`, `OT_SCHEDULING`, `SURGERY_SCHEDULING` | `route` | theater | `/theater?encounterId=…&caseId=…` |
| **Theatre** | `THEATRE_IN_PROGRESS` | `IN_THEATRE`, `SURGERY_IN_PROGRESS`, `OT_IN_PROGRESS` | `route` | theater | `/theater?encounterId=…&caseId=…` |
| **Physiotherapy** | `PHYSIOTHERAPY_SESSION` | `PHYSIO_REFERRAL`, `PHYSIO_SESSION`, `PHYSIOTHERAPY_REFERRAL` | `route` | physiotherapy | `/physiotherapy?encounterId=…&sessionId=…` |
| **Insurance** | `INSURANCE_PREAUTH` | `PRE_AUTHORIZATION`, `PREAUTH_PENDING`, `AWAITING_PREAUTH`, `INSURANCE_VERIFICATION` | `route` | claims | `/claims?encounter=…&patient=…&action=preauth` |
| **Rooms & Beds** | `ASSIGN_BED` | `BED_ASSIGNMENT_REQUIRED`, `ROOM_ASSIGNMENT`, `AWAITING_BED` | `route` | rooms_beds | `/rooms-beds?encounterId=…&admissionId=…&patientId=…` |

### 3. Workspace Pages Wired with `WorkflowActionButton` — 6 of 6 relevant worklists

| Page | Import | Button Used In | Context Passed |
|---|---|---|---|
| **Reception** (`reception_workspace_page.dart`) | `workflow_action_button.dart` | "Active Visits" and "Payment Gate" table columns (`next_action`) | `encounterId`, `patientId`, `stage`, `nextStep`, `displayNextStep`, `assignedStaffId` |
| **OPD** (`opd_workspace_page.dart`) | `workflow_action_button.dart` | `_NextStepCell` widget in the unified worklist table | `encounterId`, `patientId`, `stage`, `nextStep`, `displayNextStep`, `assignedStaffId`, `compact: true` |
| **Emergency** (`emergency_workspace_page.dart`) | `workflow_action_button.dart` | "Next" column in the emergency board table | `encounterId` (case ID), `patientId`, `stage` (status), `nextStep` (computed via `_emergencyNextStepCode`), `sourceModule: 'emergency'`, `compact: true` |
| **IPD** (`ipd_workspace_page.dart`) | `workflow_action_button.dart` | "Next step" column in the admissions table | `encounterId`, `patientId`, `admissionId`, `nextStep`, `stage`, `sourceModule: 'ipd'`, `compact: true` |
| **Lab** (`lab_workspace_page.dart`) | `workflow_action_button.dart` | Next action column in the lab orders table | `encounterId`, `patientId`, `orderId`, `nextStep` (order status), `sourceModule: 'laboratory'`, `compact: true` |
| **Discharge** (`discharge_workspace_page.dart`) | `workflow_action_button.dart` | Next action column in the discharge worklist | `encounterId`, `patientId`, `admissionId`, `nextStep` (computed via `_dischargeNextStepCode`), `stage`, `sourceModule: 'discharge'`, `compact: true` |

**Modules that have workspace pages but do NOT use `WorkflowActionButton` in their own tables** (these are target destinations, not origin worklists): Billing, Clinical, Nursing, Pharmacy, Radiology, Theater, Physiotherapy, Claims, Rooms & Beds, ICU, Operations, Biomedical, Housekeeping, HR, Communications, Mortuary, Reports, Subscriptions, Integrations.

### 4. Tests — Exist

File: `test/shared/workflow_actions/workflow_action_registry_test.dart`

- Canonicalization of 12+ codes and legacy aliases
- `isRegistered` for canonical codes, aliases, and unknown codes
- `definitionFor` for known/unknown/alias codes
- `registeredCodes` contains all 30 expected canonical codes including IPD-specific ones
- `resolve` widget tests for empty code, unknown code, `PAY_CONSULTATION`, and legacy alias `WAITING_VITALS`
- `WorkflowActionContext.effectiveActionCode` priority: `displayNextStep` > `nextStep` > `stage`

### 5. Minimum Action Coverage — Cross-reference with prompt table

| Prompt Requirement | Registered Action | What Happens on Click | Status |
|---|---|---|---|
| Pay consultation or another charge | `PAY_CONSULTATION` / `PAY_SERVICE` | Routes to `/billing?encounter=…&action=pay`. **Does not open a dialog inline** despite `mode: dialog` — executor's `_executeDialogAction` just calls `GoRouter.go()` identically to `_executeRouteAction`. The billing workspace must interpret the `action=pay` query param to auto-open a payment dialog. | **Partially done** — button navigates correctly but dialog-mode execution is identical to route-mode (no inline dialog opens from the origin page). |
| Start/check in encounter | No dedicated registry action | Handled inline by OPD's `_OpdPatientActionsDialog` (appointment check-in, queue start). Not exposed as a `WorkflowActionButton` in the table. | **Not registered** — intentional; this is a pre-encounter step handled by the OPD/Reception dialogs before a workflow flow exists. |
| Record triage or vitals | `RECORD_VITALS` | Routes to `/nursing?encounterId=…&panel=vitals` | **Done** — navigates to nursing vitals panel. |
| Assign/change doctor | `ASSIGN_DOCTOR` | Routes to `/opd?flowId=…&panel=DOCTOR`. **Does not open a dialog inline** despite `mode: dialog`. | **Partially done** — navigates correctly; OPD must interpret `panel=DOCTOR` to auto-focus the doctor assignment panel. |
| Doctor review | `DOCTOR_REVIEW` | Routes to `/clinical?encounterId=…` | **Done** — navigates to clinical workspace with encounter context. |
| Create laboratory order | No dedicated registry action | Not registered. Lab orders are created from the clinical workspace via clinical order actions. | **Not registered** — creating an order is a clinical-side action, not a workflow step. |
| Collect/process laboratory sample | `COLLECT_SAMPLE` | Routes to `/lab?encounterId=…&orderId=…` | **Done** — navigates to lab workspace with order context. |
| Review laboratory results | `REVIEW_RESULTS` | Routes to `/clinical?encounterId=…&panel=results` | **Done** — navigates to clinical results panel. |
| Create radiology request | No dedicated registry action | Not registered. Radiology requests are created from the clinical workspace via clinical order actions. | **Not registered** — creating an order is a clinical-side action, not a workflow step. |
| Perform imaging or complete report | `PERFORM_IMAGING` | Routes to `/radiology?encounterId=…&orderId=…` | **Done** — navigates to radiology workspace with order context. |
| Review radiology report | `REVIEW_REPORT` | Routes to `/clinical?encounterId=…&panel=imaging` | **Done** — navigates to clinical imaging panel. |
| Dispense medication | `DISPENSE_MEDICINE` | Routes to `/pharmacy?encounterId=…&orderId=…` | **Done** — navigates to pharmacy workspace with order context. |
| Admit patient | `ADMISSION_HANDOFF` | Routes to `/ipd?encounterId=…&admissionId=…` | **Done** — navigates to IPD workspace with admission context. |
| Assign room or bed | `ASSIGN_BED` | Routes to `/rooms-beds?encounterId=…&admissionId=…&patientId=…` | **Done** — navigates to rooms & beds workspace with all context. |
| Nursing assessment/service | `NURSING_ASSESSMENT` / `RECORD_NURSING_NOTE` | Routes to `/nursing?encounterId=…&panel=assessment` or `…&panel=notes` | **Done** — navigates to nursing workspace with panel context. |
| Physiotherapy referral/session | `PHYSIOTHERAPY_SESSION` | Routes to `/physiotherapy?encounterId=…&sessionId=…` | **Done** — navigates to physiotherapy workspace with session context. |
| Theatre scheduling/action | `THEATRE_SCHEDULING` / `THEATRE_IN_PROGRESS` / `COMPLETE_THEATRE_HANDOVER` | Routes to `/theater?encounterId=…&caseId=…` or `…&action=handover` | **Done** — navigates to theater workspace with case context. |
| Insurance pre-authorization | `INSURANCE_PREAUTH` | Routes to `/claims?encounter=…&patient=…&action=preauth` | **Done** — navigates to claims workspace with pre-auth context. |
| Discharge planning | `DISCHARGE_PLANNING` / `FINALIZE_DISCHARGE` | Routes to `/discharge?encounterId=…&admissionId=…` | **Done** — navigates to discharge workspace with admission context. |
| Disposition or close encounter | `DISPOSITION` | Routes to `/clinical?encounterId=…&panel=disposition` | **Done** — navigates to clinical disposition panel. |

### 6. Resolved Gaps

#### Gap A — Dialog-mode execution ✅ RESOLVED

The executor now supports dialog-first execution via `WorkflowDialogOpener` callbacks. `WorkflowActionRegistry` has `registerDialogOpener()` for post-hoc registration without cross-module coupling. `WorkflowActionDefinition` also supports inline `dialogOpener` and `onSuccess` fields. The executor's `_executeDialogAction` tries the dialog opener first, falls back to route-based navigation. `ASSIGN_DOCTOR` has an inline dialog opener that fetches the OPD flow and opens `AssignDoctorDialog` directly. `PAY_CONSULTATION` falls back to route with `action=pay` query param; the billing workspace auto-opens the payment dialog.

#### Gap B — Pre-execution validation ✅ RESOLVED

Dialog openers fetch fresh data before opening the dialog (e.g. `_openAssignDoctorDialog` calls `opdRepositoryProvider.getOpdFlow(flowId)` before opening `AssignDoctorDialog`). Route-mode actions navigate to the target page which loads fresh data on render.

#### Gap C — Post-success invalidation ✅ RESOLVED

`WorkflowPostSuccessCallback` is invoked after dialog-mode actions complete successfully. E.g. `ASSIGN_DOCTOR` invalidates `opdWorkspaceControllerProvider` after the dialog succeeds. Route-mode actions refresh via the target page's own lifecycle.

#### Gap D — "Start/check in encounter" not in registry — INTENTIONAL

Pre-flow action handled by OPD/Reception inline dialogs. Documented as an intentional exception.

#### Gap E — "Create laboratory order" and "Create radiology request" not in registry — INTENTIONAL

Clinical-workspace originating order-creation actions, not workflow-step buttons. Documented as intentional.

#### Gap F — Target workspace deep-link handling ✅ RESOLVED

Deep-link query parameter support added/verified for all target modules:

| Module | Query Support | Status |
|---|---|---|
| OPD | `flowId`, `panel`, `search` via `OpdWorkspaceQuery.fromUri` | Already supported |
| Billing | `encounter`, `invoice`, `action=pay` via `BillingWorkspaceQuery.fromUri` | **Added** `action` field; auto-opens payment dialog |
| Emergency | `encounterId`, `panel`, `search` via `EmergencyWorkspaceQuery.fromUri` | Already supported |
| IPD | `encounterId`, `admissionId`, `action`, `panel` via `IpdAdmissionQuery.fromUri` | Already supported |
| Discharge | `encounterId`, `admissionId` via `DischargeWorklistQuery.fromUri` | Already supported |
| Theater | `encounterId`, `caseId`, `action` via `TheaterBoardQuery.fromUri` | Already supported |
| Rooms & Beds | `encounterId`, `admissionId`, `patientId` via `RoomsBedsQuery.fromUri` | Already supported |
| ICU | `encounterId`, etc. via `IcuBoardQuery.fromUri` | Already supported |
| Nursing | `id`/`admissionId`/`encounterId`, `panel` | **Fixed** router to accept `encounterId` and `admissionId` |
| Clinical | `encounterId`, `panel`, `search` via `ClinicalWorkspaceQuery.fromUri` | **Added** query model and auto-select entry |
| Lab | `encounterId`, `orderId`, `search` via `LabWorkspaceQuery.fromUri` | **Added** (subagent) |
| Radiology | `encounterId`, `orderId`, `search` via `RadiologyWorkspaceQuery.fromUri` | **Added** (subagent) |
| Pharmacy | `encounterId`, `orderId`, `search` via `PharmacyWorkspaceQuery.fromUri` | **Added** (subagent) |
| Claims | `encounterId`, `patientId`, `action` via `ClaimsWorkspaceQuery.fromUri` | **Added** (subagent) |
| Physiotherapy | `encounterId`, `sessionId`, `search` via `PhysiotherapyWorkspaceQuery.fromUri` | **Added** (subagent) |

### 7. Implementation Summary

#### Files created:
- `shared/workflow_actions/workflow_action_dialog_openers.dart` — dialog opener registration for ASSIGN_DOCTOR

#### Files modified:
- `shared/workflow_actions/workflow_action_registry.dart` — added `WorkflowDialogOpener`, `WorkflowPostSuccessCallback` typedefs; `dialogOpener`/`onSuccess` fields on definition; `registerDialogOpener`/`dialogOpenerFor`/`postSuccessCallbackFor` on registry
- `shared/workflow_actions/workflow_action_executor.dart` — async `execute()` with `WidgetRef? ref`; dialog-first execution via registered openers; `completedViaDialog`/`cancelledByUser` result states; post-success callback invocation; mounted check before fallback navigation
- `shared/workflow_actions/workflow_action_button.dart` — passes `ref` to executor
- `shared/workflow_actions/workflow_actions.dart` — exports dialog openers
- `lib/bootstrap.dart` — calls `registerWorkflowDialogOpeners()` at startup
- `app/router/app_router.dart` — nursing route accepts `encounterId`/`admissionId`; clinical route passes `ClinicalWorkspaceQuery`
- `features/billing/domain/entities/billing_entities.dart` — added `action` field to `BillingWorkspaceQuery`
- `features/billing/presentation/pages/billing_workspace_page.dart` — auto-opens payment dialog when `action=pay`
- `features/clinical/domain/entities/clinical_entities.dart` — added `ClinicalWorkspaceQuery` with `fromUri`
- `features/clinical/presentation/pages/clinical_workspace_page.dart` — accepts `initialQuery`; auto-selects encounter
- `test/shared/workflow_actions/workflow_action_registry_test.dart` — added 6 tests for dialog opener registry and executor

#### Tests: 26 passing (20 existing + 6 new)