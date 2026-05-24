# Implementation Prompt: Refactor Laboratory Workspace Order Creation and Lab Configurations

You are working in the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Refactor the Laboratory module so the main Lab workspace has a clearer order-creation flow and a dedicated Lab Configurations area for tests, panels, and reference ranges. Treat this as a major but focused Lab-module refactor. Preserve the existing project architecture, folder structure, naming conventions, coding style, shared component patterns, and localization approach.

## Relevant areas to inspect

### Frontend

Inspect and modify only the required files, especially:

* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog.dart`
* `frontend/lib/shared/lab_catalog/lab_catalog_dialogs.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_models.dart`
* `frontend/lib/shared/components/*`
* `frontend/lib/l10n/app_en.arb`
* generated localization files, if this project commits them

Reuse existing shared components in `frontend/lib/shared/*` before creating new components.

### Backend

Inspect and modify only where needed:

* `backend/src/modules/lab-workspace/*`
* `backend/src/modules/lab-order/*`
* `backend/src/modules/lab-order-item/*`
* `backend/src/modules/lab-test/*`
* `backend/src/modules/lab-panel/*`
* `backend/src/modules/lab-result/*`
* `backend/src/modules/lab-sample/*`
* `backend/src/app/router.js`
* `backend/prisma/schema.prisma`
* lab seeders/scripts only if catalog data shape changes

### App planner

Use this as implementation guidance, not as a rewrite target unless a codebase rule requires it:

* `app-planner/dev-plan/21-lab.md`

The plan emphasizes reusing `AppWorkspace`, `AppListTable`, `AppSearchBar` / `AppListTableSearch`, `AppDialog`, shared form fields, access gates, and existing Lab API route families.

## Problem to solve

The current Lab workspace has a generic `Create Item` action and a `Reference ranges` action. This is confusing because Lab staff mainly need to create lab orders for existing patients, while tests, panels, and reference ranges belong in configuration.

Refactor the flow as follows:

1. Replace `Create Item` with `Create Lab Order`.
2. `Create Lab Order` must open the lab order creation flow directly.
3. Lab staff must be able to search/select an existing patient, encounter, or existing lab order context where supported.
4. The Lab order flow must not create a new patient.
5. The Lab order flow must not expose or require manual order time entry. The order creation time must come from the backend/system clock.
6. Replace `Reference ranges` with `Lab Configurations`.
7. `Lab Configurations` must manage lab tests, lab panels, and reference ranges.
8. Lab tests and panels must support add, edit, and delete actions.
9. Reference ranges must be editable through the lab test configuration flow.
10. Tables, searchable selects, and search bars in the Lab module must feel responsive and should not become sluggish while typing.
11. Backend and frontend state must remain synchronized, including existing Lab realtime behavior.

## UI/UX requirements

### Main Lab workspace

The Lab page currently shows:

* Header: `Laboratory` with beaker icon and green `Live sync` indicator.
* Right-side actions: `Orders view`, `Create Item`, `Reference ranges`, and refresh.
* Summary cards: `Patients`, `Patients awaiting results`, `Patients completed`.
* Worklist panel titled `Patient lab worklist`.
* Search hint: `Search patient, order, test, or encounter`.
* Worklist table with patient/order/test/status/result information.

Update this screen:

* Rename the toolbar button `Create Item` to `Create Lab Order`.
* Rename the toolbar button `Reference ranges` to `Lab Configurations`.
* Keep the current workspace layout, cards, worklist, search bar, filter icon, settings icon, refresh action, and Live sync indicator.
* Do not introduce unrelated layout changes.

### Create Lab Order flow

When the user clicks `Create Lab Order`:

* Do not show the current chooser dialog with `Lab order`, `Lab test`, and `Lab panel`.
* Open the lab order creation flow directly.
* The form must allow selecting/searching an existing patient.
* Support encounter and/or lab order context search where existing backend/frontend functionality allows it.
* Do not allow creating a new patient from this flow.
* Do not show an editable `ordered_at`, `ordered time`, or equivalent timestamp field during lab order creation.
* Do not send manual `ordered_at` from the frontend during creation.
* Rely on the backend/server clock for order creation time.
* Continue using the existing shared lab order/test/panel selection patterns where possible, especially the existing catalog-driven lab order dialog.
* Add icons to searchable options where appropriate, for example patient, encounter, order, test, and panel options.

### Lab Configurations dialog

When the user clicks `Lab Configurations`:

* Open a dialog for configuring lab tests, lab panels, and reference ranges.
* The dialog title should reflect the wider scope, for example `Lab Configurations`.
* The body text should explain that this area manages lab tests, panels, units, qualitative options, and reference ranges used by backend result interpretation.
* Keep the existing dialog shell behavior, including close and fullscreen/expand controls if provided by `AppDialog`.

The dialog must include:

* `Tests` tab.
* `Panels` tab.
* Flat/squared tab styling. Avoid rounded pill/capsule corners on the `Tests` and `Panels` tabs.
* Search bar with filter/settings actions consistent with existing Lab UI.
* Add action for the active tab:

  * `Add test` on Tests tab.
  * `Add panel` on Panels tab.
* Edit and delete actions for every test row.
* Edit and delete actions for every panel row.
* Reference range editing through the test add/edit dialog.

### Lab Configurations tables

For the Lab Configurations tables only:

* Do not show more than 3 main data columns by default.
* Keep the row number and action column usable.
* The action column must be visible by default.
* The table must scroll horizontally when additional columns are available.
* Do not let important actions become hidden or clipped.
* Preserve column settings behavior if the existing table supports it.
* Use compact, elegant actions with icons and localized labels/tooltips.

Suggested default visible columns:

Tests table:

* Test name
* Test code
* Category
* Actions

Additional columns may remain available through horizontal scroll or column settings:

* Specimen type
* Result kind
* Unit
* Reference range details

Panels table:

* Panel name
* Panel code
* Category
* Actions

Additional columns may remain available through horizontal scroll or column settings:

* Tests count
* Description or other supported metadata

## Implementation requirements

### Frontend

* Refactor the main Lab toolbar action so `Create Lab Order` calls the lab order creation flow directly.
* Remove or stop using the generic create-item chooser from this toolbar path.
* If the old create-item chooser becomes unused, remove it only if doing so does not create unrelated churn.
* Move test and panel creation into `Lab Configurations`.
* Reuse existing shared dialogs where possible:

  * existing lab test dialog
  * existing lab panel dialog
  * existing delete reason dialog
  * existing clinical lab order action dialog
  * existing shared form, search, select, table, and dialog components
* If a reusable search/select improvement is needed, place it under `frontend/lib/shared/*` and wire Lab to use it.
* Ensure all user-facing labels, hints, empty states, errors, tooltips, action text, and semantic labels are localized.
* Do not hardcode English strings in Dart widgets.
* Update `app_en.arb` and regenerate committed localization outputs if that is the project convention.
* Keep Riverpod/controller patterns already used by the Lab module.
* Keep current `AppWorkspace`, `AppListTable`, `AppSearchBar`, `AppDialog`, and shared component conventions.
* Fix any existing analyzer/linter issues touched by this refactor.

### Search and performance

Review all Lab-module tables, search bars, and searchable selects affected by this flow.

Improve typing UX by:

* Debouncing expensive searches.
* Avoiding backend requests on every keystroke unless debounced and cancel-safe.
* Limiting rendered suggestion counts.
* Reusing normalized searchable text where useful.
* Avoiding full widget rebuilds for large option lists where possible.
* Keeping local search instant for small lists.
* Showing clear icons in option rows where supported.
* Preserving keyboard and mouse usability.

### Backend

* Verify that creating a lab order without `ordered_at` uses the backend/server clock.
* If frontend currently sends `ordered_at`, remove that from the create payload.
* Do not create patients from the Lab order endpoint or UI.
* Use existing patient/encounter/order search endpoints if they already exist.
* If existing search support is missing, add only the minimal backend support required for selecting an existing patient/encounter/order context, following existing auth, facility/tenant scoping, validation, and response style.
* Confirm lab test and lab panel create/update/delete payloads align with existing backend schemas.
* Confirm reference range payloads remain compatible with backend result interpretation.
* Ensure relevant Lab mutations update frontend state and existing realtime/polling behavior correctly.
* If backend Lab catalog mutations are expected to emit realtime events, follow the existing Lab realtime event pattern.

## Synchronization requirements

After creating, editing, or deleting lab orders, tests, panels, or reference range data:

* The visible UI should update without requiring a manual page reload.
* Lab worklist counts and rows should refresh when a new order affects them.
* Lab configuration tables should update after add/edit/delete.
* Use targeted state updates where practical.
* Avoid full workspace reloads unless the current architecture requires it.
* Preserve existing polling and realtime sync behavior in `LabWorkspaceController`.

## Missing details the coding agent must verify from the codebase

Verify before implementing:

* The existing patient search/list API and frontend repository/component patterns.
* The existing encounter search/list API and whether the Lab create-order flow should resolve encounter context by ID, code, or selected encounter object.
* Whether selecting an existing lab order should only prefill context or also support adding new items to that order.
* Whether multiple reference ranges per test are fully supported by the backend and should be editable now, or whether the current single-primary-range UI should be preserved while keeping existing extra ranges intact.
* Whether generated localization files are manually committed in this repository and must be regenerated.

Do not guess these details. Use the existing codebase as the source of truth.

## Testing and verification

Run and fix all relevant checks.

Frontend:

* `flutter analyze`
* Run existing Flutter tests relevant to Lab/shared components if present.
* Add or update focused tests only where the project already has a suitable test pattern.

Backend:

* Run the backend lint/test scripts defined in `backend/package.json`.
* Verify Lab order creation still passes backend validation without `ordered_at`.
* Verify lab test/panel create, update, and delete still work.

Manual verification:

1. Open `/lab`.
2. Confirm main toolbar shows `Create Lab Order` and `Lab Configurations`.
3. Click `Create Lab Order`.
4. Confirm no generic create-item chooser appears.
5. Confirm the flow allows selecting/searching an existing patient/context.
6. Confirm no manual order time field is shown.
7. Create a lab order and confirm it appears in the Lab worklist/state without page reload.
8. Click `Lab Configurations`.
9. Confirm Tests and Panels tabs are flat/squared, not rounded pills.
10. Confirm Tests table shows no more than 3 main data columns by default and keeps actions visible.
11. Confirm Panels table shows no more than 3 main data columns by default and keeps actions visible.
12. Confirm tables scroll horizontally when needed.
13. Confirm add/edit/delete works for tests.
14. Confirm add/edit/delete works for panels.
15. Confirm reference ranges can be edited through test configuration.
16. Confirm Lab search bars and searchable selects remain responsive while typing.
17. Confirm all new visible strings are localized.
18. Confirm no linter/analyzer issues remain.

## Scope limits

* Modify only files required for this Lab refactor.
* Do not rewrite unrelated modules.
* Do not redesign the whole HMS layout.
* Do not replace the existing state-management architecture.
* Do not introduce new UI libraries.
* Do not duplicate shared dialogs/components when existing `frontend/lib/shared/*` components can be reused or extended.
* Do not create new patients from the Lab order flow.
* Do not expose manual order creation time in the create-order form.
* Do not leave dead code, unused imports, untranslated strings, or lint issues.
