# Task: Refine Radiology workspace, imaging-test configuration, reusable request imaging flow, and reporting UX

Inspect the attached HMS codebase and implement the requested radiology improvements using the existing architecture, naming conventions, UI patterns, localization approach, and testing style.

## Main problem

The Radiology module has improved, but several workflows need refinement:

1. The worklist column order must change depending on whether the user is in Orders view or Patients view.
2. The Radiology configurations dialog should manage Imaging tests only; remove the Equipment tab UI.
3. Imaging tests must be easier to create, edit, delete, and visually identify by modality.
4. The reusable Request radiology/imaging component must use a searchable select + Add flow instead of showing a large catalog list.
5. Radiology workflow details, request details editing, reporting, print preview, studies/assets, and doctor review need better usability while staying synchronized with backend state and realtime updates.

## Relevant project areas to inspect or modify

Inspect these areas first and modify only the files required for the requested changes.

### Frontend

* `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
* `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
* `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
* `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
* `frontend/lib/features/radiology/data/repositories/radiology_repository_impl.dart`
* `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_models.dart`
* `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart`
* `frontend/lib/shared/components/*`
* `frontend/lib/l10n/app_en.arb`
* generated l10n files if this project commits them

Reuse existing components in `frontend/lib/shared/*` before creating new widgets.

### Backend

* `backend/src/modules/radiology-workspace/routes`
* `backend/src/modules/radiology-workspace/controllers`
* `backend/src/modules/radiology-workspace/schemas`
* `backend/src/modules/radiology-workspace/services`
* `backend/src/modules/radiology-workspace/repositories`
* `backend/src/modules/radiology-test/*`
* `backend/src/modules/radiology-order/*`
* `backend/src/modules/radiology-result/*`
* `backend/src/modules/imaging-study/*`
* `backend/src/modules/imaging-asset/*`
* `backend/prisma/schema.prisma` only if a verified schema change is truly required

### App planner

Review relevant planning docs and update only if the project convention requires task-tracking changes:

* `app-planner/dev-plan/22-radiology.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/35-reports-audit.md`
* `app-planner/prompt.md`

## Existing UI details that must be preserved or converted into requirements

The coding agent may not have screenshots, so implement using these written UI requirements:

### Current Radiology worklist screen

The `/radiology` page shows:

* Title: `Radiology`
* Green `Live sync` status beside the title.
* Top buttons:

  * `Patients view`
  * `Configurations`
  * `Refresh`
  * primary `Request imaging`
* Summary cards:

  * `Total orders`
  * `Released`
* Worklist section:

  * Title: `Imaging worklist`
  * Subtitle: `System imaging orders with modality workflow and report status.`
  * Search placeholder: `Search patient, order, encounter, study, report, or PACS text`
  * Table currently shows `#`, `Patient`, `Order`, `Study`, `Priority`.

### Required worklist behavior

* In **Orders view**, the first data column after `#` must be `Order`.

  * Default order: `#`, `Order`, `Patient`, `Study`, `Priority`.
* In **Patients view**, the first data column after `#` must be `Patient`.

  * Default order: `#`, `Patient`, `Order`, `Study`, `Priority`.
* Preserve current filters, search, sorting, settings, pagination, mobile layout, and table-column settings behavior.
* Do not show more than the current intended number of default data columns unless the existing settings allow it.

Also verify backend support for the `view` query parameter. The frontend already sends a view value, and backend schema/service support it, but confirm that the radiology workspace controller forwards `view` from `req.query` into the service filters.

## Radiology configurations dialog

Current dialog behavior:

* Title: `Radiology configurations`
* Body text currently says it manages persisted imaging tests and equipment records.
* It has two tabs:

  * `Imaging tests`
  * `Equipment`
* Imaging tests table columns:

  * `Name`
  * `Code`
  * `Modality`
  * `Action`
