# Implementation Prompt: Refine Lab Worklist View Switching, Enforce Valid Lab Orders, and Simplify Result Entry

You are working in the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Implement the next Lab module improvements using the existing architecture, folder structure, naming conventions, coding style, shared components, localization system, permission gates, realtime sync patterns, and UI patterns already present in the project.

## Problem to solve

The Lab workspace is close to the desired workflow, but the result-entry flow is still not simple enough and some invalid lab orders can appear without tests.

Fix the following:

1. In the Lab worklist, the primary column must change based on the selected view:

   * In **Patients view**, the **Patient** column must appear first.
   * In **Orders view**, the **Order/Orders** column must appear first.

2. A lab order must never exist without at least one resolved lab test item.

   * Creating a lab order with no selected tests/panels must be blocked.
   * Creating a lab order from an empty panel must be blocked.
   * Updating an order must not leave it with zero active tests.
   * Existing invalid lab orders with no active tests must be safely removed or hidden according to backend soft-delete patterns.

3. The Lab result entry screen must make adding, editing, verifying, and removing results obvious and fast.

   * The user must clearly see the ordered tests.
   * Each test must show reference range, editable result value, and flag.
   * Existing results must be editable where business rules permit.
   * Draft/pending results must be removable.
   * Single tests must be removable/rejected safely without deleting unrelated order data.

4. The patient/order detail header in the result-entry dialog must be simplified.

   * Do not show a patient avatar.
   * Do not display patient details as large cards.
   * Show clean property/value pairs instead.

5. Keep the existing professional report preview and shared print system working.

## Relevant project areas to inspect and modify

### Frontend

Inspect and modify only where required:

* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
* `frontend/lib/shared/components/*`
* `frontend/lib/shared/forms/*`
* `frontend/lib/shared/printing/*`
* `frontend/lib/l10n/app_en.arb`
* `frontend/lib/l10n/app_localizations.dart`
* `frontend/lib/l10n/app_localizations_en.dart`

Reuse components in `frontend/lib/shared/*` before creating feature-local widgets.

### Backend

Inspect and modify only where required:

* `backend/src/modules/lab-order/*`
* `backend/src/modules/lab-order-item/*`
* `backend/src/modules/lab-result/*`
* `backend/src/modules/lab-workspace/*`
* `backend/prisma/schema.prisma`
* `backend/prisma/migrations/*` only if a schema/data cleanup migration is genuinely required
* `backend/scripts/seeders/seed-clinical-pack.js`
* `backend/scripts/seed-demo-data.js`
* `backend/scripts/verify-demo-data.js`
* Relevant backend tests under `backend/src/tests/modules/lab-*`

Use existing backend response, validation, repository, service, audit, soft-delete, Prisma, and websocket patterns.

### App planner

Use as guidance only unless a change is truly required:

* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `backend/app-planner/app-rules/*`
* `frontend/app-planner/app-rules/*`

Do not edit planner files unless the implementation genuinely requires documentation alignment.

## UI/UX requirements

### Lab worklist

* Preserve the current Lab workspace layout:

  * title: Laboratory
  * live sync status
  * summary cards
  * Patients view / Orders view toggle
  * Create Lab Order action
  * Lab Configurations action
  * Refresh action
  * searchable/filterable `AppListTable`

* In **Patients view**:

  * first main column: Patient
  * second main column: Orders
  * row identity should prioritize patient name and patient ID.

* In **Orders view**:

  * first main column: Order/Orders
  * second main column: Patient
  * row identity should prioritize lab order ID, with patient context after it.

* Apply the same priority on mobile list items:

  * Patients view starts with patient identity.
  * Orders view starts with order identity.

* Do not break sorting, search, filters, pagination, column visibility, row selection, or live refresh.

### Invalid lab orders with no tests

* The UI must not show a usable lab order that has no tests.
* The backend must reject lab order creation/update if the final resolved item list is empty.
* If a panel is selected but resolves to zero tests, reject the request with a localized validation error.
* If existing invalid rows are found, clean them safely:

  * Prefer soft delete using `deleted_at`.
  * Do not hard-delete clinical records.
  * Do not delete unrelated orders.
  * If the invalid rows are from demo seed data, fix the seed/verification logic.
  * If a migration or cleanup script is needed, follow the project’s existing Prisma/script pattern.

### Lab result entry dialog

Replace the current confusing result-entry layout with a simple report-like editable workflow.

The top header must show:

* Patient name
* Patient ID with copy action
* Encounter ID with copy action if available
* Orders included, for example: `1 active order`
* Lab order IDs below the main patient details, each copyable
* Tests summary when available

Do not show:

* patient avatar/icon block
* large card-style patient detail boxes
* empty “Tests Not available” blocks when tests exist

Use simple property/value rows or a compact key/value grid. Use existing shared components such as `AppCopyableIdentifier` where appropriate.

### Ordered tests and result entry

For each selected order, show a clear table-like section similar to the report preview:

| Tests | Reference range | Result | Flag | Actions |
| ----- | --------------- | ------ | ---- | ------- |

Requirements:

* Use `workflow.order.items` as the source of ordered tests.
* If an order was created from a panel, show the resolved child tests from that panel.
* If an order was created from individual tests, show those individual tests.
* Never show an empty ordered-tests area for a valid order.
* The **Result** column must be editable inline:

  * numeric tests: result value field + unit field/select
  * qualitative tests: dropdown/select using configured result options where available
  * text tests: text field/textarea
* Pre-fill existing result data from:

  * `resultValue`
  * `resultUnit`
  * `resultText`
  * `resultFlag`
  * `resultId`
* Show the reference range beside each test.
* Show flags clearly, for example normal, high, low, abnormal, critical, positive.
* Keep abnormal/critical results visually clear but not cluttered.

### Result actions

Each test row must make actions obvious:

* Add result / Save draft for tests without a result
* Edit result for tests with existing result values
* Verify/Submit result where allowed
* Remove draft/pending result where allowed
* Remove/reject a single test where allowed

Use existing APIs where possible:

* Create draft result: `POST /api/v1/lab-results`
* Update result: `PUT /api/v1/lab-results/:id`
* Delete draft/pending result: `DELETE /api/v1/lab-results/:id`
* Verify/release order item: `POST /api/v1/lab/order-items/:id/release`
* Reject/remove order item: `POST /api/v1/lab/order-items/:id/reject`
* Load workflow: `GET /api/v1/lab/orders/:id/workflow`

Important safety rules:

* Do not hard-delete completed clinical data.
* Use confirmation dialogs for destructive actions.
* Preserve audit logging.
* Preserve backend status synchronization for lab order, order item, and result status.
* If a completed/verified result cannot be safely deleted under current rules, allow editing through the safe audited path and make deletion unavailable with a clear localized reason.
* If removing a single test from an already processed order, use the existing reject/cancel item workflow rather than deleting the whole order.

### Report preview and printing

* Keep `LabReportPreviewDialog`, `AppReportPreviewPanel`, `AppReportActionButton`, `PrintFormTemplate`, and `printFormTemplateDocument`.
* Do not print the UI directly.
* The report preview must continue to show:

  * lab order
  * patient context
  * tests
  * reference range
  * result
  * flag
  * signature/stamp section
* The result-entry table should visually align with the report preview table, but remain editable.

## Realtime and refresh requirements

* Preserve the current stable worklist behavior.
* Do not clear/reload the whole table after each mutation.
* After creating/updating/deleting lab orders, entering/editing/removing results, rejecting/removing a test, or changing lab configuration:

  * update the affected selected workflow
  * update the affected worklist row
  * update summary counts
  * update report preview data if open
  * refresh catalogs only when catalog/configuration changes
* If backend result mutations do not currently emit lab realtime events, add appropriate realtime emission using existing websocket/event patterns.
* Keep `LabWorkspaceController` targeted-refresh behavior and avoid disruptive full-screen loading after normal mutations.

## Localization requirements

* Ensure 100% localization.
* Do not add hard-coded user-facing strings.
* Add all new UI labels, validation messages, tooltips, empty states, confirmation titles, button labels, and snackbars to the l10n system.
* Update:

  * `frontend/lib/l10n/app_en.arb`
  * generated localization files if this project tracks them manually
* Ensure `frontend/test/l10n/hard_coded_ui_text_test.dart` still passes.

## Testing and verification

Add or update tests where appropriate.

Backend coverage should include:

* creating a lab order with no tests/panels is rejected
* creating a lab order from an empty panel is rejected
* updating an order cannot leave zero active tests
* existing invalid no-test lab orders are excluded or safely soft-deleted
* result create/update/delete works with friendly IDs
* result verification updates item/order status correctly
* rejecting/removing a single order item does not delete the whole order
* workbench Patients/Orders views still return valid data

Frontend coverage should include where practical:

* Patients view shows Patient column first
* Orders view shows Order/Orders column first
* result-entry dialog renders property/value patient details without avatar cards
* ordered tests render in table-like rows
* result value editing pre-fills existing values
* result draft save / verify / remove actions call the correct controller methods
* no hard-coded UI text is introduced

Run and fix all relevant checks:

Backend:

```bash
cd backend
npm run lint
npm run test:backend
npm run i18n:check
npm run openapi:validate
```

Frontend:

```bash
cd frontend
flutter analyze
flutter test
```

## Scope limits

* Modify only the files required for this Lab task.
* Do not rewrite unrelated modules.
* Do not replace the existing Lab architecture.
* Do not introduce duplicate table, dialog, form, print, permission, or status systems when shared components already exist.
* Do not change unrelated routing, authentication, billing, pharmacy, radiology, OPD, IPD, or dashboard behavior.
* Do not create frontend-only fake workflows. Every state change must be backed by the existing backend contract or a properly implemented backend change.
* Do not hard-delete clinical records.
* Clear all linter/analyzer issues in touched files.

## Final delivery requirements for the coding agent

Return a zipped archive containing only the files and folders that were created or updated.

All files must be placed in their correct relative project directories.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete or rename operations. The scripts must use correct relative paths and must not delete unrelated files.

Do not return the full project archive.
