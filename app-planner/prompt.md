# Task: Implement Radiology workspace configuration, reusable imaging request workflow, report/asset usability, and print preview

You are working in the HMS codebase with these main project folders:

* `app-planner`
* `backend`
* `frontend`

Implement the next Radiology workspace iteration. The current `/radiology` page already has a patient/orders view toggle, refresh action, primary `Request imaging` action, summary cards, searchable table, and a request imaging modal. Keep that working, then add the requested configuration and reusable radiology workflow improvements.

## 1. Problem to solve

The Radiology workspace currently supports viewing radiology worklists and requesting a single imaging study, but it is missing:

* A top-level Radiology configuration button and configuration dialog.
* Reusable radiology request/configuration/report components.
* Multi-test imaging requests for one patient.
* Better reuse of existing shared radiology dialogs/components.
* Easier report editing, asset/PACS display, image attachment where backend support exists, and professional print preview/printing.
* Full localization for all visible text.
* A table layout that shows no more than 4 user-facing data columns at a time.

Implement this without rewriting the whole module or creating duplicate UI patterns.

## 2. Important current UI details to preserve

The coding environment may not include the screenshots, so preserve these written UI requirements:

* The Radiology workspace uses the existing HMS shell with the left navigation. `Radiology` is active under `Diagnostics and medication`.
* The page title row shows the Radiology icon, `Radiology`, and a green `Live sync` status.
* In patients view, the top action row currently shows:

  * `Orders view` toggle button with swap icon.
  * `Refresh` button with refresh icon.
  * Primary blue `Request imaging` button with plus icon.
* In orders view, the toggle button label changes to `Patients view`.
* Add a new secondary configuration button in this same action row without removing the existing buttons. Preferred order:

  1. View toggle
  2. Configuration
  3. Refresh
  4. Primary `Request imaging`
* Summary cards currently show counts such as `Radiology patients`, `Total orders`, and `Released`. Preserve the compact card style.
* The worklist search hint is: `Search patient, order, encounter, study, report, or PACS text`.
* The table currently shows columns such as Patient, Order(s), Study, Priority, Billing. Update it so no more than 4 data columns are visible by default. Put remaining columns in column settings/details rather than removing the information.
* The current request imaging modal is centered and titled `Request imaging`, with:

  * A top catalog search row: `Catalog search (optional)` and `Search catalog`.
  * `Patient *` dropdown.
  * `Encounter (optional)` dropdown.
  * `Study *` dropdown.
  * `Clinical notes (optional)` multiline field.
  * Existing AppDialog-style close/maximize behavior.
* Keep this request modal easy and responsive, but replace the single-study behavior with a multi-test imaging request workflow.

## 3. Project areas to inspect first

Use these files as the source of truth before modifying anything.

### Planner/reference files

Inspect only; do not edit planner files unless absolutely necessary.

* `app-planner/prompt.md`
* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/22-radiology.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* Relevant frontend/backend app rules under `frontend/app-planner/app-rules/*` and `backend/app-planner/app-rules/*`

### Frontend Radiology files

* `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
* `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
* `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
* `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
* `frontend/lib/features/radiology/data/repositories/radiology_repository_impl.dart`
* `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`

### Shared frontend components to reuse before creating new ones

* `frontend/lib/shared/components/*`
* `frontend/lib/shared/forms/*`
* `frontend/lib/shared/layout/*`
* `frontend/lib/shared/printing/print_form_template.dart`
* `frontend/lib/shared/printing/printing.dart`
* `frontend/lib/shared/components/app_file_upload_panel.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_models.dart`
* `frontend/lib/shared/lab_catalog/*`

The existing shared `ClinicalRadiologyOrderActionDialog` already supports catalog search and multiple radiology requests. Reuse/refactor this behavior instead of creating a second unrelated multi-test selector.

### Frontend localization files

* `frontend/lib/l10n/app_en.arb`
* `frontend/lib/l10n/app_localizations.dart`
* `frontend/lib/l10n/app_localizations_en.dart`
* `frontend/lib/l10n/app_localizations_x.dart`

### Backend Radiology files

* `backend/src/app/router.js`
* `backend/src/modules/radiology-workspace/*`
* `backend/src/modules/radiology-test/*`
* `backend/src/modules/radiology-order/*`
* `backend/src/modules/radiology-result/*`
* `backend/src/modules/imaging-study/*`
* `backend/src/modules/imaging-asset/*`
* `backend/src/modules/pacs-link/*`
* `backend/prisma/schema.prisma`

### Backend equipment files

Radiology configuration asks for equipment support. Verify and reuse the existing equipment modules before adding anything new.