* Existing rows include standard catalog items such as:

  * `Abdomen and pelvis Contrast fluoroscopy`
  * `Abdomen and pelvis CT 3D reconstruction`
* The current action column is too limited.

Required behavior:

* Remove the Equipment tab UI completely.
* Remove the tab strip entirely because there is now only one section: Imaging tests.
* Update copy/body text so it no longer mentions equipment.
* Keep the configurations dialog focused on Imaging tests.
* Preserve the current dialog visual style, spacing, toolbar, search, refresh, and create behavior.
* Add useful row actions for imaging tests:

  * edit
  * delete
  * copy/customize only where still needed for standard catalog rows
* Do not fake edit/delete for generated standard catalog rows if the backend does not support direct mutation of those rows.

  * Standard catalog rows may remain read-only or use a localized “copy/customize” flow.
  * Once a standard row is copied into a persisted/custom imaging test, the copied row must be editable and deletable.
* The create/edit form should support the existing backend contract:

  * `name`
  * optional `code`
  * `modality`
* Do not add unsupported imaging-test fields unless verified in the backend model and APIs.

## Modality labels and icons

Current modality labels are inconsistent, for example some display as title case.

Required behavior:

* Use consistent uppercase display labels for modalities throughout Radiology and reusable request imaging UI.

  * Examples: `X-RAY`, `CT`, `MRI`, `ULTRASOUND`, `FLUOROSCOPY`, `MAMMOGRAPHY`, `PET`, `NUCLEAR MEDICINE`, `INTERVENTIONAL RADIOLOGY`, `ECG`, `ECHO`, `ENDO`, `GASTRO`, `OTHER`.
* Preserve stored enum/API values; only change display labels unless backend data truly requires normalization.
* Add appropriate visual icons for modality options and rows.

  * Use existing Material icons/shared icon patterns where possible.
  * Do not add external packages or assets unless absolutely necessary.
  * Provide sensible fallbacks for unknown modalities.
* Use these icons consistently in:

  * imaging-test configuration rows/forms,
  * modality filters,
  * request imaging/radiology selector options,
  * selected request rows,
  * workflow detail summaries where appropriate.

## Reusable Request radiology/imaging component

There is already a good shared clinical radiology request dialog in:

`frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`

This shared flow appears from the clinical workspace and currently has:

* `Modality`
* `Body region`
* `Laterality`
* `Priority`
* `Clinical note`
* `Search radiology catalog`
* A large left-side catalog list showing text such as `Showing 100 of 6500 matches`
* A right-side `Selected radiology requests` panel

The Radiology workspace has a separate `Request imaging` form with:

* `Catalog search (optional)`
* `Search catalog`
* `Patient *`
* `Encounter (optional)`
* `Clinical notes (optional)`
* `Selected radiology requests`

Required behavior:

* Reuse/refactor the shared clinical radiology request component instead of maintaining separate request-selection behavior in Radiology.
* Remove the large catalog results list that shows text like `Showing 100 of 6500 matches`.
* Replace it with a searchable select/dropdown for radiology catalog items.
* Place an `Add` button to the right of the searchable select.
* The `Add` button must remain disabled until a catalog item is selected.
* When the user clicks `Add`, the selected catalog item is added to `Selected radiology requests`.
* Prevent duplicate selected requests unless the existing clinical model explicitly supports duplicates.
* Keep the selected requests list visible and easy to manage.
* Selected requests should support removing items and editing per-request details where already supported.
* The catalog dropdown options must narrow based on selected filters:

  * modality
  * body region
  * laterality
  * priority where applicable
  * search text
