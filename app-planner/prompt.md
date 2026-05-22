You are working in the HMS codebase from `hms.zip`. The archive contains:

* `app-planner`
* `backend`
* `frontend`

No task-specific screenshots were found in the archive beyond normal app/logo assets, so use the raw task, the actual codebase, and the existing UI patterns as the source of truth.

## Goal

Perform a focused UI/UX consistency refactor across the HMS workspace screens. The app already looks close to complete, so do not redesign it from scratch. Improve layout consistency, table/search/filter behavior, detail display behavior, icon consistency, displayed ID handling, and the subscription workspace flow while preserving the existing architecture.

The implementation must follow the existing Flutter frontend architecture, Node/Express/Prisma backend architecture, naming conventions, folder structure, shared UI components, Riverpod state patterns, localization patterns, and planner rules already present in the project.

## Source-of-truth files to inspect first

Inspect these planner/rule files before changing code:

* `app-planner/dev-plan/01-policy.md`
* `app-planner/dev-plan/10-workspace-ui.md`
* `app-planner/dev-plan/24-billing.md`
* `app-planner/dev-plan/26-physiotherapy.md`
* `app-planner/dev-plan/27-mortuary.md`
* `app-planner/dev-plan/28-hr.md`
* `app-planner/dev-plan/29-rooms-beds.md`
* `app-planner/dev-plan/30-biomedical.md`
* `app-planner/dev-plan/31-operations.md`
* `app-planner/dev-plan/32-housekeeping.md`
* `app-planner/dev-plan/33-subscriptions.md`
* `app-planner/dev-plan/36-integrations.md`
* `frontend/app-planner/app-rules/architecture.md`
* `frontend/app-planner/app-rules/project_structure.md`
* `frontend/app-planner/app-rules/navigation.md`
* `frontend/app-planner/app-rules/reusable_components.md`
* `frontend/app-planner/app-rules/responsive_adaptive_design.md`
* `frontend/app-planner/app-rules/state_management.md`
* `frontend/app-planner/app-rules/network_api.md`
* `frontend/app-planner/app-rules/permissions.md`
* `frontend/app-planner/app-rules/forms.md`
* `frontend/app-planner/app-rules/search_filtering.md`
* `frontend/app-planner/app-rules/pagination_data_tables.md`
* `frontend/app-planner/app-rules/localization_i18n.md`
* `frontend/app-planner/app-rules/performance.md`
* `frontend/app-planner/app-rules/accessibility.md`

If backend changes are required, also inspect:

* `backend/app-planner/app-rules/api.md`
* `backend/app-planner/app-rules/api-versioning.md`
* `backend/app-planner/app-rules/response-format.md`
* `backend/app-planner/app-rules/auth-security.md`
* `backend/app-planner/app-rules/validation.md`
* `backend/app-planner/app-rules/module-creation.md`

## Existing shared frontend components to reuse

Use the existing shared components instead of creating duplicate screen-specific versions:

* `frontend/lib/shared/layout/app_workspace.dart`
* `frontend/lib/shared/layout/responsive_page.dart`
* `frontend/lib/shared/components/app_list_table.dart`
* `frontend/lib/shared/components/app_search_bar.dart`
* `frontend/lib/shared/components/app_dialog.dart`
* `frontend/lib/shared/components/app_copyable_identifier.dart`
* `frontend/lib/shared/components/app_info_tile.dart`
* `frontend/lib/shared/components/components.dart`
* `frontend/lib/shared/forms/forms.dart`
* `frontend/lib/shared/actions/actions.dart`

Do not create another app-wide table, search bar, filter control, dialog shell, workspace shell, permission wrapper, or form field family.

## Global implementation requirements

1. Preserve the existing feature-first structure:

   * `frontend/lib/features/<feature>/data`
   * `frontend/lib/features/<feature>/domain`
   * `frontend/lib/features/<feature>/presentation`
   * backend modules under `backend/src/modules/<module>`

2. Preserve existing Riverpod controller/repository boundaries. UI must not call HTTP directly.

3. Preserve existing localization patterns. Do not hard-code user-facing strings where localization is already used.

4. Modify only files required for this task.

5. Avoid unrelated refactors, broad rewrites, or changes to modules explicitly marked as “leave for now.”

6. Keep all layouts responsive for mobile, tablet, desktop, and large desktop.

