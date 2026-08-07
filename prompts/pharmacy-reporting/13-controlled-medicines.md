# Pharmacy Reporting: Controlled / Regulated Medicines Dialogs and Demo Seed

Implement Controlled / Regulated Medicines report dialogs as a balance-and-log view with quantity units, batch lineage, and demo regulatory coverage.

## Context

**Current behavior**

- Category `controlled_medicines` has 12 reports; all unavailable.
- Drugs can be flagged controlled; dispense logs and stock movements exist, but Reporting lacks opening/closing balance and regulatory log projections.

**Intended behavior**

- Dialogs present controlled stock, opening/received/dispensed/closing balances, batches, prescriber, patient, dispensing staff, adjustments, wastage, and a regulatory log for the selected period.

**Definitions**

- *Balance quantity:* Controlled pack counts—quantity unit throughout.
- *Report ids:* `controlled_medicine_stock`, `opening_balance`, `quantity_received`, `quantity_dispensed`, `closing_balance`, `batch_numbers`, `controlled_prescriber`, `controlled_patient`, `dispensing_staff`, `controlled_adjustments`, `wastage`, `regulatory_log`.

## Requirements

1. Dataset + projections for every controlled report id from controlled-flagged drugs + movements/dispenses; balances must reconcile received/dispensed/adjustments/wastage within rounding rules you document in tests.
2. Units: all stock/movement fields → quantity; actor/patient/prescriber names plain; wastage qty → quantity; timestamps formatted; no currency unless value columns exist.
3. Period defines opening (as-of from) and closing (as-of to); soft-refresh; empty when no controlled stock.
4. Seed ≥1 controlled medicine with opening stock, receipt, dispense to named patient/prescriber/staff, adjustment, and wastage so balances are demonstrable.
5. Reuse shared reporting + pharmacy inventory; tighter permission checks for regulatory log if required.
6. Responsive; light/dark; unauthorized log fields absent.
7. Tests: balance identity; seed controlled graph; export gated.

## Constraints

- Do not weaken controlled-drug audit requirements; follow `.cursor/access/permissions.mdc`, `.cursor/flows/pharmacy-flow.mdc`.
- Follow `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`, `.cursor/mandatories.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 12 controlled reports map to ready/empty/error with seed. | R1 |
| A2 | Balance/movement fields use quantity units; actors plain. | R2 |
| A3 | Demo controlled graph shows open→receive→dispense→close path. | R4 |
| A4 | Regulatory fields permission-safe; shared kit + responsive OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §13
- Controlled drug flags on catalog; dispense/movement tables
- `pharmacy_reporting_catalog.dart`, data provider
- Clinical catalog seeder (controlled examples)
- `frontend/lib/shared/reporting/**`

## Verification

- Balance reconciliation unit test.
- Manual: Controlled → opening/closing, regulatory log; dark + narrow.
