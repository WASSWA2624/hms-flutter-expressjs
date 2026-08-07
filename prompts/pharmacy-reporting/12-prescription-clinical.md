# Pharmacy Reporting: Prescription & Clinical — Accurate Clinical Mapping

Map clinical reports to `pharmacy_order_item` prescription fields and linked encounter data—Reporting must not create prescriptions.

## Context

**Order item fields exist:** `dosage`, `dose_amount`, `dose_unit`, `frequency`, `route`, `duration_value`, `duration_unit`, `instructions`, `quantity`, `quantity_unit`, `drug_id`, `status`.

**Order:** optional `encounter_id` (CLINICAL vs walk-in PHARMACY).

**Gaps:** dedicated drug-interaction / duplicate-therapy / allergy-alert tables may exist under clinical modules—**only surface rows from real alert entities**. No `drug.is_controlled`—controlled reporting needs migration or custody JSON productization.

**All 12 prescription_clinical ids unavailable.**

## Data contract

| Report id | Source |
| --- | --- |
| `prescription_count` | count `pharmacy_order` in range (align with throughput `orders_created`) |
| `prescriber` | encounter clinician / order author FK if present; else unavailable |
| `diagnosis_indication` | encounter diagnosis link when `encounter_id` set |
| `medicine_prescribed` | item `drug.name`, counts/qty |
| `dosage` | `dosage` / `dose_amount`+`dose_unit` plain |
| `frequency` | `frequency` plain |
| `duration` | `duration_value` + `duration_unit`; if unit=day expose `duration_days` for day formatting |
| `drug_interactions` | clinical alert store only |
| `allergy_alerts` | allergy alert store only |
| `duplicate_therapy` | alert store only |
| `antibiotic_usage` | filter drugs by catalog heuristic (e.g. anti-infective seed set / ATC if present)—**document filter list**; qty dispensed |
| `controlled_drug_dispensing` | requires controlled flag migration or explicit drug allow-list (Morphine/Tramadol seed keys) documented in tests |

## Requirements

1. Prefer order_item fields for dosage/frequency/duration; do not parse free text into fake structured fields.
2. Alert reports: empty ready when no alerts—not fabricated.
3. Seed clinical orders with dosage/frequency/duration; antibiotic drugs from ANTI_INFECTIVE catalog; optional allergy alert fixture.
4. Reuse pharmacy/clinical reads; follow pharmacy-flow handoffs.
5. Tests: duration_days formatting; antibiotic filter includes Amoxicillin seed; controlled allow-list stable.

## Constraints

- `.cursor/flows/pharmacy-flow.mdc`, `.cursor/flows/opd-flow.mdc`; permissions for PHI; `index.md`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Dosage/frequency/duration match order_item columns. | contract |
| A2 | Alert/controlled reports never invent rows. | R2 |
| A3 | Demo clinical orders show non-empty medicine/dosage reports. | R3 |

## Relevant Files

- Prisma pharmacy_order_item, encounter/diagnosis/allergy modules; clinical seed; catalog/provider

## Verification

- Compare one order_item row to dialog medicine_prescribed/dosage.
- Manual: Prescription → duration, antibiotic usage.
