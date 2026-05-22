You are working on the Hospital Management System archive with this project root structure:

```txt
hms/
  app-planner/
  backend/
  frontend/
```

Refine and implement the requested changes directly against the existing codebase. Use the actual project architecture, naming conventions, UI patterns, localization style, backend module style, and app-planner rules as the source of truth. Do not introduce unrelated rewrites.

No task-specific screenshots were present in the archive beyond standard app icon/logo assets, so the written UI/UX requirements below are the complete UI source of truth.

## Main problem

Across the HMS app, displayed user IDs, patient IDs, patient numbers, patient identifiers, encounter IDs, admission IDs, and patient/encounter-related public identifiers are not consistently copyable. Some are rendered as plain `Text`, some have separate copy buttons, and many areas still fall back to raw/internal IDs such as `id` when `displayId`, `publicId`, `patientDisplayId`, `patientIdentifier`, or `human_friendly_id` is unavailable.

Also, several production-facing workflows still expose “backend gap”, placeholder, or temporary states to users instead of real backend-backed behavior.

Implement an app-wide cleanup so identifiers are safe, consistent, clickable/copyable, visually confirm copy success, and production UI no longer exposes avoidable backend-gap/placeholder states.

## Project rules to follow

Before editing, inspect and follow these files:

```txt
app-planner/dev-plan/37-quality-release.md
app-planner/dev-plan/10-workspace-ui.md
app-planner/dev-plan/19-discharge.md
app-planner/dev-plan/23-pharmacy.md
app-planner/dev-plan/24-billing.md
app-planner/dev-plan/26-physiotherapy.md
app-planner/dev-plan/29-rooms-beds.md
app-planner/dev-plan/32-housekeeping.md
app-planner/dev-plan/36-integrations.md

frontend/app-planner/app-rules/architecture.md
frontend/app-planner/app-rules/project_structure.md
frontend/app-planner/app-rules/coding_conventions.md
frontend/app-planner/app-rules/reusable_components.md
frontend/app-planner/app-rules/localization_i18n.md
frontend/app-planner/app-rules/accessibility.md
frontend/app-planner/app-rules/testing.md
frontend/app-planner/app-rules/network_api.md

backend/app-planner/app-rules/project-structure.md
backend/app-planner/app-rules/coding-standards.md
backend/app-planner/app-rules/testing.md
backend/app-planner/app-rules/response-format.md
```

Preserve:

```txt
frontend/lib/features/<feature>/data|domain|presentation
frontend/lib/shared/components
frontend/lib/shared/layout
frontend/lib/core/network
backend/src/modules/<module>/controllers|repositories|routes|schemas|services
backend CommonJS style
Flutter package imports: package:hosspi_hms/...
Dart file names: snake_case.dart
Backend module folders: kebab-case
```

Do not import anything from `app-planner/` into application source code.

## Scope limits

Modify only files required for this task.

Do not:

* Rewrite unrelated screens.
* Replace existing state management patterns.
* Replace Riverpod, Dio, Drift, GoRouter, or shared layout architecture.
* Add duplicate UI components when an existing shared component can be extended.
* Hide backend gaps by only deleting UI text while leaving broken workflows.
* Expose raw UUID/internal IDs in production UI unless the codebase explicitly treats that value as the public identifier.
* Change unrelated routes, permissions, seed data, or schemas.

If a referenced gap is already fixed in the current codebase, leave that area unchanged except for tests if needed.

## Part 1: App-wide clickable/copyable identifiers

Implement a shared reusable solution for copyable identifiers instead of repeating private copy helpers in feature pages.

Relevant existing files to inspect first:

```txt
frontend/lib/shared/layout/app_workspace.dart
frontend/lib/shared/components/app_info_tile.dart
frontend/lib/shared/components/components.dart
frontend/lib/shared/components/app_list_item_text.dart
frontend/lib/shared/components/app_list_table.dart
frontend/lib/shared/opd_actions/opd_action_context.dart
frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart
frontend/lib/features/patients/presentation/pages/patient_registry_page.dart
frontend/lib/l10n/app_en.arb
frontend/lib/l10n/app_localizations.dart
frontend/lib/l10n/app_localizations_en.dart
```

Suggested implementation direction:

* Add or extend a shared component for copyable identifiers, for example `AppCopyableIdentifier`, and export it from `frontend/lib/shared/components/components.dart`.
* Extend `AppWorkspacePatientContextField` and `AppInfoTileData`/`AppInfoTile` so identifier fields can opt into copy behavior.
* Update `AppWorkspacePatientContextHeader` so:

  * `patientNumber` can be clickable/copyable when non-empty.
  * encounter/admission/patient identifier fields can be copyable through field metadata.
  * tile and inline field styles both support the same copy behavior.
* Reuse the shared copy behavior in OPD/clinical/patient registry areas that currently have custom copy functions, where doing so does not remove existing useful quick actions.

Behavior requirements:

* The displayed ID text/token itself must be clickable/tappable, not only a tiny icon.
* Copy exactly the visible identifier value unless an existing action explicitly copies a different API value.
* Do not copy placeholder values such as empty string, `Unknown`, `N/A`, or localized missing-value labels.
* On copy, use `Clipboard.setData`.
* Show immediate visual confirmation:

  * a localized `SnackBar`, and
  * a short-lived visible state such as a check icon, changed tooltip, or “copied” affordance on the clicked token.
* Use existing theme spacing, colors, typography, icon sizes, and Material controls.
* Support mouse, touch, keyboard focus, and screen readers.
* Use localized tooltips, semantic labels, and SnackBar messages. Do not hard-code user-facing text.
* Keep tap targets accessible; use the existing app token sizes where practical.
* Use `MaterialLocalizations.copyButtonLabel` only where appropriate, otherwise add HMS-specific localization keys.

Add localization keys as needed for:

```txt
Copy patient ID
Copy encounter ID
Copy admission ID
Copy user ID
Copy identifier
Patient ID copied.
Encounter ID copied.
Admission ID copied.
User ID copied.
Identifier copied.
```

Use existing keys where they already exist:

```txt
clinicalPatientIdCopiedMessage
opdEncounterIdCopiedMessage
opdCopyPatientIdAction
opdCopyEncounterIdAction
```

Regenerate localization files after editing ARB files.

## Part 2: App-wide scan and update identifier displays

Perform a full frontend scan for displayed identifiers using labels and variables such as:

```txt
patientId
patientIdentifier
patientNumber
patientDisplayId
encounterId
encounterPublicId
admissionId
displayId
publicId
humanFriendlyId
human_friendly_id
userId
user_id
```

At minimum inspect and update these files where identifiers are displayed:

```txt
frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart
frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart
frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart
frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart
frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart
frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart
frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart
frontend/lib/features/billing/presentation/pages/billing_workspace_page.dart
frontend/lib/features/claims/presentation/pages/claims_workspace_page.dart
frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart
frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart
frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart
frontend/lib/features/patients/presentation/pages/patient_registry_page.dart
frontend/lib/features/emergency/presentation/pages/emergency_workspace_page.dart
frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart
frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart
frontend/lib/features/profile/presentation/pages/user_profile_page.dart
```

Known current patterns to fix include but are not limited to:

```txt
displayId ?? id
publicId ?? id
patientId ?? displayId ?? id
encounterId rendered as plain text
patientNumber rendered without copy behavior
AppInfoTileData identifier values rendered as plain text
AppWorkspacePatientContextField identifier values rendered as plain text
```

Specific examples currently present in the codebase:

```txt
frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart
frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart
frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart
frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart
frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart
frontend/lib/features/patients/presentation/pages/patient_registry_page.dart
frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart
```

Display requirements:

* Prefer human-friendly/public identifiers in UI:

  * `displayId`
  * `publicId`
  * `patientDisplayId`
  * `patientIdentifier`
  * `encounterPublicId`
  * `human_friendly_id`
  * existing `effective...` public display fields
* Keep internal IDs available for API calls, keys, route params, repository methods, and equality checks.
* Do not use raw `id` as a UI fallback unless the codebase proves that field is already a public/human-friendly ID for that entity.
* When no public identifier exists, show the feature’s existing localized missing/unknown value or omit the identifier field.
* Ensure every visible patient, encounter, admission, and user identifier is copyable after this change.

## Part 3: Remove production-facing backend-gap states where real contracts can be wired

Inspect frontend and backend together. Replace backend-gap panels/states with real backend-backed data or minimal backend endpoints where required.

