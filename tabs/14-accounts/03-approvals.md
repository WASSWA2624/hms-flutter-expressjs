# Accounts tab — Need approval

## 1. Tab strip

- Label: `AccountsStrings.needApprovalLabel` (`Need approval`)
- Icon: `Icons.rule_outlined`
- Count source: `accountsSectionTabCount` → `AccountsSummary.needApproval`; active + narrowed (search / Filters / date) → `workItems.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `approvals` (alias `approval-required`)
- Tab gate: `AccountsNeedApprovalAtomPermissions.tab` = entry
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (no strip context actions)

- Search hint: shared accounts hint
- Filters: `Filters` → Advanced filters (`commonAdvancedFiltersTitle`)
  - Footer: **Clear filters** → **Apply filters** → **Close**
  - Date filter **enabled** — `Posted date`
- Settings: Table Settings; key `accounts_approvals_v1`; exposes defaults + By / Reason / Period; Reset restores defaults
- Export / table Print: `enableExport` / `enablePrint` + `canExport` / `canPrint` — omit without ∩ `evidence:export` (`AccountsNeedApprovalAtomPermissions.export` / `print`); Print label `Print`; preview-first `printAccountsListTable`
- Context trailing actions: **none**

## 3. Table

- Row model: `AccountsWorkItem` (pending approvals)
- Row select: `showAccountsWorkItemDetailDialog` — generic title `Approval` (no identity)
- Default columns (**5** when approve allowed):
  1. Journal (alwaysVisible)
  2. Type
  3. Amount
  4. Status
  5. Next (Approve) — **omitted** without `canDecideAccountsApproval` (justified → 4 defaults); alwaysVisible / not exportable when present
- Column choices (Settings extras): By, Reason, Period
- Mobile: caption approval type; trailing Approve

## 4. Advanced filters / search fields

- Text: Account, Journal, Period
- Groups: Type (Journal post / Void / Reversal / Period close), Status (Pending)
- Date range on posted date
- Same `AccountsWorkspaceQuery` model drives table rows and active tab badge (`source` carries approval type)

## 5. Primary / secondary / row actions

- Next / row path: Approve → `showAccountsApproveDialog`
- Detail also Reject when decision allowed

## 6. Dialogs from this tab

| Dialog | Owner | Title policy |
| --- | --- | --- |
| Work-item detail | Accounts-owned | Generic `Approval` |
| Approve | Accounts-owned | Action label |
| Reject | Accounts-owned (from detail) | Action label |

## 7. Nested / follow-on

Approve/Reject → notes/reason → mutation snackbar. Print from detail → approval packet. Stays in-desk.

## 8. Forms (summary)

- Approve / Reject: notes / reason fields
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: trigger `Print`; preview-first `printAccountsListTable` → `PrintDocumentTemplates.registry`
- Detail Print → `printAccountsApprovalPacket` (`PrintDocumentTemplates.claimStatement` template reuse)

## 10. Loading / empty / error / success

- Loading: workspace + table `isRefreshing`
- Empty: `No pending approvals.`
- Error: table error string / snackbars
- Success: mutation snackbars; list + tab count refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / filters / settings | entry |
| Next Approve / Reject | `accountsApprovalDecisionRequirement` (∩ `accounts:write` + `financial:approve` + modules) |
| Write-only mutations in detail | ∩ `accounts:write` when applicable |
| List Export / Print | ∩ `evidence:export` |
