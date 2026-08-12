# Billing inventory — convention gaps

Residual findings vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual / notes

- None — required Export / table Print / filter-label / count-tone / filtered active-badge gaps closed.
- Trailing context actions remain **owner-tab exclusive** (Charge → Open work; Issue all → To issue; Close day/shift → Collect) — intentional product split.
- `BillingQueueType.overdue` remains in the enum and atom map but is normalized to Collect + overdue filter (not a desk tab).

Per-tab inventory lives under this folder; remediation prompts: `prompts/13-billing/`.
