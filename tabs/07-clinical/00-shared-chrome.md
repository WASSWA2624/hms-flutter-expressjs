# Clinical — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.clinical` under app `ShellRoute` (`/clinical`)
- AppRoutes declaration: ∩ `clinical:read` + roles + module `encounters-vitals` (aligned with catalog)
- Catalog entry: `RouteAccessCatalog.clinicalEntry` = ∩ `clinical:read` + `encounters-vitals`
- Workspace read: `clinicalWorkspaceReadRequirement` = ∩ `clinical:read` + module
- Workspace write: `clinicalWorkspaceWriteRequirement` = ∪ `clinical:write` \| `platform:admin` + module
- Export / list Print: `clinicalWorkspaceExportRequirement` = ∩ `evidence:export`
- Lab / radiology / pharmacy / admission writes: dedicated ∪ requirements (+ domain write \| platform:admin)
- Discharge financial read: `billingReadRequirement` (∩ `billing:read` + `billing-payments`)
- Follow-ups: `clinicalFollowUpsRequirement` / write ∪ (= same read/write clinical gates)
- Shell badge: `clinicalWorkloadCount` from facet `workload` (urgent ∪ results-ready outpatient non-terminal)
- Tabs omitted when unauthorized — not disabled; fallback prefers `all`
- Legacy `waiting-review` / `in-consultation` deep-links remap to Pending (`all`); orphan atom maps removed

## Page chrome

- `AsyncStateScaffold` — loading `clinicalLoadingTitle` / `clinicalLoadingBody`; retry → `refresh()`; `PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + worklist / follow-ups panel
- **No** page title widgets; **no** strip Refresh / OPD / Lab / Discharge primary actions
- URL: `syncWorkspaceLocation` writes `section` when non-empty (Pending omits)
- Deep-link (`ClinicalWorkspaceQuery`): `section`/`tab`, `encounterId`/`id`, `panel`, `search`/`q`
  - Applied: section, search, open encounter dialog
  - `panel` opens encounter detail and anchors panel key (`notes` / `vitals` / `lab` / `radiology` / `pharmacy` / `diagnoses`)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard)
- Worklist tabs gated by `clinicalWorkspaceReadRequirement`; Follow-ups by `clinicalFollowUpsRequirement`
- Counts: authoritative facet totals under shared filter/search context (`pendingCount`, `assignedToMeCount`, `urgentCount`, `resultsReadyCount`, `completedCount`); Follow-ups uses `followUpTabCountProvider` with narrowed active badge via `onNarrowedCountChanged`
- Candidate loads use `AppPageRequest.maxPageSize` for facet authority
- Tones: `danger` urgent; `warning` assignedToMe; `info` pending / resultsReady / completed / followUps
- Icons: inventory_2 / person_outline / priority_high / science / task_alt / phone_callback

## Table toolbar (shared worklist pattern)

Order on search bar: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `clinicalSearchLabel` / `clinicalSearchHint`; clear `opdClearFiltersAction` | 300ms debounce |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Close `commonCloseActionLabel` | Apply `opdApplyFiltersAction`; reset `opdClearFiltersAction` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | `Export` | gated by `canExportClinicalWorkspace` (∩ `evidence:export`) |
| Print (table) | `commonPrintActionLabel` (`Print`) | preview-first via `printClinicalWorkspaceList`; same gate |

Column storage: `'clinical_${section.name}'` / `'clinical_cw_${section.name}'`.  
Always-visible: `status`, `nextAction`. Default visible columns: **5**.  
Date filter: **enabled** on `clinicalLastUpdatedLabel`.

Follow-ups host: Filters → Settings → Export → Print (clinical RW + export gate); Reception detail dialogs with clinical requirements override.

## Shared dialogs (owner notes)

| Surface | Owner |
| --- | --- |
| `_ClinicalEncounterDialog` | Clinical-owned (page-private) |
| Notes / vitals / diagnosis / lab / radiology / Rx / procedure / referral / follow-up / admission / disposition | **reused** shared clinical_actions |
| `showClinicalPrintSummaryDialog` | **reused** clinical; trigger label `Print`; gate ∩ `evidence:export` |
| `AppConfirmActionDialog` | **reused** shared |
| `WorkflowActionButton` | **reused** workflow |
| `showDischargePlanningDialog` | **reused** Discharge (admission context) |
| Follow-up detail | **reused** Reception (`showReceptionFollowUpDetailDialog`) |

## Feedback patterns (cross-tab)

- Realtime notices: `clinicalLabResultCriticalNotice` / Ready / Updated
- Success: `clinicalSavedMessage`
- Failures: `showAppFailureSnackBar`; detail `AppFailureStateView` + retry
- Empty worklist: `clinicalNoWorklistTitle` / `Body`
- Empty detail: `clinicalNoSelectionTitle` / `Body`