### Rooms, beds, housekeeping, and discharge-to-housekeeping

Relevant frontend files:

```txt
frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart
frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart
frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart
frontend/lib/features/discharge/domain/entities/discharge_entities.dart
frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart
```

Relevant backend modules to inspect:

```txt
backend/src/modules/bed
backend/src/modules/bed-assignment
backend/src/modules/room
backend/src/modules/ward
backend/src/modules/housekeeping-task
backend/src/modules/housekeeping-schedule
backend/src/modules/housekeeping-workspace
backend/src/modules/discharge-summary
backend/src/modules/ipd-flow
backend/src/modules/admission
```

Fix requirements:

* Remove or replace the rooms/beds backend gap notice currently shown through `roomsBedsBackendGapsTitle` / `roomsBedsBackendGapsBody`.
* Replace hard-coded `housekeepingBackendGaps` with backend-backed capability/readiness state.
* Support bed cleaning/readiness states without exposing “Backend gap” to users.
* Wire final discharge/bed release to housekeeping task creation atomically where the backend contract supports it, or add the minimal backend contract needed.
* Replace `DischargeClearanceState.backendGap` for insurance/housekeeping with real states derived from backend-backed data or explicit unavailable states that are not described as “backend gaps”.
* Preserve existing statuses and permissions where they already work.

### Pharmacy

Relevant frontend file:

```txt
frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart
```

Relevant backend modules to inspect:

```txt
backend/src/modules/pharmacy-workspace
backend/src/modules/pharmacy-order
backend/src/modules/pharmacy-order-item
backend/src/modules/dispense-log
backend/src/modules/drug
backend/src/modules/drug-batch
backend/src/modules/inventory-item
backend/src/modules/inventory-stock
backend/src/modules/invoice
backend/src/modules/payment
backend/src/modules/report-definition
backend/src/modules/report-run
```

Fix requirements:

* Remove `_BillingGapPanel` as a production-facing gap panel.
* Replace payment authorization/billing gate gap with actual invoice/payment/billing status where available.
* Replace batch availability gap with real drug batch/inventory availability.
* Replace hold/substitution gap with real supported order/item state if backend supports it; otherwise implement the smallest backend-backed status needed.
* Replace report-template gap with existing report/print template integration where available.
* Do not enable unsafe dispense actions when stock, batch, payment, or authorization state blocks them.

### Physiotherapy

Relevant frontend files:

```txt
frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart
frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart
frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart
```

Relevant backend modules to inspect:

```txt
backend/src/modules/encounter
backend/src/modules/procedure
backend/src/modules/care-plan
backend/src/modules/follow-up
backend/src/modules/clinical-note
backend/src/modules/invoice
backend/src/modules/report-definition
backend/src/modules/report-run
```

Fix requirements:

* Remove hard-coded `_backendGapCodes`.
* Remove `_BackendGapsPanel` as a production-facing panel.
* Provide backend-backed status, billing authorization, and report behavior using existing clinical/procedure/care-plan/follow-up/billing/report contracts where possible.
* If a dedicated physiotherapy endpoint is truly required, add the smallest backend module/route/schema/service/repository changes needed and tests for that contract.

### Integrations / interop readiness

Relevant frontend file:

```txt
frontend/lib/features/integrations/data/repositories/integrations_repository_impl.dart
```

Relevant backend modules to inspect:

```txt
backend/src/modules/integration
backend/src/modules/integration-log
backend/src/modules/interop
backend/src/modules/webhook-subscription
backend/src/modules/api-key
```

Fix requirements:

* Remove hard-coded `BACKEND_GAP` readiness capability.
* Derive interop readiness from actual integration status, API key/webhook state, sanitized logs, and interop route availability.
* Keep error states safe and non-PHI.

## Part 4: Remove placeholder/temporary production records

Relevant backend files:

```txt
backend/src/modules/dashboard-workspace/services/dashboard-workspace.service.js
backend/src/modules/biomedical-workspace/services/biomedical-workspace.service.js
backend/src/modules/biomedical-workspace/repositories/biomedical-workspace.repository.js
```

Fix requirements:

