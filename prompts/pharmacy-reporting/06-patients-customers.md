# Pharmacy Reporting: Patients / Customers — Accurate Mapping

Map customer reports to `patient` + pharmacy orders/dispenses + billing balances—PHI-minimized and formula-clear.

## Context

**Mapped:** `frequently_purchased_medicines` → `pharmacy_drug_consumption` (top 20 by `amount` then `quantity_dispensed`).

**Exists:** `pharmacy_order.patient_id`, dispense amounts via consumption join, `invoice`/`payment` with `patient_id`, open invoice statuses.

**Gaps:** No first-class “customer credit balance” field—derive from open invoices/payments or unavailable. Demographics only from existing patient fields allowed for reports.

**Seed:** volume patients with pharmacy orders; billing UGX; returning purchasers appear when same patient has multiple orders across days.

## Data contract

| Report id | Source / formula |
| --- | --- |
| `number_of_customers` | count distinct `patient_id` on pharmacy orders (or dispenses) in range |
| `new_vs_returning` (chart) | **new** = first-ever pharmacy order in range and no prior order before `from`; **returning** = had order before `from` and again in range. Columns: `segment`, `customer_count` |
| `purchases_by_customer` | group consumption/dispenses by patient: `patient`, `amount`, `quantity_dispensed` |
| `patient_medication_history` | dispense lines: `patient`, `drug`, `quantity_dispensed`, `dispensed_at`, `amount` |
| `customer_credit_balance` | sum open pharmacy-scoped invoice balances per patient—**define open status set to match billing module**; column `credit_balance` currency |
| `outstanding_payments` | same open invoices aged: `patient`, `amount`, `issued_at` |
| `frequently_purchased_medicines` | keep existing top projection |
| `customer_demographics` | only permitted patient attributes already used in reports; aggregate counts—no new PHI columns without permission review |
| `customer_retention` (chart) | retained = purchasing in prior window and current window; `retention_rate` percent |

## Requirements

1. Implement formulas above; document window for retention (e.g. previous period of equal length) in subtitle.
2. Money from consumption/invoice currencies (UGX seed); counts as count units.
3. Seed volume: ≥1,000 distinct patients with pharmacy activity is ideal; at minimum ≥1,000 `pharmacy_order` tied to a large patient pool with multi-visit returning buyers, plus ≥1,000 invoices/payments including open pharmacy invoices for credit (`index.md` rule 9).
4. Reuse billing open-balance concepts from `billing_collections_open_balances` where possible.
5. Tests: new vs returning partition is disjoint; frequent medicines sort stable; unauthorized PHI absent.

## Constraints

- `.cursor/access/permissions.mdc`; `index.md` accuracy rules; no CRM module.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Customer metrics match distinct-patient and billing open-balance definitions. | contract |
| A2 | Credit/outstanding currency; retention percent; medicine qty units. | R2 |
| A3 | ≥1,000 pharmacy orders/invoices in mix; non-empty new/returning and frequent medicines. | R3 |

## Relevant Files

- Prisma patient, pharmacy_order, dispense_log, invoice, payment; datasets billing + consumption; volume seed; provider

## Verification

- Pick one patient HFI: history lines sum to purchases_by_customer amount.
- Manual: Customers → new vs returning, credit balance.
