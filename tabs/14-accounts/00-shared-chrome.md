# Accounts — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.accounts` under app `ShellRoute`
- Workspace gate: `accountsWorkspaceEntryRequirement` — (`accounts:read` ∪ `accounts:write`) ∩ module `facility-accounts` (`RouteAccessCatalog.accountsEntry`)
- Catalog entry: `RouteAccessCatalog.accountsEntry`
- If no desk tabs are allowed: empty `SizedBox.shrink()` (no disabled placeholders / no forbidden banner on body)

## Page chrome

- `AppAccessGate` + `AsyncStateScaffold<AccountsWorkspaceState>` over `accountsWorkspaceControllerProvider`
  - Loading: `AccountsStrings.loadingTitle` / `loadingBody`
  - App bar title: `AccountsStrings.workspaceTitle` (`Accounts`)
  - Retry: controller `refresh()`
- Body: `ResponsivePage` + `AppTabStrip` + section panel (`AccountsOpenWorkPanel` / `AccountsToPostPanel` / …)
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-link query (`AccountsWorkspaceQuery.fromUri`): `section`|`tab`|`queue`, `search`|`q`, `source`, `status`, `accountId`, `patientId`, `periodId`, `id`, `action`, `from`, `to`
  - `accountId` preserved on `gl`; `patientId` on `ledgers`; `periodId` / `action` / `id` on `journals`|`books`

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized (`canViewAccountsSection` → `accountsSectionTabRequirement`) — not disabled
- Counts from `AccountsSummary.countFor` (GL / books / ledgers may prefer dedicated providers when set)
- Count tones (`accountsSectionCountTone`): `warning` for journals, approvals, books; `info` for work / gl / ledgers / chart
- Icons: inventory / post_add / rule / account_balance / person / list_alt / menu_book
- Labels: Open work · To post · Need approval · General ledger · Patient ledgers · Account chart · Close books (`AccountsStrings`)

## Table toolbar (shared pattern)

Order varies by tab; common atoms:

| Control | Label | Notes |
| --- | --- | --- |
| Search | `AccountsStrings.searchHint` (ledgers/books/chart have section hints) | |
| Clear | `Clear search` | |
| Filters | `Filters` → `commonAdvancedFiltersTitle` | Approvals omit date filter; Books uses FilterChips (Open / Overdue) instead of advanced Filters |
| Settings | `commonTableSettingsActionLabel` | storage keys `accounts_*_v1` / `*_cw` |
| Export | `enableExport: true` on journals, approvals, gl, ledgers | **absent** on open work, chart (uses Print action), books |
| Print (table) | Chart strip `Print`; detail/dialog packets elsewhere | No uniform `AppListTable.enablePrint` across all tabs |
| Context | Journal / Post all / Open period / Close period / Add | gated per tab |

## Shared row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Work-item detail | Accounts-owned | `showAccountsWorkItemDetailDialog` (`accounts_work_actions.dart`) |
| Journal create/edit | Accounts-owned | `showAccountsJournalDialog` |
| Journal similarity | Accounts-owned | `showAccountsJournalSimilarityDialog` |
| Post / Approve / Reject / Reverse / Void | Accounts-owned | `accounts_work_actions.dart` + form dialogs |
| GL account ledger | Accounts-owned | `showAccountsGlDialog` |
| Patient ledger | Accounts-owned | `showAccountsPatientLedgerDialog` |
| Pay (patient balance) | **reused** Billing deep-link | `AppRoutes.billing` `section=collect&action=pay` |
| Chart create/edit / similarity | Accounts-owned | `accounts_chart_dialogs.dart` |
| Period open/close / books detail | Accounts-owned | `accounts_period_dialogs.dart` |
| Print packets | Accounts-owned helpers | journal / approval / GL / chart / books / patient ledger → mostly `PrintDocumentTemplates.claimStatement` or `registry` |

## Feedback patterns (cross-tab)

- Success: `showAccountsMutationSnackBar` (`AccountsStrings.saved` / `posted` / …)
- Failures: snackbars / table `error` / panel `AppFailureStateView` (books hard fail)
- Empty: section-specific `AppWorkspaceStatePanel.empty` titles
- Loading: scaffold + per-panel `isLoading` / `isRefreshing`
