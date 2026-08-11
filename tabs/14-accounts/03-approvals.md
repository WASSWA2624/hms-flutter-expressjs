# Accounts tab — Need approval

## 1. Tab strip

- Label: `Need approval`
- Icon: `Icons.rule_outlined`
- Count source: `AccountsSummary.needApproval`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `approvals` (alias `approval-required`)
- Tab gate: `AccountsNeedApprovalAtomPermissions.tab` = entry
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Search hint: shared accounts hint
- Filters: present; **no date filter** on this tab
- Settings: `accounts_approvals_v1`
- Export: `enableExport: true`
- Print (toolbar): **absent**
- Context trailing actions: **none**

## 3. Table

- Row model: `AccountsWorkItem` (pending approvals)
- Row select: work-item detail
- Default columns: Journal, Amount, Status, Next (Approve when decision allowed)
- Column choices: Type, By, Reason, Period
- Next column omitted without `canDecideAccountsApproval`
- Mobile: caption approval type; trailing Approve

## 4. Advanced filters / search fields

- Text: Account, Journal, Period
- Groups: Type (Journal post / Void / Reversal / Period close), Status (Pending)
- Date filter: **intentionally omitted**

## 5. Primary / secondary / row actions

- Next / row path: Approve → `showAccountsApproveDialog`
- Detail also Reject when decision allowed

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Work-item detail | Accounts-owned |
| Approve | Accounts-owned |
| Reject | Accounts-owned (from detail) |

## 7. Nested / follow-on

Approve/Reject → notes/reason → mutation snackbar. Print from detail → approval packet.

## 8. Forms (summary)

- Approve / Reject: notes / reason fields

## 9. Print / labels / preview

- Detail Print → `printAccountsApprovalPacket` (`PrintDocumentTemplates.claimStatement`)
- Table Print: absent

## 10. Loading / empty / error / success

- Empty: `No pending approvals.`
- Success: mutation snackbars; list refresh

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / Export | entry |
| Next Approve / Reject | `accountsApprovalDecisionRequirement` (∩ `accounts:write` + `financial:approve` + modules) |
| Write-only mutations in detail | ∩ `accounts:write` when applicable |
