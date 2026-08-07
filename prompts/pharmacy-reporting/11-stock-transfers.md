# Pharmacy Reporting: Stock Transfers Dialogs and Demo Seed

Implement Stock Transfers report dialogs from transfer documents with quantity/status mappings and demo pending/discrepancy coverage.

## Context

**Current behavior**

- Category `stock_transfers` has 8 reports; all unavailable.
- Inventory transfer entities (send/receive location, qty, status, product lines) exist or are adjacent in inventory modules used by multi-store flows.

**Intended behavior**

- Each transfer subcategory dialog lists transfer quantity, sending/receiving branch, dates, status, products, pending queue, and discrepancies for the selected period.

**Definitions**

- *Transfer quantity:* Moved pack counts—quantity unit.
- *Report ids:* `transfer_quantity`, `sending_branch`, `receiving_branch`, `transfer_date`, `transfer_status`, `products_transferred`, `pending_transfers`, `transfer_discrepancies`.

## Requirements

1. Dataset + projections for every transfer report id from real transfer tables; no client-fabricated transfers.
2. Units: quantities → units; dates plain/ISO display via formatters; status plain; discrepancy qty → quantity; value if present → currency.
3. Period filters by transfer date; pending ignores closed outside range only if still open (document in subtitle).
4. Seed transfers: completed, pending, and ≥1 discrepancy (ordered/shipped ≠ received) across demo locations.
5. Reuse inventory transfer read APIs + shared reporting kit.
6. Access, responsive (status chips readable on xs), light/dark.
7. Tests: pending + discrepancy projections; seed coverage; export gated.

## Constraints

- If transfer schema is minimal, extend schema only with migrations per `.cursor/mandatories.mdc`—no orphan FKs.
- Follow `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 8 transfer reports map to ready/empty/error with seed. | R1 |
| A2 | Qty/status/date fields correctly typed and labeled. | R2 |
| A3 | Demo includes pending and discrepancy transfers. | R4 |
| A4 | Shared kit + migrations (if any) + responsive access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §11
- Inventory transfer modules + Prisma models
- `pharmacy_reporting_catalog.dart`, data provider
- Seed packs for stock movements/transfers
- `frontend/lib/shared/reporting/**`

## Verification

- Dataset tests for pending_transfers and transfer_discrepancies.
- Manual: Transfers → pending, discrepancies, products transferred; dark mode.
