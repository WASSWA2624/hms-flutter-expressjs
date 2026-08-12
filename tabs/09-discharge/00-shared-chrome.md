# Discharge — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.discharge` under app `ShellRoute` (`/discharge`)
- Catalog entry: `RouteAccessCatalog.dischargeEntry` — ∩ `discharge:read` + module `inpatient-bed-management`
- Workspace read: `dischargeWorkspaceReadRequirement` — ∪ `clinical:read` | `last_office:read` + module
- Pending clearance tab read: `dischargePendingClearanceReadRequirement` — ∪ `clinical:read` | `pharmacy:read` | `billing:read` | `operations:read` | `last_office:read` + module
- Write: `dischargeClinicalWriteRequirement` — clinical write roles/source + module
- AppRoutes metadata aligned with catalog ∩ `discharge:read` + module
- If no desk tabs allowed: `AppFailureStateView(forbidden)` (Reception pattern)

## Page chrome

- `AsyncStateScaffold<DischargeWorkspaceState>` over `dischargeWorkspaceControllerProvider`
  - Loading: `dischargeLoadingTitle` / `dischargeLoadingBody`
  - Retry: `ref.invalidate(dischargeWorkspaceControllerProvider)`
  - `maxWidth: PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + either `AppListTable<IpdAdmissionSummary>` or **reused** `FollowUpWorklistPanel`
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-link (`DischargeWorklistQuery.fromUri`):
  - `section`
  - focus: `id` | `admission` | `admissionId` | `admission_id` → select + open detail
  - search: `search` | `q` (also seeded from admission id when focus keys used)
- Helpers: `discharge_scope_navigation.dart` (`dischargeSectionToQueryValue` / `dischargeSectionFromQuery` / tab counts)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`; tab `id` = `section.name`
- Tabs omitted when unauthorized (`dischargeSectionTabRequirement` / `dischargeAllowedSections`) — not disabled
- Sibling-count model: dedicated unfiltered `DischargeSectionCounts` from catalog fetch (`pageSize: 100`); active tab with search/advanced filters uses filtered section membership of `queue.items`
- Follow-ups: `followUpTabCountProvider(IPD)` / narrowed callback from panel
- Count tones: `warning` for Planned and Pending clearance; `info` for All, Completed, Follow-ups
- Icons: inventory_2 / event_available / pending_actions / check_circle / phone_callback
- Follow-ups label: `dischargeSectionFollowUps`

## Table toolbar (queue tabs)

Order on search bar: **Filters → Settings → Export → Print** (context actions omitted; row next-action only — justified product exception vs strip Plan/Clearance)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `dischargeQueueSearchLabel` / hint `dischargeQueueSearchHint` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | Reset/Apply/Close shared labels |
| Export | gated ∩ `evidence:export` (`canExportDischargeWorkspace`) | omitted when unauthorized |
| Print (table) | `commonPrintActionLabel` → preview-first `printDischargeWorkspaceList` | omitted when unauthorized; same export gate |
| Plan / Clearance strip | — | **not mounted**; row next-action only (justified) |

Column visibility: `discharge_${section.name}` / widths `discharge_cw_${section.name}`.  
Follow-ups: `discharge_follow_ups_cols` / `discharge_follow_ups_cw`; Filters + date on; Export/Print gated ∩ `evidence:export` (`printDischargeWorkspaceList`).  
Default visible columns: **5** including `status` + `next_action`.  
Date filter: **on** (status + date range share `DischargeWorklistQuery`).

## Shared row hubs (owner notes)

| Surface | Owner | Entry |
| --- | --- | --- |
| Discharge detail | Discharge-owned `AppDialog` | row select / deep-link |
| Planning / clearance | Discharge-owned `DischargePlanningDialog` via `showDischargePlanningDialog` | next-action Plan/Clearance; detail Continue; section-scoped create/update gates |
| `DischargeClearanceDialog` | Thin wrapper → planning dialog | available wrapper; workspace path uses `showDischargePlanningDialog` (justified) |
| Pharmacy request | Discharge-owned `_PharmacyDialog` | detail `dischargeRequestPharmacyAction` |
| Open Billing | navigate `AppRoutes.billing?patient_id=…` | no local cashier dialog (justified) |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` | Follow-ups panel |
| Print summary | `PrintDocumentTemplates.clinicalSummary` | detail footer / completed next-action; trigger label `Print` |

## Detail dialog chrome (queue sections)

- Title: `dischargeDetailTitle`
- Footer print: `commonPrintActionLabel` gated by `dischargeDetailPrintRequirement(section)`; enabled when `detail.hasSummary`
- Patient: `AppPatientDetails` + admission/encounter/location/target fields; copy admission/encounter IDs
- Actions (gated): Continue/plan (write), Open billing (billing read), Request medicines (write)
- Sections: cross-module links, pending orders, clearance checklist (`DischargeClearanceTile`), summary, medicines, billing, timeline
- Clearance tiles **omitted when unauthorized** per code (`doctor`/`nursing`/`documents` workspace read; `pharmacy` pharmacy read; `billing`/`insurance` billing read; `bedRelease`/`housekeeping` operations read)

## Feedback patterns (cross-tab)

- Success: `dischargeSavedMessage`
- Failures: `showAppFailureSnackBar`
- Empty queue: `dischargeEmptyQueueTitle` / `dischargeEmptyQueueBody`
- Follow-ups empty/error: Reception follow-up + unexpected error keys + Retry
- Unauthorized empty desk: forbidden `AppFailureStateView`
