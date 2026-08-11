# ICU — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.icu` under app `ShellRoute` (`/icu`, name `icu`)
- AppRoutes gate: ∪ `clinical:read` \| `emergency:read` \| `operations:read` + roles `icuWorkspaceRoles` + module `icu-critical-care`
- Catalog entry: `RouteAccessCatalog.icu` / `icuEntry` = ∩ `icu:read` + module `icu-critical-care`
- Workspace tab read: `icuWorkspaceReadRequirement` = ∪ `clinical:read` \| `emergency:read` + `icu-critical-care`
- Write: `icuWorkspaceWriteRequirement` = ∪ `clinical:write` \| `emergency:write` + module
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
  - Beds → `IcuBedBoardPanel`
  - Follow-ups → **reused** `FollowUpWorklistPanel` (`encounterType: 'ICU'`, prefix `icu_follow_ups`)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>` (default `active` omits `section`)
- Deep-link query (`IcuBoardQuery`): `id`/`admission`/`admissionId`/`admission_id`, `search`/`q`, `panel`, `section`
  - Focus + `panel` → `openIcuFocusedAction` when write panel allowed; else `openIcuDetailDialog`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized — not disabled
- Counts: page-derived scope fields on patient tabs; beds = `bedBoard.beds.length`; follow-ups = `followUpTabCountProvider`
- Count tones: `danger` critical; `warning` active / transfers / discharge; `info` ended / all / beds / follow-ups
- Icons: bed / priority / compare_arrows / fact_check / output / inventory_2 / bed / phone_callback
- Strip primary (beds only): Manage beds (`ipdBedBoardManageBedsAction`) → `AppRoutes.roomsBeds` when `canManageIcuBedBoard`

## Table toolbar (shared patient-board pattern)

Order on search bar: **Filters → Settings** (no Export / Print on list)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `icuSearchHint` | submit/clear → `applySearch` |
| Filters | `icuAdvancedFiltersLabel` / title `icuAdvancedFiltersTitle` | Apply `icuApplyFiltersLabel`; Reset `icuResetFiltersLabel` |
| Settings | `commonTableSettingsActionLabel` → title `icuTableSettingsTitle` | |
| Export | — | **not configured** |
| Print (table) | — | **not configured**; print lives in stay detail only |

Column visibility storage: shared `'icu_board'` / widths `'icu_cw_board'` across patient sections.  
Follow-ups: `'icu_follow_ups_cols'` / `'icu_follow_ups_cw'`.

## Shared row hubs (owner notes)

| Surface | Owner | File / entry |
| --- | --- | --- |
| Stay detail (`openIcuDetailDialog` / `IcuStayDetailPanel`) | ICU-owned | `icu_detail_panel.dart` |
| Observation / vitals / alert / round / start stay / transfer / manage transfer / readiness / assign bed | ICU-owned | `icu_action_dialogs.dart` |
| `AppTransferRequestDialog` | **reused** shared | ICU-wired |
| Assign bed (`ClinicalAdmissionActionDialog`) | **reused** clinical | |
| Lab / radiology / prescription order dialogs | **reused** clinical | |
| `ClinicalRequestBillingPanel` | **reused** clinical | gated billing read |
| Print summary | **reused** `PrintDocumentTemplates.clinicalSummary` + ICU HTML | from stay detail |
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
