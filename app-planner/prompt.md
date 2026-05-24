# Implementation Prompt: Improve Lab Worklist Realtime Stability, Patient/Order Result Entry Flow, and Lab Report Print Preview

You are working in the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Implement the requested Lab module improvements using the existing project architecture, naming conventions, coding style, shared components, localization system, and UI patterns.

## Problem to solve

The Lab screen currently works visually, but the worklist table feels unstable because it reloads/clears itself instead of staying visible while data refreshes. The expected behavior is:

* The Lab worklist is up to date when loaded.
* Creating/updating/deleting lab orders, entering results, editing results, deleting/removing results, and changing lab configuration updates the Lab screen automatically without a disruptive full table reload.
* Clicking a patient or lab order opens a useful patient/order result-entry detail view.
* The result-entry workflow should be simple, clear, and fast.
* Lab reports should have a proper print preview and use the shared print system.

## Relevant areas to inspect and modify

### Frontend

Inspect and modify only where required:

* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/shared/printing/print_form_template.dart`
* `frontend/lib/app/printing/print_form_template_context.dart`
* `frontend/lib/shared/components/app_report_actions.dart`
* `frontend/lib/shared/components/app_list_table.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
* `frontend/lib/l10n/app_en.arb`
* generated localization files under `frontend/lib/l10n/`

Reuse existing shared components in `frontend/lib/shared/*` before creating new components.

### Backend

Inspect and modify only if needed:

* `backend/src/modules/lab-workspace/routes/lab-workspace.routes.js`
* `backend/src/modules/lab-workspace/controllers/lab-workspace.controller.js`
* `backend/src/modules/lab-workspace/services/lab-workspace.service.js`
* `backend/src/modules/lab-workspace/services/lab.serializer.js`
* `backend/src/modules/lab-workspace/services/lab.shared.js`
* `backend/src/modules/lab-order/*`
* `backend/src/modules/lab-order-item/*`
* `backend/src/modules/lab-result/*`
* `backend/src/modules/lab-test/*`
* `backend/src/modules/lab-panel/*`
* relevant backend tests under `backend/src/tests/modules/lab-*`

Only add backend support if the current API cannot supply the required frontend data safely.

### App planner

Inspect:

* `app-planner/dev-plan/21-lab.md`

Use it as guidance for Lab architecture and UI rules. Do not modify planner files unless the project convention requires it.

## Existing UI behavior to preserve from screenshots

The current Lab screen uses:

* Left navigation with Lab selected.
* Main Lab worklist titled `Patient lab worklist`.
* Search placeholder similar to `Search patient, order, test, or encounter`.
* Summary cards above the table.
* `AppListTable`-style table.
* Patient rows showing patient name, patient ID, encounter/order context, order count, tests summary, and status badges.
* Lab result entry dialog with:

  * title `Lab result entry`
  * subtitle like `Nia Demo-Charlie · Order LAB0000003`
  * patient header card with patient name, copyable patient ID, and order status badge
  * detail cards for lab order, ordered date/time, order status, and tests
  * `Ordered tests` section
  * empty state: beaker icon, `No tests on this order`, and explanatory text
  * bottom actions: `Edit order`, `Delete order`, `Close`
  * maximize/restore and close controls

Preserve this visual language: clean healthcare UI, simple cards, copyable identifiers, status badges, clear empty states, and bottom action buttons.

## Required implementation

### 1. Stabilize the Lab worklist refresh behavior

The Lab table must not disappear, blank out, or visually reload during normal refreshes.

Implement non-disruptive updates for:

* realtime Lab events
* polling refreshes
* creating lab orders
* updating lab orders
* deleting lab orders
* entering/saving/submitting/verifying/rejecting results
* creating/updating/deleting lab tests
* creating/updating/deleting lab panels
* lab configuration changes

Use the existing Lab realtime system and controller patterns. Keep polling as a fallback, but do not use polling in a way that causes table flicker.

Important implementation details:

* Keep current table rows visible while background refreshes happen.
* Do not pass a normal background refresh state into `AppListTable` in a way that replaces rows with a loading state.
* Use subtle refresh indicators instead of clearing the table.
* Preserve the active search, filters, selected Lab view, current page, sort, and column state while refreshing.
* Deduplicate overlapping refreshes and ignore stale refresh responses.
* For mutations made by the current user, update local state from the mutation response immediately, then run a background refresh only if needed.
* For realtime events from other users, update the affected order/workflow/catalog data without a full workspace reload when possible.
* Avoid broad `refresh()` calls after catalog updates unless no targeted update is possible.

### 2. Simplify the main Lab worklist table

The main worklist table should show a maximum of four main/default columns.

Use this default column model:

| Column        | Required content                                                                |
| ------------- | ------------------------------------------------------------------------------- |
| Patient       | Patient name, patient ID, and compact encounter/order context                   |
| Orders        | Active order count for patient view, or lab order ID/copy chip for order view   |
| Entry status  | Ordered, partially entered, pending results, verified, rejected, etc.           |
| Result status | Ordered, partially filled, filled, verified/completed, critical, rejected, etc. |

Requirements:

* Remove `Next action` from the default visible table.
* Do not show `Tests` as a default main column if it causes more than four columns or horizontal scrolling.
* If tests are still useful, keep them available only through column settings/details, not as a required default column.
* Avoid horizontal scrolling on normal desktop width for the default four-column layout.
* Use localized labels for all headings, statuses, empty states, tooltips, and actions.
* Do not introduce hardcoded user-facing strings such as `active order` or `active orders`.

### 3. Improve patient/order detail opening behavior

Clicking a patient row or a lab order row should open a detailed result-entry view.

For patient-group rows:

* Do not force the user through a separate order selector first.
* Open a patient-centered detail dialog/page that shows all active lab orders for that patient.
* If there is only one order, show it directly.
* If there are multiple orders, show them as clear order sections, cards, tabs, or accordions inside the same detail view.

For order rows:

* Open the selected order directly.

The detail view must show:

* Patient name
* Patient ID
* relevant encounter/order context
* each lab order ID
* ordered date/time
* order status
* ordered tests
* result-entry controls
* edit/delete actions where permitted
* print/preview action

If the current worklist payload only contains grouped order IDs, load each order workflow by ID or add a minimal backend endpoint only if necessary.

### 4. Show panels and tests correctly

For each lab order:

* Show single tests as individual test rows.
* Show panels as a parent panel label with the panel’s child tests listed underneath.
* Result entry should happen at the actual test/result item level, not on the panel container unless the existing domain model explicitly supports panel-level results.
* Empty orders must keep the existing clear empty state.

Verify whether the backend currently exposes enough panel grouping information on order workflow items.

If panel grouping is missing:

* Prefer a safe frontend inference from existing catalog panel child IDs only if it is reliable.
* Otherwise, add backend serialization support to expose the panel relationship/grouping for order items.
* Do not invent panel/test relationships that are not present in the data.

### 5. Make result entry, editing, and removal simple

Reuse and extend the existing result-entry table/draft patterns.

Each test row should clearly show:

* test name
* reference range
* result input or current result
* unit where applicable
* flag/status: normal, low, high, abnormal, critical, pending, verified, rejected
* simple actions to save/edit/remove where permitted

Behavior requirements:

* Entering a result should be straightforward from the row.
* Editing an unverified result should be simple.
* Removing a draft/unverified result should be supported if the backend allows it.
* For verified/finalized results, do not hard-delete clinical data. Use the existing reverse/reject/correction workflow if that is the project pattern.
* If the backend lacks a safe result-delete/remove endpoint, implement the smallest safe backend change needed, or explicitly preserve the existing clinical safety workflow.
* After every result mutation, update the detail view and main worklist statuses immediately.

### 6. Improve Lab statuses

Update the status logic so the main table and detail view accurately reflect result-entry progress.

At minimum, distinguish:

* ordered / no results started
* partially entered
* pending results
* filled / results entered
* verified / completed
* rejected / cancelled
* critical where applicable

