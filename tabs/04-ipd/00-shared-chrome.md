# IPD — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.ipd` under app `ShellRoute`
- Catalog / route entry: `RouteAccessCatalog.ipdEntry` — ∪ `ipd:read` \| `clinical:read` \| `operations:read` \| `billing:read` + `inpatient-bed-management`
- Board chrome read: `ipdWorkspaceReadRequirement` — ∪ `clinical:read` \| `operations:read` + module (`ipd:read` / billing-alone do **not** unlock tabs)
- If no board tabs allowed: `AppWorkspaceStatePanel.forbidden` (`routeForbiddenTitle` / `routeForbiddenBody`) — not a blank `SizedBox.shrink()`

## Page chrome

- `AsyncStateScaffold<IpdWorkspaceState>` over `ipdWorkspaceControllerProvider`
  - Loading: `ipdLoadingTitle` / `ipdLoadingBody`
  - Retry: controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + board table / bed board / follow-ups panel
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-link (`IpdAdmissionQuery.fromUri`): `section`, `id`/`admission`, `panel`, `action`, `wardId`, `patientId`, `transferStatus`, `search`
  - Focused mutation: `focusAdmissionId` + `panel`/`action` → detail + panel-driven next action when `ipdFocusedMutationRequirement` allows

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem`
- Tabs omitted when unauthorized (`ipdBoardTabRequirement`) — not disabled
- Counts (sibling model — dedicated unfiltered workspace summary totals):
  - Admission queue / Active / Transfers / Discharge → `summaryCounts.*`
  - **Active queue tab** with search or advanced filters: filtered membership via `admissions.totalItemCount`
  - Bed board → **no count** (`null`)
  - Follow-ups → `followUpTabCountProvider(IPD)`; when active and narrowed → `onNarrowedCountChanged`
- Count tones: `warning` for Admission queue, Transfers, Discharge, Follow-ups; `info` for Active patients and Bed board
- Icons: bed / local_hospital / swap_horiz / fact_check / grid_view / phone_callback
- Strip primary (Bed board only): Manage beds → `/rooms-beds` — **omitted when unauthorized** (`ipdBedManageRequirement`)

## Table toolbar (queue tabs + bed board)

Order on search bar: **Filters → Settings → Export → Print → Start admission**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `ipdSearchHint` / `ipdSearchLabel` (bed board: bed-board keys) | field-scoped |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel` |
| Settings | `commonTableSettings*` (Apply/Reset use reception column keys) | storage `ipd_${section.name}` / `ipd_bed_board` |
| Export | `commonTableExportActionLabel` | gated by `ipdWorkspaceExportRequirement` (∩ `evidence:export`); omitted when denied |
| Print (table) | `commonPrintActionLabel` → `Print` | `enablePrint` + `canPrint`; preview-first via `printIpdWorkspaceList` → `PrintDocumentTemplates.registry` |
| Start admission | `ipdStartAdmissionAction` | omitted without operational write for section; absent on Follow-ups |

Date filter: **enabled** on queue tabs — label `ipdAdmittedAtColumnLabel`. Bed board: ward/status filters only (no date).

## Follow-ups host

- `FollowUpWorklistPanel` with `showAdvancedFilterButton: true`, date filter, status group, `canExport` / Print gated like queue tabs.

## Shared row hub — Admission detail

Opened via `_openIpdDetailDialog` / `_openIpdDetailDialogById` → `AppDialog` title `ipdAdmissionDetailTitle` hosting `_IpdDetailPanel`.

| Surface | Owner |
| --- | --- |
| Detail shell / patient context | IPD-owned (`_IpdDetailPanel`) |
| Start admission | IPD-owned `showIpdStartAdmissionDialog` |
| Assign / release bed | **reused** shared ipd_actions / release-bed dialog |
| Transfer request / update | IPD-owned transfer dialogs |
| Nursing note | IPD-owned `showIpdNursingNoteDialog` |
| Discharge plan/manage | **reused** `showDischargePlanningDialog` / discharge feature |
| Clinical orders (lab/rad/Rx/therapy) | IPD wrappers → **reused** clinical |
| Insurance / billing panel | **reused** `InsuranceAuthorizationPanel` (∩ `billing:read`) |
| Open Billing / ICU / Theater / Nursing / Physio | navigate (gates: billing read / navigation / clinical) |
| Bed board panel | IPD-owned `IpdBedBoardPanel` |
| Follow-ups | **reused** `FollowUpWorklistPanel` + Reception follow-up detail |

### Detail panel deep links (`IpdDetailPanel`)

| Panel | Mutation gate (`ipdFocusedMutationRequirement`) |
| --- | --- |
| `beds` | operational write ∪ |
| `transfer` | operational write ∪ |
| `discharge` | clinical write ∩ |
| `nursing` | clinical write ∩ |
| `medication` | null (no focused write requirement) |
| `rounds` | null (no focused write requirement) |
| `action=approve` | operational write ∪ |

Detail sections always include (when data present): source context, theatre handover, bed, insurance (if billing), transfers list, rounds, nursing notes, medication, discharge, timeline — plus Quick Actions (`_IpdDetailActions`) gated by operate/clinical/billing.

## Shared dialogs (dialogs.mdc)

- Create/edit hubs maximize by default (`ClinicalAdmissionActionDialog` / `AppDialog`); Start admission no longer opts out of maximize.
- Scrollable mutation dialogs pin footers (`pinActionsToBottom: true`): nursing note, ward round, medication, reject via `ClinicalFreeTextActionDialog`.
- Titles stay generic (action/surface); patient/admission identity lives in the body.

## Feedback patterns (cross-tab)

- Success: `_showSaved` snackbar after mutations
- Empty queue: `ipdNoAdmissionsTitle` / `ipdNoAdmissionsBody`
- Bed board empty: `ipdBedBoardEmptyTitle` / `ipdBedBoardEmptyBody`
- Follow-ups empty: reception follow-ups empty keys
- Failures: `_showFailureIfNeeded`
- No board tabs: forbidden panel (`routeForbiddenTitle` / `routeForbiddenBody`)
