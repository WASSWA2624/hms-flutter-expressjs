# Billing tab — To issue (`needsIssue` / `issue`)

## 1. Tab strip

- Label: `billingNeedsIssue`
- Tooltip: `billingNeedsIssueTooltip`
- Icon: `Icons.receipt_long_outlined`
- Count source: `summary.needsIssue`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `issue` (aliases `needs-issue`, `ready-to-issue`)
- Tab gate: `BillingNeedsIssueAtomPermissions.tab` / entry requirement
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Issue all**

- Settings key: `billing_issue_v1`
- Export / table Print: **absent**
- Context: Issue all (`billingIssueAllAction`) — omitted without write ∩ or when no issuable rows
- Charge / Close shift·day: **not mounted**

## 3. Table

- Default columns: Patient / Invoice / Encounter / Status / Next action (when shown)
- Column choices: shared non-default set
- Row select → detail (Issue primary)

## 4. Advanced filters / search fields

- Groups: Source, Status (needs-issue choices)
- Text filters + issued date

## 5. Primary / secondary / row actions

- Strip: Issue all → confirm dialog → `issueInvoices`
- Next action Issue → issue notes dialog
- Secondary detail mutations (adjust/void/send) when item exposes them

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Billing-owned |
| Issue / Issue all confirm | Billing-owned |
| Adjust / Void / Send (if exposed) | Billing-owned |
| Ledger / Print invoice | Billing-owned |

## 7. Nested / follow-on

Issue all confirm → batch issue; detail Issue → notes form; print/download from detail.

## 8. Forms (summary)

- Issue notes; optional adjust/void/send fields

## 9. Print / labels / preview

- Table Print: **absent**
- Detail invoice Print/Download when document read ∩

## 10. Loading / empty / error / success

- Empty: `billingEmptyReadyToIssueBody` (short title copy)
- Issue all disabled when saving or no issuable items

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome | NeedsIssue atom / entry |
| Issue / Issue all | write ∩ |
| Close shift/day | write ∩ documented — **not mounted** |
| Approve nested | approve ∩ |
| Claims strip / nested | claims pending / claims write |
| Print/Download | document ∩ |
