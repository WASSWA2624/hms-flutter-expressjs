# Billing inventory — convention gaps

Residual findings vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual / notes

- **None** — required Export / table Print / filter-label / count-tone / filtered active-badge gaps closed.

### Closed inventory residuals (Requirements 1–4)

1. Queue `AppListTable` mounts Export + table Print (`canExport` / `enablePrint` / `commonPrintActionLabel`) gated by ∩ `evidence:export`.
2. Filters button uses `commonFiltersActionLabel` on queue tables and Price book.
3. Trailing context actions remain **owner-tab exclusive** (Charge → Open work; Issue all → To issue; Close day/shift → Collect) — intentional product split (tested).
4. `BillingQueueType.overdue` remains in the enum and atom map but is normalized to Collect + overdue filter (not a desk tab).

### Justified tested exceptions

- Default visible columns: **5** when next-action mounts; **4** when read-only omits next-action (queue tabs).
- Price book defaults: Item / Mode / Price / Status (**4**); Actions mounts only with write.

Per-tab inventory lives under this folder; remediation prompts: `prompts/13-billing/`.