Use existing backend/domain status fields where possible. Do not rely only on display text. Result-bearing test counts should exclude rejected/cancelled items and should not incorrectly count panel parent containers as result-bearing tests unless the domain model requires that.

### 7. Add Lab report print preview

Add a print/preview action to the Lab result detail view.

On click:

* Open an in-app print preview dialog first.
* Do not immediately trigger browser print.
* Reuse the existing shared print/report components:

  * `PrintFormTemplate`
  * `PrintFormPage`
  * `PrintFormMetadataItem`
  * `AppReportPreviewPanel`
  * `printFormTemplateDocument`
  * existing print context/provider patterns
* Do not create a separate duplicate print system.

The preview must allow the user to choose what to print:

* include/exclude individual orders
* include/exclude individual tests/results
* remove items from the preview before printing
* reset selection if practical

The printed report layout must be simple and professional.

Report table columns:

| Column          | Required content                             |
| --------------- | -------------------------------------------- |
| Test            | Test name                                    |
| Reference range | Reference range/normal range                 |
| Result          | Result value/text with unit where applicable |
| Flag            | Normal, Low, High, Abnormal, Critical, etc.  |

Include patient/order context, facility/report header, printed timestamp, page numbers, and verification/signature block where existing data supports it.

### 8. Fix the shared print template patient-details repetition bug

The current shared print template must not repeat patient details on every printed page.

Requirement:

* Patient/order metadata should appear only on the first page.
* Page numbers and footer information may continue on every page.
* Facility/report header behavior should follow the existing template design.
* Do not break other modules that already use the shared print template.

Make the change in the shared print template in a backward-compatible way where possible.

### 9. Backend requirements if backend changes are needed

Preserve existing backend architecture and safety rules.

If adding or changing backend behavior:

* keep tenant/facility scoping intact
* preserve authorization checks
* preserve audit behavior
* preserve realtime event publishing
* update serializers consistently
* update schemas/controllers/services/repositories according to existing module patterns
* add or update tests
* update OpenAPI only if that is the project convention for changed endpoints

Do not add database migrations unless absolutely required.

### 10. Localization

Ensure 100% localization.

* No new hardcoded user-facing strings in Dart.
* Add all new labels/messages/tooltips/statuses to `frontend/lib/l10n/app_en.arb`.
* Regenerate localization outputs using the existing Flutter l10n setup.
* Include updated generated localization files if they are tracked in the repository.

### 11. Testing and verification

Run the relevant checks before producing the final archive.

Frontend:

* `flutter pub get`
* Flutter l10n generation using the project’s existing setup
* `dart format` on changed Dart files
* `flutter analyze`
* relevant Flutter tests, if present

Backend, if touched:

* `npm run lint`
* relevant Jest tests for Lab modules
* `npm run test:backend:unit` or targeted backend test command
* `npm run openapi:validate` if OpenAPI was changed

Also manually verify:

* Lab worklist does not flicker or clear during refresh.
* Creating/editing/deleting lab orders updates the table smoothly.
* Lab configuration changes update affected UI smoothly.
* Patient rows open a detail view with all active orders.
* Order rows open the selected order directly.
* Panels display parent panel plus child tests.
* Single tests display normally.
* Result entry/edit/removal updates statuses immediately.
* Print preview opens before printing.
* Patient details appear only on the first printed page.
* Default Lab table has no more than four visible main columns.

## Scope limits

* Modify only the files required for this task.
* Do not rewrite unrelated Lab screens.
* Do not refactor unrelated shared components.
* Do not change global shell/navigation layout.
* Do not change unrelated backend modules.
* Do not introduce a new design system.
* Reuse `frontend/lib/shared/*` components before creating new ones.
* Preserve existing folder structure, naming conventions, and coding style.
* Clear all linter/analyzer issues caused by your changes.

## Final deliverable

Return a zipped archive containing only the files and folders that were created or updated, placed in their correct relative project directories.

Do not include:

* the whole repository
* build outputs
* dependency folders
* cache folders
* unrelated files

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete/rename operations using correct relative paths. The scripts must not delete unrelated files.
