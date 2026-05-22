Implement the HMS clinical action fixes and UI refresh improvements described below.

## Objective

Fix and improve the existing clinical action workflows in the Hospital Management System so that diagnosis, lab request, radiology request, admission request, follow-up, disposition, clinical notes, prescriptions/pharmacy orders, and radiology orders behave consistently, update the UI immediately after successful actions, and follow the existing HMS architecture and UI patterns.

Use the actual project codebase as the source of truth. Preserve the existing architecture, folder structure, naming conventions, coding style, localization approach, Riverpod/state management patterns, backend service/controller/schema patterns, and shared UI components.

No task-specific screenshots were found in the archive. Any UI/UX requirements below are derived from the raw implementation task and the existing code patterns.

---

## Project areas to inspect first

Inspect these files and related modules before making changes.

### App planner

Use these planning documents to understand the intended architecture and flows:

* `app-planner/dev-plan/01-policy.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/14-clinical.md`
* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/22-radiology.md`
* `app-planner/dev-plan/23-pharmacy.md`
* `app-planner/dev-plan/29-rooms-beds.md`
* `app-planner/opd-flow.md`
* `app-planner/ipd-flow.md`
* `frontend/app-planner/app-rules/`
* `backend/app-planner/app-rules/`

### Frontend

Main files to inspect and modify where required:

* `frontend/lib/shared/clinical_actions/clinical_order_action_dialogs.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_dialogs.dart`
* `frontend/lib/shared/clinical_actions/clinical_action_models.dart`
* `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
* `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
* `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart`
* `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart`
* `frontend/lib/features/clinical/domain/clinical_entities.dart`
* `frontend/lib/features/opd/shared/opd_flow_actions_dialog.dart`
* `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
* `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`
* `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/l10n/app_en.arb`
* generated localization files, if this project checks them in

Also inspect related tests under:

* `frontend/test/features/clinical/`
* `frontend/test/features/opd/`
* `frontend/test/features/radiology/`
* `frontend/test/features/rooms_beds/`
* `frontend/test/shared/`

### Backend

Inspect and modify backend only where needed to support the frontend correctly:

* `backend/src/modules/diagnosis/`
* `backend/src/modules/clinical-note/`
* `backend/src/modules/clinical-term/`
* `backend/src/modules/lab-order/`
* `backend/src/modules/radiology-order/`
* `backend/src/modules/pharmacy-order/`
* `backend/src/modules/admission/`
* `backend/src/modules/follow-up/`
* `backend/src/modules/opd-flow/`
* `backend/src/modules/bed/`
* `backend/src/modules/room/`
* `backend/src/modules/ward/`
* `backend/prisma/schema.prisma`, only if a schema change is truly required
* `backend/docs/api/v1/openapi.yaml`, only if API contracts are changed
* related backend tests under `backend/src/tests/modules/`

---

## Required implementation

### 1. Rename “Add note” to “Add clinical note”

Update the clinical note action label from:

* `Add note`

to:

* `Add clinical note`

Use the existing localization system. Do not hard-code this visible string directly in widgets.

Relevant current localization key to inspect:

* `clinicalAddNoteAction`

Keep existing dialog title and clinical note behavior unless a code issue is found.

---

### 2. Redesign diagnosis creation to use the shared reusable diagnosis/search component

The current diagnosis action must use the existing shared clinical term/diagnosis mechanism instead of a standalone or non-reusable implementation.

Requirements:

* Use the existing shared clinical action dialog/component architecture.
* Use existing clinical term suggestions for diagnosis search.
* Search diagnosis terms using the existing clinical terms API/repository flow with `term_type` / `termType` set to diagnosis.
* Diagnosis search must be searchable by diagnosis name and code where available.
* Support selecting more than one diagnosis before submission.
* Redesign the diagnosis dialog similarly to the existing lab request and radiology request dialogs:

  * left side: searchable existing/predefined diagnosis results
  * right side: selected diagnoses
  * allow adding/removing selected diagnoses before submission
  * clearly show selected diagnosis name, code, and type/status where available
