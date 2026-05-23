# Implementation Prompt: Fix HMS Lab Workspace Load Failure and Flutter Localization Resource Error

You are working on the HMS codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

## 1. Problem to solve

Fix two issues in the current Hospital Management System codebase:

1. The **Lab** module route at `/lab` does not open correctly. The app shell loads, but the Lab workspace body shows a generic failure state:

   * red warning/exclamation icon
   * title: `Connection problem`
   * body: `Check your connection and try again.`
   * blue `Try again` button

2. Running the Flutter frontend using `frontend/tool/run_web_5201.ps1` shows this localization generation error:

```txt
Error: Resource attribute "@opdSummaryAllPatientsLabel" was not found. Please ensure that each resource has a corresponding @resource.
```

All other modules reportedly open correctly, so keep the fix focused on Lab and the localization/resource-attribute problem.

## 2. Screenshot-derived UI/UX requirements

The coding agent may not have access to the screenshots, so preserve these requirements explicitly:

* Browser URL shown: `127.0.0.1:5201/lab`.
* The HMS shell/header loads successfully:

  * HOSSPI logo and `HOSSPI Hospital Management System` title.
  * Top-right online status badge shows `Online`.
  * Notification icon has a red badge.
  * User avatar initials are visible.
* The left navigation loads successfully and the **Lab** menu item is highlighted under **Diagnostics and medication**.
* The broken state appears only inside the main content area.
* After the fix, `/lab` must render the existing Laboratory workspace UI using the project’s current `AppWorkspace`/shared layout pattern, not a placeholder.
* If there are no lab orders, show the existing localized empty/no-orders Lab state, not the generic connection problem.
* The generic connection problem state should only appear for real network/backend availability failures.

## 3. Relevant files and folders to inspect

Use the actual codebase as the source of truth.

### Planner/reference files

Inspect for architecture and workflow conventions, but do not modify unless required:

* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/01-policy.md`
* `app-planner/opd-flow.md`
* `app-planner/ipd-flow.md`
* `app-planner/app-write-up.md`
* `app-planner/prompt.md`

Note: `app-planner/prompt.md` appears to describe a broader previous Lab workflow refactor. Use it only as context. Do not expand this task into an unrelated Lab redesign.

### Frontend files

Inspect and modify only where needed:

* `frontend/tool/run_web_5201.ps1`
* `frontend/l10n.yaml`
* `frontend/lib/l10n/app_en.arb`
* `frontend/lib/l10n/app_localizations.dart`
* `frontend/lib/l10n/app_localizations_en.dart`
* `frontend/lib/l10n/app_localizations_x.dart`
* `frontend/lib/app/router/app_router.dart`
* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/features/lab/domain/entities/lab_entities.dart`
* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`
* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`
* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
* Add/update focused tests under `frontend/test/features/lab/**` if needed.

Also compare against the working diagnostics module pattern where helpful:

* `frontend/lib/features/radiology/**`

### Backend files

Inspect and modify only where needed:

* `backend/src/app/router.js`
* `backend/src/modules/lab-workspace/routes/lab-workspace.routes.js`
* `backend/src/modules/lab-workspace/controllers/lab-workspace.controller.js`
* `backend/src/modules/lab-workspace/schemas/lab-workspace.schema.js`
* `backend/src/modules/lab-workspace/services/lab-workspace.service.js`
* `backend/src/modules/lab-workspace/services/lab.serializer.js`
* `backend/src/modules/lab-workspace/services/lab.shared.js`
* `backend/src/modules/lab-workspace/services/lab.configuration.js`
* `backend/src/modules/lab-workspace/services/lab.interpretation.js`
* `backend/src/modules/lab-order/**`
* `backend/src/modules/lab-order-item/**`
* `backend/src/modules/lab-sample/**`
* `backend/src/modules/lab-result/**`
* `backend/src/modules/lab-test/**`
* `backend/src/modules/lab-panel/**`
* `backend/src/modules/lab-qc-log/**`
* `backend/src/locales/en.json`
* Existing tests under `backend/src/tests/modules/lab-workspace/**` and related Lab module tests.

## 4. Specific implementation requirements

### A. Fix the Lab page load failure

Reproduce the failure first:

1. Start the backend using the existing backend workflow.
2. Start the frontend from `frontend` using:

```powershell
.\tool\run_web_5201.ps1
```

3. Open:

```txt
http://127.0.0.1:5201/lab
```

4. Inspect browser console/network and backend logs to identify the actual failing request.

Likely request to verify from the codebase:

```txt
GET /api/v1/lab/workbench
```

Fix the actual root cause. Do not hide the error by swallowing failures or replacing the Lab page with static content.

Verify these contracts:

* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart` calls the correct backend Lab workspace endpoint.
* `backend/src/app/router.js` correctly mounts Lab workspace routes at `/api/v1/lab`.
* `backend/src/modules/lab-workspace/routes/lab-workspace.routes.js` exposes `/workbench`.
* `getLabWorkbench` returns a stable response shape compatible with `LabWorkbenchDto`:

  * `data.summary`
  * `data.worklist`
  * `data.pagination.total`
* Empty Lab data must return success with an empty worklist, not HTTP 500.
* Patient view and order view must both work:

  * `view=PATIENTS`
  * `view=ORDERS`
* The Lab controller must not fail when the first worklist item is missing, empty, or represents a patient group.
* Keep existing auth, role, permission, and active-module behavior. Do not loosen security.

Also inspect and fix any Lab frontend analyzer/runtime issue found in:

```txt
frontend/lib/features/lab/data/dtos/lab_dtos.dart
```

There is a suspicious duplicate mapping in `LabOrderItemDto.toEntity()` around `resultOptions`:

```dart
.map(LabResultOptionDto.new)
.map(LabResultOptionDto.new)
```

Verify this and fix it if it is invalid or contributing to Lab failures.

### B. Fix the Flutter localization resource-attribute error

The project has:

```yaml
required-resource-attributes: true
```

in:

```txt
frontend/l10n.yaml
```

Do not disable this setting.

Fix `frontend/lib/l10n/app_en.arb` so every user-facing resource key has a matching `@key` metadata object.

At minimum, the current archive shows these OPD keys without matching resource attributes:

```txt
opdSummaryAllPatientsLabel
opdSummaryAllOpdPatientsLabel
opdSummaryActiveOpdLabel
opdSummaryVitalsNeededLabel
opdSummaryDoctorNeededLabel
opdSummaryWithDoctorLabel
opdSummaryLabPendingLabel
opdSummaryImagingPendingLabel
opdSummaryPharmacyPendingLabel
opdSummaryDecisionNeededLabel
opdSummaryAdmissionPendingLabel
opdSummaryDischargedTodayLabel
opdStatusPaymentDueLabel
opdStatusVitalsNeededLabel
opdStatusDoctorNeededLabel
opdStatusWithDoctorLabel
opdStatusDoctorReviewLabel
opdStatusLabPendingLabel
opdStatusSamplePendingLabel
opdStatusInLabLabel
opdStatusResultsReadyLabel
opdStatusImagingPendingLabel
opdStatusReportPendingLabel
opdStatusReportReadyLabel
opdStatusLabAndImagingPendingLabel
opdStatusPharmacyPendingLabel
opdStatusDispensingLabel
opdStatusMedicinesDispensedLabel
opdStatusDecisionNeededLabel
opdStatusAdmissionPendingLabel
opdStatusAdmittedLabel
opdStatusDischargedLabel
opdNextCollectSampleLabel
opdNextProcessLabLabel
opdNextReviewResultsLabel
opdNextLabHandoffLabel
opdNextPerformImagingLabel
opdNextCompleteImagingReportLabel
opdNextReviewReportLabel
opdNextImagingHandoffLabel
opdNextDiagnosticsPendingLabel
opdNextDispenseMedicineLabel
opdNextPharmacyHandoffLabel
opdNextDispositionLabel
opdNextAdmissionHandoffLabel
```

Requirements:

* Add proper `@...` metadata descriptions for every missing key.
* Search the full ARB file programmatically or manually to ensure there are no other missing resource attributes.
* Run Flutter localization generation.
* Include generated localization Dart files only if they actually change.
* The frontend must no longer print the `Resource attribute ... was not found` error when started.

### C. Preserve existing architecture and style

Follow the current project patterns:

* Flutter + Riverpod frontend.
* Feature folders under `frontend/lib/features/<feature>`.
* DTO/repository/controller/page separation.
* Shared UI components such as `AppWorkspace`, `AppListTable`, `AsyncStateScaffold`, status badges, dialogs, and shared form controls.
* Backend Express module pattern:

  * routes
  * controllers
  * schemas
  * services
  * repositories
  * tests
* Existing response format using `sendSuccess`/error middleware.
* Existing backend aliases and naming style.
* Existing role/permission checks.

Do not introduce a new state-management approach, UI framework, API format, or folder structure.

## 5. Testing and verification

Run the relevant checks and fix all issues found:

### Frontend

From `frontend`:

```powershell
flutter gen-l10n
flutter analyze
flutter test
.\tool\run_web_5201.ps1
```

Verify manually:

* `/lab` opens without the generic connection problem when backend is running.
* Lab page refresh works.
* Lab page retry works only for real failures.
* Patients/orders view toggle does not crash.
* Empty Lab data shows the Lab empty state.
* Existing working modules still open.

### Backend

From `backend`:

```powershell
npm run lint
npm run test:backend
npm run i18n:check
```

Add or update focused tests where appropriate, especially for:

* Lab workspace workbench response.
* Empty Lab workbench response.
* Patient and order workbench views.
* Any fixed serializer/service edge case.
* Any endpoint/response mismatch discovered during reproduction.

## 6. Scope limits

Keep the change focused.

Do not:

* Rewrite the entire Lab module.
* Implement unrelated Lab workflow redesign items.
* Change unrelated modules just because they are nearby.
* Disable localization validation.
* Remove `required-resource-attributes: true`.
* Loosen auth, RBAC, ABAC, or active-module checks.
* Replace the Lab workspace with a placeholder.
* Modify generated/build/cache folders.
* Include `node_modules`, `.dart_tool`, `build`, screenshots, logs, or temporary files.

Modify only the files required to fix:

1. `/lab` load failure.
2. frontend localization resource-attribute error.
3. tests/lint issues directly caused by the fix.

## 7. Required final delivery format

Return a zipped archive containing only files and folders that were created or updated.

The zip root must use correct paths relative to the project root, for example:

```txt
frontend/lib/l10n/app_en.arb
frontend/lib/features/lab/data/dtos/lab_dtos.dart
backend/src/modules/lab-workspace/services/lab-workspace.service.js
```

Do not include unchanged files.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the zip that safely perform those operations.

PowerShell script requirements:

* Use correct relative paths from the project root.
* Use `Test-Path` before deletion/rename.
* Do not use broad destructive wildcards.
* Do not delete unrelated files.
* Do not require absolute machine-specific paths.
