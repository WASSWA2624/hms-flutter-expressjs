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
  - `scrollable: false` (bounded desk height for main-tab tables)
- Body: `ResponsivePage(scrollable: false)` + `AppTabStrip` + `Expanded` section body (`AppListTable<_OpdTableItem>` or Follow-ups panel)
- Main-tab tables: no `shrinkWrap` / page-nested vertical scroll; horizontal overflow scrolls; footer pinned; empty-row padding via `AppListTable` defaults (`tables.mdc`)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>` (omitted for All)
- Deep-link (`OpdWorkspaceQuery`): `section`/`tab`, `id`/`flowId`/`encounter`, `panel`/`stage`/`filter`, `search`/`q`/`patient`
  - `flowId` + `panel` → stage next-action when `opdFocusedPanelRequirement` allows; else Flow Actions when detail allowed
  - `panel` alone can seed worklist filters via `_opdFilterForPanel` (multi-status sets preserved unless Advanced filters picks a single status)

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`
- Tabs omitted when unauthorized (`opdBoardTabRequirement`) — not disabled
- Counts (sibling model — dedicated unfiltered scope totals):
  - All → `summaryCounts.allOpdPatients` (fallback combined `_tableItems` length)
  - Arrivals → board ARRIVAL membership (same rows as table; not raw appointments `totalItemCount`)
  - Queue → board QUEUE membership (same rows as table; not raw queue `totalItemCount`)
  - Triage → board TRIAGE membership (same rows as table; not raw triage `totalItemCount`)
  - Active → `summaryCounts.activeOpd` (fallback `activeFlowCount`)
  - Follow-ups → `followUpTabCountProvider(OPD)`
  - **Active tab** with search or advanced filters: filtered membership length for that tab only
- Count tones: `warning` for Arrivals, Queue, Triage, Active; `info` for All and Follow-ups
- Icons: dashboard / event / queue / monitor_heart / medical_services / event_repeat
- No strip primary/secondary actions (Start OPD lives on search bar)

## Table toolbar

Board tabs (`AppListTable`) and Follow-ups (`FollowUpWorklistPanel`):

Order on search bar: **Filters → Settings → Export → Print → Start OPD**  
(Start OPD omitted on Follow-ups by design; omitted on board tabs without encounter gate)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | board `opdSearchHint` / Follow-ups `receptionFollowUpsSearchHint` | field-scoped on board via `searchFields` |
| Clear | board `opdClearFiltersAction` / Follow-ups `receptionClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply/Clear/Close common labels; Follow-ups date + status group |
| Settings | `commonTableSettings*` | Apply `receptionApplyColumnsAction` / Reset `receptionResetColumnsAction` / Close `commonCloseActionLabel`; board storage `opd_${section.name}`; Follow-ups `opd_follow_ups_*` |
| Export | `commonTableExportActionLabel` | gated by `opdWorkspaceExportRequirement` (∩ `evidence:export`); **full filtered membership** (not page slice); omitted when denied |
| Print (table) | `commonPrintActionLabel` → `Print` | board `printOpdWorkspaceList` over filtered membership; Follow-ups same helper; preview-first; section empty titles for empty docs |
| Start OPD | `opdStartWalkInAction` / tooltip `opdStartEncounterTooltip` | board only; omitted without `opdStartEncounterRequirementForSection` |

Date filter: **enabled** — board/Follow-ups label `opdArrivalDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`.  
Default visible columns prefer **5** data columns (when Next action is unauthorized, board promotes from column choices so defaults stay at 5). Follow-ups active badge uses narrowed membership via panel `onNarrowedCountChanged`.  
Patient name cells are **atomic** (name only); identifier stays on mobile caption / search, not as a subtitle in the name cell.

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
- Empty board by section: Arrivals `opdNoArrivals*`; Queue `opdNoQueue*`; Triage `opdNoTriage*`; Active `opdNoActive*`; All `opdNoFlows*`
- Follow-ups empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Loading / retry: scaffold
- Forbidden: `routeForbiddenTitle` / `routeForbiddenBody` when board read denied or no tabs