* Preserve or reuse the existing visual pattern from `ClinicalLabOrderActionDialog`.
* Do not create a separate modal family if the shared clinical action dialogs already support the pattern.
* If the backend endpoint only creates one diagnosis at a time, submit selected diagnoses sequentially using the existing endpoint and refresh the selected patient/encounter bundle only after all successful creations.
* Continue creating/updating shared clinical term favorites where the existing flow already does so.
* Ensure diagnosis creation updates the patient details dialog/clinical workspace in real time after success, without requiring a manual page refresh or reopening the encounter.

Apply this behavior consistently anywhere the shared diagnosis dialog is used, including clinical workspace and OPD flow actions.

---

### 3. Fix real-time UI updates after successful actions

After these actions succeed, the currently selected patient/encounter/OPD details must update immediately in the visible UI:

* add clinical note
* add diagnosis
* request lab
* request radiology
* request admission
* create follow-up
* complete disposition
* prescribe/create pharmacy order
* cancel/delete/update lab order
* cancel/delete/update radiology order where supported
* cancel/delete pharmacy order where supported

Requirements:

* Use the existing controller/repository refresh patterns.
* Do not force full app reloads.
* Refresh only the affected selected detail/worklist data where possible.
* Ensure modal dialogs only report success after persistence succeeds and the relevant state has been refreshed.
* Fix stale DTO/entity mapping if the backend response already includes the new records but the frontend does not display them.
* Fix backend list/detail endpoints only if they are not returning newly created records correctly.
* Ensure loading/saving states are always cleared on success and failure.
* Show useful error messages instead of vague messages such as “check the details” when the backend provides or can provide a clearer validation error.

---

### 4. Improve radiology request dialog globally

Update the shared radiology request dialog so all callers benefit.

Relevant existing component:

* `ClinicalRadiologyOrderActionDialog`

Requirements:

* Keep the existing multi-select request pattern.
* Add a searchable select for modality.

  * Label it `Modality`.
  * Example modality: `CT`.
* Add a searchable select for body region.

  * Label it `Body region`.
* Keep or improve the existing laterality select.
* Keep the clinical notes text field.
* Keep the priority/urgency field if it already exists.
* Move the free-text search/matching study list below the modality, body region, and laterality selectors.
* The matching radiology studies section must only show studies that match the selected modality/body region/laterality and the entered search text.
* Derive modality/body-region/laterality options from existing radiology catalog/reference data where possible.
* Do not hard-code a fixed radiology catalog.
* Use existing `ClinicalActionCatalogOption` fields such as category, secondary text, status, search text, and related metadata where appropriate.
* Add appropriate existing project icons to make the dialog visually clear and consistent with the lab request dialog.
* Preserve the selected radiology requests panel on the right.
* Allow selecting more than one radiology request.
* Each selected radiology request must clearly show:

  * study name
  * modality where available
  * body region where available
  * laterality where available
  * priority/urgency
  * clinical notes if provided
* When `Request radiology` succeeds, update the patient details/dialog/tables in real time.

Backend/API requirement:

* Verify whether radiology order payloads and DTOs already support modality.
* If modality is catalog-derived only, use it for filtering/display without changing the backend payload.
* If the backend supports or should persist modality in `request_details`, update frontend DTOs and backend schemas/services consistently.
* Do not invent unsupported API fields without checking the backend schema and service first.

Also verify frontend DTO mapping for radiology requested test items. If per-item `request_details` are returned by the backend, ensure body region, laterality, priority, clinical note, and modality are decoded from the correct item-level or parent-level location.

---

### 5. Fix lab request real-time refresh

The lab request dialog is mostly working, but after clicking `Request lab`, the UI does not update immediately.

Requirements:

* Keep the existing lab request dialog design unless a bug requires a small adjustment.
* Fix the controller/repository/backend refresh path so new lab orders appear immediately in:

  * patient details
  * clinical workspace sections
  * lab order tables/panels
  * OPD flow details where applicable
* Preserve existing edit/cancel/delete behavior for lab orders.

---

