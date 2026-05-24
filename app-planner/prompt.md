# Implementation Prompt: Complete and Harden Laboratory Workspace Order Creation + Lab Configurations Refactor

You are working in the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Complete and harden the focused Laboratory module refactor so Lab staff have a clear order-creation flow and a dedicated Lab Configurations area for tests, panels, and reference ranges.

Use the actual codebase as the source of truth. Preserve the existing architecture, folder structure, naming conventions, coding style, Riverpod/controller patterns, shared component patterns, backend route style, authorization/scoping patterns, realtime behavior, and localization approach.

No task-specific screenshots were present in the archive. Use the existing Lab UI/code and the written requirements below as the visual/UX source of truth.

---

## Problem to Solve

The Lab workspace must prioritize creating lab orders for existing patients. Lab catalog management must be moved into a dedicated Lab Configurations area.

Required behavior:

1. The main Lab toolbar must show `Create Lab Order`, not a generic `Create Item`.
2. `Create Lab Order` must open the lab order creation flow directly.
3. The generic chooser flow with `Lab order`, `Lab test`, and `Lab panel` must not appear from the main Lab toolbar.
4. Lab order creation must allow selecting/searching an existing patient.
5. Encounter and existing lab order context search/selection must be supported where the current codebase supports it.
6. The Lab order flow must not create a new patient.
7. The Lab order flow must not show or require editable order time fields such as `ordered_at`, `ordered time`, or equivalent.
8. The frontend must not send manual `ordered_at` during Lab order creation.
9. Lab order creation time must come from the backend/server clock.
10. The main Lab toolbar must show `Lab Configurations`, not `Reference ranges`.
11. `Lab Configurations` must manage Lab tests, Lab panels, and reference ranges.
12. Lab tests and Lab panels must support add, edit, and delete.
13. Reference ranges must be editable through the Lab test configuration flow.
14. Lab tables, search bars, and searchable selects must remain responsive while typing.
15. Frontend state, backend state, and existing Lab realtime/polling behavior must remain synchronized.

---

## Relevant Project Areas to Inspect and Modify Only Where Needed

### Frontend

Inspect these files first and modify only the files required for the task:

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
* `frontend/lib/l10n/app_localizations.dart`
* `frontend/lib/l10n/app_localizations_en.dart`

Reuse existing shared components in `frontend/lib/shared/*` before creating new ones.

### Backend

Inspect these files/modules and modify only where needed:

* `backend/src/modules/lab-workspace/*`
* `backend/src/modules/lab-order/*`
* `backend/src/modules/lab-order-item/*`
* `backend/src/modules/lab-test/*`
* `backend/src/modules/lab-panel/*`
* `backend/src/modules/lab-result/*`
* `backend/src/modules/lab-sample/*`
* `backend/src/app/router.js`
* `backend/prisma/schema.prisma`
* Lab seeders/scripts only if the catalog data shape actually changes

### App Planner

Use as guidance only; do not rewrite planner files unless required by an existing project rule:

* `app-planner/dev-plan/21-lab.md`

The planner emphasizes preserving the existing Lab architecture and reusing `AppWorkspace`, `AppListTable`, `AppSearchBar` / `AppListTableSearch`, `AppDialog`, shared form fields, access gates, and existing Lab API route families.

---

## Existing Codebase Facts to Preserve

The current Lab frontend already uses:

* `AppWorkspace` for the Lab page shell.
* `AppListTable` and `AppListTableSearch` for Lab worklists/configuration tables.
* `AppDialog` for Lab dialogs.
* `LabWorkspaceController` with Riverpod state, polling, and realtime refresh.
* `LabOrderContextDialog` for selecting existing patient/encounter/order context.
* `ClinicalLabOrderActionDialog` for selecting tests/panels for an order.
* `LabCatalogTestDialog` and `LabCatalogPanelDialog` for Lab catalog configuration.
* `LabDeleteReasonDialog` for delete confirmation/reason flows.
* Shared searchable/select/form/table/dialog components.

