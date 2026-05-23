Implementation Prompt: Fix Lab, Subscriptions, and Reports workspace load failures in HMS

You are working on the Hospital Management System codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Your task is to fix the workspace pages that currently fail to open:

* `http://127.0.0.1:5201/lab`
* `http://127.0.0.1:5201/subscriptions`
* `http://127.0.0.1:5201/reports`

Current observed behavior:

* `/lab` loads the HMS shell and highlights **Lab**, but the page body shows:

  * red warning icon
  * `Connection problem`
  * `Check your connection and try again.`
  * blue `Try again` button
* `/subscriptions` loads the HMS shell and highlights **Subscriptions**, but the page body shows:

  * red warning icon
  * `Not found`
  * `The item is not available.`
* `/reports` loads the HMS shell and highlights **Reports**, but the page body shows:

  * red warning icon
  * `Connection problem`
  * `Check your connection and try again.`
  * blue `Try again` button

The existing shell, header, sidebar, active menu state, route navigation, and authenticated layout already work. Do not rebuild them. Fix the underlying frontend/backend issues causing these pages to fail.

Relevant frontend areas to inspect and modify only if required:

* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/app/router/app_router.dart`
* `frontend/lib/app/router/app_route_icons.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/features/lab/**`
* `frontend/lib/features/subscriptions/**`
* `frontend/lib/features/reports/**`
* Shared workspace/error/loading/table/search components only if a real bug is found there.

Relevant backend areas to inspect and modify only if required:

* `backend/src/app/router.js`
* `backend/src/config/feature-flags.js`
* `backend/.env` and any env/example/dev config files used by the local workflow
* `backend/src/modules/lab-workspace/**`
* `backend/src/modules/reports-workspace/**`
* `backend/src/modules/subscriptions-workspace/**`
* Related backend modules used by these workspaces:

  * lab order/test/sample/result/QC modules
  * report definition/run/schedule/dashboard/audit modules
  * subscription plan/subscription/invoice/module/license modules

Relevant planner references:

* `app-planner/dev-plan/21-lab.md`
* `app-planner/dev-plan/33-subscriptions.md`
* `app-planner/dev-plan/35-reports-audit.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* Other planner files only if needed for workflow expectations.

Use `app-planner` as workflow guidance, but treat the current source code as authoritative where planner text is stale.

UI/UX requirements:

* Preserve the existing HMS layout:

  * top header with HOSSPI logo/title
  * online status badge
  * notification bell/avatar area
  * left sidebar with grouped menu sections
  * search menu field
  * existing selected menu styling
* `/lab` must open as the existing Lab workspace, not a blank page or placeholder.
* `/subscriptions` must open as the existing Subscriptions workspace, not a `Not found` page.
* `/reports` must open as the existing Reports and audit workspace, not a connection error page.
* Keep existing design patterns:

  * workspace titles
  * cards
  * tables
  * filters/search
  * refresh buttons
  * empty states
  * `AsyncStateScaffold` / existing failure-state patterns
* Error screens should appear only for real failures, not because of broken route/API/config integration.
* If there is no data, show the existing empty-state UI instead of a connection or not-found error.

Specific implementation requirements:

1. Reproduce and identify the failing requests from the frontend and backend logs.

   Verify these workspace API calls:

   * Lab:

     * `GET /api/v1/lab/workbench`
   * Subscriptions:

     * `GET /api/v1/subscriptions-workspace/workspace`
   * Reports:

     * `GET /api/v1/reports-workspace`

2. Fix `/lab`.

   Requirements:

   * Keep the route `AppRoutes.lab` mapped to `LabWorkspacePage`.
   * Keep the backend route mounted under `/api/v1/lab`.
   * Ensure `GET /api/v1/lab/workbench` returns HTTP 200 for authorized users.
   * Ensure the response shape matches the frontend DTO expectations:

     * `data.summary`
     * `data.worklist`
     * `data.pagination.total`
   * Both lab workbench views must keep working:

     * `PATIENTS`
     * `ORDERS`
   * Empty data must return a valid successful response with an empty worklist, not a server error.
   * Do not bypass lab permissions, tenant scoping, branch/facility scoping, or module checks.

3. Fix `/subscriptions`.

   Requirements:

   * Keep the route `AppRoutes.subscriptions` mapped to `SubscriptionsWorkspacePage`.
   * Keep the backend route mounted under `/api/v1/subscriptions-workspace`.
   * Fix the current `Not found` behavior.
   * Verify the feature flag/config path for `subscriptions_workspace_v1`.
   * The archive currently contains a local env value where `FEATURE_SUBSCRIPTIONS_WORKSPACE_V1` is disabled. Verify whether this is the root cause.
   * Make the development/local configuration consistent with the visible Subscriptions menu and route so that authorized users can open `/subscriptions`.
   * Do not remove or bypass:

     * route guards
     * `PERMISSIONS.SUBSCRIPTIONS_READ`
     * tenant checks
     * authorization middleware
   * Ensure `GET /api/v1/subscriptions-workspace/workspace` returns HTTP 200 with the response shape expected by the frontend DTO.

4. Fix `/reports`.

   Requirements:

   * Keep the route `AppRoutes.reports` mapped to `ReportsWorkspacePage`.
   * Keep the backend route mounted under `/api/v1/reports-workspace`.
   * Ensure `GET /api/v1/reports-workspace` returns HTTP 200 for authorized users.
   * Verify and fix backend summary/query failures.
   * Specifically inspect `backend/src/modules/reports-workspace/repositories/reports-workspace.repository.js`.
   * Check whether summary queries apply `facility_id` or `branch_id` filters to Prisma models that do not have those fields, especially `dashboard_widget`.
   * Do not pass unsupported filters to Prisma queries.
   * Preserve tenant scoping and access control.
   * Ensure the response shape matches `ReportsWorkspaceOverviewDto`.

5. Preserve architecture and style.

   * Follow existing frontend architecture:

     * feature folders
     * domain/data/presentation separation
     * repositories
     * DTOs
     * controllers
     * existing shared UI components
   * Follow existing backend architecture:

     * routes
     * controllers
     * services
     * repositories
     * schemas
     * serializers/helpers
   * Keep existing naming conventions and code style.
   * Do not replace real workspace pages with static mock screens.
   * Do not create fake frontend-only fixes that hide backend errors.
   * Do not introduce unrelated UI redesigns.
   * Do not loosen security, permissions, tenant isolation, branch/facility scoping, or module access controls.

6. Scope limits.

   * Modify only files required to fix the three failing pages.
   * Do not rewrite unrelated modules.
   * Do not refactor large areas unless required by the bug.
   * Do not change unrelated routes, permissions, menus, seeds, or UI components.
   * Do not include generated folders or dependency folders in the final archive.

7. Testing and verification.

   Backend:

   * Run backend linting.
   * Run relevant backend tests.
   * Add focused tests if needed for:

     * `GET /api/v1/lab/workbench`
     * `GET /api/v1/subscriptions-workspace/workspace`
     * `GET /api/v1/reports-workspace`
   * Run OpenAPI validation if any API contract/schema changes are made.
   * Verify the endpoints return HTTP 200 for an authorized demo/development user.

   Frontend:

   * Run Flutter analysis.
   * Run relevant Flutter tests.
   * Verify the app runs on web using the existing local workflow, including `frontend/tool/run_web_5201.ps1` if applicable.

   Manual browser verification:

   * `/clinical` still opens correctly.
   * `/lab` opens without the centered `Connection problem` error.
   * `/subscriptions` opens without the centered `Not found` error.
   * `/reports` opens without the centered `Connection problem` error.
   * Refresh/Try-again behavior still works for real failures.
   * Browser console has no relevant runtime errors.
   * Network tab shows no 404/500 for the workspace load requests.
   * Empty datasets render valid empty states.

8. Lint and quality requirements.

   * Clear all linter issues introduced by your changes.
   * Keep formatting consistent with the existing project.
   * Do not leave debug logs, temporary code, commented-out code, or unused imports.
   * Do not include build artifacts, caches, screenshots, logs, `node_modules`, `.dart_tool`, or generated temporary files.

Final delivery requirements:

* Return one zipped archive.
* The zip must contain only files and folders that were created or updated.
* Every changed file must be placed under its correct relative project path, for example:

  * `backend/src/...`
  * `frontend/lib/...`
  * `app-planner/...`
* If any file or folder must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those operations.
* Delete/rename scripts must:

  * use correct relative paths
  * check that the target exists before modifying it
  * avoid deleting unrelated files
* Do not include unchanged files in the returned archive.