* Example: when `CT` is selected, the dropdown must not show `X-RAY` tests. When `MRI` is selected, it should show MRI-compatible tests only.
* Use catalog/test metadata from the existing backend/reference-data model; do not hard-code unsupported medical mappings.
* Body regions should have clear icons where possible.
* Laterality should include supported values such as `LEFT`, `RIGHT`, and `BILATERAL`; verify any additional values from the existing code/catalog before adding them.
* The raw task mentions “colono and so on”; treat this as unclear. Verify whether this belongs to body region, modality, procedure, or catalog metadata before implementing. Do not invent unsupported laterality values.
* The shared selector must remain reusable across clinical, radiology, nursing, IPD, ICU, theater, OPD, physiotherapy, or any future place where radiology requests are made.
* Keep the Radiology workspace request payload compatible with the existing backend multi-test contract:

  * patient
  * optional encounter
  * order notes/clinical notes
  * one or more selected requested tests
  * per-test modality, body region, laterality, priority, clinical note/request details

## Radiology workflow detail screen

Current workflow detail shows:

* Header title: `Radiology workflow`
* Patient name and status.
* Status such as `Completed`.
* Warning such as `Billing gate unavailable`.
* Action button such as `Perform study`.
* Card-like fields:

  * `Ordered`
  * `Modality`
  * `Payment`
  * `Authorization`
* Request details:

  * `Study`
  * `Priority`
  * `Body region`
  * `Laterality`
  * `Clinical notes`

Required behavior:

* Keep patient name and status prominent.
* Replace the card-like summary fields with a compact property/value layout.
* Show values as simple rows or inline fields:

  * `Ordered: <date>`
  * `Modality: <MODALITY>`
  * `Payment: <value>`
  * `Authorization: <value>`
  * include `Encounter: <value>` if available and already supported by the data model
* Use uppercase modality display in this detail view.
* Preserve missing values as localized `Not available`.
* Do not invent billing or authorization data.
* Make request details editable:

  * priority
  * body region
  * laterality
  * clinical notes
* Use a focused edit action/dialog or inline edit pattern consistent with existing HMS UI.
* Persist edits to the backend using the smallest correct existing API path where possible.
* After saving edits, refresh the selected workflow detail and worklist row.
* Ensure realtime events or existing refresh mechanisms propagate the update to other open clients.

## Reporting UX

Current report section shows:

* Report status such as `Final`.
* Reported timestamp.
* Generated report preview.
* Actions such as print, draft, finalize, attest, amend/addendum depending on state.

Required behavior:

* Improve the draft/final report editor so it is easier to use and visually clear.
* Keep existing backend report lifecycle actions:

  * draft
  * finalize
  * attest/request attestation if present
  * amend/addendum if present
* Use clear localized sections such as:

  * Findings
  * Impression/Conclusion
  * Report narrative
  * References/assets where supported
* Make addendum/amendment entry user-friendly, but do not change backend semantics unless required.
* Do not add unsupported medical AI/report-generation behavior.
* Preserve audit/realtime behavior for report mutations.

## Print/report preview

Current print preview has selectable sections but can show too much metadata.

Required behavior:

* Default print/report preview should emphasize:

  * patient identity/context
  * modality
  * test/study performed
  * requested details
  * findings
  * impression/report text
  * signer/reporter where available
* Metadata should be optional and not dominate the default preview.
* Keep a way for the user to select what appears on the printed report.
* Use the existing shared print template/components.
* Do not implement printing by screenshots.

## Studies/assets and PACS

Current section says studies will appear after imaging is performed and supports tracking imaging studies, uploaded assets, and PACS synchronization state.

Required behavior:

* Preserve existing studies/assets/PACS display.
* Support adding images/assets only if the backend and storage contract are already present and can be verified.
* If upload persistence is not fully wired, do not fake it. Keep or improve the localized empty/disabled state text so users understand what is available.
* Do not introduce unrelated storage architecture.

## Doctor review section

Current section says the latest report is released for clinical review and shows a `Ready for review` state.

Required behavior:

* Clarify the purpose of this section with concise localized text or tooltip.
* Meaning: the final/released radiology report is ready for the requesting clinician or doctor to review.
* If no final report is released, show a clear pending/unavailable state.
* Do not add new doctor-review workflow actions unless existing backend support is verified.

