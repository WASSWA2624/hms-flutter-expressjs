# Accounts — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.accounts` under app `ShellRoute`
- Workspace gate: `accountsWorkspaceEntryRequirement` — (`accounts:read` ∪ `accounts:write`) ∩ module `facility-accounts` (`RouteAccessCatalog.accountsEntry`)
- Catalog entry: `RouteAccessCatalog.accountsEntry`
- List Export / table Print: ∩ `evidence:export` (`accountsWorkspaceExportRequirement` / `canExportAccountsWorkspace` / `canPrintAccountsWorkspace`) — omit when unauthorized
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
- `accounts_gl_workspace_page.dart`: intentional re-export of the desk page — GL is in-desk only (`?section=gl` + `AccountsGlPanel` / dialog), not a separate nested route surface

## Tab strip (all visible sections)

- Component: `AppTabStrip` / `AppTabItem` (standard variant)
- Tabs omitted when unauthorized (`canViewAccountsSection` → `accountsSectionTabRequirement`) — not disabled
- Counts: `accountsSectionTabCount` / `accountsSectionCountTone` in `accounts_scope_navigation.dart`
  - Sibling model: unfiltered `AccountsSummary` scope totals (seeded on workspace load into live providers)
  - Live overrides when set: GL / books / ledgers / chart count providers — **filtered** totals only while Advanced filters / search narrow that panel; unfiltered clears override so the badge falls back to summary (not painted `page.items.length`)
  - Active work-queue tabs (`work` / `journals` / `approvals`): filtered `workItems.totalItemCount` when search / advanced filters narrow
- Count tones: `warning` for journals, approvals, books; `info` for work / gl / ledgers / chart
- Icons: inventory / post_add / rule / account_balance / person / list_alt / menu_book
- Labels: Open work · To post · Need approval · General ledger · Patient ledgers · Account chart · Close books (`AccountsStrings`)

## Table toolbar (shared pattern)

Order: **Filters → Settings → Export → Print → context**

| Control | Label | Notes |
| --- | --- | --- |
| Search | `AccountsStrings.searchHint` (ledgers/books/chart have section hints) | |
| Clear | `Clear search` | |
| Filters | `Filters` → `commonAdvancedFiltersTitle` | All list tabs; Books also keeps Open / Overdue FilterChips synced with advanced Filters |
| Settings | `commonTableSettingsActionLabel` | storage keys `accounts_*_v1` / `*_cw` |
| Export | `enableExport: true` + `canExport` | ∩ `evidence:export` — omit when unauthorized |
| Print | `enablePrint: true` + `canPrint` | after Export; preview-first via `printAccountsListTable` / `accounts_workspace_print_helpers.dart`; omit without ∩ `evidence:export` |
| Context | Journal / Post all / Open period / Close period / Add | gated per tab |

Date filters: **enabled** on work / journals / approvals (`Posted date`) and GL (`Updated date`). Ledgers / chart / books have no date range (Books uses Open / Overdue chips + advanced Filters groups).

Atom maps: every desk atom class includes `filters` / `settings` / `export` / `print` (`Accounts*AtomPermissions`).

## Shared row hubs (owner notes)

| Surface | Owner | File |
| --- | --- | --- |
| Work-item detail | Accounts-owned | `showAccountsWorkItemDetailDialog` (`accounts_work_actions.dart`) |
| Journal create/edit | Accounts-owned | `showAccountsJournalDialog` |
| Journal similarity | Accounts-owned | `showAccountsJournalSimilarityDialog` |
| Post / Approve / Reject / Reverse / Void | Accounts-owned | `accounts_work_actions.dart` + form dialogs |
| GL account ledger | Accounts-owned | `showAccountsGlDialog` |
| Patient ledger | Accounts-owned | `showAccountsPatientLedgerDialog` — generic title `Patient ledger`; identity in body |
| Pay (patient balance) | **reused** Billing deep-link | `AppRoutes.billing` `section=collect&action=pay` |
| Chart create/edit / similarity | Accounts-owned | `accounts_chart_dialogs.dart` |
| Period open/close / books detail | Accounts-owned | `accounts_period_dialogs.dart` |
| List Print | Accounts-owned | `printAccountsListTable` → `PrintDocumentTemplates.registry` |
| Detail Print packets | Accounts-owned helpers | journal / approval / GL / books / patient ledger → shared `PrintDocumentTemplates.claimStatement` template reuse (Accounts-owned option panels) |

## Feedback patterns (cross-tab)

- Success: `showAccountsMutationSnackBar` (`AccountsStrings.saved` / `posted` / …)
- Failures: snackbars / table `error` / panel `AppFailureStateView` (books hard fail)
- Empty: section-specific `AppWorkspaceStatePanel.empty` titles
- Loading: scaffold + per-panel `isLoading` / `isRefreshing`
- List Export / Print omitted when unauthorized (no disabled stubs)
