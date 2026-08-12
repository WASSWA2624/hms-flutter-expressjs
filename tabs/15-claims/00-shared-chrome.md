# Claims — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.claims`
- Workspace gate: `claimsWorkspaceEntryRequirement` (`RouteAccessCatalog.claimsEntry` — ∩ `claims:read` + `insurance-claims`)
- Module: `insurance-claims`
- If no desk tabs allowed: `SizedBox.shrink()` (no disabled placeholders)

## Page chrome

- `AsyncStateScaffold` / workspace controller over claims state
- Body: `ResponsivePage` + `AppTabStrip` (+ optional summary chips) + queue table or insurance setup panel
- In-desk URL: `?section=<query>` via `claimsDeskSectionToQuery`
- Deep-link: section + search/filter; `action=preauth` opens Request authorization when write allowed

## Tab strip

- Tabs omitted when `canViewClaimsDeskSection` fails — not disabled
- Sibling counts: dedicated unfiltered summary scope totals (`claimsSectionTabCount` / `claims_scope_navigation.dart`)
- Active queue tab with search / advanced filters: filtered `queue.totalItemCount`
- Insurance Setup: **count omitted** (`null` — catalog hub, not a worklist)
- Count tones: `warning` authorizations + activeClaims; `info` settled (+ insuranceSetup when counted)
- Icons: verified_user / receipt_long / task_alt / business
- Primary action on strip (not Refresh): Request authorization | Prepare claim — Settled / Insurance Setup primaries **absent**

## Queue table toolbar (authorizations / active / settled)

Order: **Filters → Settings → Export → Print**

| Control | Notes |
| --- | --- |
| Search | `claimsSearchHint` / semantic label |
| Clear | controller clear search |
| Filters | all queue tabs (`commonFiltersActionLabel`) |
| Settings | `claims_${section.name}` / `claims_cw_${section.name}` |
| Export | ∩ `evidence:export` (`canExportClaimsWorkspace`) — omit when denied |
| Print | after Export; label `commonPrintActionLabel` (`Print`); preview-first via `printClaimsListTable` |
| Date filter | **disabled** (justified: `ClaimsQueueQuery` / work-items API have no date range) |

## Shared dialogs

| Surface | Owner |
| --- | --- |
| Claims detail | Claims-owned `_openClaimsDetailDialog` |
| Request authorization / Update auth | Claims-owned |
| Prepare / Submit / Record response / Close as paid | Claims-owned |
| Sync insurer status | Claims-owned (Active Claims detail) |
| Collect patient share | **reused** Billing receive-payment when invoice collectible |
| Insurance catalog dialogs | Claims-owned (`claims_insurance_config_dialogs.dart`) |
| Detail Print | label `Print`; `PrintDocumentTemplates.claimStatement` (Settled: ∩ `evidence:export`; others: read ∩) |
| Table Print | `claims_workspace_print_helpers.dart` → `PrintDocumentTemplates.registry` |

## Feedback

- Empty queue: `claimsEmptyQueueTitle` / body
- Failures: `_showFailureIfNeeded` snackbars
- Saving: strip primary `isLoading` / dialog saving
- Success: controller refresh after mutations