The backend Lab order creation flow already has server-side order time behavior in the Lab order service. Verify this behavior and do not regress it.

---

## Main Lab Workspace Requirements

On `/lab`, preserve the existing workspace layout and behavior:

* Header: `Laboratory` with Lab/beaker-style icon.
* Green `Live sync` indicator when not saving.
* Toolbar actions:

  * `Orders view` / `Patients view`
  * `Create Lab Order`
  * `Lab Configurations`
  * Refresh
* Summary cards:

  * `Patients`
  * `Patients awaiting results`
  * `Patients completed`
* Worklist panel:

  * Patient Lab worklist / Lab worklist according to the current view.
* Search hint:

  * `Search patient, order, test, or encounter`
* Existing filter/settings/search/table behavior.
* Existing responsive layout.
* Existing worklist table behavior.
* Existing refresh behavior.
* Existing access/permission gates.

Do not redesign the whole Lab workspace.

---

## Create Lab Order Flow Requirements

When the user clicks `Create Lab Order`:

1. Open the Lab order creation flow directly.
2. Do not show a generic create chooser with `Lab order`, `Lab test`, and `Lab panel`.
3. Use the existing patient/context selection pattern where possible.
4. Allow selecting/searching an existing patient.
5. Support encounter selection/search where the existing patient detail/workspace or backend API supports it.
6. Support existing Lab order context selection where currently supported.
7. Do not allow creating a new patient from this flow.
8. Do not expose `ordered_at`, `ordered time`, or any editable manual order timestamp.
9. Do not send `ordered_at` in the frontend create payload.
10. Use the backend/server clock for Lab order creation time.
11. Continue using the existing catalog-driven Lab order dialog for selecting tests/panels where possible.
12. Add/keep icons in searchable options where supported:

    * Patient
    * Encounter
    * Existing order
    * Test
    * Panel
13. Keep keyboard and mouse usability.
14. Keep search responsive and cancel-safe.

If the shared `ClinicalLabOrderActionDialog` needs Lab-specific wording, add localized optional overrides or context-aware labels without breaking existing clinical-action usage elsewhere.

---

## Lab Configurations Dialog Requirements

When the user clicks `Lab Configurations`:

1. Open a configuration dialog using the existing dialog shell.
2. The visible title must be `Lab Configurations`.
3. The body text must explain that this area manages Lab tests, panels, units, qualitative options, and reference ranges used by backend result interpretation.
4. Preserve existing `AppDialog` behavior, including close and fullscreen/expand controls if available.
5. Include these tabs:

   * `Tests`
   * `Panels`
6. Tabs must use flat/squared styling.
7. Avoid rounded pill/capsule styling on the `Tests` and `Panels` tabs.
8. Include a search bar with filter/settings actions consistent with the existing Lab UI.
9. Include an add action for the active tab:

   * `Add test` on the Tests tab
   * `Add panel` on the Panels tab
10. Every test row must have edit and delete actions.
11. Every panel row must have edit and delete actions.
12. Reference ranges must be editable through the Lab test add/edit dialog.
13. Preserve any existing Lab QC/configuration action that is already part of the Lab configuration dialog unless it conflicts with this task.

---

## Lab Configurations Table Requirements

For Lab Configurations tables only:

1. Do not show more than 3 main data columns by default.
2. Keep the row number column usable.
3. Keep the action column visible by default.
4. The action column must not be hidden, clipped, or pushed out of reach.
5. Tables must support horizontal scrolling when additional columns are available.
6. Preserve column settings behavior if the existing table supports it.
7. Use compact, elegant icon actions with localized labels/tooltips.

Default visible columns:

### Tests Table

* Test name
* Test code
* Category
* Actions

Additional columns may remain available through horizontal scroll or column settings:

* Specimen type
* Result kind
* Unit
* Reference range details

### Panels Table

