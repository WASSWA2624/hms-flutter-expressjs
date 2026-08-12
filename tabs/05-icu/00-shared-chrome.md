# ICU — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.icu` under app `ShellRoute` (`/icu`, name `icu`)
- Live gate: `RouteAccessCatalog.icuEntry` = ∩ `icu:read` + module `icu-critical-care` (preferred by `AppRouteData.accessRequirement`)
- AppRoutes fields aligned to the same ∩ `icu:read` + module; roles `icuWorkspaceRoles`
- Workspace tab read: `icuWorkspaceReadRequirement` = ∪ `clinical:read` \| `emergency:read` + `icu-critical-care`
- Write: `icuWorkspaceWriteRequirement` = ∪ `clinical:write` \| `emergency:write` + module
- Export / Print: `icuWorkspaceExportRequirement` / `canExportIcuWorkspace` / `canPrintIcuWorkspace` = ∩ `evidence:export`
- Billing panel/nav: `icuBillingReadRequirement` / `icuBillingPanelReadRequirement` = ∩ `billing:read` + `billing-payments`
- Bed manage: `icuBedBoardManageRequirement` (admin roles/perms + `inpatient-bed-management`)
- Navigation chrome: `icuNavigationRequirement` = empty `AccessRequirement()`
- Shell badge: `icuCriticalCount` from workspace controller
- Tabs omitted when unauthorized (`icuAllowedSections`) — not disabled; fallback prefers `active`

## Page chrome

- `AsyncStateScaffold<IcuWorkspaceState>` over `icuWorkspaceControllerProvider`
  - Loading: `icuLoadingBoardTitle` / `icuLoadingBoardBody`
  - Retry → `IcuWorkspaceController.refresh`
  - `maxWidth: PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + section body
  - Patient tabs → `IcuBoardPanel` (`AppListTable<IcuPatientSummary>`)
  - Beds → `IcuBedBoardPanel` (`AppListTable<IcuBed>`)
  - Follow-ups → **reused** `FollowUpWorklistPanel` (`encounterType: 'ICU'`, prefix `icu_follow_ups`) with Filters / Export / Print
- In-desk URL: `syncWorkspaceLocation` preserves `section` / `search` / `id` / `panel` (default `active` omits `section`)
- Deep-link query (`IcuBoardQuery`): `id`/`admission`/`admissionId`/`admission_id`, `search`/`q`, `panel`, `section`
  - Focus + `panel` → `openIcuFocusedAction` when write panel allowed; else `openIcuDetailDialog`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized — not disabled
- Counts: sibling model = dedicated unfiltered `IcuScopeCounts` (server `totalItemCount` per scope); active patient tab uses filtered/search total when narrowed; beds uses `visibleBeds` (ward/status/search) while Beds is selected; follow-ups uses `followUpTabCountProvider` + `onNarrowedCountChanged`
- Count tones: `danger` critical; `warning` active / transfers / discharge / follow-ups; `info` ended / all / beds
- Icons: bed / priority / compare_arrows / fact_check / output / inventory_2 / bed / phone_callback
- Strip primary (beds only): Manage beds (`ipdBedBoardManageBedsAction`) → `AppRoutes.roomsBeds` when `canManageIcuBedBoard`

## Table toolbar (shared patient-board / bed / follow-ups pattern)

Order on search bar: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `icuSearchHint` | submit/clear → `applySearch` |
| Filters | `commonFiltersActionLabel` / title `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel`; date filter on admitted-at |
| Settings | `commonTableSettingsActionLabel` → title `commonTableSettingsTitle` | |
| Export | `commonTableExportActionLabel` | gated by `canExportIcuWorkspace` |
| Print (table) | `commonPrintActionLabel` | gated by `canPrintIcuWorkspace`; preview-first via `printIcuWorkspaceList` / `PrintDocumentTemplates.registry` |

Column visibility storage: per-section `'icu_${section.name}'` / widths `'icu_cw_${section.name}'`.  
Follow-ups: `'icu_follow_ups_cols'` / `'icu_follow_ups_cw'`.  
Bed board: `'icu_bed_board'` / `'icu_bed_board_cw'`.

## Shared row hubs (owner notes)

| Surface | Owner | File / entry |
| --- | --- | --- |
| Stay detail (`openIcuDetailDialog` / `IcuStayDetailPanel`) | ICU-owned | `icu_detail_panel.dart` |
| Observation / vitals / alert / round / start stay / transfer / manage transfer / readiness / assign bed | ICU-owned | `icu_action_dialogs.dart` |
| `AppTransferRequestDialog` | **reused** shared | ICU-wired |
| Assign bed (`ClinicalAdmissionActionDialog`) | **reused** clinical | |
| Lab / radiology / prescription order dialogs | **reused** clinical | |
| `ClinicalRequestBillingPanel` | **reused** clinical | gated billing read |
| Print (stay detail) | **reused** `PrintDocumentTemplates.clinicalSummary` + ICU HTML; trigger label `commonPrintActionLabel` (`Print`) | from stay detail |
| List Print | **reused** `icu_workspace_print_helpers.dart` | table toolbar |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` | ICU host RW overrides |
| Open IPD / billing / rooms-beds | cross-module routes | |

## `IcuDetailPanel` deep links (`?id=&panel=`)

| `panel` | Opens | Gate |
| --- | --- | --- |
| `vitals` | `openIcuVitalsDialog` | `icuWorkspaceWriteRequirement` |
| `alerts` | `openIcuAlertDialog` | write |
| `observations` | `openIcuObservationDialog` | write |
| `orders` | `openIcuLabOrderDialog` (lab) | write |
| `transfer` | `openIcuTransferDialog` | write |
| `discharge` | `openIcuReadinessDialog` | write |

Unauthorized focused panel → fallback read-only stay detail.

## Feedback patterns (cross-tab)

- Success snackbars: `icuChangesSavedMessage`
- Failures: `showIcuFailureIfNeeded` / `showAppFailureSnackBar`; dialogs `AppFormInformationBanner.failure`
- Empty board: `icuNoPatientsTitle` / `icuNoPatientsBody`
- Detail empty/loading: `icuDetailEmpty*` / `icuDetailLoading*`
- Critical rows: `errorContainer` tint when `hasCriticalAlert`
