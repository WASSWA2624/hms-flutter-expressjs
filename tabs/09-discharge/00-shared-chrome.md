# Discharge — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.discharge` under app `ShellRoute` (`/discharge`)
- Catalog entry: `RouteAccessCatalog.dischargeEntry` — ∩ `discharge:read` + module `inpatient-bed-management`
- Workspace read: `dischargeWorkspaceReadRequirement` — ∪ `clinical:read` | `last_office:read` + module
- Pending clearance tab read: `dischargePendingClearanceReadRequirement` — ∪ `clinical:read` | `pharmacy:read` | `billing:read` | `operations:read` | `last_office:read` + module
- Write: `dischargeClinicalWriteRequirement` — clinical write roles/source + module
- AppRoutes metadata (any-of clinical/pharmacy/billing/operations) **differs** from catalog ∩ `discharge:read`
- If no desk tabs allowed: `SizedBox.shrink()` (not forbidden `AppFailureStateView`)

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

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`; tab `id` = `section.name`
- Tabs omitted when unauthorized (`dischargeSectionTabRequirement` / `dischargeAllowedSections`) — not disabled
- Counts from loaded queue / client filters (`plannedCount`, `summaryPendingCount`, `completedCount`, full `queue.items.length`); Follow-ups via `followUpTabCountProvider(IPD)`
- Count tones: `warning` for Planned and Pending clearance; `info` for All, Completed, Follow-ups
- Icons: inventory_2 / event_available / pending_actions / check_circle / phone_callback

## Table toolbar (queue tabs)

Order on search bar: **Filters → Settings → Export** (default Export; **no** Print; **no** strip Plan/Clearance)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `dischargeQueueSearchLabel` / hint `dischargeQueueSearchHint` | |
| Filters | `dischargeFiltersLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Reset `opdClearFiltersAction` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | default AppListTable Export | **no** ∩ `evidence:export` gate |
| Print (table) | — | **not mounted** |
| Plan / Clearance strip | — | **not mounted**; row next-action only |

Column visibility: `discharge_${section.name}` / widths `discharge_cw_${section.name}`.  
Follow-ups: `discharge_follow_ups_cols` / `discharge_follow_ups_cw`.  
Default visible columns: **5** including `status` + `next_action`.  
Date filter: **off** on all queue tabs.

## Shared row hubs (owner notes)

| Surface | Owner | Entry |
| --- | --- | --- |
| Discharge detail | Discharge-owned `AppDialog` | row select / deep-link |
| Planning / clearance | Discharge-owned `DischargePlanningDialog` via `showDischargePlanningDialog` | next-action Plan/Clearance; detail Continue |
| `DischargeClearanceDialog` | Discharge-owned wrapper | **not** called from workspace page path |
| Pharmacy request | Discharge-owned `_PharmacyDialog` | detail `dischargeRequestPharmacyAction` |
| Open Billing | navigate `AppRoutes.billing?patient_id=…` | no local cashier dialog |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` | Follow-ups panel |
| Print summary | `PrintDocumentTemplates.clinicalSummary` | detail footer / completed next-action |

## Detail dialog chrome (queue sections)

- Title: `dischargeDetailTitle`
- Footer print: `dischargePrintSummaryAction` gated by `dischargeDetailPrintRequirement(section)`; enabled when `detail.hasSummary`
- Patient: `AppPatientDetails` + admission/encounter/location/target fields; copy admission/encounter IDs
- Actions (gated): Continue/plan (write), Open billing (billing read), Request medicines (write)
- Sections: cross-module links, pending orders, clearance checklist (`DischargeClearanceTile`), summary, medicines, billing, timeline
- Clearance tiles **omitted when unauthorized** per code (`doctor`/`nursing`/`documents` workspace read; `pharmacy` pharmacy read; `billing`/`insurance` billing read; `bedRelease`/`housekeeping` operations read)

## Feedback patterns (cross-tab)

- Success: `dischargeSavedMessage`
- Failures: `showAppFailureSnackBar`
- Empty queue: `dischargeEmptyQueueTitle` / `dischargeEmptyQueueBody`
- Follow-ups empty/error: Reception follow-up + unexpected error keys + Retry