* Dashboard must not emit fake/placeholder entities such as a guide signal with `meta: { placeholder: true }` as production workflow data.
* Replace the empty-dashboard fallback with a real empty state, real recommendation payload, or safe non-entity guidance that the frontend can render without treating it as operational data.
* Biomedical fault reporting must not create placeholder equipment registry records that can appear as real assets.
* If a fault report is submitted without equipment, store the reported equipment text as contextual report data or require selecting/creating a real equipment record through the proper equipment registry workflow.
* Preserve audit logging and notifications without marking placeholder equipment as real equipment.

## Part 5: Integrate backend settings workspace into frontend settings

Backend settings workspace already exists:

```txt
backend/src/modules/settings-workspace/controllers/settings-workspace.controller.js
backend/src/modules/settings-workspace/repositories/settings-workspace.repository.js
backend/src/modules/settings-workspace/routes/settings-workspace.routes.js
backend/src/modules/settings-workspace/schemas/settings-workspace.schema.js
backend/src/modules/settings-workspace/services/settings-workspace.service.js
```

Frontend already has:

```txt
frontend/lib/core/network/api_endpoints.dart
frontend/lib/features/settings/presentation/pages/settings_page.dart
```

`HmsApiResource.settingsWorkspace` already exists in `api_endpoints.dart`.

Implement frontend integration using the project’s clean architecture style. Add files under `frontend/lib/features/settings/` as needed:

```txt
data/dtos
data/repositories
domain/entities
domain/repositories
presentation/controllers
presentation/state
presentation/pages
presentation/widgets
```

Requirements:

* Fetch `/settings-workspace/workspace`.
* Fetch `/settings-workspace/reference-data` where needed.
* Render backend-backed settings workspace content inside the existing Settings page or a focused settings workspace section.
* Support backend states:

  * `ready`
  * `tenant_context_required`
* Render:

  * context summary
  * summary cards
  * setup checklist
  * quick actions
  * module groups
  * filters/search where appropriate
  * tenant/facility selector if required by backend state
* Preserve local preferences already in `settings_page.dart`:

  * language
  * theme mode
  * profile action
  * change password action
  * admin navigation actions
* Use shared components: `AppScreen`, `AppScreenSection`, `AppWorkspace`, `AppInfoTile`, `AppButton`, `AppSelectField`, state/error views, and existing theme tokens.
* Do not hard-code settings labels from backend `label_key`; map known backend label keys to localized frontend strings or add localization keys where required.
* If a backend route points to a frontend route that does not exist, do not create fake navigation. Route to the closest existing setup page only if supported by the router; otherwise show a disabled/clear unavailable action and mark the missing route mapping in code comments/tests.

## Part 6: Route entitlement gating consistency

Relevant file:

```txt
frontend/lib/app/router/app_routes.dart
```

Current inconsistent areas to verify:

```txt
communications
reports
subscriptions
settings
```

Requirements:

* Align route gating with the module-subscription model used by operational workspaces where supported by existing module slugs.
* Do not guess module slugs. Derive them from backend seeders, module catalog, route definitions, or app-planner docs.
* If a route is intentionally platform/core/auth-only, preserve that behavior and make the intention explicit in code through existing route metadata/comment style only if the codebase already uses such comments.
* Ensure route guards still pass for tenant/facility context requirements.

Missing details to verify from codebase:

```txt
Exact active module slug for communications, if any.
Exact active module slug for reports/audit, if any.
Exact active module slug for subscriptions, if any.
Whether settings is intentionally core/auth-only or should require tenant/admin entitlement.
```

## Part 7: Frontend test coverage

Existing missing feature test folders include:

```txt
frontend/test/features/discharge
frontend/test/features/emergency
frontend/test/features/housekeeping
frontend/test/features/hr
frontend/test/features/icu
frontend/test/features/integrations
frontend/test/features/ipd
frontend/test/features/lab
frontend/test/features/pharmacy
frontend/test/features/physiotherapy
frontend/test/features/profile
frontend/test/features/settings
frontend/test/features/tenant_facility
```

Add focused tests for the changed behavior. At minimum:

* Shared copyable identifier widget/component tests.
* `AppWorkspacePatientContextHeader` tests proving patient number and encounter/admission fields are copyable.
* `AppInfoTile` tests proving identifier fields are copyable when configured and non-copyable when empty/missing.
* Feature smoke/widget/controller/DTO tests for every feature folder you create or modify.
* Settings workspace DTO/repository/controller tests.
* Tests proving production UI no longer renders “Backend gap” panels in the updated workspaces.
* Tests proving raw/internal ID fallback does not appear when public display IDs are absent.

