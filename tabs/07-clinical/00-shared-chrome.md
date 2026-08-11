# Clinical — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.clinical` under app `ShellRoute` (`/clinical`)
- AppRoutes gate: ∪ `clinical:read` \| `clinical:write` + roles `clinicalWorkspaceRoles` + module `encounters-vitals`
- Catalog entry: `RouteAccessCatalog.clinicalEntry` = ∩ `clinical:read` + `encounters-vitals`
- Workspace read: `clinicalWorkspaceReadRequirement` = ∩ `clinical:read` + module
- Workspace write: `clinicalWorkspaceWriteRequirement` = ∪ `clinical:write` \| `platform:admin` + module
- Lab / radiology / pharmacy / admission writes: dedicated ∪ requirements (+ domain write \| platform:admin)
- Discharge financial read: `billingReadRequirement` (∩ `billing:read` + `billing-payments`)
- Follow-ups: `clinicalFollowUpsRequirement` / write ∪ (= same read/write clinical gates)
- Shell badge: `clinicalWorkloadCount` (urgent ∪ results-ready outpatient non-terminal)
- Tabs omitted when unauthorized — not disabled; fallback prefers `all`

## Page chrome

- `AsyncStateScaffold` — loading `clinicalLoadingTitle` / `clinicalLoadingBody`; retry → `refresh()`; `PageMaxWidth.dataHeavy`
- Body: `ResponsivePage` + `AppTabStrip` + worklist / follow-ups panel
- **No** page title widgets; **no** strip Refresh / OPD / Lab / Discharge primary actions
- URL: `syncWorkspaceLocation` writes `section` when non-empty (Pending omits)
- Deep-link (`ClinicalWorkspaceQuery`): `section`/`tab`, `encounterId`/`id`, `panel`, `search`/`q`
  - Applied: section, search, select encounter
  - `panel` parsed but **not applied** in `_applyRouteQuery`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard)
- Worklist tabs gated by `clinicalWorkspaceReadRequirement`; Follow-ups by `clinicalFollowUpsRequirement`
- Counts: `pendingCount`, `assignedToMeCount`, `urgentCount`, `resultsReadyCount`, `completedCount`, follow-up provider
- Tones: `danger` urgent; `warning` assignedToMe; `info` pending / resultsReady / completed / followUps
- Icons: inventory_2 / person_outline / priority_high / science / task_alt / phone_callback

## Table toolbar (shared worklist pattern)

Order on search bar: **Filters → Settings** (no Export / Print / context create)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `clinicalSearchLabel` / `clinicalSearchHint`; clear `opdClearFiltersAction` | 300ms debounce |
| Filters | `clinicalFiltersLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; reset `opdClearFiltersAction` |
| Settings | `commonTableSettingsActionLabel` → `commonTableSettingsTitle` | |
| Export | — | **absent** |
| Print (table) | — | **absent**; print from encounter action bar |

Column storage: `'clinical_${section.name}'` / `'clinical_cw_${section.name}'`.  
Always-visible: `status`, `nextAction`.  
Date filter: **enabled** on `clinicalLastUpdatedLabel`.

Follow-ups host: search + Settings only (no Filters / Export / Print / create).

## Shared dialogs (owner notes)

| Surface | Owner |
| --- | --- |
| `_ClinicalEncounterDialog` | Clinical-owned (page-private) |
| Notes / vitals / diagnosis / lab / radiology / Rx / procedure / referral / follow-up / admission / disposition | **reused** shared clinical_actions |
| `showClinicalPrintSummaryDialog` | **reused** clinical |
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
