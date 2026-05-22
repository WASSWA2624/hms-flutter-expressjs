
You are working inside the attached hms Hospital Management System codebase containing: app-planner, backend, frontend.

Implement the requested changes directly against the existing codebase.

Use the actual project structure, architecture, naming conventions, UI patterns, localization style, backend module style, and app-planner rules as the source of truth.

Do not introduce unrelated rewrites.

---

## Core Objective

Across the HMS app:

1. Make all visible patient, encounter, admission, user, and public identifiers consistently clickable/copyable.
2. Prevent raw/internal IDs from appearing in production UI when public identifiers are unavailable.
3. Remove production-facing “Backend gap”, placeholder, and temporary-record states.
4. Integrate the existing backend settings workspace into the frontend Settings page.
5. Align route entitlement gating with backend module subscriptions.
6. Remove unused example scaffold code from production storage/source.
7. Add focused frontend and backend tests for all changed behavior.

---

## Mandatory Project Rules

Before editing, inspect these files:

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
Flutter imports: package:hosspi_hms/...
Dart files: snake_case.dart
Backend folders: kebab-case
```

Do not import anything from `app-planner/` into runtime source code.

---

# Part 1: Shared Copyable Identifier Component

## Files to inspect first

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

## Required implementation

Create or extend a reusable shared component, for example:

```txt
frontend/lib/shared/components/app_copyable_identifier.dart
```

Export it from:

```txt
frontend/lib/shared/components/components.dart
```

The component must:

* Render the visible identifier as the clickable/tappable target.
* Support optional copy icon.
* Use `Clipboard.setData`.
* Copy exactly the visible identifier value.
* Refuse to copy empty or placeholder values.
* Show a localized `SnackBar` after copy.
* Show short-lived visual success state, such as check icon or changed tooltip.
* Support mouse, touch, keyboard focus, and screen readers.
* Use HMS theme spacing, colors, typography, icon sizes, and Material controls.
* Use localized tooltip, semantic label, and copied message.

Do not copy placeholder values such as:

```txt
empty string
Unknown
N/A
localized unknown values
localized missing values
```

---

## Extend existing shared models

Update:

```txt
frontend/lib/shared/layout/app_workspace.dart
frontend/lib/shared/components/app_info_tile.dart
```

Extend these APIs with optional copy metadata:

```dart
AppWorkspacePatientContextField
AppInfoTileData
AppInfoTile
```

Support copy behavior in:

```dart
AppWorkspacePatientContextHeader
_PatientContextNumberToken
_PatientContextInlineFact
_PatientContextFieldTile
AppInfoTileGrid
AppInfoTile
```

Requirements:

* `patientNumber` must be copyable when non-empty.
* Encounter/admission/patient/user identifier fields must be copyable through field metadata.
* Tile and inline field layouts must support the same copy behavior.
* Existing non-copyable behavior must remain unchanged unless explicitly opted in.

---

## Localization

Use existing keys where already available:

```txt
clinicalPatientIdCopiedMessage
opdEncounterIdCopiedMessage
opdCopyPatientIdAction
opdCopyEncounterIdAction
```

Add missing localization keys for:

```txt
Copy admission ID
Copy user ID
Copy identifier
Admission ID copied.
User ID copied.
Identifier copied.
```

Update:

```txt
frontend/lib/l10n/app_en.arb
```

Then regenerate localization files:

```bash
cd frontend
flutter gen-l10n
```

---

# Part 2: App-Wide Identifier Scan and Fixes

Perform a full frontend scan for displayed identifiers using:

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
effectiveDisplayId
effectiveIdentifier
```

At minimum inspect and update:

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

## Identifier display rules

Prefer public/human-friendly identifiers:

```txt
displayId
publicId
patientDisplayId
patientIdentifier
encounterPublicId
human_friendly_id
effective public display fields
```

Keep raw/internal IDs only for:

```txt
API calls
repository methods
route params
equality checks
keys
internal state
```

