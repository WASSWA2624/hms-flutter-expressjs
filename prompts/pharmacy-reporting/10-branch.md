# Pharmacy Reporting: Branch / Multi-Store Dialogs and Demo Seed

Implement Branch / Multi-Store report dialogs with facility/branch slices, comparison chart, and demo multi-branch seed—reusing facility-scoped pharmacy data.

## Context

**Current behavior**

- Category `branch` has 8 reports; all unavailable. App is tenant/facility-scoped; multi-branch may be multiple facilities or pharmacy locations depending on schema.
- Transfers and stock already carry location/facility foreign keys in inventory modules.

**Intended behavior**

- When multi-location data exists, dialogs compare sales, stock, profit, transfers, purchases, shortages, and best performer by branch; comparison chart enabled. Single-branch demos still show one-row ready (not unavailable).

**Definitions**

- *Branch:* Facility or pharmacy location key used in stock/sales scope.
- *Report ids:* `sales_by_branch`, `stock_by_branch`, `profit_by_branch`, `transfers_between_branches`, `purchases_by_branch`, `stock_shortages_by_branch`, `best_performing_branch`, `branch_comparison`.

## Requirements

1. Map all branch report ids to datasets keyed by facility/location; `branch_comparison` chart.
2. Units: sales/profit → currency; stock/shortage qty → quantity; transfer counts → count.
3. Soft-refresh; empty only when zero rows; subtitle clarifies single- vs multi-branch.
4. Seed ≥2 demo branches/facilities with differing sales, stock, shortages, and at least one transfer between them when schema supports it; otherwise seed one branch honestly and still map columns.
5. Reuse facility scope + shared reporting; do not invent a second tenancy model.
6. Access, responsive, themes; tests for comparison projection and seed branch count policy.

## Constraints

- Do not break single-facility tenants; follow demo-safety and existing facility seed patterns.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 8 branch reports leave unavailable (ready/empty/error). | R1 |
| A2 | Currency/qty units correct; comparison chart works. | R2 |
| A3 | Demo policy documents multi-branch when supported; single-branch still ready. | R4 |
| A4 | Shared kit + access + responsive OK. | R5–R6 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §10
- Facility/inventory transfer models
- `pharmacy_reporting_catalog.dart`, data provider
- Seed runtime facility helpers
- `frontend/lib/shared/reporting/**`

## Verification

- Tests for branch_comparison series.
- Manual: Branch section → comparison chart, shortages; tablet width.
