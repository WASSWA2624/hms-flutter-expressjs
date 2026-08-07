# Pharmacy Reporting: Dispensing — Accurate Throughput Mapping

Complete `dispensing` dialogs using `pharmacy_order` / `dispense_log` semantics already encoded in `buildPharmacyDispenseThroughputAnalytics`.

## Context

**Mapped today** → `pharmacy_dispense_throughput`: `number_of_prescriptions`, `items_dispensed`, `medicines_dispensed_by_period` (chart).

**Throughput columns:** `date`, `orders_created`, `dispensed`, `partially_dispensed`, `cancelled`, `returns`.

**Semantics (accuracy-critical)**

- `orders_created` / status buckets count **orders** by `pharmacy_order.ordered_at` + `status` (`DISPENSED|PARTIALLY_DISPENSED|CANCELLED`).
- `returns` counts `dispense_log` with `status=RETURNED` by `updated_at`—**not** sum of `quantity_dispensed`.
- Pack quantities live on `dispense_log.quantity_dispensed` (DISPENSED) or order_item.quantity—**do not** use throughput `dispensed` as pack qty.

**Order item clinical fields exist:** `dosage`, `frequency`, `duration_value`/`duration_unit`, `quantity_unit`.

**Missing:** dispensed-by user on `dispense_log` (attestation has `attested_by_user_id`).

**Seed:** clinical curated orders + volume orders with RETURNED logs.

## Data contract

| Report id | Source | Columns / notes |
| --- | --- | --- |
| `number_of_prescriptions` | summary/rows `orders_created` | count |
| `items_dispensed` | sum `dispense_log.quantity_dispensed` where DISPENSED in range **or** clear alias—if keeping throughput, rename UI to “orders dispensed” **or** switch datasetKey to consumption qty | prefer real pack qty for this label |
| `medicines_dispensed_by_period` | daily/monthly series of pack qty or order counts—**subtitle must state which** | chart |
| `medicines_dispensed_by_prescriber` | order → encounter → clinician if linked; else unavailable | do not invent |
| `medicines_dispensed_by_patient` | `pharmacy_order.patient_id` + qty | `patient`, `quantity_dispensed` |
| `prescription_status` | group orders by `status` | `status`, `orders_created` |
| `dispensing_errors_voids` | `CANCELLED` orders (+ RETURNED if treated as void)—document | counts |
| `partial_dispensing` | status `PARTIALLY_DISPENSED` | counts + optional remaining qty |
| `prescription_frequency` | orders per patient or per day | count |
| `average_items_per_prescription` | items per order: count `pharmacy_order_item` / orders **or** sum qty / orders—pick one; test it | plain/decimal |

## Requirements

1. Fix `items_dispensed` label/data mismatch (packs vs order counts).
2. Wire remaining ids with joins above; chart keeps contentKind chart.
3. Seed volume: ≥1,000 `pharmacy_order` and ≥1,000 `dispense_log` with status mix DISPENSED, PARTIALLY_DISPENSED, CANCELLED, RETURNED across the period (`index.md` rule 9).
4. Reuse throughput builders; extend rather than duplicate status enums.
5. Tests: cancelled≠returned; average items formula locked; pharmacy-flow: no new encounters from Reporting.

## Constraints

- `.cursor/flows/pharmacy-flow.mdc`; `index.md` accuracy rules.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Every dispensing id uses contract semantics; items_dispensed means packs. | R1 |
| A2 | Count vs quantity columns not mixed up in UI units. | contract |
| A3 | ≥1,000 orders + dispense logs; partial, cancelled, and returned present in volume. | R3 |

## Relevant Files

- `datasets.js` throughput + consumption; Prisma pharmacy_order(_item), dispense_log; volume/clinical seed; provider tests

## Verification

- Compare dialog totals to SQL/group counts for one seeded day.
- Manual: Dispensing → status, partial, by period.