Do not render raw UUID/internal `id` in production UI unless the codebase clearly treats that value as the public identifier.

When no public identifier exists:

* show the feature’s existing localized missing/unknown value, or
* omit the identifier field.

Every visible patient, encounter, admission, and user identifier must be copyable.

---

# Part 3: Remove Production-Facing Backend-Gap States

Search the frontend and backend for phrases like:

```txt
Backend gap
Backend gaps
Backend endpoint required
Not exposed by API
Pending payment - backend gap
Partial stock - backend gap
placeholder
temporary record
```

Users must not see developer-facing backend-gap text.

Replace these with:

* real backend-backed workflow state,
* empty states,
* permission states,
* unavailable states,
* disabled actions with business-facing explanations.

---

## Rooms, Beds, Housekeeping, and Discharge

Inspect frontend:

```txt
frontend/lib/features/rooms_beds/presentation/pages/rooms_beds_workspace_page.dart
frontend/lib/features/housekeeping/domain/entities/housekeeping_entities.dart
frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart
frontend/lib/features/discharge/domain/entities/discharge_entities.dart
frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart
```

Inspect backend:

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

Required fixes:

* Remove rooms/beds backend gap notice.
* Replace hard-coded housekeeping backend gaps with backend-backed readiness/capability state.
* Support real bed cleaning/readiness state.
* Wire final discharge/bed release to housekeeping task creation atomically where supported.
* If needed, add the smallest backend contract required.
* Replace `DischargeClearanceState.backendGap` with real states or explicit unavailable states.

---

## Pharmacy

Inspect frontend:

```txt
frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart
```

Inspect backend:

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

Required fixes:

* Remove `_BillingGapPanel`.
* Replace billing/payment authorization gap with real invoice/payment status.
* Replace batch availability gap with real drug batch/inventory availability.
* Replace hold/substitution gap with backend-backed order/item status.
* Replace report-template gap with existing report/print template integration where available.
* Do not enable unsafe dispense actions when stock, batch, payment, or authorization blocks them.

---

## Physiotherapy

Inspect frontend:

```txt
frontend/lib/features/physiotherapy/data/repositories/physiotherapy_repository_impl.dart
frontend/lib/features/physiotherapy/domain/entities/physiotherapy_entities.dart
frontend/lib/features/physiotherapy/presentation/pages/physiotherapy_workspace_page.dart
```

Inspect backend:

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

Required fixes:

* Remove hard-coded `_backendGapCodes`.
* Remove `_BackendGapsPanel`.
* Replace fake status, billing, and report behavior with backend-backed behavior.
* If a physiotherapy-specific backend endpoint is truly required, add the smallest backend module/route/schema/service/repository changes needed.

---

## Integrations / Interop

Inspect frontend:

```txt
frontend/lib/features/integrations/data/repositories/integrations_repository_impl.dart
frontend/lib/features/integrations/presentation/pages/integrations_workspace_page.dart
```

Inspect backend:

```txt
backend/src/modules/integration
backend/src/modules/integration-log
backend/src/modules/interop
backend/src/modules/webhook-subscription
backend/src/modules/api-key
```

Required fixes:

* Remove hard-coded `BACKEND_GAP` readiness.
* Derive readiness from:

  * integration status,
  * API key state,
  * webhook state,
  * sanitized logs,
  * interop route availability.
* Keep error states safe and non-PHI.

---

# Part 4: Remove Placeholder Production Records

Inspect:

```txt
backend/src/modules/dashboard-workspace/services/dashboard-workspace.service.js
backend/src/modules/biomedical-workspace/services/biomedical-workspace.service.js
backend/src/modules/biomedical-workspace/repositories/biomedical-workspace.repository.js
```

Required fixes:

## Dashboard

Do not emit fake/placeholder workflow entities such as:

```js
meta: { placeholder: true }
```

Replace placeholder operational data with:

* real empty state,
* real recommendation payload, or
* safe non-entity guidance that frontend can render without treating it as operational data.

## Biomedical fault reporting

Do not create placeholder equipment registry records.

