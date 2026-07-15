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