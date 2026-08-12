# Accounts inventory — convention gaps

Residual findings vs `prompts/.cursor/*.mdc` after shared-chrome / per-tab / convention-gap remediation.

## Gaps

- none

## Justified product exceptions (documented + tested)

### Routes / ownership

- `accounts_gl_workspace_page.dart` remains a re-export of the desk page — GL is in-desk only (`?section=gl`), not a separate nested route surface (`screens.mdc`).
- Patient ledgers **Pay** deep-links to Billing Collect due — allowed ownership handoff (`screens.mdc`).

### Printing

- List Print uses `printAccountsListTable` → `PrintDocumentTemplates.registry` (preview-first; trigger label `Print`).
- Detail / dialog print packets may reuse `PrintDocumentTemplates.claimStatement` (shared template name; Accounts-owned option panels) — intentional template reuse, not a residual list-chrome gap.

### Filters / date

- Date range **enabled** on Open work / To post / Need approval (`Posted date`) and General ledger (`Updated date`).
- Date range **omitted** on Patient ledgers / Account chart / Close books — domain filters (clearance / type-status-effective / Open–Overdue chips + advanced groups) cover scope; recorded per-tab inventories.

### Columns

- Default visible columns prefer **5**; write/approve-gated Actions/Next may drop to **4** when unauthorized — justified per-tab compliance tests.

### Counts / tones

- Sibling model: unfiltered `AccountsSummary` scope totals; dedicated panels push filtered overrides only while narrowed; work-queue active tab uses `workItems.totalItemCount` when narrowed (`accounts_scope_navigation.dart`).
- Tones: `warning` = journals / approvals / books; `info` = work / gl / ledgers / chart.

## Closed inventory residuals (was open in `99-convention-gaps` prompt)

| Residual | Resolution |
| --- | --- |
| Open work lacked Export/Print | All 7 list panels: `enableExport` / `enablePrint` + ∩ `evidence:export` |
| Chart custom Print trailing | Chart uses table toolbar Print slot (not search trailing) |
| Approvals/GL omitted date filter | Both have date filters now |
| Books omitted advanced Filters | Filters present; chips sync with Open / Overdue groups |
| Open work Export vs siblings | Export present on Open work |
| `claimStatement` packet reuse | Justified exception above |
| GL re-export page | Justified exception above |