7. Clear all linter/analyzer issues introduced or exposed by these changes.

8. If any backend contract is missing or wrong, implement the smallest backend change required using the existing Express controller/service/repository/schema/router pattern.

9. Use targeted refresh after actions. Do not reload entire workspaces unnecessarily after modal actions.

10. Use human-readable/public identifiers wherever available instead of raw UUID/database IDs.

11. Every displayed ID must use `AppCopyableIdentifier` directly, or a shared component that enables copy support such as `AppInfoTileData(copyable: true)` or `AppWorkspacePatientContextField(copyable: true)`.

Examples of IDs that must be copyable when displayed:

* patient number / MRN
* patient public ID
* encounter ID
* admission ID
* invoice/payment/billing IDs
* subscription IDs
* equipment/asset IDs
* mortuary case IDs
* staff IDs
* room/bed IDs
* integration/API key/webhook IDs
* source/reference IDs

## Dashboard rename

Current code still uses Home terminology in places such as:

* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/app/router/app_router.dart`
* `frontend/lib/app/router/app_route_icons.dart`
* `frontend/lib/features/home/...`
* `frontend/lib/l10n/app_en.arb`
* generated localization files under `frontend/lib/l10n/`

Rename the user-facing Home screen to Dashboard.

Requirements:

1. Navigation label must show `Dashboard`, not `Home`.

2. Loading/error/user-facing text should say dashboard where appropriate, for example “Preparing dashboard” instead of “Preparing home.”

3. Use dashboard terminology in route/component names where it is safe and consistent.

4. Keep `/` as the main landing path unless the codebase already supports a safer dashboard path. If adding `/dashboard`, preserve `/` as an alias or redirect so existing links still work.

5. If renaming files/folders/classes such as `features/home` to `features/dashboard`, do it consistently across imports, providers, route declarations, generated localization references, and tests.

6. If any file/folder is renamed or deleted, include a PowerShell `.ps1` script that safely performs the rename/delete using correct relative paths.

7. If a full internal rename is too risky, at minimum complete the user-facing rename and clearly keep internal compatibility without broken imports or routes.

## Standard list/search/filter/table pattern

Standardize all relevant workspaces to this pattern:

1. Use `AppWorkspace` or the existing responsive workspace shell.

2. Use `AppListTable` for worklists/tables.

3. Use `AppListTableSearch` / `AppSearchBar` for search.

4. The search field should use the built-in clear `X` only when text exists.

5. Use one advanced filters button.

6. Use one table settings button when column visibility is available.

7. Do not show duplicate filter, advanced filter, clear filter, or settings buttons.

8. Do not manually add `columnVisibilityController.settingsAction(...)` if `AppListTable` already adds the settings action.

9. Standardize the advanced filter icon to the same funnel/filter icon across the app. Update the shared search/filter component so screens such as Theater, Mortuary, Biomedical, Subscriptions, and other advanced-filter workspaces use the same funnel/filter icon. Prefer `Icons.filter_alt_outlined` for inactive and `Icons.filter_alt` for active.

10. Keep patient screen behavior as the visual reference for search + advanced filters.

Relevant files include:

* `frontend/lib/shared/components/app_search_bar.dart`
* `frontend/lib/shared/components/app_list_table.dart`
* all affected workspace pages listed below

## Detail display pattern

For these workspaces, the main worklist/table must span the full available width. Details must open in a dialog instead of occupying a persistent side/detail panel:

* Physiotherapy
* Operations
* Housekeeping
* Biomedical
* Mortuary
* HR
* Integrations

Use existing `AppDialog`, `showAppDialog`, or `showAppWorkspaceActionDialog` patterns. Reuse existing detail body widgets where possible instead of rewriting detail content.

Dialog requirements:

1. Row click opens a focused detail dialog.

2. Dialog must include relevant action buttons that previously lived in the side/detail panel.

3. Dialog content must scroll on smaller screens.

4. Main table remains full width.

5. Preserve selected-row/action behavior where required by controllers, but do not force a persistent detail column in the layout.

6. After a dialog action succeeds, refresh only the affected row/list/detail state.

## Screen-specific requirements

### Patients

Leave the patient screen layout as-is, except for global shared improvements such as the standardized advanced filter icon and copyable ID consistency.

Reference file:

* `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

### OPD, Emergency, IPD, ICU, Nursing, Discharge, Clinical, Lab, Radiology, Pharmacy, Claims

