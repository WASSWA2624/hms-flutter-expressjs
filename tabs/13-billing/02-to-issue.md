# Billing tab — To issue (`needsIssue` / `issue`)

## 1. Tab strip

- Label: `billingNeedsIssue`
- Tooltip: `billingNeedsIssueTooltip`
- Icon: `Icons.receipt_long_outlined`
- Count source: `billingQueueTabCount` → `summary.needsIssue` / filtered `workItems.totalItemCount` when search/filters active
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `issue` (aliases `needs-issue`, `ready-to-issue`)
- Tab gate: `BillingNeedsIssueAtomPermissions.tab` / entry requirement
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Issue all**

- Filters: `commonFiltersActionLabel`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings key: `billing_issue_v1`
- Export / table Print: present; omit without ∩ `evidence:export` (`BillingNeedsIssueAtomPermissions.export` / `print`)
- Context: Issue all (`billingIssueAllAction`) — omitted without write ∩; disabled when no issuable rows / saving
- Charge / Close shift·day: **not mounted**

## 3. Table

- Row model: `BillingWorkItem`
- Row select → detail dialog (`billingInvoiceDetailTitle` — generic; identity in body)
- Default columns (**5** when next-action mounts; **4** when read-only omits next-action — tested exception):
  1. Patient
  2. Invoice
  3. Encounter
  4. Status
  5. Next action — only if `billingQueueShowsNextActionColumn`
- Column choices (Settings): amount due, source, paid, updated (not age; not approval/claims-only ids)
- Reset columns restores the default set via shared Table Settings

## 4. Advanced filters / search fields

- Groups: Source (`billingSourceFilterLabel`), Status (needs-issue: DRAFT only)
- Text filters: patient / invoice / encounter
- Date range on issued date (`billingIssuedDateFilterLabel`)
- Footer: Clear filters → Apply filters → Close
- Overdue / Age groups: **not** on To issue (Collect owns them)
- Same `BillingWorkspaceQuery` drives table rows + active tab badge via `billingQueueTabCount`

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
| Ledger / Print | Billing-owned |

## 7. Nested / follow-on

Issue all confirm → batch issue; detail Issue → notes form; print/download from detail.

## 8. Forms (summary)

- Issue notes; optional adjust/void/send fields

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printBillingWorkspaceList`
- Detail invoice `Print` / Download when document read ∩

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
| List Export / Print | ∩ `evidence:export` |