### 6. Fix admission request dialog and admission creation

Improve the admission request UI and fix admission submission failures.

Relevant existing component:

* `ClinicalAdmissionActionDialog`

Requirements:

* Do not show raw row IDs/UUIDs to users when a human-readable ward, room, or bed label/name is available.
* Ward selection should narrow the next options to rooms with available beds.
* Room selection should narrow the next options to beds available in that room.
* Bed options should show availability/status directly inside the bed option display.
* Remove or avoid a separate “Bed availability” display if the same information can be cleanly merged into the bed row/selection.
* If no available rooms or beds exist for the selected ward/room, show a clear empty-state message.
* If a selected bed is unavailable, show a clear message such as “This bed is no longer available. Please choose another bed.”
* Improve the visual layout so ward, room, bed, and availability/status fields do not wrap awkwardly into two-line cramped controls.
* Use existing shared components such as:

  * `AppDialog`
  * `AppFormSection`
  * `AppResponsiveFieldRow`
  * `AppSelectField.searchable`
  * `AppTextField`
  * `AppInfoTileGrid`
  * existing status badges/chips where available
* Fix the admission request submission so a valid available bed creates the admission successfully.
* Verify the frontend payload against the backend admission schema/service.
* Include reason/notes only if the backend supports them or the existing domain model expects them.
* If backend validation fails, surface the actual useful validation message to the user.
* After a successful admission request, update the clinical/OPD patient details in real time.

---

### 7. Fix follow-up creation/update behavior

Ensure follow-up actions work correctly and persist to the database.

Requirements:

* Verify the frontend follow-up dialog payload.
* Verify backend follow-up endpoint/schema/service behavior.
* After creating a follow-up, update the visible clinical/OPD details immediately.
* Show follow-up records in the correct patient detail section.
* Avoid duplicate follow-up rows after refresh.

---

### 8. Fix disposition completion and indefinite loading

The disposition flow can enter an indefinite loading state, especially when completing disposition with “admission not required” and notes such as “patient is stable”.

Requirements:

* Fix the loading state so it always stops after success or failure.
* Verify the OPD disposition backend schema and accepted decision values.
* Map frontend disposition values to backend-supported values correctly.
* For “admission not required”, complete the disposition using the correct backend decision, likely the discharge/close-flow equivalent after verifying the backend schema.
* Preserve notes/reason.
* Show a useful success or failure message.
* Update selected patient/OPD/clinical details immediately after success.
* Do not hard-code incorrect disposition decisions.
* Do not remove required clinical review behavior unless the backend flow requires it.

---

### 9. Improve clinical notes, prescriptions, radiology orders, and pharmacy orders display

Improve the patient details/clinical record sections.

Requirements:

* Label the clinical notes section clearly as patient clinical notes.
* Keep clinical notes visually separate from prescriptions/pharmacy orders.
* Improve prescription/pharmacy order display so it is human-readable.

  * Show medication name, dose, route, frequency, duration, quantity, and instructions clearly where available.
  * Avoid confusing duplicate rows/items.
  * If one pharmacy order contains multiple items, render them cleanly without repeating unnecessary parent information.
* Improve radiology order display.

  * Show study name, status, priority, modality/body region/laterality, clinical notes, and date where available.
  * Add edit/cancel/delete actions for radiology orders only where supported by existing backend routes/API contracts.
  * If backend supports cancellation but not hard delete, implement cancel and do not fake deletion.
  * Match the existing lab order action style as closely as possible.
* Keep lab order display behavior intact, including existing edit/cancel/delete support.

---

### 10. Backend/API changes, only if required

Only modify backend code if the frontend cannot correctly support the requested behavior with existing APIs.

When backend changes are required:

* Preserve existing Express/Prisma module architecture.
* Preserve controller/service/repository/schema separation.
* Update validation schemas.
* Update services with tenant/facility/patient/encounter scoping preserved.
* Update OpenAPI documentation if request/response contracts change.
* Add or update backend tests for changed behavior.
* Do not create duplicate endpoints if an existing endpoint should be fixed or extended.
* Do not bypass authorization, tenant scoping, facility scoping, or audit behavior.

