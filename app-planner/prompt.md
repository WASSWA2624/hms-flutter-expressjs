## Implementation Prompt: Deep Review and Fix HMS Workspace Loading Failures

You are working on the Hospital Management System codebase. The archive contains these main folders:

* `app-planner`
* `backend`
* `frontend`

Your task is to deeply inspect the existing backend and frontend implementation, identify the blockers causing selected HMS screens/dialogs to fail, and implement focused fixes so the UI opens reliably without breaking.

Do not rewrite the application. Preserve the current architecture, folder structure, naming conventions, coding style, state-management patterns, API patterns, and UI component system.

---

## 1. Problem to Solve

Several HMS workspaces currently open correctly, but some screens or detail dialogs fail with generic connection errors.

Confirmed behavior from the raw task:

### Working or mostly working areas

These areas currently open and must not regress:

* Dashboard
* Patients list
* Patient detail dialog
* OPD workspace, although OPD flows are currently empty
* Emergency workspace
* Emergency detail dialog
* IPD workspace
* Rooms and beds workspace
* ICU workspace, currently empty
* Nursing workspace
* Discharge workspace
* Discharge detail dialog
* Physiology workspace, currently empty
* Theater workspace, currently empty
* Radiology workspace
* Radiology flow dialog
* Pharmacy workspace, currently empty
* Billing workspace, currently empty
* Claims workspace, currently empty
* Operations workspace
* Operation/request detail dialog
* Housekeeping workspace
* Housekeeping detail dialog
* Biomedical workspace
* Equipment detail dialog
* Mortuary workspace
* Mortuary case dialogs
* HR workspace
* Staff detail dialog
* Communications workspace
* Alerts integration workspace
* Gateway dialog
* Reports/Audit workspace, currently with no reports
* Settings workspace
* Setup workspace

### Broken or priority areas

Fix these issues:

1. **Clinical workspace**

   * The Clinical page opens.
   * The clinical worklist is visible.
   * Clicking a clinical patient fails with the message:

     * “Connection problem”
     * “Check your connection and try again”
   * The clinical patient/encounter dialog does not open.

2. **Lab workspace**

   * The Lab page opens into a full-page error state:

     * “Connection problem”
     * “Check your connection and try again”
   * A “Try again” button is shown.
   * Clicking “Try again” does not recover or visibly retry.

3. **Subscriptions workspace**

   * The Subscriptions page opens into a full-page error state:

     * “Connection problem”
     * “Check your connection and try again”
   * A “Try again” button is shown.
   * Clicking “Try again” does not recover or visibly retry.

4. **Mortuary case dialog**

   * Mortuary opens and case dialogs open.
   * Some actions inside the case dialog are unavailable.
   * Review this and determine whether the disabled/unavailable actions are intentional business-rule behavior or caused by missing frontend/backend wiring. Fix only if it is a defect supported by the codebase.

---

## 2. Project Areas to Inspect

Use the existing project as the source of truth.

### Frontend

Inspect these frontend areas first:

* `frontend/lib/app/router/app_router.dart`
* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/core/network/network_failure_mapper.dart`
* `frontend/lib/core/errors/app_failure.dart`
* `frontend/lib/shared/components/app_state_view.dart`
* `frontend/lib/shared/components/`
* `frontend/lib/l10n/app_en.arb`

Inspect the affected feature folders:

* `frontend/lib/features/clinical/`
* `frontend/lib/features/lab/`
* `frontend/lib/features/subscriptions/`
* `frontend/lib/features/mortuary/`

Important frontend files to review include:

* `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart`

* `frontend/lib/features/clinical/domain/entities/clinical_entities.dart`

* `frontend/lib/features/clinical/domain/repositories/clinical_repository.dart`

* `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`

* `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`

* `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`

* `frontend/lib/features/lab/data/dtos/lab_dtos.dart`

* `frontend/lib/features/lab/domain/entities/lab_entities.dart`

* `frontend/lib/features/lab/domain/repositories/lab_repository.dart`

* `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`

* `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`

* `frontend/lib/features/subscriptions/data/repositories/subscriptions_repository_impl.dart`

* `frontend/lib/features/subscriptions/data/dtos/subscription_dtos.dart`

* `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`

* `frontend/lib/features/subscriptions/domain/repositories/subscriptions_repository.dart`

* `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`

* `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`

### Backend

Inspect the backend root router and affected modules:

* `backend/src/app/router.js`

Clinical-related backend modules:

* `backend/src/modules/encounter/`
* `backend/src/modules/clinical-note/`
* `backend/src/modules/diagnosis/`
* `backend/src/modules/procedure/`
* `backend/src/modules/care-plan/`
* `backend/src/modules/lab-order/`
* `backend/src/modules/radiology-order/`
* `backend/src/modules/pharmacy-order/`
* `backend/src/modules/referral/`
* `backend/src/modules/follow-up/`
* `backend/src/modules/admission/`

Lab-related backend modules:

* `backend/src/modules/lab-workspace/`
* `backend/src/modules/lab-order/`
* `backend/src/modules/lab-order-item/`
* `backend/src/modules/lab-sample/`
* `backend/src/modules/lab-result/`
* `backend/src/modules/lab-test/`
* `backend/src/modules/lab-panel/`
* `backend/src/modules/lab-qc-log/`

Subscriptions-related backend modules:

* `backend/src/modules/subscriptions-workspace/`
* `backend/src/modules/subscription-plan/`
* `backend/src/modules/subscription/`
* `backend/src/modules/subscription-invoice/`
* `backend/src/modules/module/`
* `backend/src/modules/module-subscription/`
* `backend/src/modules/license/`
* `backend/src/lib/subscriptions/`

Also inspect:

* `backend/prisma/schema.prisma`
* backend validation schemas
* backend serializers
* backend authorization/feature-flag handling where relevant
* backend response format helpers

### App Planner

Use these documents as reference only. Do not edit them unless directly required:

* `app-planner/app-write-up.md`
* `app-planner/dev-plan/04-api-data.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/14-clinical.md`
* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/33-subscriptions.md`
* `app-planner/dev-plan/37-quality-release.md`
* `frontend/app-planner/app-rules/architecture.md`
* `frontend/app-planner/app-rules/network_api.md`
* `frontend/app-planner/app-rules/state_management.md`
* `frontend/app-planner/app-rules/error_handling.md`
* `frontend/app-planner/app-rules/reusable_components.md`
* `frontend/app-planner/app-rules/pagination_data_tables.md`
* `frontend/app-planner/app-rules/testing.md`
* `backend/app-planner/app-rules/project-structure.md`
* `backend/app-planner/app-rules/api.md`
* `backend/app-planner/app-rules/response-format.md`
* `backend/app-planner/app-rules/auth-security.md`
* `backend/app-planner/app-rules/validation.md`
* `backend/app-planner/app-rules/testing.md`
* `backend/app-planner/app-rules/coding-standards.md`

---

## 3. Implementation Requirements

### A. Clinical patient detail failure

Investigate the full request flow when a clinical worklist patient is clicked.

The frontend currently loads the clinical encounter bundle by calling related resources such as:

* encounters
* clinical notes
* diagnoses
* procedures
* care plans
* lab orders
* radiology orders
* pharmacy orders
* referrals
* follow-ups
* admissions

Verify that:

* the frontend query parameters match backend schemas
* backend routes accept the query parameters being sent
* `encounter_id`, pagination, sorting, and filtering names are consistent
* frontend DTO parsing matches backend response shape
* backend serializers return the fields expected by the frontend
* backend authorization/tenant/module middleware is not incorrectly blocking the request
* missing optional records return empty lists instead of server errors
* failed optional sections do not unnecessarily block the entire clinical dialog unless the current architecture requires all sections to load successfully