* `backend/src/modules/equipment-category/*`
* `backend/src/modules/equipment-registry/*`
* `frontend/lib/core/network/api_endpoints.dart`

Known schema facts to verify in code before implementation:

* `radiology_test` currently has `tenant_id`, `name`, `code`, `modality`, timestamps, soft delete/version fields.
* `equipment_registry` exists separately with fields such as `equipment_name`, `equipment_code`, `serial_number`, `manufacturer`, `model_number`, `status`, `facility_id`, and `equipment_category_id`.
* A direct persisted radiology-test-to-equipment relationship may not exist. Do not fake this relationship in UI state only.

## 4. Architecture and style requirements

Preserve the existing architecture:

* Frontend must continue using Flutter, Riverpod, feature/domain/data/presentation layering, `Result<T>`, DTO mapping, repository interfaces, and existing shared UI components.
* Backend must continue using the existing Express module structure: routes, schemas, controllers, services, repositories, Prisma, Zod validation, audit logging, soft-delete conventions, and response format conventions.
* Reuse `frontend/lib/shared/*` components before creating new components.
* Use `AppWorkspace`, `AppListTable`, `AppListTableSearch`, `AppDialog`, `showAppWorkspaceActionDialog`, shared form fields, `AppFormShell`, `AppFormActions`, `AppWorkspaceDetailPanel`, status badges, and async/error state components.
* Follow the Lab module’s configuration pattern, especially `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`, but do not copy lab-specific naming or duplicate lab-only logic.
* Do not perform broad unrelated refactors.
* Do not rewrite the whole Radiology page.
* Do not change unrelated modules except where a shared radiology component refactor requires updating existing callers.
* Modify only the files required for this change.
* Keep all linter issues cleared.

## 5. Frontend implementation requirements

### A. Add Radiology configuration button

Add a secondary configuration button to the Radiology workspace action row.

* Button label: localized `Configurations`.
* Icon: `Icons.tune_outlined`.
* Gate it behind the same permission style used elsewhere. Configuration create/edit/delete should require radiology write access.
* Do not remove:

  * View toggle.
  * Refresh.
  * Primary `Request imaging`.
* Disable or show loading consistently while mutations are in progress.

### B. Add Radiology configuration dialog

Create a reusable Radiology configuration dialog using existing AppDialog/list/search/form patterns.

Expected dialog:

* Title: localized `Radiology configurations`.
* Icon: tune/settings icon.
* Scrollable.
* Desktop max width similar to lab configuration dialog, around `980`.
* Responsive layout for desktop/tablet/mobile.
* Search should be fast and easy while typing.
* Use validation, disabled states, loading states, and duplicate-submit protection.

Include these configuration areas:

#### Imaging tests

Support listing, searching, creating, editing, and deleting custom radiology/imaging tests using the existing backend radiology-test API.

Fields must be based on the actual backend schema. At minimum:

* Name, required.
* Code, optional.
* Modality, required/defaulted according to backend rules.
* Any additional fields only if they are actually persisted or backed by existing backend metadata.

Use `/api/v1/radiology-tests` through the existing `ApiEndpoints`/repository pattern. The backend already has `radiologyTests` in `frontend/lib/core/network/api_endpoints.dart`.

Also account for the backend standard radiology catalog if available through `include_standard_catalog=true`:

* Standard catalog rows should be searchable/selectable.
* Do not allow editing/deleting standard rows unless backend explicitly supports it.
* Show read-only state or a localized message for standard rows.
* If “copy/customize standard test” is implemented, persist it as a custom test using the backend create endpoint.

#### Equipment

Add equipment configuration only using verified backend support.

* Reuse existing equipment registry/category APIs if they support the required create/edit/list behavior.
* Do not create a duplicate equipment model.
* If direct radiology-test-to-equipment association is not persisted in the current schema, do not fake that association in local UI state.
* Either:

  * manage equipment records separately in the configuration dialog using `equipment-registry`, or
  * add a narrowly scoped, fully migrated, fully tested persisted relationship if it clearly matches project conventions.
* If a required equipment-to-test persistence detail is missing or unclear, show a localized disabled/gap state in the dialog and document the backend gap in code comments near the implementation point.

### C. Refactor request imaging into reusable shared radiology components

The current `_CreateOrderForm` in `radiology_workspace_page.dart` is feature-local and supports one test. Replace/refactor it.

Requirements:

* Use or refactor the existing shared `ClinicalRadiologyOrderActionDialog` multi-test catalog behavior.
* Avoid duplicating the multi-test selector logic.
* If the existing shared dialog cannot directly handle patient/encounter selection, extract the reusable catalog selector into a neutral shared radiology component, for example under:

  * `frontend/lib/shared/radiology_catalog/`