* Panel name
* Panel code
* Category
* Actions

Additional columns may remain available through horizontal scroll or column settings:

* Tests count
* Description or other supported metadata

---

## Frontend Implementation Requirements

1. Refactor or verify the main Lab toolbar so `Create Lab Order` calls the Lab order creation flow directly.
2. Remove or stop using the generic create-item chooser from the main Lab toolbar path.
3. If the old chooser becomes unused, remove it only if doing so does not cause unrelated churn.
4. Keep test and panel creation inside `Lab Configurations`.
5. Reuse existing shared dialogs where possible:

   * Existing Lab test dialog
   * Existing Lab panel dialog
   * Existing delete reason dialog
   * Existing clinical Lab order action dialog
   * Existing shared form/search/select/table/dialog components
6. If a reusable search/select improvement is needed, place it under `frontend/lib/shared/*`.
7. Keep the existing Riverpod/controller patterns used by the Lab module.
8. Keep current `AppWorkspace`, `AppListTable`, `AppListTableSearch`, `AppDialog`, and shared component conventions.
9. Do not introduce new UI libraries.
10. Do not duplicate shared dialogs/components that already exist in `frontend/lib/shared/*`.
11. Fix analyzer/linter issues in all touched files.
12. Remove unused imports, dead code, and stale references caused by the refactor.

---

## Localization Requirements

Ensure 100% localization/l10n.

1. Do not hardcode English strings in Dart widgets.
2. Localize all visible labels, hints, empty states, errors, dialog titles, body text, tab labels, tooltips, action labels, semantic labels, and confirmation messages.
3. Audit touched Lab UI code for hardcoded user-facing strings, including strings produced by entity/display helpers if those strings appear in widgets.
4. Update `frontend/lib/l10n/app_en.arb`.
5. Regenerate committed localization outputs because this project commits generated localization files.
6. Existing legacy key names may remain if renaming them would cause unnecessary churn; the visible localized text must match the required UX.

---

## Search and Performance Requirements

Review affected Lab tables, search bars, searchable selects, and catalog selectors.

Improve or preserve typing responsiveness by:

1. Debouncing expensive searches.
2. Avoiding backend requests on every keystroke unless debounced and cancel-safe.
3. Using generation tokens/cancel-safe logic for async search where applicable.
4. Limiting rendered suggestion counts.
5. Reusing normalized searchable text where useful.
6. Avoiding full widget rebuilds for large option lists where practical.
7. Keeping local search instant for small lists.
8. Showing clear icons in option rows where supported.
9. Preserving keyboard and mouse usability.
10. Avoiding sluggishness in Lab worklist search, patient search, encounter/order context search, and test/panel catalog search.

---

## Backend Implementation Requirements

1. Verify Lab order creation works without `ordered_at`.
2. Verify the Lab order create schema does not require frontend-supplied `ordered_at`.
3. Ensure Lab order creation uses backend/server time.
4. Do not create patients from the Lab order endpoint or Lab order UI.
5. Use existing patient, encounter, and order lookup/search patterns where available.
6. If search support is missing, add only the minimal backend support required for selecting an existing patient/encounter/order context.
7. Follow existing auth, facility/tenant scoping, validation, response shape, and error handling.
8. Confirm Lab test create/update/delete payloads align with existing backend schemas.
9. Confirm Lab panel create/update/delete payloads align with existing backend schemas.
10. Confirm reference range payloads remain compatible with backend result interpretation.
11. Preserve existing audit logging behavior.
12. Preserve existing Lab realtime/polling behavior.
13. If backend Lab catalog mutations are expected to emit realtime events, follow the existing Lab realtime event pattern; do not invent unrelated event families.
14. Do not make Prisma schema changes unless the existing schema cannot support the required behavior.

---

## State Synchronization Requirements

After creating, editing, or deleting Lab orders, tests, panels, or reference range data:

