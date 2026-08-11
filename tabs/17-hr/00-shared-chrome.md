# HR — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.hr` under app `ShellRoute` (`path: '/hr'`)
- Workspace gate (page/catalog): `HrHumanResourcesAtomPermissions.routeEntry` / `RouteAccessCatalog.hrEntry` — ∩ `hr:read` + module `hr-rosters` + facility context
- Route declaration note: `AppRoutes.hr` advertises ∪ `hr:read` \| `hr:write`; page gate is ∩ `hr:read` (tests call this out)
- Catalog entry: `RouteAccessCatalog.hr` / `hrEntry`
- If no desk tabs are allowed: `SizedBox.shrink()` (no forbidden placeholders)

## Page chrome

- `AsyncStateScaffold<HrWorkspaceState>` over `hrWorkspaceControllerProvider`
  - Loading: `hrLoadingTitle` / `hrLoadingBody`
  - App bar: `hrTitle`
  - Retry → controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + per-section body
- In-desk URL: `syncWorkspaceLocation` via `_updateUrlForSection` → `?section=<routeQueryValue>` + optional `?queue=<HrQueue.value>`
- Deep-link (`HrWorkspaceQuery.fromUri`): `id|staff|staffId|staff_id|staff_profile_id`, `queue`, `search|q`, `section|tab`
  - Queue wins over section when both present
  - Staff focus → force `staffDirectory` + `openHrStaffDetailById`
  - One-shot focus opens staff detail; queue applies then rewrites URL

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (`id: section.name`)
- Tabs omitted when `canViewHrSection` / `hrSectionRequirement` fails — not disabled
- Counts from `_sectionCount` (overview summary / staff page / positions total); Access hard-coded **0**
- Count tones (`AppTabCountTone`): `info` for staff, positions, roster, payroll, access; `warning` for leave / swap; `danger` for unassigned
- Icons per section (leading): people / work / calendar / event_busy / swap / pending / payments / manage_accounts

## Table toolbar (shared pattern)

Intended work-queue order: **Filters → Settings → Export → Delete selected → context**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | section-specific (`hrSearchHint`, positions/payroll variants) | mic via `AppSearchBar` default where used |
| Clear | `hrClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Access uses `hrFiltersLabel`; ManageUsers uses `commonFilterActionLabel` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | default `enableExport: true` | **not** gated by ∩ `evidence:export` on desk tables |
| Print (table) | — | `enablePrint` default false — no list Print |
| Context | section primary | Request leave / Schedule templates / Generate payroll / Create position / Create user / Access creates |

Column visibility storage: work queues `hr_work_queue_${queue.name}_v2` / widths `hr_work_queue_cw_${queue.name}_v2`; payroll `…_payrollDrafts_v4`. Positions: `hr.positions.table.v2` / `hr.positions.table.widths.v2`. Staff directory: `access_admin_manage_users_v4`. Access tables: no storage keys.

## Shared strip / row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Staff detail | HR-owned | `showHrStaffDetailDialog` |
| Staff print preview | HR-owned | `showHrStaffPrintPreview` → `PrintDocumentTemplates.registry` |
| Work-queue browse / item actions | HR-owned | `showHrWorkQueueDialog` / `_WorkItemActions` |
| Request leave | HR-owned | |
| Create/edit roster template | HR-owned | `hr_roster_dialogs.dart` |
| Roster / payroll detail | HR-owned | |
| ManageUsers CRUD (staff directory host) | **reused** Access Admin | `ManageUsersPanel` |
| Access create/edit role/permission/user | HR-owned wrappers | `hr_access_dialogs.dart` |
| Success snackbar | HR | `hrSavedMessage` via `showHrMutationSnackBar` |

## Feedback patterns (cross-tab)

- Success snackbars: `hrSavedMessage` (+ Access Admin messages on ManageUsers)
- Failures: `showAppFailureSnackBar` / form banners / table `error`
- Empty: section-specific `AppStateView` / empty titles (`hrNoQueueItems*`, `hrNoPositions*`, Access tenant-required)
- Hard failure with no prior data: error surfaces + retry where controllers expose them