Implement the root-cause fix so clicking a clinical worklist patient opens the patient/encounter dialog reliably.

The dialog must preserve the existing clinical UI style and must show clear empty states for sections with no records.

### B. Lab workspace full-page connection error

Investigate why the Lab workspace fails on initial load.

The frontend Lab workspace calls the Lab backend workbench flow, including:

* `/api/v1/lab/workbench`
* lab order workflow/detail endpoints
* lab tests
* lab panels
* lab QC logs where applicable

Verify that:

* `frontend/lib/core/network/api_endpoints.dart` maps Lab resources correctly
* `LabRepositoryImpl` calls the correct backend endpoints
* backend route `/api/v1/lab/workbench` is registered correctly
* lab workbench query validation accepts frontend query parameters
* Prisma query fields and relation filters are valid for the configured database provider
* backend serializers produce the response shape expected by `LabWorkbenchDto`
* empty lab data returns a valid empty workspace state, not a server error
* backend errors are not being incorrectly mapped to a generic connection problem
* frontend retry actually reissues the failed request

Fix both the backend/frontend root cause and the retry behavior.

The Lab screen must load with either real data or a proper empty state. It must not show a full-page connection error for valid empty data.

### C. Subscriptions workspace full-page connection error

Investigate why the Subscriptions workspace fails on initial load.

The frontend currently targets the subscriptions workspace and related resources, including:

* subscriptions workspace
* subscription plans
* subscriptions
* subscription invoices
* modules
* module subscriptions
* licenses

Verify that:

* the frontend endpoint construction matches the backend route registration
* `/api/v1/subscriptions-workspace/workspace` is the intended route
* the backend route is enabled and reachable
* feature flag `subscriptions_workspace_v1` is configured correctly or handled gracefully
* permission checks return clear authorization/feature-disabled states instead of generic connection errors
* query validation matches frontend parameters
* Prisma filters/search are compatible with the configured database provider
* backend serializers return the response shape expected by the frontend DTOs
* empty subscriptions data returns a normal empty workspace
* frontend retry actually reissues the failed request and updates state

Fix the root cause.

The Subscriptions screen must load with real data or a proper empty state. If the feature is disabled or the user lacks permission, show a clear existing-style access/disabled state instead of a misleading connection problem.

### D. Retry behavior

Review the retry behavior used by `AsyncStateScaffold`, Lab, and Subscriptions controllers.

Fix retry behavior so that when initial loading fails:

* pressing “Try again” triggers a fresh request
* the UI visibly enters a loading or refreshing state
* success replaces the error state
* failure updates with the latest failure
* retry does not silently no-op when there is no current successful state

Preserve the existing Riverpod/state-management architecture.

Do not replace the shared state system with a new pattern.

### E. Error handling

Improve only where necessary.

Ensure that:

* backend validation errors map to validation/user-facing errors
* backend authorization errors map to access-denied states
* backend feature-disabled/not-found cases are not shown as generic connection failures
* true network/server failures can still show the existing connection problem message
* existing localization patterns are preserved
* new user-facing strings are added to localization files instead of being hard-coded

Do not create noisy debug UI.

### F. Mortuary actions

Review the disabled/unavailable actions in the Mortuary case dialog.

Determine from backend state/status rules and frontend action conditions whether the unavailable actions are intentional.

Only change Mortuary behavior if the codebase clearly shows a defect, such as:

* frontend action wired to a missing or wrong endpoint
* backend action route exists but frontend does not call it
* action state condition is wrong
* permissions are checked incorrectly
* backend response shape prevents the action from appearing

Do not force-enable actions that are intentionally disabled by case status, role, permission, or business rules.

---

## 4. UI/UX Requirements

No issue screenshots were present in the archive. Use the raw task description and the existing UI patterns as the source of truth.

Preserve the existing HMS visual design:

