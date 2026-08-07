# Pharmacy Reporting: Branch / Multi-Store — Facility-Accurate Mapping

Treat **branch = `facility`**. Demo has one facility—reports must stay accurate for 1-N facilities.

## Context

**Exists:** `facility` (`name`, `tenant_id`, …); `inventory_stock.facility_id`; patient/invoice/`payment.facility_id`; storage_room.facility_id for batches.

**No `branch` model.** Seed: single `DemoCare General Hospital`.

**All 8 branch report ids unavailable.**

## Data contract

| Report id | Source |
| --- | --- |
| `sales_by_branch` | consumption/payments grouped by facility (patient.facility_id or payment.facility_id)—document join | `facility`, `amount`, `quantity_dispensed` |
| `stock_by_branch` | `inventory_stock` by facility | `facility`, `quantity`, `value` (qty×buy) |
| `profit_by_branch` | consumption profit by facility scope | `facility`, `profit` |
| `transfers_between_branches` | `stock_movement` `TRANSFER` with from/to facilities if modeled; else unavailable until transfer endpoints stored |
| `purchases_by_branch` | PO/`purchase_request.facility_id` counts/value basis | `facility`, metrics |
| `stock_shortages_by_branch` | stock risk LOW/CRITICAL/OOS by facility | reuse classifiers |
| `best_performing_branch` | rank by `amount` or `profit`—subtitle states rank key | |
| `branch_comparison` (chart) | side-by-side series per facility | |

**Single-facility:** return one ready row (not unavailable). Multi-facility requires seeding ≥2 facilities with stock+dispenses.

## Requirements

1. Implement grouping by `facility.name`/`id`; never invent branch codes.
2. Optional multi-facility seed: ≥2 facilities each with volume stock+dispenses. Fact tables still meet ≥1,000 tenant-wide rows (`index.md` rule 9); facility masters remain few.
3. Transfer report only when transfer movement records both ends.
4. Reuse inventory/consumption datasets with facility scope parameter already used by runners.
5. Tests: one-facility ready; two-facility comparison sums to tenant total.

## Constraints

- `index.md` rule 5; demo-safety; no second tenancy model.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Branch metrics = facility metrics. | contract |
| A2 | Single-facility demo shows ready rows; optional 2nd facility documented. | R2 |
| A3 | Shortage classifiers match inventory; applicable fact tables ≥1,000 rows tenant-wide. | R3 |

## Relevant Files

- Prisma facility, inventory_stock, stock_movement; seed-catalog.js; datasets scope facility_id; catalog/provider

## Verification

- Facility-scoped preview matches unscoped single-facility tenant.
- Manual: Branch → sales/stock/comparison.
