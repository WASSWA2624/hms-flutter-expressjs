# Claims — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.claims`
- Workspace gate: `claimsWorkspaceEntryRequirement` (`RouteAccessCatalog.claimsEntry` — claims read ∪ write ∪ financial approve family)
- Module: `insurance-claims`
- If no desk tabs allowed: `SizedBox.shrink()` (no disabled placeholders)

## Page chrome

- `AsyncStateScaffold` / workspace controller over claims state
- Body: `ResponsivePage` + `AppTabStrip` (+ optional summary chips) + queue table or insurance setup panel
- In-desk URL: `?section=<query>` via `claimsDeskSectionToQuery`
- Deep-link: section + search/filter; `action=preauth` opens Request authorization when write allowed

## Tab strip

- Tabs omitted when `canViewClaimsDeskSection` fails — not disabled
- Counts: authorizations pending-scope / active claims scope / settled paid-closed; insurance setup count **0** (no badge pressure)
- Count tones: `warning` authorizations + activeClaims; `info` settled + insuranceSetup
- Icons: verified_user / receipt_long / task_alt / business
- Primary action on strip (not Refresh): Request authorization | Prepare claim — Settled / Insurance Setup primaries **absent**

## Queue table toolbar (authorizations / active / settled)

| Control | Notes |
| --- | --- |
| Search | `claimsSearchHint` / semantic label |
| Clear | controller clear search |
| Filters | **Settled only** (`showAdvancedFilterButton`) |
| Settings | `claims_${section.name}` / `claims_cw_${section.name}` |
| Export / table Print | **not** on `AppListTable` |
| Date filter | **disabled** (`enableDateFilter: false`) |

## Shared dialogs

| Surface | Owner |
| --- | --- |
| Claims detail | Claims-owned `_openClaimsDetailDialog` |
| Request authorization / Update auth | Claims-owned |
| Prepare / Submit / Record response / Close as paid | Claims-owned |
| Sync insurer status | Claims-owned (Active Claims detail) |
| Collect patient share | **reused** Billing receive-payment when invoice collectible |
| Insurance catalog dialogs | Claims-owned (`claims_insurance_config_dialogs.dart`) |
| Print statement | `PrintDocumentTemplates.claimStatement` |

## Feedback

- Empty queue: `claimsEmptyQueueTitle` / body
- Failures: `_showFailureIfNeeded` snackbars
- Saving: strip primary `isLoading` / dialog saving
- Success: controller refresh after mutations