Leave these screens as-is except for global shared changes that automatically apply through shared components, such as advanced filter icon consistency and copyable ID consistency.

### Rooms and Beds

Relevant files:

* `frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart`
* `frontend/lib/features/rooms_beds/presentation/controllers/rooms_beds_workspace_controller.dart`
* `frontend/lib/features/rooms_beds/domain/entities/rooms_beds_entities.dart`

Requirements:

1. The screen layout is mostly acceptable.

2. Make the clickable information/summary cards more compact.

3. On desktop/large desktop, the primary clickable summary cards should fit on one row when space permits.

4. Do not make cards too wide for short content.

5. Preserve mobile responsiveness.

6. Use existing `AppWorkspaceSummaryCard` / `AppWorkspaceSummaryGrid` behavior. Extend shared sizing only if necessary and without breaking other screens.

### Physiotherapy

Relevant files:

* `frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart`
* `frontend/lib/features/physiotherapy/presentation/controllers/physiotherapy_workspace_controller.dart`
* `frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart`
* `frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart`

Requirements:

1. Make the physiotherapy shortcut/summary cards smaller and less space-consuming.

2. Remove the duplicated “Therapy worklist” visual section/heading.

3. The therapy worklist must use the shared `AppListTable` with built-in search, advanced filter, and settings behavior.

4. The therapy worklist table must span the full available width.

5. Remove the persistent selected therapy item/detail section from the main layout.

6. Clicking a therapy worklist row should open the selected therapy item in an `AppDialog`.

7. Move therapy item actions into that dialog.

8. Ensure patient/encounter/source IDs shown in the table or dialog are copyable.

### Theater

Relevant files:

