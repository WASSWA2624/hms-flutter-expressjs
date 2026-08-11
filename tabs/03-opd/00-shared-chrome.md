# OPD — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.opd` under app `ShellRoute`
- Catalog / shell entry: `RouteAccessCatalog.opdEntry` — ∩ `opd:read` + `scheduling-queue`
- Board chrome read: `opdWorkspaceReadRequirement` — ∪ `patient:read` \| `clinical:read` + module
- Prompt route ∪ also documents billing/operations/emergency read — catalog keeps unique `opd:read`
- Page wraps `AppAccessGate` → forbidden `AppStateScaffold` when board read denied
- If no board tabs allowed: body returns forbidden `AppStateView` (not `SizedBox.shrink()`)

## Page chrome

- `AsyncStateScaffold<OpdWorkspaceState>` over `opdWorkspaceControllerProvider`
  - Loading: `opdLoadingTitle` / `opdLoadingBody`
  - Retry: controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + section body (`AppListTable<_OpdTableItem>` or Follow-ups panel)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>` (omitted for All)
- Deep-link (`OpdWorkspaceQuery`): `section`/`tab`, `id`/`flowId`/`encounter`, `panel`/`stage`/`filter`, `search`/`q`/`patient`
  - `flowId` + `panel` → stage next-action when `opdFocusedPanelRequirement` allows; else Flow Actions when detail allowed
  - `panel` alone can seed worklist filters via `_opdFilterForPanel`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`
- Tabs omitted when unauthorized (`opdBoardTabRequirement`) — not disabled
- Counts (sibling model — dedicated unfiltered scope totals):
  - All → `summaryCounts.allOpdPatients` (fallback combined `_tableItems` length)
  - Arrivals → `appointments.totalItemCount` (fallback `arrivalCount`)
  - Queue → `queueEntries.totalItemCount` (fallback `queueCount`)
  - Triage → `triageQueue.totalItemCount` (fallback `triageQueueCount`)
  - Active → `summaryCounts.activeOpd` (fallback `activeFlowCount`)
  - Follow-ups → `followUpTabCountProvider(OPD)`
  - **Active tab** with search or advanced filters: filtered membership length for that tab only
- Count tones: `warning` for Arrivals, Queue, Triage, Active; `info` for All and Follow-ups
- Icons: dashboard / event / queue / monitor_heart / medical_services / event_repeat
- No strip primary/secondary actions (Start OPD lives on search bar)

## Table toolbar (board tabs; not Follow-ups)

Order on search bar: **Filters → Settings → Export → Print → Start OPD**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `opdSearchHint` / `opdSearchLabel` | field-scoped via `searchFields` |
| Clear | `opdClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettings*` | storage `opd_${section.name}`; Close `commonCloseActionLabel` |
| Export | `commonTableExportActionLabel` | date via item `time`; gated by `opdWorkspaceExportRequirement` (∩ `evidence:export`); omitted when denied |
| Print (table) | `commonPrintActionLabel` → `Print` | `enablePrint` + `canPrint`; opens `printOpdWorkspaceList` → `PrintDocumentTemplates.registry` preview-first |
| Start OPD | `opdStartWalkInAction` / tooltip `opdStartEncounterTooltip` | omitted on Follow-ups; omitted without `opdStartEncounterRequirementForSection` |

Date filter: **enabled** — label `opdArrivalDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`.  
Default visible columns prefer **5** data columns.

## Shared row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Flow Actions | **reused** shared | `showFlowActionsDialog` (`printActionLabel: commonPrintActionLabel`) |
| Appointment Actions | **reused** | `showOpdAppointmentActionsDialog` (`omitPrimaryAction: true` from table) |
| Queue Actions | **reused** | `showQueueActionsDialog` (`OpdQueueAtomPermissions.write`) |
| Start / walk-in encounter | **reused** | `openOpdWorkspaceEncounterFlow` / encounter dialog |
| Board next-action runners | **reused** | `runOpdBoardNextAction` / `opd_board_next_action.dart` |
| Print OPD summary | **reused** | `showPrintOpdSummaryDialog` → clinical summary template (from Flow Actions; trigger `Print`) |
| Follow-up detail | **reused** Reception dialog | `showReceptionFollowUpDetailDialog` via `FollowUpWorklistPanel` |

## Feedback patterns (cross-tab)

- Success: `opdSavedMessage` snackbar after hub / next-action mutations
- Empty board: `opdNoFlowsTitle` / `opdNoFlowsBody`
- Follow-ups empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Loading / retry: scaffold
- Forbidden: `routeForbiddenTitle` / `routeForbiddenBody` when board read denied or no tabs