* workspace layout
* cards/panels
* tables
* dialogs
* action panels
* empty states
* loading states
* failure states
* typography
* spacing
* colors
* icons
* localization approach

Specific UX requirements:

1. Lab must open as a normal workspace.

   * If there are no lab orders, show the existing-style empty state.
   * Do not show a connection error for empty data.
   * “Try again” must work when a real failure occurs.

2. Subscriptions must open as a normal workspace.

   * If there are no subscriptions, plans, invoices, modules, or licenses, show existing-style empty states.
   * Do not show a connection error for empty data.
   * If disabled by feature flag or blocked by permissions, show a clear existing-style message.
   * “Try again” must work when a real failure occurs.

3. Clinical patient selection must open the patient/encounter dialog.

   * Related clinical sections should show data where available.
   * Sections with no records should show empty states.
   * The user should not see a generic connection error when the selected encounter exists and the backend is reachable.

4. Existing working screens must continue to open and behave as before.

---

## 5. Scope Limits

Stay tightly focused on the requested stability fixes.

Do not:

* rewrite the app architecture
* replace Riverpod, GoRouter, Dio, Prisma, or Express patterns
* redesign the UI
* rename folders unnecessarily
* move modules unnecessarily
* introduce unrelated features
* refactor unrelated screens
* change working workflows unless required by the fix
* hard-code fake successful responses
* hide real backend errors by swallowing them silently
* modify planner documents unless directly required

Modify only the files required for the requested change.

---

## 6. Testing and Verification

Run and satisfy all relevant checks.

### Frontend

Run:

```bash
cd frontend
flutter analyze
```

Also run relevant frontend tests if present, or add focused tests where useful for changed controller/repository behavior.

Verify manually:

* Clinical page opens.
* Clicking a clinical worklist patient opens the clinical patient/encounter dialog.
* Lab page opens without full-page connection error.
* Lab retry button performs a real retry after a failure.
* Subscriptions page opens without full-page connection error when valid.
* Subscriptions retry button performs a real retry after a failure.
* Existing working screens listed above still open.

### Backend

Run the project’s available backend lint/test commands, including the relevant one or ones from `backend/package.json`.

At minimum, run the backend linter if available:

```bash
cd backend
npm run lint
```

Run relevant backend tests for:

* lab workspace
* subscriptions workspace
* clinical related-resource list endpoints
* authorization/feature-disabled behavior where changed

If no tests exist for a changed behavior, add focused tests only where practical and consistent with the existing test style.

### Required verification points

Confirm that:

* no frontend analyzer issues remain
* no backend linter issues remain
* fixed endpoints return valid response envelopes
* empty datasets return successful empty states
* retry buttons are functional
* no unrelated screens regress
* no unrelated files were modified

---

## 7. Delivery Requirements

Return a zipped archive containing only the files and folders that were created or updated.

All files must be placed in their correct relative project directories, for example:

* `frontend/lib/...`
* `backend/src/...`
* `backend/prisma/...`

Do not include the full project unless every included file was actually changed.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those operations.

The scripts must:

* use correct relative paths
* check that the target exists before deleting or renaming
* avoid deleting unrelated files
* avoid broad wildcards
* be safe to run from the project root

Do not delete or rename anything unless it is truly required.

---

## 8. Missing or Unclear Details to Verify from the Codebase

The raw task does not include backend logs, browser console output, API response bodies, or screenshots showing the failing states.

Verify these details directly from the codebase and runtime behavior:

* exact failing API request for Clinical patient click
* exact failing API request for Lab initial load
* exact failing API request for Subscriptions initial load
* exact backend status code and response body for each failure
* whether Subscriptions is blocked by feature flag, permission, route mismatch, validation, Prisma query failure, serializer mismatch, or frontend DTO parsing
* whether Lab fails because of backend route/service/query/serializer issues or frontend DTO/retry issues
* whether Mortuary unavailable actions are intentional or defective

Implement the smallest correct fix after confirming the actual root cause.