1. The visible UI must update without requiring a manual page reload.
2. Lab worklist counts and rows must refresh when a new order affects them.
3. Lab configuration tables must update after add/edit/delete.
4. Use targeted state updates where practical.
5. Avoid full workspace reloads unless the current controller architecture requires it.
6. Preserve existing polling and realtime sync behavior in `LabWorkspaceController`.

---

## Missing Details to Verify From the Codebase Before Implementing

Do not guess these details. Verify from the current codebase and preserve existing behavior where appropriate:

1. The current patient search/list API and frontend repository/component pattern.
2. The current encounter search/list API and whether Lab create-order context should resolve encounter by ID, code, or selected encounter object.
3. Whether selecting an existing Lab order should only prefill context or should support adding new items to that existing order.
4. Whether multiple reference ranges per test are fully supported in the UI/backend now, or whether the current single-primary-range editing UI should be preserved while keeping existing additional ranges intact.
5. Whether any legacy `Reference ranges` localization keys should be renamed or kept to avoid unnecessary churn.
6. Whether generated Flutter localization files must be regenerated after ARB changes.
7. Whether Lab catalog mutations should emit realtime events in addition to local state updates.
8. Whether any existing tests cover Lab workspace, Lab catalog dialogs, or shared searchable/select/table components.

---

## Testing and Verification

Run and fix all relevant checks.

### Frontend

Run:

* `flutter analyze`
* Existing Flutter tests relevant to Lab/shared components, if present
* Localization generation/checks according to the project convention

Add or update focused tests only where the project already has a suitable test pattern.

### Backend

From `backend`, run and fix:

* `npm run lint`
* `npm run test`
* `npm run openapi:validate` if backend API contracts are changed
* Any narrower relevant backend tests if available

Verify:

1. Lab order creation passes backend validation without `ordered_at`.
2. Lab order creation uses server time.
3. Lab test create/update/delete still works.
4. Lab panel create/update/delete still works.
5. Reference range payloads still work with backend interpretation.

---

## Manual Verification Checklist

1. Open `/lab`.
2. Confirm the main toolbar shows `Create Lab Order`.
3. Confirm the main toolbar shows `Lab Configurations`.
4. Click `Create Lab Order`.
5. Confirm no generic create-item chooser appears.
6. Confirm the flow allows searching/selecting an existing patient.
7. Confirm encounter/order context behavior matches verified codebase support.
8. Confirm no manual order time field is shown.
9. Confirm the frontend create payload does not send `ordered_at`.
10. Create a Lab order and confirm it appears in the Lab worklist/state without page reload.
11. Confirm Lab worklist counts update correctly.
12. Click `Lab Configurations`.
13. Confirm `Tests` and `Panels` tabs are flat/squared, not rounded pills.
14. Confirm the Tests table shows no more than 3 main data columns by default and keeps actions visible.
15. Confirm the Panels table shows no more than 3 main data columns by default and keeps actions visible.
16. Confirm both tables scroll horizontally when additional columns are available.
17. Confirm add/edit/delete works for tests.
18. Confirm add/edit/delete works for panels.
19. Confirm reference ranges can be edited through test configuration.
20. Confirm Lab search bars and searchable selects remain responsive while typing.
21. Confirm all new/touched visible strings are localized.
22. Confirm no analyzer/linter/test issues remain.

---

## Scope Limits

1. Modify only files required for this Lab refactor.
2. Do not rewrite unrelated modules.
3. Do not redesign the whole HMS layout.
4. Do not replace the existing state-management architecture.
5. Do not introduce new UI libraries.
6. Do not duplicate shared dialogs/components when existing `frontend/lib/shared/*` components can be reused or extended.
7. Do not create new patients from the Lab order flow.
8. Do not expose manual order creation time in the create-order form.
9. Do not send manual `ordered_at` from frontend Lab order creation.
10. Do not make backend schema/database changes unless strictly required.
11. Do not leave dead code, unused imports, untranslated strings, stale labels, or lint issues.
