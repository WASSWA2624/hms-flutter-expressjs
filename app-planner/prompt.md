# Implementation Prompt: Fix Lab Order Search Focus, Existing Order Selection, and Lab Configuration Smoothness

You are working in the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Inspect the actual codebase first and implement only the changes required for this task. Preserve the existing Flutter/Riverpod frontend architecture, Express backend architecture, folder structure, naming conventions, coding style, shared UI components, localization approach, authorization/scoping behavior, and Lab realtime/polling behavior.

## Problem to Solve

The Lab module has good progress, but the current UX has these issues:

1. In `Create lab order`, the Patient searchable select loses focus while searching because the options reload and/or loading state rebuilds/disables the field.
2. Searchable select fields should remain focused and smooth while typing.
3. All searchable select components used in this Lab flow must show an `X` clear button when there is typed text or a selected value.
4. The optional existing Lab order context select must be searchable, clearable, and must affect the next step correctly:

   * no existing order selected → create a new Lab order;
   * existing order selected → update that existing Lab order using the existing update flow.
5. The request dialog for selecting `Individual tests` and `Lab panels` must not use rounded pill/capsule tabs. The interface uses squared/flat controls.
6. `Lab Configurations` opens and searches sluggishly. It must open faster, type smoothly, and avoid unnecessary reload/flicker while searching.
7. Preserve 100% localization/l10n and clear all analyzer/linter issues.

## Relevant Project Areas to Inspect

### Frontend

Inspect first and modify only where required:

* `frontend/lib/shared/components/app_select_field.dart`
* `frontend/lib/shared/components/app_search_bar.dart`
* `frontend/lib/shared/components/app_list_table.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_models.dart`
* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/l10n/app_en.arb`
* `frontend/lib/l10n/app_localizations.dart`
* `frontend/lib/l10n/app_localizations_en.dart`

Reuse existing components in `frontend/lib/shared/*` before creating new components.

### Backend

Inspect and modify only if frontend changes require backend support:

* `backend/src/modules/lab-workspace/*`
* `backend/src/modules/lab-order/*`
* `backend/src/modules/lab-order-item/*`
* `backend/src/app/router.js`
* `backend/prisma/schema.prisma`

Do not change backend schema/database unless strictly required.

### App Planner

Use as guidance only; do not rewrite planner files unless a project rule requires it:

* `app-planner/prompt.md`
* `app-planner/dev-plan/21-lab.md`
* `frontend/app-planner/app-rules/*`
* `backend/app-planner/app-rules/*`

## Current Codebase Facts to Preserve

The Lab flow currently uses:

* `LabWorkspacePage` with `AppWorkspace`.
* `LabWorkspaceController` with Riverpod state, polling, and realtime refresh.
* `LabOrderContextDialog` in `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`.
* `ClinicalLabOrderActionDialog` in `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`.
* `AppSelectField.searchable` in `frontend/lib/shared/components/app_select_field.dart`.
* `AppListTable`, `AppListTableSearch`, and `AppSearchBar`.
* `LabCatalogTestDialog`, `LabCatalogPanelDialog`, and `LabDeleteReasonDialog`.
* Backend Lab order create already removes frontend `ordered_at` and sets `ordered_at = new Date()` in `backend/src/modules/lab-order/services/lab-order.service.js`.
* Backend Lab order update already supports updating requested tests/panels for editable orders.

## Screenshot-Based UI Requirements

### Create Lab Order Dialog

The dialog must keep the current style:

* App dialog overlay with dimmed page background.
* Header title: `Create lab order`.
* Header icon: assignment/clipboard-style icon.
* Close and fullscreen/expand controls must remain if provided by `AppDialog`.
* Body text explains that the user should search/select an existing patient, and encounter/existing order context is optional where available.
* Patient field:

  * label: `Patient *`;
  * hint: `Search patient name, ID, phone, or identifier`;
  * dropdown rows show person icon, patient name, and subtitle with patient ID / display ID / phone.
* While typing in Patient search, the text field must not lose focus, must not clear typed text, and the dropdown must not flicker/restart unnecessarily.
* Encounter field may remain disabled when no patient/context is available.
* Existing Lab order context field is optional but must be searchable and clearable.

### Lab Configurations Dialog

The dialog must keep the current style:

* Title: `Lab Configurations`.
* Body: explains managing lab tests, panels, units, qualitative options, and reference ranges used by backend result interpretation.
* Full-width squared tabs:

  * `Tests`
  * `Panels`
* No rounded pill/capsule styling on tabs.
* Search bar with attached clear/filter/add/settings actions.
* Table columns visible by default:

  * `#`
  * name column (`Test name` or `Panel name`)
  * code column
  * category column
  * action column
* Action column must remain reachable and not clipped.
* Close action at the bottom/right must remain.

## Specific Implementation Requirements

### 1. Fix searchable select focus loss

Improve `AppSelectField.searchable` so async option updates and loading indicators do not make the input lose focus.

Requirements:

* Do not disable the searchable input just because `isLoading == true`.
* Loading should be shown as a non-blocking trailing indicator.
* Keep the `TextEditingController` and focus stable during option list refresh.
* Avoid keys or rebuild patterns that recreate the underlying `DropdownMenuFormField` unnecessarily during typing.
* Do not overwrite typed search text with the selected label unless the selected value actually changed.
* Keep `onSearchTextChanged` from firing during internal controller sync.
* Ensure stale async results cannot replace newer search results.
* Keep keyboard and mouse usability.

### 2. Add clear button behavior to all Lab searchable selects

For Lab order context searchable selects:

* Patient select must show an `X` clear button when the user has typed text or selected a patient.
* Encounter select must show an `X` clear button when selected/typed.
* Existing Lab order context select must show an `X` clear button when selected/typed.
* Clearing Patient must clear selected patient, selected encounter, selected existing order context, and patient-specific context options safely.
* Clearing Encounter must clear only encounter.
* Clearing Existing Lab order context must clear only existing order selection unless the current codebase requires linked cleanup.
* Required fields may still be clearable; validation should catch missing required values on submit.
* Use localized clear labels/tooltips. `MaterialLocalizations` is acceptable for standard clear tooltip behavior.

### 3. Fix Create Lab Order create-vs-update behavior

`LabOrderContextDialog` currently tracks `_selectedOrderId`, but the submitted context does not fully use it. Fix this flow.

Required behavior:

* Extend the submitted Lab order context model as needed so it carries optional selected existing order ID/context.
* If no existing Lab order is selected, the next step must create a new Lab order using the existing `createOrder` path.
* If an existing Lab order is selected, the next step must update that existing Lab order using the existing `updateOrder` path.
* Do not send `selected_order_id` or similar extra frontend-only fields in the create payload.
* When updating an existing order, load/resolve the existing order items before opening `ClinicalLabOrderActionDialog` so existing selected tests/panels are preserved and displayed.
* Preserve the backend’s current update semantics unless the codebase clearly requires otherwise.
* If the backend rejects updating a processed/non-editable Lab order, show the existing localized failure/error UI.
* Do not reintroduce manual `ordered_at` fields.

### 4. Keep Patient search smooth

In `LabOrderContextDialog`:

* Keep debounced patient search.
* Keep generation-token/cancel-safe behavior.
* Do not set loading state in a way that disables the active Patient field.
* Do not clear the typed query while results are being fetched.
* Do not replace the dropdown list in a way that closes focus on every keystroke.
* Limit visible patient options to a reasonable number as the current code does.

### 5. Make Lab request tabs squared

In `ClinicalLabOrderActionDialog`:

* The `Individual tests` and `Lab panels` tab buttons must not be rounded.
* Replace or restyle the current segmented control so it matches the squared/flat Lab UI.
* Keep icons, selected state, accessibility labels, keyboard usability, and l10n.
* Do not affect unrelated clinical action dialogs.

### 6. Improve Lab Configurations responsiveness

In `_LabConfigurationsDialog`:

* The dialog should open immediately using already-loaded `LabWorkspaceState` catalog data.
* Do not block opening the dialog on a fresh network call unless the existing controller absolutely requires it.
* Search in the configuration dialog should be local, responsive, and focus-stable.
* Typing in the search field must not trigger a full workspace reload.
* Avoid expensive work directly in `build`.
* Memoize/precompute normalized searchable text where useful.
* Keep rendered row counts reasonable.
* Avoid unnecessary `ref.watch` rebuilds for local search-only changes.
* Keep the current add/edit/delete actions for tests and panels.
* Preserve QC/config actions already present unless they conflict with the task.

## Backend Requirements

Backend changes are likely not required for the focus/performance bug. Still verify:

* Lab order creation works without frontend `ordered_at`.
* Lab order creation uses server time.
* Existing Lab order update supports requested tests/panels.
* Existing patient/encounter/order identifiers are resolved through current backend patterns.
* Existing auth, tenant/facility scoping, validation, audit logging, and realtime events remain intact.

Only add backend support if the current frontend cannot search/select/update existing Lab orders correctly using existing endpoints.

## Localization Requirements

Ensure 100% l10n.

* Do not hardcode new user-facing English strings in Dart widgets.
* Localize all labels, hints, tooltips, semantic labels, button text, empty states, validation messages, and errors introduced or modified.
* Update `frontend/lib/l10n/app_en.arb` when adding keys.
* Regenerate committed localization outputs:

  * `frontend/lib/l10n/app_localizations.dart`
  * `frontend/lib/l10n/app_localizations_en.dart`
* Run the existing hard-coded UI text/localization checks if available.

## Testing and Verification

Run and fix all relevant checks.

### Frontend

From `frontend`, run:

* `flutter gen-l10n`
* `flutter analyze`
* `flutter test test/l10n/hard_coded_ui_text_test.dart`
* `flutter test test/shared/components/app_list_table_test.dart`
* Add/update focused widget tests for `AppSelectField.searchable` if a suitable pattern exists.

Manual verification:

1. Open `/lab`.
2. Click `Create Lab Order`.
3. Type quickly in Patient search.
4. Confirm focus remains in the field while results update.
5. Confirm typed text is not cleared or overwritten.
6. Confirm the dropdown does not flicker/reload in a disruptive way.
7. Confirm Patient, Encounter, and Existing Lab order context searchable selects show clear `X` buttons when applicable.
8. Select no existing order, choose tests/panels, and confirm a new Lab order is created.
9. Select an existing order, choose/update tests/panels, and confirm the selected order is updated rather than creating a duplicate order.
10. Confirm the request dialog tabs `Individual tests` and `Lab panels` are squared, not rounded.
11. Click `Lab Configurations`.
12. Confirm the dialog opens quickly.
13. Type in the Lab Configurations search field and confirm no sluggishness, no focus loss, no full reload/flicker.
14. Confirm add/edit/delete still works for tests and panels.
15. Confirm all visible text is localized.

### Backend

Run only if backend files are changed:

* `npm run lint`
* `npm run test`
* `npm run openapi:validate` if API contracts changed

## Scope Limits

* Modify only files required for this Lab UX fix.
* Do not rewrite unrelated modules.
* Do not redesign the whole HMS layout.
* Do not introduce new UI libraries.
* Do not duplicate shared components that can be reused or extended in `frontend/lib/shared/*`.
* Do not change database schema unless strictly required.
* Do not touch `.env`, logs, generated build folders, or dependency folders.
* Do not leave unused imports, dead code, stale labels, hardcoded new UI text, analyzer issues, or linter issues.

## Required Delivery Format

Return a zipped archive containing only files and folders that were created or updated, placed in their correct relative project directories.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete/rename operations. The scripts must:

* use correct relative paths from the repository root;
* check that targets exist before changing them;
* not delete unrelated files;
* be included in the zip with the changed files.