If a fault report is submitted without selected equipment:

* store reported equipment text as contextual report data, or
* require selecting/creating a real equipment record through the proper equipment registry workflow.

Preserve:

* audit logging,
* notifications,
* WebSocket updates.

Do not mark placeholder equipment as real equipment.

---

# Part 5: Integrate Backend Settings Workspace into Frontend Settings

Backend already exists:

```txt
backend/src/modules/settings-workspace/controllers/settings-workspace.controller.js
backend/src/modules/settings-workspace/repositories/settings-workspace.repository.js
backend/src/modules/settings-workspace/routes/settings-workspace.routes.js
backend/src/modules/settings-workspace/schemas/settings-workspace.schema.js
backend/src/modules/settings-workspace/services/settings-workspace.service.js
```

Frontend currently has:

```txt
frontend/lib/core/network/api_endpoints.dart
frontend/lib/features/settings/presentation/pages/settings_page.dart
```

`HmsApiResource.settingsWorkspace` already exists.

Implement frontend clean architecture files under:

```txt
frontend/lib/features/settings/data/dtos
frontend/lib/features/settings/data/repositories
frontend/lib/features/settings/domain/entities
frontend/lib/features/settings/domain/repositories
frontend/lib/features/settings/presentation/controllers
frontend/lib/features/settings/presentation/state
frontend/lib/features/settings/presentation/widgets
```

## Required API calls

Fetch:

```txt
GET /settings-workspace/workspace
GET /settings-workspace/reference-data
```

## Required backend states

Support:

```txt
ready
tenant_context_required
```

## Required UI

Render backend-backed settings workspace content inside the existing Settings page or a focused settings workspace section.

Render:

```txt
context summary
summary cards
setup checklist
quick actions
module groups
filters/search
tenant/facility selector when required
loading state
error state
empty/unavailable state
```

Preserve existing local settings behavior:

```txt
language
theme mode
profile action
change password action
admin navigation actions
```

Use shared components:

```txt
AppScreen
AppScreenSection
AppWorkspace
AppInfoTile
AppButton
AppSelectField
state/error views
existing theme tokens
```

Do not display backend `label_key` directly.

Map known backend label keys to localized frontend strings or add localization keys.

If a backend route points to a frontend route that does not exist:

* do not create fake navigation,
* route only to the closest real supported route,
* otherwise show a disabled action with clear localized unavailable text,
* add code comments/tests where route mapping is intentionally unavailable.

---

# Part 6: Route Entitlement Gating Consistency

Inspect:

```txt
frontend/lib/app/router/app_routes.dart
```

Verify and align these routes:

```txt
communications
reports
subscriptions
settings
```

Use backend/app-planner sources to derive module slugs.

Known module slugs to verify from codebase before use:

```txt
notifications-communications
reporting-analytics
subscription-controls
compliance-audit-core
integrations-core
```

Expected direction:

* `communications` should require `notifications-communications` if the module exists.
* `reports` should require `reporting-analytics` if the module exists.
* `subscriptions` should require `subscription-controls` if the module exists.
* Keep `/settings` authenticated/core if it contains user-level preferences.
* Gate only backend/admin settings workspace content by role, permission, or backend state.

Do not guess module slugs.

Do not add multiple active modules unless the route truly requires all of them or the existing guard supports OR logic.

---

# Part 7: Remove Example Scaffold from Production Storage

Inspect:

```txt
frontend/lib/features/example/
frontend/test/features/example/
frontend/lib/core/storage/database/tables/example_resource_cache_entries.dart
frontend/lib/core/storage/database/app_database.dart
frontend/lib/core/storage/database/app_database.g.dart
frontend/test/helpers/provider_override_examples_test.dart
frontend/test/core/storage/database/app_database_test.dart
```

Required fixes:

* Remove unused production example feature code.
* Remove `ExampleResourceCacheEntries` from `AppDatabase`.
* Update Drift generated code.
* Update database tests to use real production tables such as `SyncQueueEntries`.
* Remove or rewrite provider override tests that import example production code.

