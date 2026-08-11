# Billing tab — Need approval (`approvalRequired` / `approvals`)

## 1. Tab strip

- Label: `billingApprovalRequired`
- Tooltip: `billingApprovalRequiredTooltip`
- Icon: `Icons.rule_outlined`
- Count source: `summary.approvalRequired`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `approvals` (alias `approval-required`)
- Tab gate: `BillingApprovalRequiredAtomPermissions.tab` / entry requirement
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings** (no Charge / Issue all / Close trailing)

- Settings key: `billing_approvals_v1`
- Export / table Print: **absent**
- Trailing context: **none**

## 3. Table

- Default columns: Patient / Invoice / Amount due / Status / Next action
- Next action column mounts only when `canDecideBillingApproval` (write alone must not mount empty column)
- Column choices (approval-specific): Type, By, Reason
- Row select → detail

## 4. Advanced filters / search fields

- Groups: Approval type (`billingApprovalTypeFilterLabel`), Status (approval status choices)
- Text filters + issued date

## 5. Primary / secondary / row actions

- Next action Approve → approve dialog; Reject from detail
- Close shift/day **not mounted** (Collect-owned)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Billing-owned |
| Approve / Reject (+ notes) | Billing-owned |
| Ledger | Billing-owned |
| Approval packet print | Billing approval print helpers |

## 7. Nested / follow-on

Approve/Reject notes dialogs → refresh; print approval packet from detail when authorized.

## 8. Forms (summary)

- Approval / rejection notes

## 9. Print / labels / preview

- Table Print: **absent**
- Detail: Print/Download approval packet (`printBillingApprovalPacket`) when document read ∩

## 10. Loading / empty / error / success

- Empty: `billingEmptyApprovalRequiredBody` (short title copy)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | entry / ApprovalRequired atom |
| Approve / Reject / next-action column | write ∩ financial:approve |
| Close shift/day | write ∩ documented — **not mounted** |
| Nested claims | claims write / claims pending tab |
| Ledger / Print | read / document ∩ |