---

## UI/UX requirements

Follow existing HMS UI patterns.

Use existing shared frontend components and visual conventions. Do not introduce a new design system.

Specific UI requirements:

* Diagnosis dialog should visually match the lab request dialog pattern:

  * searchable results on the left
  * selected items on the right
  * clear selected count
  * easy remove action
  * empty states
* Radiology dialog should visually match the lab request dialog pattern while adding:

  * modality searchable select
  * body region searchable select
  * laterality select
  * clinical notes
  * filtered matching studies below the selectors
* Admission dialog should be cleaner and less cramped:

  * ward, room, and bed controls should be readable
  * bed status should be visible in the bed option itself
  * no raw IDs should be visible when labels exist
  * clear empty and unavailable states
* Use existing icons already used in the project where possible.
* Use localization for user-facing strings.
* Maintain responsive behavior for desktop and smaller widths.

---

## Testing and verification

Add or update tests where practical and relevant.

At minimum, verify:

### Frontend

Run:

* `cd frontend`
* `flutter test`

Add/update targeted tests for:

* diagnosis multi-select dialog behavior
* clinical workspace refresh after diagnosis/lab/radiology/admission/follow-up/disposition actions
* radiology DTO mapping for request details
* admission option filtering and unavailable-bed validation
* pharmacy/prescription display formatting where practical
* OPD flow action refresh behavior where applicable

### Backend

If backend files are changed, run:

* `cd backend`
* `npm run lint`
* `npm run test:backend`
* `npm run validate`

If OpenAPI is changed, also run:

* `npm run openapi:validate`

Add/update targeted backend tests for any changed module, especially:

* diagnosis
* lab order
* radiology order
* admission
* follow-up
* OPD disposition
* pharmacy order

### Manual verification scenarios

Verify these flows manually in the running app:

1. Open a patient/encounter clinical detail.
2. Click `Add clinical note`; save a note; confirm it appears immediately.
3. Click `Add diagnosis`; search diagnosis terms; select multiple diagnoses; save; confirm they appear immediately.
4. Click `Request lab`; select tests/panels; submit; confirm lab orders appear immediately.
5. Click `Request radiology`; select modality/body region/laterality; confirm matches filter correctly; select one or more studies; submit; confirm radiology orders appear immediately.
6. Request admission:

   * select ward
   * confirm rooms are filtered to those with available beds
   * select room
   * confirm beds are filtered to available beds
   * submit
   * confirm the admission appears immediately
7. Try admission when no available bed exists and confirm a clear message is shown.
8. Create a follow-up and confirm it persists and appears immediately.
9. Complete disposition with “admission not required” and notes; confirm no indefinite loading occurs.
10. Review clinical notes, prescriptions/pharmacy orders, lab orders, and radiology orders for clean display and no confusing duplicates.
11. Verify radiology edit/cancel/delete behavior only where supported by the backend.

---

## Scope limits

Do not implement printing in this task.

Do not perform unrelated rewrites, broad refactors, dependency changes, route restructuring, theme redesigns, or database schema changes unless absolutely required for the requested behavior.

Do not replace the existing Riverpod/controller/repository/DTO architecture.

Do not create new duplicate modal/dialog families when existing shared clinical action dialogs should be extended.

Do not hard-code catalog data.

Do not hard-code user-facing strings.

Do not modify unrelated modules.

Do not include generated build artifacts, caches, `node_modules`, `.dart_tool`, build output, or full project copies in the final deliverable.

Modify only the files required for this requested change.

---

## Final deliverable

Return a `.zip` archive containing only the files and folders that were created or updated, placed in their correct relative project directories.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the archive that safely perform those delete or rename operations.

PowerShell scripts must:

* use correct relative paths
* check that the target exists before deleting or renaming
* not delete unrelated files
* not use broad wildcards that could remove unrelated project content

Also include a concise implementation summary and verification results inside the archive as a small text or markdown file, unless the calling workflow explicitly forbids summary files.
