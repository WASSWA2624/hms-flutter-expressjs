# Pharmacy Reporting: Patients / Customers Dialogs and Demo Seed

Implement Patients / Customers report dialogs from patient/customer purchase and credit data with correct count/money units and demo retention coverage.

## Context

**Current behavior**

- Category `patients_customers` has 9 reports; only `frequently_purchased_medicines` maps to `pharmacy_drug_consumption`. Others unavailable.
- Patients, encounters, pharmacy orders, and billing/credit artifacts exist in demo volume but are not projected for new-vs-returning, credit balance, or retention reports.

**Intended behavior**

- Each customer subcategory dialog shows period-scoped customer metrics: counts, purchase amounts, medication history, credit/receivables, demographics (when appropriate), retention charts.

**Definitions**

- *Customer purchase amount:* Currency totals per patient/customer.
- *Report ids:* `number_of_customers`, `new_vs_returning`, `purchases_by_customer`, `patient_medication_history`, `customer_credit_balance`, `outstanding_payments`, `frequently_purchased_medicines`, `customer_demographics`, `customer_retention`.

## Requirements

1. Map every customers report id to dataset + provider projection; charts for `new_vs_returning` and `customer_retention`; keep top medicines projection.
2. Units: customer/visit counts → count; purchases/credit/outstanding → currency; medicine qty in history → quantity; demographics categorical plain; retention rates → percent.
3. Respect PHI minimization: demographics only fields already allowed in reports; no new sensitive columns without permission rules.
4. Seed demo: mix of new and returning patients with pharmacy purchases in range, medication history lines, non-zero credit and outstanding balances where billing supports it, demographic variety appropriate to seed policy.
5. Reuse patient/billing read models + shared reporting kit; do not build a CRM module.
6. Gate with reports read ∩ pharmacy; hide unauthorized fields/actions; responsive; light/dark.
7. Tests: projections; credit columns currency-formatted; seed new-vs-returning non-empty; export gated.

## Constraints

- Do not expose unauthorized PHI; follow `.cursor/access/permissions.mdc`.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 9 customer reports map to ready/empty/error with seed. | R1 |
| A2 | Count/money/percent/qty units correct; charts export PDF. | R2 |
| A3 | Demo shows new vs returning, history, and credit/outstanding samples. | R4 |
| A4 | PHI-safe columns; shared kit + responsive access OK. | R3, R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §6
- `pharmacy_reporting_catalog.dart`, `pharmacy_reporting_data_provider.dart`
- Billing/patient modules used by pharmacy sales
- `backend/src/lib/reports/datasets.js`, volume patient/billing seeders
- `frontend/lib/shared/reporting/**`

## Verification

- Provider tests for retention/new-vs-returning projections.
- Seed/verify returning purchasers + credit rows.
- Manual: Customers → retention chart, credit balance, frequent medicines; dark + narrow.
