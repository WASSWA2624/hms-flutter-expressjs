# Pharmacy Reporting: Dispensing Dialogs and Demo Seed

Complete Dispensing report dialogs from pharmacy order/dispense throughput with count/quantity units and demo queue diversity—extending `pharmacy_dispense_throughput`.

## Context

**Current behavior**

- Category `dispensing` has 10 reports. `number_of_prescriptions`, `items_dispensed`, `medicines_dispensed_by_period` map to `pharmacy_dispense_throughput`; others unavailable.
- Throughput dataset already exposes orders_created, dispensed, partially_dispensed, cancelled, returns.

**Intended behavior**

- Every dispensing subcategory dialog shows period-filtered dispense metrics with correct units; chart for by-period; tables for breakdowns by prescriber/patient/status/errors/partials/frequency/averages.

**Definitions**

- *Prescription count:* Order/prescription counters (`orders_created`, status counts)—count unit.
- *Items dispensed:* Line/pack quantities (`dispensed`, `quantity_dispensed`)—quantity unit.
- *Report ids:* `number_of_prescriptions`, `items_dispensed`, `medicines_dispensed_by_period`, `medicines_dispensed_by_prescriber`, `medicines_dispensed_by_patient`, `prescription_status`, `dispensing_errors_voids`, `partial_dispensing`, `prescription_frequency`, `average_items_per_prescription`.

## Requirements

1. Extend throughput (or companion) dataset + provider projections for all dispensing report ids; keep encounter-linked dispense invariants from `.cursor/flows/pharmacy-flow.mdc`.
2. Units: status/order counters → count; item quantities → quantity; averages may be plain decimal; no currency unless amount columns exist.
3. Period presets drive series; soft-refresh; empty when no dispenses in range.
4. Seed demo dispenses across statuses (dispensed, partial, cancelled/void), multiple prescribers/patients, multi-item prescriptions, and returns/errors where schema allows.
5. Reuse shared dialog/chart/table/export and existing throughput analytics builders.
6. Access, responsive, light/dark; unauthorized export absent.
7. Tests: each report id; partial + void rows present in seed path; Analytics chips unchanged.

## Constraints

- Must not create encounters or mix OPD/IPD/discharge queues in Reporting.
- Follow `.cursor/mandatories.mdc`, `.cursor/flows/pharmacy-flow.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 10 dispensing reports leave unavailable with seed/API available. | R1 |
| A2 | Count vs quantity columns format correctly; by-period chart exports PDF. | R2, R3 |
| A3 | Demo includes partial, void/cancel, multi-prescriber, multi-item Rx. | R4 |
| A4 | Shared kit + pharmacy flow invariants + responsive access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §5
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- `backend/src/lib/reports/datasets.js` (throughput builders)
- Pharmacy order/dispense seeders in clinical/volume packs
- `frontend/test/.../pharmacy_reporting_data_provider_test.dart`

## Verification

- Throughput projection tests for new breakdowns.
- Seed asserts status diversity.
- Manual: Dispensing → by period chart, partial dispensing, average items; xs width.
