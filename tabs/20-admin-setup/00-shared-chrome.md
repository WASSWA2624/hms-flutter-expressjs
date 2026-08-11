# Admin setup — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.tenantFacilitySetup` — name `tenantFacilitySetup`, path `/admin/setup` under app `ShellRoute`
- Catalog gate: `RouteAccessCatalog.tenantFacilitySetup` / `RouteAccessCatalog.setupEntry` — ∩ `setup:read` + `requiresFacilityContext: true`
- Shell nav label (by policy): `tenantFacilitySetupNavigationLabel`
  - platform elevated (`isPlatformElevated`): `navigationPlatformSetupLabel`
  - `canManageTenant()`: `navigationSetupLabel`
  - else: `navigationFacilitySetupLabel`
- Settings navigate tile reuses same catalog: `SettingsAdministrationAtomPermissions.tenantFacilitySetup` → `RouteAccessCatalog.setupEntry`

## Workspace page gate (in-page)

After load, tabs use imperative policy (no dedicated `tenant_facility_access.dart` / AccessRequirement atoms):

- `canManageTenant()` → elevated **or** `tenant:admin`
- `canManageFacility()` → elevated **or** ∪ `tenant:admin` \| `facility:admin` \| `platform:admin`
- `canEditFacilitySetupStructure()` ≡ `canManageFacility()`
- `canManageAccess` → `grantsAny` ∪ `platform:admin` \| `tenant:admin` \| `facility:admin` \| `hr:write`
- Subscription tabs → `accessPolicy.isElevated` (`PLATFORM_OWNER` \| `PLATFORM_ADMIN` roles)
- If **no** visible sections: `AppWorkspaceStatePanel.empty` (`tenantFacilitySetupTitle` / `tenantFacilitySetupBody`) — not a forbidden `AppFailureStateView`

## Page chrome

- `AsyncStateScaffold<FacilitySetupSnapshot>` over `tenantFacilitySetupControllerProvider`
  - Loading: `tenantFacilitySetupLoadingTitle` / `tenantFacilitySetupLoadingBody`
  - Retry → controller `refresh()`
- Body: `AppWorkspace` + `AppTabStrip` + `IndexedStack` (keep-alive per visited tab)
- Title: `tenantFacilitySetupWorkspaceTitle`
- Leading icon: `AppRouteIcons.setup`
- Toolbar: `appWorkspaceToolbarWithLabels` with **global/fault/housekeeping actions off**
- Success snackbar (submission): `tenantFacilitySavedMessage`

## URL sync

- Query model: `TenantFacilitySetupPageQuery` — `?section=` **or** `?tab=`
- Sync: `syncWorkspaceLocation` → `AppRoutes.tenantFacilitySetup.location(queryParameters: {section: routeQueryValue})`
- **No** search/patientId/action deep-links (unlike Reception)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` — standard variant
- Tabs **omitted** when unauthorized (`tenantFacilitySetupDeskSectionVisible`) — not disabled
- **No `count`**, **no `AppTabCountTone`** on any tab
- Icons / labels from `tenantFacilitySetupDeskSectionIcon` / `tenantFacilitySetupDeskSectionLabel`

## Table toolbar (shared pattern)

Structure tabs (dept→beds): private `_SearchableEntityGroup` — Filters + Settings + **Add**; `AppListTable` default **`enableExport: true`** (ungated), **`enablePrint: false`**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | section-specific hints | |
| Filters | often `commonFilterActionLabel` (singular) | clinical catalog uses `commonFiltersActionLabel` |
| Settings | `commonTableSettingsActionLabel` | storage keys `setup_structure_*`, `setup_manage_*`, `admin_catalog_*` |
| Export | default on | not ∩ `evidence:export` |
| Print (table) | off | |
| Context | Add / Configure | gated by create/edit policy |

Apply/Reset: `opdApplyFiltersAction` / `opdClearFiltersAction`. Soft-delete filter keys commonly `status` = `active` \| `deleted`.

## Shared hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Tenant / facility manage panels | Setup-owned | `tenant_facility_management_dialogs.dart` |
| Structure forms dept→bed | Setup-owned | setup page `_*FormDialog` |
| Structure details / similarity | Setup-owned | `*_details_dialog.dart`, `*_similarity_dialog.dart` |
| Roles / Permissions / Users | **reused** Access Admin | `access_admin_management_dialogs.dart` |
| Clinical catalog CRUD/configure | **reused** shared catalogs | radiology / lab / clinical catalog dialogs |
| Subscription approve / activate | Setup panels + access-admin API | `manage_subscription_*_panel.dart` |

## Legacy wizard

- `tenant_facility_setup_wizard.dart` — `TenantFacilitySetupWizard(` **never constructed** elsewhere; desk replaced guided wizard as primary nav.

## Feedback patterns (cross-tab)

- Success: `tenantFacilitySavedMessage` (+ access-admin / lab messages on reused panels)
- Failures: `AppFailureStateView` / banners / plain failure text (beds less polished)
- Empty: section-specific empty titles/bodies
