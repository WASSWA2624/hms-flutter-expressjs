# IPD — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.ipd` under app `ShellRoute`
- Catalog / route entry: `RouteAccessCatalog.ipdEntry` — ∪ `clinical:read` \| `operations:read` \| `billing:read` + `inpatient-bed-management`
- Board chrome read: `ipdWorkspaceReadRequirement` — ∪ `clinical:read` \| `operations:read` + module (billing-alone does **not** unlock tabs)
- If no board tabs allowed: body `SizedBox.shrink()`

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
- Counts:
  - Admission queue / Active / Transfers / Discharge → workspace summary counts
  - Bed board → **no count** (`null`)
  - Follow-ups → `followUpTabCountProvider(IPD)`
- Count tones: `warning` for Admission queue, Transfers, Discharge, Follow-ups; `info` for Active patients and Bed board
- Icons: bed / local_hospital / swap_horiz / fact_check / grid_view / phone_callback
- Strip primary (Bed board only): Manage beds → `/rooms-beds` — **omitted when unauthorized** (`ipdBedManageRequirement`)

## Table toolbar (queue tabs)

Order on search bar: **Filters → Settings → Export → Start admission** (no table Print)

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `ipdSearchHint` / `ipdSearchLabel` | field-scoped |
| Filters | `ipdFiltersLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction` |
| Settings | `commonTableSettings*` (Apply/Reset use reception column keys) | storage `ipd_${section.name}` |
| Export | `commonTableExportActionLabel` | `enableExport: true`; date via `admittedAt` |
| Print (table) | **absent** | |
| Start admission | `ipdStartAdmissionAction` | omitted without operational write for section; absent on Follow-ups |

Date filter: **enabled** on queue tabs — label `ipdAdmittedAtColumnLabel`.

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

## Feedback patterns (cross-tab)

- Success: `_showSaved` snackbar after mutations
- Empty queue: `ipdNoAdmissionsTitle` / `ipdNoAdmissionsBody`
- Bed board empty: `ipdBedBoardEmptyTitle` / `ipdBedBoardEmptyBody`
- Follow-ups empty: reception follow-ups empty keys
- Failures: `_showFailureIfNeeded`