* Keep old clinical/OPD callers working if shared code is refactored.
* Add a barrel export for any new shared radiology folder.

Radiology workspace request dialog must support:

* Patient selection, required.
* Encounter selection, optional and filtered by selected patient where possible.
* One or more selected imaging tests, required.
* Catalog search.
* Optional clinical notes.
* Optional request metadata where supported by backend/reference data:

  * modality
  * body region
  * laterality
  * priority
* Duplicate prevention.
* Remove/edit selected tests before submit.
* Clear validation messages.
* Good keyboard/mouse responsiveness.
* Mobile-friendly layout.

Payload requirements:

* Use `requested_tests` array when backend support exists.
* Each selected test should map to a backend-compatible shape similar to:

```json
{
  "patient_id": "...",
  "encounter_id": "...",
  "ordered_at": "...",
  "requested_tests": [
    {
      "radiology_test_id": "...",
      "clinical_note": "...",
      "request_details": {
        "modality": "...",
        "body_region": "...",
        "laterality": "...",
        "priority": "..."
      }
    }
  ]
}
```

Do not discard clinical notes. Do not keep the old single-test-only payload unless backend verification shows it is the only supported route.

### D. Align frontend with backend multi-test ordering

The generic backend `/api/v1/radiology-orders` create schema already supports `requested_tests`. The current workspace route `/api/v1/radiology/orders` may only support single-test creation.

Implement the smallest correct backend/frontend alignment:

* Prefer extending the Radiology workspace create route to accept the same `requested_tests` shape and return a workspace-compatible workflow response.
* Reuse backend radiology-order service logic where possible instead of duplicating multi-test order creation.
* Preserve current worklist/detail refresh behavior.
* If multiple orders are created for multiple tests, the UI should return to the same Radiology workspace context and show the updated patient/order group correctly.
* Do not create frontend-only fake orders.

### E. Radiology worklist table: no more than 4 visible columns

Update the Radiology table so no more than 4 data columns are visible by default.

* Do not globally change `AppListTable` behavior unless absolutely necessary.
* Prefer passing 4 default `columns` and moving additional available columns into `columnChoices`.
* Suggested default visible columns:

  * Patient
  * Order(s)
  * Study
  * Priority
* Billing, status, next action, modality, dates, and similar fields should remain available through:

  * column settings,
  * row/detail panel,
  * mobile tile,
  * or workflow detail.
* Preserve sorting where applicable.
* Preserve patient and orders views.
* Convert hard-coded Radiology table labels and empty states to l10n.

### F. Reporting, images/assets, PACS, and editability

Improve Radiology reporting without inventing unsupported backend features.

* Keep report drafting/editing easy and focused.
* Reuse existing report form patterns and shared form components.
* Make findings, impression/conclusion, and report text easy to edit.
* Show existing imaging studies, assets, and PACS links using the existing `_StudiesSection`/workflow data pattern, but refactor reusable pieces only if helpful.
* Reuse `AppFileUploadPanel` for image attachment UI.
* Wire upload only to verified backend endpoints, such as:

  * `/api/v1/radiology/studies/:id/assets/init-upload`
  * `/api/v1/radiology/studies/:id/assets/commit-upload`
  * or existing imaging asset endpoints if they are the correct contract.
* Do not fake uploaded image persistence.
* Let the user insert an existing asset/PACS reference into the report text if it can be done with current persisted data.
* Image annotation persistence is unclear in the current archive. Verify backend support before implementing. If no storage model/API exists for annotations, do not fake persistence; show a localized unavailable/gap state or leave the annotation action disabled.

### G. Print configuration and preview

Add a patient/order report print configuration and preview flow.

Requirements:

* Reuse `frontend/lib/shared/printing/print_form_template.dart`.
* Reuse `printFormTemplateDocument` from `frontend/lib/app/printing/print_form_template_context.dart` if that matches existing patterns.
* Do not print the visible UI screen directly.
* Provide a preview/configuration UI where the user can choose what to include.
* Include available sections such as:

  * facility/app header,
  * patient details,
  * encounter/order details,
  * selected imaging tests/studies,
  * findings,
  * impression/conclusion,
  * report text,
  * image/PACS references where available,
  * signer/release metadata where available.
* Use professional report formatting with page numbers and footer, consistent with Lab report printing patterns.

## 6. Backend implementation requirements

Update backend only where needed to support the frontend correctly.

### A. Multi-test workspace ordering

If `/api/v1/radiology/orders` does not support `requested_tests`, update:

* `backend/src/modules/radiology-workspace/schemas/radiology-workspace.schema.js`
* `backend/src/modules/radiology-workspace/services/radiology-workspace.service.js`
* related controller/repository/serializer files as needed.

Requirements:

* Accept single-test legacy payloads and new multi-test `requested_tests`.
* Preserve backward compatibility for existing callers.
* Persist `clinical_note` and `request_details`.
* Prevent duplicate test requests.
* Create clinical notes if existing generic radiology-order behavior does so and it fits the workspace route.
* Return a workspace-compatible workflow/order response.
* Publish realtime/audit events consistently with existing workspace mutations.
* Add/update backend tests.

### B. Radiology test configuration

Use existing `/api/v1/radiology-tests` behavior first.

If the frontend needs extra fields, verify they are supported by:

* schema,
* service,
* Prisma model,
* serializer,
* tests.

Do not add UI fields that silently disappear after save.

### C. Equipment configuration

Use existing equipment routes if they satisfy the configuration need.

If a new relation or field is required:

* Add the Prisma migration.
* Update schemas, repositories, services, serializers, and tests.
* Keep it narrowly scoped to Radiology configuration.
* Do not break Biomedical/equipment modules.

## 7. Localization requirements

Ensure 100% l10n for all UI text touched or added.

* No hard-coded user-visible strings in Dart UI.
* Add keys to `frontend/lib/l10n/app_en.arb`.
* Keep generated localization files in sync.
* Include labels, hints, buttons, tooltips, validation messages, empty states, disabled/gap messages, confirmation text, print section labels, and error messages.
* Replace existing hard-coded Radiology strings in touched files, including labels like:

  * `Orders view`
  * `Patients view`
  * `Radiology patients`
  * `Patients waiting imaging`
  * `Orders`
  * `1 active order`
  * `{n} active orders`
  * Radiology empty-state strings.

Backend validation/errors should use existing error-key conventions rather than raw user-facing strings.

## 8. Responsiveness, UX, and accessibility

* Maintain 100% UI responsiveness across desktop, tablet, and mobile.
* Use existing breakpoints/layout helpers.
* Dialogs must not overflow vertically or horizontally.
* Tables should become usable list/card layouts on small screens.
* Search must feel responsive while typing.
* All actions must show loading/disabled states.
* Prevent duplicate submits.
* Keep focus/keyboard behavior usable.
* Use tooltips/semantic labels for icon-only controls.
* Preserve the HMS visual style, spacing, typography, borders, and button hierarchy.

## 9. Scope limits

Do not:

* Rewrite the Radiology module from scratch.
* Replace the HMS workspace shell.
* Create a second unrelated radiology request dialog when shared radiology request logic already exists.
* Perform broad shared-folder reorganization.
* Move or rename existing shared components unless directly required.
* Change unrelated lab/clinical/OPD behavior except to keep shared refactors compiling.
* Add frontend-only fake data, fake upload state, fake equipment associations, or fake annotations.
* Modify planner files unless truly required.
* Include screenshots, logs, build output, generated caches, `node_modules`, `.dart_tool`, or unchanged files in the final archive.

For shared components, organize any new reusable radiology components in a clear folder, such as `frontend/lib/shared/radiology_catalog/`, with a barrel export. Only reorganize existing shared files if it directly removes duplication required by this task.

## 10. Testing and verification

Run the existing relevant checks and fix all issues.

Frontend:

* `cd frontend`
* `flutter pub get`
* regenerate l10n using the project’s standard Flutter l10n flow if localization files change
* `flutter analyze`
* `flutter test`

Backend:

* `cd backend`
* `npm run lint`
* `npm run test:backend`
* Run targeted Radiology/Radiology workspace tests if available.

Manual verification:

* Open `/radiology`.
* Verify patients/orders toggle still works.
* Verify new configuration button opens the configuration dialog.
* Verify custom radiology test create/edit/delete works with backend persistence.
* Verify equipment UI only exposes supported persisted behavior.
* Verify `Request imaging` can submit one or more imaging tests for a selected patient.
* Verify clinical notes and request details persist.
* Verify worklist refreshes without losing the selected view/search context.
* Verify the table shows no more than 4 default data columns.
* Verify column settings/details still expose hidden information.
* Verify report editing remains functional.
* Verify asset/PACS display remains functional.
* Verify upload actions only appear/work where backend support exists.
* Verify print preview/print uses the shared print template.
* Verify desktop and mobile layouts do not overflow.
* Verify all new/touched visible strings are localized.

## 11. Final deliverable requirements

Return a zipped archive containing only the files and folders that were created or updated.

* Preserve correct relative project paths inside the zip.
* Do not include unchanged files.
* Do not include build/cache/log/dependency folders.
* If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the zip that safely perform those delete/rename operations.
* PowerShell scripts must use correct relative paths and must not delete unrelated files.
* Ensure the archive is ready to extract over the existing HMS project.