Use existing test helpers and style:

```txt
frontend/test/shared/components/component_test_app.dart
frontend/test/helpers/test_harness.dart
frontend/test/shared/layout/app_workspace_test.dart
```

## Part 8: Backend tests

Add or update backend tests for every backend contract changed.

Relevant commands and patterns are in:

```txt
backend/package.json
backend/src/tests
backend/app-planner/app-rules/testing.md
```

Cover:

* Settings workspace frontend contract if backend payload changes.
* Rooms/beds/housekeeping/discharge atomic handoff if changed.
* Pharmacy payment/batch/hold/report contract if changed.
* Physiotherapy status/billing/report contract if changed.
* Integrations interop readiness contract if changed.
* Dashboard no-placeholder behavior.
* Biomedical no-placeholder-equipment behavior.
* Validation errors for missing required IDs.

## Part 9: Remove example scaffold from production storage

Current production example scaffold files include:

```txt
frontend/lib/features/example/
frontend/test/features/example/
frontend/lib/core/storage/database/tables/example_resource_cache_entries.dart
frontend/lib/core/storage/database/app_database.dart
frontend/lib/core/storage/database/app_database.g.dart
frontend/test/helpers/provider_override_examples_test.dart
frontend/test/core/storage/database/app_database_test.dart
```

Fix requirements:

* Remove `features/example` from production source if still unused by routes/features.
* Remove `ExampleResourceCacheEntries` from `AppDatabase`.
* Update Drift generated code by running build generation.
* Update database tests so they test real production tables such as `SyncQueueEntries` instead of the example table.
* Update or remove provider override example tests that import production example feature code.
* If deleting files/folders, include a PowerShell deletion script as described in the final packaging section.

## UI/UX requirements

For copyable identifiers:

* Use a compact identifier chip/token style consistent with existing HMS panels.
* Keep the ID readable and selectable-looking without making the layout noisy.
* Use hover/focus affordance on desktop/web.
* Use `Icons.copy_outlined` before copy and a success/check affordance after copy.
* SnackBar text must be localized and specific where possible:

  * patient ID copied
  * encounter ID copied
  * admission ID copied
  * user ID copied
  * identifier copied
* The component must work in:

  * patient context headers
  * info tiles
  * table/list cells
  * detail panels
  * inline metadata rows
* Avoid huge padding or new visual styles that conflict with existing `AppWorkspace`, `AppContentPanel`, `AppInfoTile`, and `AppListTable` patterns.

For backend-gap cleanup:

* Users should see real workflow state, unavailable/permission states, empty states, or actionable disabled states.
* Users should not see developer-facing phrases such as:

  * “Backend gap”
  * “Backend endpoint required”
  * “Not exposed by API”
  * “placeholder”
  * “temporary record”
* If an action is unavailable because business preconditions are not met, explain the business reason in user-facing language.

## Verification commands

Run all relevant commands from the correct directories.

Frontend:

```bash
cd frontend
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format lib test integration_test
flutter analyze
flutter test
```

Backend, if backend files changed:

```bash
cd backend
npm install
npm run lint
npm run test:backend
npm run openapi:generate
npm run openapi:validate
```

Also run focused tests for changed areas while developing.

All analyzer, linter, localization, generated-code, and test issues introduced by this task must be fixed.

## Final delivery format

Return a single zipped archive containing only files and folders that were created or updated.

The archive must preserve correct relative paths, for example:

```txt
frontend/lib/shared/components/app_copyable_identifier.dart
frontend/lib/shared/layout/app_workspace.dart
backend/src/modules/...
```

Do not include:

```txt
node_modules/
build/
.dart_tool/
coverage/
android/.gradle/
ios/Pods/
entire unchanged project folders
```

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the zip, for example:

```txt
scripts/remove-example-scaffold.ps1
scripts/rename-old-file.ps1
```

PowerShell script requirements:

* Use only correct relative paths from the project root.
* Check existence before deleting or renaming.
* Delete or rename only the intended files/folders.
* Do not use wildcards that could remove unrelated files.
* Do not delete user data, environment files, or unrelated generated assets.

The zip must include all changed source, generated localization/Drift files when applicable, tests, and safe `.ps1` delete/rename scripts when needed.