* `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
* `frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart`

Requirements:

1. Keep the existing layout.

2. Ensure the advanced filter button uses the standardized funnel/filter icon.

3. Do not otherwise refactor Theater unless required by shared component changes or linter fixes.

### Billing

The raw task refers to “Beading”; verify from the codebase context that this means the Billing workspace.

Relevant files:

* `frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart`
* `frontend/lib/features/billing/presentation/controllers/billing_workspace_controller.dart`
* `frontend/lib/features/billing/domain/entities/billing_entities.dart`
* `frontend/lib/app/router/app_route_icons.dart`

Requirements:

1. Billing must use a consistent billing/point-of-sale/receipt style icon, not a sun/light icon.

2. Confirm the Billing worklist uses the shared `AppListTable` and `AppListTableSearch`. If any billing list still uses a custom table/list where the shared table is appropriate, convert it to the shared table pattern.

3. Remove any duplicate filter/search/settings controls if present.

4. Ensure billing IDs, invoice IDs, patient numbers, payment IDs, and related identifiers are copyable wherever displayed.

### Subscriptions

Relevant frontend files:

* `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
* `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`
* `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`
* `frontend/lib/features/subscriptions/domain/repositories/subscriptions_repository.dart`
* `frontend/lib/features/subscriptions/data/repositories/subscriptions_repository_impl.dart`
* `frontend/lib/features/subscriptions/data/dtos/subscription_dtos.dart`
* `frontend/lib/core/network/api_endpoints.dart`
* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/app/router/app_router.dart`

Relevant backend files if API changes are required:

* `backend/src/modules/subscriptions-workspace/...`
* `backend/src/modules/subscription/...`
* `backend/src/modules/subscription-plan/...`
* `backend/src/modules/subscription-invoice/...`
* `backend/src/modules/module-subscription/...`
* `backend/src/lib/subscriptions/...`
* `backend/prisma/schema.prisma`

Requirements:

1. The Subscriptions route must not show a generic “not found” state for valid users who have access.

2. The screen should show subscription information based on the logged-in user/session/tenant context.

3. Show the current subscription where available.

4. Show available subscription plans/options where available.

5. Provide a simple, standardized upgrade/change-plan flow.

6. Provide a simple payment/collection flow using the existing supported backend fields. The raw task mentions selecting amount and payment method. Verify whether the backend supports amount entry for subscription invoice collection. If it does, include amount. If it does not, use the existing invoice amount and payment method, and mark the missing amount support as a backend contract gap only if implementation requires it.

7. Use shared forms such as `AppCurrencyAmountField`, `AppSelectField`, `AppTextField`, and shared dialogs.

8. Use shared table/search/filter/settings behavior for subscription lists.

9. Remove duplicate clear-filter actions from the toolbar. Keep reset inside the advanced filter dialog or follow the shared table pattern.

10. If details remain in the Subscriptions screen, ensure they do not create a cluttered or confusing layout. Prefer dialog-based detail/action flows where it improves consistency.

11. Use human-readable subscription, plan, invoice, license, and module identifiers where available, and make displayed IDs copyable.

12. Do not fake subscription data on the frontend. If data is missing, fix the minimal backend/frontend contract needed or show a clear empty state.

### Operations

Relevant files:

* `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`
* `frontend/lib/features/operations/presentation/controllers/operations_workspace_controller.dart`
* `frontend/lib/features/operations/domain/entities/operations_entities.dart`
* `frontend/lib/features/operations/data/repositories/operations_repository_impl.dart`

Requirements:

1. The maintenance requests table must span the full available width.

2. Remove the persistent request details section from the main screen.

3. Clicking a maintenance request row should open request details in an `AppDialog`.

4. Put request action buttons in the dialog.

5. Fix the unstable/self-refreshing behavior. Inspect the periodic sync/realtime refresh behavior in the controller and prevent unnecessary visible reloads, repeated detail reloads, or workspace refresh loops.

6. Preserve useful realtime/periodic updates, but they must not constantly disrupt the user, reset scroll, reset selected context, or cause visible flicker.

7. Ensure operation request IDs, asset IDs, service log IDs, and related identifiers are copyable.

### Housekeeping

Relevant files:

* `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart`
* `frontend/lib/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart`
* `frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart`

Requirements:

1. The task table must span the full available width.

2. Remove the persistent housekeeping details section from the main screen.

3. Clicking a task row should open a dialog containing task details and action buttons.

4. Remove the section that shows unavailable workflows from the housekeeping screen.

5. Ensure task IDs, room/bed IDs, maintenance request IDs, and related identifiers are copyable.

### Biomedical

Relevant files:

* `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart`
* `frontend/lib/features/biomedical/presentation/controllers/biomedical_workspace_controller.dart`
* `frontend/lib/features/biomedical/domain/entities/biomedical_entities.dart`

Requirements:

1. The equipment/worklist table must span the full available width.

2. Move equipment details into an `AppDialog`.

3. Clicking a biomedical asset/equipment row should open the equipment detail dialog.

4. Remove duplicate search toolbar controls. There must not be separate duplicate filter, advanced filter, and clear filter controls.

5. Follow the shared pattern: search field with built-in clear `X`, one advanced filters button, and one settings button.

6. Ensure equipment IDs, asset tags, facility/location identifiers, and related IDs are copyable.

### Mortuary

Relevant files:

* `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart`
* `frontend/lib/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart`
* `frontend/lib/features/mortuary/domain/entities/mortuary_entities.dart`

Requirements:

1. The mortuary table must span the full available width.

2. Move case details into an `AppDialog`.

3. Clicking a case row should open case details in the dialog.

4. Remove duplicate table settings controls.

5. Ensure the filters button uses the standardized funnel/filter icon.

6. In the source column and source/reference detail fields, display the human-readable/source reference ID where available, not an internal UUID.

7. Case IDs, patient IDs, source IDs, storage IDs, release IDs, billing IDs, and related identifiers must be copyable.

### HR

Relevant files:

* `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
* `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`
* `frontend/lib/features/hr/domain/entities/hr_entities.dart`

Requirements:

1. The staff table/directory must span the full available width.

2. Move staff details into an `AppDialog`.

3. Clicking a staff row should open staff details in the dialog.

4. Remove the persistent work queue panel from the main layout.

5. Remove the persistent HR activities section from the main layout.

6. If work queue or activity actions are still needed, expose them as compact action buttons in the screen header near refresh/add actions, permission-gated where appropriate.

7. Ensure staff IDs/staff numbers and related HR identifiers are copyable.

### Communications

Leave Communications unchanged for now except for global shared component changes that apply automatically.

### Integrations

Relevant files:

* `frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart`
* `frontend/lib/features/integrations/presentation/controllers/integrations_workspace_controller.dart`
* `frontend/lib/features/integrations/domain/entities/integration_entities.dart`
* `frontend/lib/features/integrations/data/repositories/integrations_repository_impl.dart`

