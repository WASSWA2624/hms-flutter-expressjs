# Theater — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.theater` under app `ShellRoute` (`/theater`)
- Catalog entry: `RouteAccessCatalog.theaterEntry` = `theaterWorkspaceEntryRequirement` — ∩ `theater:read` + module `theatre-anesthesia`
- Board / tab chrome read: `theaterWorkspaceReadRequirement` — ∪ `clinical:read` | `patient:read` + `theatre-anesthesia`
- AppRoutes metadata (broader ∪): `patient:read` | `clinical:read` | `billing:read` | `operations:read` + module + `theaterWorkspaceRoles`
- If no board tabs allowed: `AppFailureStateView(failure: AppFailure.forbidden())` (Reception pattern)

## Page chrome

- `AsyncStateScaffold<TheaterWorkspaceState>` over `theaterWorkspaceControllerProvider`
  - Loading: `theaterLoadingTitle` / `theaterLoadingBody`
  - App bar: `theaterTitle`
  - Retry → controller `refresh()`
  - `keepPreviousDataDuringRefresh`: **true**
- Body: `ResponsivePage` + `AppTabStrip` + either `_TheaterCaseBoard` (`AppListTable<TheaterCase>`) or **reused** `FollowUpWorklistPanel`
- In-desk URL: `syncWorkspaceLocation` with `?section=<queryValue>` (cleared when section is All)
- Deep-link (`TheaterBoardQuery.fromUri`):
  - `section` — tab
  - `search` / `q` — search
  - `id` / `case` / `caseId` / `case_id` — focus case → detail (or panel)
  - `panel` — `checklist` | `anesthesia` | `postop`/`post-op`/`post_op` | `resources` (write ∩ required; else bare detail)
  - `patient_id` / `patientId` / `patient`, `encounter_id` / `encounterId` / `encounter`, `emergency_case_id` / … — schedule seed
  - `action=schedule|schedule_case` + patient/encounter context → open schedule dialog

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`
- Tabs omitted when unauthorized (`theaterBoardTabRequirement` / `theaterAllowedBoardSections`) — not disabled
- Enum order: Scheduled → In theater → Recovery → All cases → Follow-ups
- Counts (sibling-count model — dedicated unfiltered `TheaterScopeCounts` from pageSize-1 scope queries):
  - Scheduled / In theater / Recovery / All: `theaterSectionTabCount` → `state.scopeCounts` unless active tab is narrowed by search/operator filters (then filtered `cases.totalItemCount`)
  - Follow-ups: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'THEATRE'))` with `onNarrowedCountChanged` when Filters/search narrow
- Count tones: `warning` for Scheduled, In theater, Recovery; `info` for All and Follow-ups (`theaterSectionCountTone`)
- Icons: event_available / meeting_room / monitor_heart / inventory_2 / phone_callback

## Table toolbar (case boards)

Order on search bar: **Filters → Settings → Export → Print → Schedule case**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `theaterSearchLabel` / hint `theaterSearchHint` | mic via `AppSearchBar` default |
| Clear | `theaterClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → `theaterAdvancedFiltersTitle` | Apply `theaterApplyFiltersAction`; Reset `theaterClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettingsActionLabel` → `theaterTableSettingsTitle` | Apply/Reset/Close via reception column keys |
| Export | `commonTableExportActionLabel` | gated ∩ `evidence:export` (`canExportTheaterWorkspace`); omitted when denied |
| Print (table) | `commonPrintActionLabel` | preview-first via `printTheaterWorkspaceList` / `PrintDocumentTemplates.registry`; same export gate; omitted when denied |
| Schedule case | `theaterScheduleCaseAction` | omitted without `theaterScheduleCaseRequirement` |

Column visibility storage: `theater_${section.name}` / widths `theater_cw_${section.name}`.  
Follow-ups: `theater_follow_ups_cols` / `theater_follow_ups_cw`.  
Default visible columns: **5** data columns (+ optional `next_action` when write ∩).

## Shared strip actions → dialogs

### Schedule case — Theater-owned

- Entry: `showTheaterScheduleCaseDialog` → `TheaterScheduleCaseForm`
- Titles: `theaterScheduleCaseDialogTitle` / reschedule `theaterRescheduleDialogTitle`
- Nested: **reused** procedure catalog / billing panel when billing holds readable (`billing:read` ∩ `billing-payments`)
- Success: snackbar `theaterSavedMessage` + refresh

## Shared row hubs (owner notes)

| Surface | Owner | File / entry |
| --- | --- | --- |
| Case detail | Theater-owned | `AppDialog` + `_TheaterCaseDetail` / `_TheaterCaseDetailBody` |
| Quick Actions | Theater-owned | `AppQuickActions` (`patientsQuickActionsTitle`) |
| Next-action column | Theater-owned | `_TheaterNextActionButton` → mutation dialogs |
| Follow-up detail | **reused** | `showReceptionFollowUpDetailDialog` |
| Schedule / reschedule | Theater-owned | `showTheaterScheduleCaseDialog` |

## Detail panels (`panel=` deep-link)

Opened when `?id=…&panel=…` and write ∩ (`theaterFocusedPanelRequirement`); skips empty detail shell:

| `panel` | Dialog / form | Submit |
| --- | --- | --- |
| `checklist` | `_ChecklistForm` (`theaterReadinessDialogTitle`) | `toggleChecklistItem` |
| `anesthesia` | `_AnesthesiaForm` (`theaterAnesthesiaDialogTitle`) | `upsertAnesthesiaRecord` |
| `postop` | `_PostOpForm` (`theaterPostOpDialogTitle`) | `upsertPostOpNote` |
| `resources` | `_ResourceForm` (`theaterAssignResourceDialogTitle`) | `assignResource` |

Read-only sections inside case detail (not the mutation dialogs): checklist list, anesthesia/post-op records + observations, resources, timeline, Source / Team / `AppPatientDetails`.

## Feedback patterns (cross-tab)

- Success: `theaterSavedMessage`
- Failures: `showAppFailureSnackBar` / `failureMessage`
- Empty board: `theaterNoCasesTitle` / `theaterNoCasesBody`
- Empty detail: `theaterNoCaseSelectedTitle` / `theaterNoCaseSelectedBody`
- Follow-ups empty/error: Reception follow-up keys + `errorUnexpectedTitle` / `errorUnexpectedMessage` + `commonRetryActionLabel`