Run:

```bash
cd frontend
dart run build_runner build --delete-conflicting-outputs
```

If files/folders are deleted, include a safe PowerShell deletion script:

```txt
scripts/remove-example-scaffold.ps1
```

Script requirements:

* use paths relative to project root,
* check existence before deleting,
* delete only intended files/folders,
* do not use unsafe wildcards,
* do not delete user data or environment files.

---

# Part 8: Frontend Tests

Add or update focused tests.

Minimum coverage:

```txt
frontend/test/shared/components/app_copyable_identifier_test.dart
frontend/test/shared/components/app_info_tile_test.dart
frontend/test/shared/layout/app_workspace_test.dart
frontend/test/features/settings/...
```

Use existing test helpers:

```txt
frontend/test/shared/components/component_test_app.dart
frontend/test/helpers/test_harness.dart
frontend/test/shared/layout/app_workspace_test.dart
```

Test:

* copyable identifier copies visible value,
* placeholder values are not copyable,
* SnackBar appears after copy,
* success/check state appears after copy,
* `AppWorkspacePatientContextHeader` copy behavior,
* `AppInfoTile` identifier copy behavior,
* modified workspaces no longer render backend-gap text,
* raw/internal ID fallback is not displayed when public ID is absent,
* settings workspace DTO parsing,
* settings repository API integration,
* settings controller/state transitions,
* settings workspace UI states.

---

# Part 9: Backend Tests

Add or update backend tests for every backend contract changed.

Cover:

* settings workspace frontend contract if changed,
* rooms/beds/housekeeping/discharge atomic handoff if changed,
* pharmacy payment/batch/hold/report contract if changed,
* physiotherapy status/billing/report contract if changed,
* integrations interop readiness if changed,
* dashboard no-placeholder behavior,
* biomedical no-placeholder-equipment behavior,
* validation errors for missing required IDs.

Use existing backend test style under:

```txt
backend/src/tests
backend/package.json
backend/app-planner/app-rules/testing.md
```

---

# Part 10: UI/UX Requirements

For copyable identifiers:

* Use compact identifier chip/token style consistent with HMS panels.
* Keep IDs readable.
* Do not make layouts noisy.
* Use hover/focus affordance on desktop/web.
* Use `Icons.copy_outlined` before copy.
* Use success/check affordance after copy.
* SnackBar text must be localized and specific where possible.
* Support use in:

  * patient context headers,
  * info tiles,
  * table/list cells,
  * detail panels,
  * inline metadata rows.
* Avoid large padding or visual styles that conflict with:

  * `AppWorkspace`,
  * `AppContentPanel`,
  * `AppInfoTile`,
  * `AppListTable`.

For backend-gap cleanup:

* Do not show developer-facing phrases to users.
* Show real workflow state, permission state, empty state, or disabled action with business reason.
* Business-facing unavailable explanations are acceptable.
* Developer-facing backend-gap labels are not acceptable.

---

# Part 11: Verification Commands

Run from the correct directories.

## Frontend

```bash
cd frontend
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format lib test integration_test
flutter analyze
flutter test
```

## Backend

Run if backend files changed:

```bash
cd backend
npm install
npm run lint
npm run test:backend
npm run openapi:generate
npm run openapi:validate
```

Fix all issues introduced by this task.

---

# Final Delivery Format

Return a single zipped archive containing only files and folders created or changed.

Preserve relative paths, for example:

```txt
frontend/lib/shared/components/app_copyable_identifier.dart
frontend/lib/shared/layout/app_workspace.dart
frontend/lib/features/settings/...
backend/src/modules/...
scripts/remove-example-scaffold.ps1
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

If any file or folder is deleted or renamed, include one or more safe `.ps1` scripts, for example:

```txt
scripts/remove-example-scaffold.ps1
```

The zip must include:

* changed source files,
* generated localization files,
* generated Drift files when applicable,
* tests,
* safe PowerShell delete/rename scripts when needed.