Requirements:

1. The integration worklist table must span the full available width.

2. Remove the persistent selected integration detail panel from the main screen.

3. Clicking an integration/API key/webhook row should open selected item details in an `AppDialog`.

4. Move configure/test/sync/enable/disable/revoke/replay actions into the dialog where applicable.

5. Remove any fixed table height that prevents the table from naturally using available width/space unless required for responsiveness.

6. Ensure integration IDs, API key IDs, webhook IDs, external reference IDs, and related identifiers are copyable.

### Reports and Audits, Settings, Setup

Leave these screens unchanged for now except for global shared component changes that apply automatically.

## Icon and color consistency

1. Standardize module icons through `frontend/lib/app/router/app_route_icons.dart`.

2. Billing must use a billing/point-of-sale/receipt icon, not a sun/light icon.

3. Advanced filters must use a consistent funnel/filter icon app-wide.

4. Add color to icons and labels where the current UI looks too plain, especially in light theme.

5. Use existing theme tokens and color scheme only:

   * `Theme.of(context).colorScheme`
   * `AppWorkspaceStatusTone`
   * existing shared component tone/color behavior

6. Do not hard-code random colors.

7. Keep normal icons around the existing shared sizes unless a component already defines otherwise.

## Backend requirements

Only change backend files if the frontend cannot correctly implement the requested behavior with existing APIs.

Backend changes may be needed for:

* subscription workspace current/available subscription data
* subscription upgrade/change-plan/payment flow
* missing human-readable IDs in API responses
* unstable operations refresh if caused by backend response behavior

If backend changes are required:

1. Follow existing controller/service/repository/schema/router patterns.

2. Use existing Zod validation patterns.

3. Use existing response format and localization keys.

4. Preserve permission checks and tenant/facility scoping.

5. Update or add backend tests where the changed module already has test coverage patterns.

6. Do not change Prisma schema unless strictly required. If Prisma schema changes are required, include migration files and ensure generated client expectations are documented.

## Testing and verification

Run and fix issues from:

Frontend:

```bash
cd frontend
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Backend, only if backend files changed:

```bash
cd backend
npm install
npm run lint
npm test
```

Also manually verify:

1. Dashboard appears instead of Home in navigation and user-facing text.

2. `/` still loads the dashboard.

3. Patient search/filter still works.

4. Advanced filter icon is consistent across affected screens.

5. Rooms/Beds clickable summary cards are compact and fit one row on desktop when space permits.

6. Physiotherapy worklist no longer has duplicated worklist sections.

7. Physiotherapy, Operations, Housekeeping, Biomedical, Mortuary, HR, and Integrations tables span full width and show details in dialogs.

8. Billing uses the correct billing icon and shared table/search pattern.

9. Subscriptions route loads correctly for authorized users and supports current subscription, available plans, upgrade/change-plan, and payment/collection flow based on available backend data.

10. No affected screen has duplicate filter, advanced filter, clear filter, or settings controls.

11. All displayed IDs are copyable and prefer human-readable/public IDs.

12. Operations no longer visibly refreshes or flickers unnecessarily.

13. Mobile/tablet/desktop layouts remain usable.

14. All linter/analyzer/test issues are resolved.

## Scope limits

Do not rewrite unrelated modules.

Do not refactor Communications, Reports/Audits, Settings, Setup, OPD, Emergency, IPD, ICU, Nursing, Discharge, Clinical, Lab, Radiology, Pharmacy, Claims, or Patients beyond global shared component effects and ID-copy consistency.

Do not replace the shared UI system.

Do not introduce new state-management libraries.

Do not introduce new backend architecture.

Do not fake API data.

Do not delete or rename files unless required for the Dashboard rename or removal of obsolete components.

## Final delivery requirements

Return a zipped archive containing only the files and folders that were created or updated.

All files must be placed in their correct relative project directories, for example:

* `frontend/lib/...`
* `backend/src/...`
* `backend/prisma/...`
* `app-planner/...`

Do not include unchanged files.

If files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the archive that safely perform those operations.

PowerShell script requirements:

1. Use correct relative paths from the project root.

2. Check whether each path exists before deleting or renaming.

3. Do not delete unrelated files.

4. Do not use broad wildcards that could remove unrelated files.

5. Make rename/delete operations explicit and reversible where practical.