## Backend and realtime synchronization

* Preserve the existing backend architecture and service boundaries.
* Ensure frontend changes are backed by real backend mutations.
* Avoid frontend-only fake state.
* Ensure radiology order creation, request-detail edits, imaging-test CRUD, report actions, study/assets actions, and refreshes remain synchronized.
* Use the existing realtime group/event system already used by the Radiology workspace.
* The UI should update after:

  * a user changes data in the UI,
  * the backend/database changes data and emits existing realtime events,
  * refresh/polling runs.
* Verify that creating multiple requested tests remains supported.
* Verify that radiology reference data refreshes after imaging-test create/update/delete so the request selector reflects new tests.

## Localization

* Ensure 100% localization.
* No new hard-coded user-facing strings in Dart widgets or backend responses shown directly to users.
* Add/update l10n keys for:

  * uppercase modality display labels,
  * imaging-test configuration copy,
  * edit/delete actions,
  * request selector searchable dropdown and Add behavior,
  * request-detail edit labels,
  * doctor-review explanatory text,
  * studies/assets empty or disabled states,
  * report/print section labels.
* Update generated localization files if that is the project convention.

## Scope limits

* Do not rewrite the Radiology module.
* Do not redesign unrelated screens.
* Do not change unrelated backend modules.
* Do not replace existing shared HMS components when they can be reused.
* Do not introduce new packages unless there is no reasonable existing project solution.
* Do not change database schema unless verified as necessary.
* Do not remove backend equipment APIs unless the codebase proves they are unused and removal is required. The requested removal is specifically for the Radiology configurations UI.
* Modify only files required for this task.

## Testing and verification

Run existing targeted and general checks according to the project scripts.

Minimum expected verification:

### Frontend

* Run Flutter/Dart dependency and generation steps used by this project.
* Run `flutter analyze`.
* Run relevant Flutter tests, including existing radiology DTO/controller/widget tests if present.
* Add or update tests for:

  * Orders view default column order.
  * Patients view default column order.
  * request selector filtering by modality.
  * Add button disabled/enabled behavior.
  * selected request population/removal.
  * imaging-test create/edit/delete UI state where practical.
  * request detail edit payload/state refresh where practical.

### Backend

* Run backend lint.
* Run backend tests.
* Add or update tests for:

  * radiology workspace `view` query forwarding/filtering.
  * imaging-test create/update/delete behavior.
  * request-detail update path if a new or adjusted endpoint/service method is required.
  * realtime/event emission or refresh behavior where existing tests cover this pattern.

### Manual verification

Verify manually in the browser:

1. `/radiology` Patients view shows `Patient` immediately after `#`.
2. `/radiology` Orders view shows `Order` immediately after `#`.
3. Configurations dialog shows only Imaging tests and no Equipment tab.
4. Imaging-test rows have correct available actions.
5. Create/edit/delete imaging test works for persisted/custom tests.
6. Modality labels are uppercase and have appropriate icons.
7. Request imaging/radiology uses searchable select + Add instead of a large catalog list.
8. Selecting `CT` hides `X-RAY` tests from the dropdown; selecting `MRI` hides non-MRI tests.
9. Add button is disabled until a catalog item is selected.
10. Selected radiology requests populate correctly.
11. Radiology workflow detail uses property/value rows instead of summary cards.
12. Request details can be edited and persisted.
13. Report editor is clearer and existing report lifecycle actions still work.
14. Print preview defaults to clinically useful report content, with metadata optional.
15. Doctor review section clearly explains its purpose.
16. Realtime/live refresh still updates the worklist and selected workflow.

## Final deliverable

Return a zipped archive containing only files and folders that were created or updated, placed in their correct relative project directories.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those delete or rename operations using correct relative paths. The scripts must not delete unrelated files.

Clear all linter/analyzer issues before returning the archive.
