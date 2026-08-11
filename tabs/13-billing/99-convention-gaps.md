# Billing inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` after code trace (2026-08-11). No UI changes in this inventory pass.

## Residual / notes

- Queue `AppListTable` does **not** mount Export or table Print; print/download lives on detail (invoice/receipt/claim/approval) and Price book list Print.
- Filters button uses `billingFiltersLabel` rather than always `commonFiltersActionLabel` (Price book uses common Filters label).
- Trailing actions are **owner-tab exclusive** (Charge → Open work; Issue all → To issue; Close day/shift → Collect) — intentional product split, not a missing control on other tabs.
- `BillingQueueType.overdue` remains in the enum and atom map but is normalized to Collect + overdue filter (not a desk tab).
- Historical `prompts/01-billing/` naming (`01-open-work` … `06-price-book`) matches this folder’s file names; prompts directory was not present on disk during this write pass—inventories authored from presentation/access/tests.

Per-tab inventory lives under this folder; source prompt: `tabs-lister/13-billing.md`.
