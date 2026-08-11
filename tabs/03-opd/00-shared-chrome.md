# OPD — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.opd` under app `ShellRoute`
- Catalog / shell entry: `RouteAccessCatalog.opdEntry` — ∩ `opd:read` + `scheduling-queue`
- Board chrome read: `opdWorkspaceReadRequirement` — ∪ `patient:read` \| `clinical:read` + module
- Prompt route ∪ also documents billing/operations/emergency read — catalog keeps unique `opd:read`
- If no board tabs allowed: body returns `SizedBox.shrink()` (no forbidden placeholder on page)

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
- Counts:
  - All → client `allItems.length`
  - Arrivals / Queue / Triage / Active → `state.arrivalCount` / `queueCount` / `triageQueueCount` / `summaryCounts.activeOpd` (fallback `activeFlowCount`)
  - Follow-ups → `followUpTabCountProvider(OPD)`
- Count tones: `warning` for Arrivals, Queue, Triage, Active; `info` for All and Follow-ups
- Icons: dashboard / event / queue / monitor_heart / medical_services / event_repeat
- No strip primary/secondary actions (Start OPD lives on search bar)

## Table toolbar (board tabs; not Follow-ups)

Order on search bar: **Filters → Settings → Export → Start OPD** (no table Print)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `opdSearchHint` / `opdSearchLabel` | field-scoped via `searchFields` |
| Clear | `opdClearFiltersAction` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction` |
| Settings | `commonTableSettings*` | storage `opd_${section.name}` |
| Export | `commonTableExportActionLabel` | date via item `time` |
| Print (table) | **absent** | |
| Start OPD | `opdStartWalkInAction` / tooltip `opdStartEncounterTooltip` | omitted on Follow-ups; omitted without `opdStartEncounterRequirementForSection` |

Date filter: **enabled** — label `opdArrivalDateFilterLabel`; From/To `opdDateFromLabel` / `opdDateToLabel`.

## Shared row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Flow Actions | **reused** shared | `showFlowActionsDialog` |
| Appointment Actions | **reused** | `showOpdAppointmentActionsDialog` (`omitPrimaryAction: true` from table) |
| Queue Actions | **reused** | `showQueueActionsDialog` (`OpdQueueAtomPermissions.write`) |
| Start / walk-in encounter | **reused** | `openOpdWorkspaceEncounterFlow` / encounter dialog |
| Board next-action runners | **reused** | `runOpdBoardNextAction` / `opd_board_next_action.dart` |
| Print OPD summary | **reused** | `showPrintOpdSummaryDialog` → clinical summary template (from Flow Actions) |
| Follow-up detail | **reused** Reception dialog | `showReceptionFollowUpDetailDialog` via `FollowUpWorklistPanel` |

## Feedback patterns (cross-tab)

- Success: `opdSavedMessage` snackbar after hub / next-action mutations
- Empty board: `opdNoFlowsTitle` / `opdNoFlowsBody`
- Follow-ups empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Loading / retry: scaffold
