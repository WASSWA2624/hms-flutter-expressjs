# Implementation Prompt: Refactor HMS Laboratory Workflow Into Result Entry, Verification, Reference Range, and Reporting Flow

You are working on the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Implement a focused refactor of the Laboratory module so it behaves like a practical lab result-entry and reporting workflow, not a sample-collection workflow.

## 1. Problem to solve

The current lab workspace is too sample-centric. It exposes primary actions and labels such as **Collect sample**, **Receive sample**, **Waiting sample**, **Sample**, and a prominent **Record QC** action.

The intended workflow is:

1. A doctor/user requests lab tests or panels.
2. Lab staff see the requested tests.
3. Lab staff enter result values for each requested test.
4. The backend applies configured reference ranges/result options.
5. The backend flags results as normal, low, high, abnormal, critical, etc.
6. Lab staff verify one result or verify all entered results in a batch.
7. Verified results become visible to requester/doctor-facing clinical areas.
8. Report preview/copy output shows patient/order details, result values, units, reference ranges, and flags.

Do not turn this into a device/equipment workflow. The lab module is for entering, verifying, interpreting, and reporting manually performed lab results.

## 2. Important archive findings

Use the actual codebase as the source of truth.

No task-specific screenshots were found in the archive. The only image files found are app/logo/splash/icon assets. Therefore, all UI/UX requirements below are derived from the raw task and the existing codebase.

The raw task also exists in:

* `app-planner/prompt.md`
* `app-planner/external-prompt-prefix.md`

Use planner docs for guidance only unless project conventions require implementation notes.

## 3. Relevant project areas to inspect or modify

### Planner/reference files

Inspect for architecture and UI conventions:

* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/02-codebase.md`
* Relevant app rules under `app-planner`

Do not modify planner files unless existing project conventions explicitly require documentation updates.

### Backend files

Inspect and modify only where needed:

* `backend/prisma/schema.prisma`
* `backend/src/app/router.js`
* `backend/src/modules/lab-workspace/routes/lab-workspace.routes.js`
* `backend/src/modules/lab-workspace/controllers/lab-workspace.controller.js`
* `backend/src/modules/lab-workspace/services/lab-workspace.service.js`
* `backend/src/modules/lab-workspace/services/lab.serializer.js`
* `backend/src/modules/lab-workspace/services/lab.shared.js`
* `backend/src/modules/lab-workspace/services/lab.interpretation.js`
* `backend/src/modules/lab-workspace/services/lab.configuration.js`
* `backend/src/modules/lab-workspace/schemas/lab-workspace.schema.js`
* `backend/src/modules/lab-test/**`
* `backend/src/modules/lab-panel/**`
* `backend/src/modules/lab-order/**`
* `backend/src/modules/opd-flow/services/opd-flow.service.js`
* Any requester/doctor-facing backend consumer of lab result data, only if required
* Relevant backend tests under `backend/src/tests/**`

Confirmed backend facts:

* `lab.interpretation.js` already evaluates numeric, qualitative, and text results.
* Lab test reference ranges, unit options, and result options already exist in the backend lab-test model/service.
* Lab panels already expand into individual `lab_order_item` records through lab-order logic.
* `releaseLabOrderItem` already creates/updates `lab_result` and computes interpretation.
* There is no obvious existing batch result verification endpoint.
* Current rejection is sample-level, not clearly durable per order item/test.
* The lab workspace controller currently needs verification that it passes the `view` query parameter through to the service so the patient/order toggle works as intended.

### Frontend files

Inspect and modify only where needed:

* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* `frontend/lib/core/network/api_endpoints.dart`, only if new endpoint constants are needed
* `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`
* `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart`
* `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
* Existing localization files, including:

  * `frontend/lib/l10n/app_en.arb`
  * generated localization Dart files, if this project keeps them committed

Confirmed frontend facts:

* The lab workspace uses Flutter with the existing DTO/entity/repository/controller/page pattern.
* The lab workspace uses shared UI patterns such as `AppWorkspace`, `AppListTable`, dialogs, badges, report preview/copy actions, and async state handling.
* The current lab page has:

  * Laboratory title
  * green `Live sync` indicator
  * Patients/orders view toggle
  * Refresh action
  * prominent `Record QC` action
  * sample-centered summary labels
  * sample column
  * detail dialog with `Collect sample`, `Receive sample`, sample sections, result release dialog, and report preview
* The current detail header shows lab order ID as copyable but does not correctly expose a copyable patient ID.
* The current result dialog lets the frontend choose result status manually. This must be replaced or constrained so the backend interpretation is authoritative.
* Patient-group rows may represent multiple active lab orders. Do not silently open only one order.

## 4. Architecture and style rules

Preserve the existing architecture.

* Do not introduce a new frontend state-management pattern.
* Do not introduce a new UI framework.
* Do not rewrite unrelated modules.
* Do not duplicate backend result interpretation in the frontend.
* Do not create duplicate DTOs/entities/services when existing ones can be extended.
* Do not hardcode new user-facing strings if the feature uses localization.
* Preserve backend route/controller/service/schema/serializer patterns.
* Preserve existing authorization and role patterns.
* Preserve realtime/event behavior for lab workflow updates.
* Modify only files required for this lab workflow change.
* Clear all linter/analyzer issues.

## 5. Main lab workspace UI requirements

Keep the existing Laboratory workspace visual style:

* Page title: `Laboratory`
* Green live-sync indicator
* Patients/orders toggle
* Refresh action
* Existing table/workspace layout language

Change the visible workflow language away from sample collection.

Replace or remove sample-centered labels:

| Current concept                   | Required direction                                   |
| --------------------------------- | ---------------------------------------------------- |
| `Waiting sample`                  | `Awaiting results`, `Pending results`, or equivalent |
| `Patients waiting sample`         | Result-entry-oriented wording                        |
| `Sample` primary column           | Remove or replace with result/status-oriented column |
| `Collect sample` primary action   | Remove from primary lab workflow                     |
| `Receive sample` primary action   | Remove from primary lab workflow                     |
| `Release result` primary UI label | Prefer `Verify result`                               |
| `Record QC` top-level action      | Remove/hide from primary action bar                  |

The primary worklist should emphasize:

* Patient
* Patient ID
* Encounter ID, if available
* Lab order ID
* Requested tests/panels
* Result status
* Next action

Do not delete backend sample models/routes simply because the primary UI no longer shows sample collection.

## 6. QC behavior

The current top-level `Record QC` button is confusing in the main lab workflow.

Required behavior:

* Remove or hide `Record QC` from the primary lab action bar.
* Do not delete backend QC routes/models unless proven unused and deletion is truly required.
* If QC remains accessible, move it to a less prominent catalog/configuration/admin-style area and label it clearly, for example `QC logs`.

## 7. Lab detail dialog requirements

Refactor the lab detail dialog into a compact lab order/result entry screen.

Remove from the primary detail dialog:

* `Collect sample`
* `Receive sample`
* sample-first actions
* sample-first empty states such as `No samples recorded`
* large bordered cards that waste space for simple label/value data

The top section must display compact patient/order information:

* Patient name
* Patient ID, visible and copyable
* Encounter ID, only if available
* Lab order ID, visible and copyable
* Ordered date/time
* Order/result status
* Requested tests/panels summary

Rules:

* Do not show `Not available` when an optional field can be omitted.
* Do not show `Not available` for patient ID if a patient identifier exists in workflow/order data.
* Do not render an empty encounter value as copyable.
* Preserve existing HMS spacing, badge, typography, and dialog style.

## 8. Multiple lab orders in patient view

In patients view, one patient row may represent multiple active lab orders.

Verify how grouped rows are represented by `LabOrderSummary`.

If a row represents multiple orders:

* Do not silently open only the representative order.
* Show all active lab orders for that patient, or provide a compact order selector/list inside the detail dialog.
* Each order must expose its own tests, result entry state, result status, and actions.
* Use the existing `orderIds`, `orderDisplayIds`, and patient-group fields where possible.
* Add only the smallest backend/frontend support needed if existing data is insufficient.

## 9. Ordered tests and result entry requirements

Inside the lab detail dialog, replace the sample-first sections with a compact ordered tests/result entry table or list.

Each ordered test row should include, where data exists:

* Test name
* Test code
* Result kind/type
* Unit
* Result input or released value
* Reference range or qualitative options
* Result flag/status
* Row action

Input behavior:

| Result kind | Required input                                            |
| ----------- | --------------------------------------------------------- |
| Numeric     | numeric input, unit/default unit, reference range display |
| Qualitative | dropdown/options if configured                            |
| Text        | text input/textarea                                       |

Rules:

* Do not collapse a panel into one vague row if individual panel tests require individual result values.
* Show component tests for ordered panels.
* Do not let the frontend manually decide final result status.
* The backend must compute interpretation using configured reference ranges/result options.
* Prevent double submission while a result is saving/verifying.
* Show validation/server errors using existing HMS UI patterns.
* After verification, refresh the selected order/workflow and worklist.

Use user-facing action labels such as:

* `Enter result`
* `Save result`
* `Verify result`
* `Verify all`

Avoid using `Release result` as the main user-facing label.

## 10. Individual and batch verification

Implement or reuse backend-supported result verification.

Required behavior:

* Verify/save one result at a time.
* Verify/save all entered results in a batch.
* Use the existing backend result interpretation logic.
* Return updated workflow/order data after verification.
* Preserve realtime updates so requester-facing views refresh.

If the existing release endpoint is sufficient for individual verification, keep the backend endpoint but change the user-facing wording to `Verify result`.

If batch verification is not currently supported, add a focused endpoint following existing route/controller/schema/service conventions.

## 11. Test/order-item rejection

Add a way to reject a requested test/order item with a required reason.

Required behavior:

* Rejection must apply to the requested test/order item, not only to a sample.
* A rejection reason is required.
* Suggested reason options:

  * `Test not performed here`
  * `Insufficient information`
  * `Invalid request`
  * free-text reason

Before adding schema fields, verify whether durable per-test rejection already exists.

If it does not exist, add the smallest safe Prisma/API extension required, for example nullable rejection metadata on `lab_order_item`.

Do not delete unrelated order/sample behavior while adding this.

## 12. Reference range configuration

The lab module must expose a way to configure lab test reference ranges.

Use existing backend lab-test support where possible.

The UI should allow lab users/admins to add or update lab test configuration, including:

* Test name
* Code
* Category
* Specimen type, if supported
* Result kind
* Default unit
* Unit options, if supported
* Qualitative result options, if supported
* Reference ranges

Reference range fields should match the existing backend model/support:

* Label
* Gender applicability
* Age minimum/maximum values
* Age units
* Unit
* Normal minimum/maximum values
* Critical minimum/maximum values
* Reference text
* Notes, if supported
* Sort order, if supported

Validation requirements:

* Validate numeric ranges in the UI.
* Keep backend schema validation authoritative.
* Show clear errors using existing UI patterns.
* Reuse existing `/api/v1/lab-tests` create/update patterns where possible.
* Do not create a duplicate reference-range API if the existing lab-test API can handle it.

## 13. Backend implementation requirements

Implement the smallest backend changes needed.

Required backend behavior:

* Reuse `backend/src/modules/lab-workspace/services/lab.interpretation.js`.

* Ensure numeric results are interpreted against configured reference ranges using patient demographics where available.

* Ensure qualitative/text results use configured result options or existing interpretation logic.

* Ensure serialized workflow/order data exposes enough information for the frontend to show:

  * patient ID
  * encounter ID
  * lab order IDs
  * ordered tests
  * test result kind
  * current result values
  * result units
  * result text
  * reference ranges
  * qualitative result options
  * result flags/statuses
  * rejection status/reason, if applicable

* Fix the lab workspace query flow if the `view` query parameter is not currently passed from controller to service.

* Support individual result verification using the existing release/verify logic if suitable.

* Add backend-supported batch verification if the current API cannot safely verify multiple results in one operation.

* Add order-item rejection with required reason if not already supported.

* Preserve lab realtime notifications when results are verified or rejected.

* Preserve existing authorization/role patterns.

* Update schemas and OpenAPI-related validation if API contracts change.

* Add Prisma migration only if the current schema cannot durably store required data.

Do not duplicate result interpretation logic in frontend code.

## 14. Frontend implementation requirements

Update the lab frontend while preserving the existing feature architecture.

Required frontend changes:

* Update lab DTOs/entities to parse any new backend fields.

* Update repository methods for:

  * individual result verification
  * batch result verification
  * order-item rejection
  * lab test/reference range configuration, if not already exposed

* Update the lab controller without changing the state-management pattern.

* Redesign the lab detail dialog inside the existing lab workspace page/components.

* Keep refresh/live-sync behavior working.

* Keep patients/orders toggle working.

* Use backend-provided interpretation/status/flag data.

* Do not manually compute final result status in the frontend.

* Ensure copy actions exist for both patient ID and lab order ID.

* Update localization for new/changed labels where applicable.

UI styling requirements:

* clean spacing
* compact rows
* minimal borders
* clear status badges
* readable table/list layout
* no crowded multi-card layout for simple label/value data
* consistent with existing HMS shared components

## 15. Report preview/copy requirements

Improve the existing lab report preview/copy output.

The report must include:

* Patient name
* Patient ID
* Encounter ID, only if available
* Lab order ID
* Ordered date/time, if available
* Test name
* Test code, if available
* Result value
* Unit
* Reference range
* Result flag/status
* Verified/reported timestamp, if available

Rules:

* Do not print empty `Not available` lines.
* Omit optional missing fields instead.
* Reuse existing report preview/copy components.
* If the project already has a shared print/export/report pattern, reuse it instead of creating an unrelated printing flow.

## 16. Requester/doctor-facing behavior

After lab results are verified:

* The order should no longer appear as merely ordered/pending.
* Clinical/requester-facing areas should show completed/verified result details.
* Result values, units, reference ranges, and flags should be available wherever lab results are displayed.

Inspect existing clinical/frontend and OPD/backend result consumers.

Modify only the minimum required files if clinical/requester views do not already receive or display this data.

## 17. Testing and verification

Clear all linter/analyzer issues.

Run or update relevant checks.

### Backend checks

Run where applicable:

* `npm run lint`
* targeted backend tests for lab workspace/lab test/lab order/lab result changes
* `npm run test:backend`, if feasible
* `npm run openapi:validate`, if API contracts changed

Add or update backend tests for:

* lab workspace `view` query behavior, if fixed
* numeric reference range interpretation
* low/high/critical flagging
* qualitative result option interpretation
* individual result verification
* batch result verification
* order-item rejection with required reason
* durable rejection serialization, if schema is extended
* workflow serialization fields required by the frontend

### Frontend checks

Run where applicable:

* `flutter analyze`
* `flutter test`

Add or update frontend tests where the project has test patterns for:

* DTO/entity parsing for result metadata
* reference ranges
* qualitative result options
* verified result values
* result flags/statuses
* controller/repository methods for verify/reject/configuration actions

### Manual verification

Manually verify:

* Patients/orders toggle works.
* Summary cards use result-oriented wording.
* `Record QC` is no longer prominent in the main workflow.
* Lab detail opens cleanly.
* Patient ID is visible and copyable.
* Lab order ID is visible and copyable.
* Empty encounter ID is omitted.
* Multiple active orders for one patient are not silently collapsed into one order.
* Ordered tests and panel component tests are visible.
* Numeric result entry works.
* Qualitative result entry works when options exist.
* Text result entry works.
* `Verify result` works for one result.
* `Verify all` works for multiple entered results.
* Backend-generated result flags appear automatically.
* Rejection requires a reason.
* Report preview/copy includes result, unit, range, and flag.
* Requester/clinical views update after verification.

## 18. Scope limits

Do not:

* rewrite the whole lab module
* remove backend sample models/routes unless absolutely necessary
* remove backend QC support unless proven unused and required
* change unrelated OPD, IPD, billing, pharmacy, authentication, or layout code
* change global theme/layout unless required by existing component usage
* introduce unrelated refactors
* include generated build outputs, logs, screenshots, dependencies, `node_modules`, Flutter build folders, or the full project in the final archive

Modify only files required for this requested change.

## 19. Unclear details to verify from the codebase

Before implementing, verify these from the codebase and handle them without guessing:

* Whether QC should be hidden only from the main lab screen or moved to an existing catalog/admin area.
* Whether durable per-test/order-item rejection storage already exists.
* Whether requester/clinical views already receive released result values, ranges, and flags.
* Whether patient-group rows already include enough order IDs to show all active orders.
* Whether current report copy behavior is enough or an existing shared report/export pattern should be reused.
* Whether generated localization files are committed and must be updated manually or through the project’s localization generation workflow.

## 20. Final delivery format

Return a zipped archive containing only files and folders that were created or updated.

All files must be placed in their correct relative project paths.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those operations.

The scripts must:

* use correct relative paths
* check that targets exist before deleting or renaming
* avoid deleting unrelated files
* avoid broad wildcards

Do not include the full repository.
