# Pharmacy Reporting: Prescription & Clinical Dialogs and Demo Seed

Implement Prescription & Clinical Parameter dialogs from prescription/order clinical fields with dosage/duration units and demo clinical coverage—without owning prescribing UX.

## Context

**Current behavior**

- Category `prescription_clinical` has 12 reports; all unavailable.
- Clinical prescriptions, diagnoses, allergies, and pharmacy orders exist across OPD/pharmacy modules; Reporting does not project them yet.

**Intended behavior**

- Dialogs report prescription counts, prescriber, indication, medicines, dosage, frequency, duration, interaction/allergy/duplicate alerts, antibiotic usage, and controlled-drug dispensing for the period.

**Definitions**

- *Clinical report:* Read-only aggregation of prescribed/dispensed clinical attributes.
- *Report ids:* `prescription_count`, `prescriber`, `diagnosis_indication`, `medicine_prescribed`, `dosage`, `frequency`, `duration`, `drug_interactions`, `allergy_alerts`, `duplicate_therapy`, `antibiotic_usage`, `controlled_drug_dispensing`.

## Requirements

1. Map all prescription report ids to datasets from prescription/order/alert sources; respect pharmacy-flow handoff (Reporting does not create prescriptions).
2. Units: counts → count; duration → days when numeric; dosage/frequency plain strings; antibiotic/controlled quantities → quantity.
3. Soft-refresh; empty when no Rx in range; never fabricate interaction/allergy rows—seed real alert entities if shown.
4. Seed prescriptions with diagnoses, varied dosage/frequency/duration, antibiotic and controlled examples, and at least one allergy alert / duplicate-therapy flag if those tables exist.
5. Reuse clinical + pharmacy read models and shared reporting UI.
6. PHI/permission-safe columns; responsive; light/dark.
7. Tests: controlled + antibiotic projections; alert rows permission-filtered; export gated.

## Constraints

- Must not create encounters or alter OPD prescribing; follow `.cursor/flows/pharmacy-flow.mdc`, `.cursor/flows/opd-flow.mdc`.
- Follow `.cursor/access/permissions.mdc`, `.cursor/access/demo-data.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | All 12 clinical reports leave unavailable with seed/API. | R1 |
| A2 | Count/days/qty/plain clinical fields use correct units. | R2 |
| A3 | Demo includes antibiotic, controlled, and ≥1 alert sample when schema allows. | R4 |
| A4 | No prescribing side effects; shared kit + access OK. | R5–R7 |

## Relevant Files

- `.cursor/reporting-analytics.md/pharmacy-reporting.md` §12
- Prescription/allergy/alert modules
- `pharmacy_reporting_catalog.dart`, data provider
- Clinical seed packs
- `frontend/lib/shared/reporting/**`

## Verification

- Provider tests for antibiotic_usage and controlled_drug_dispensing.
- Manual: Prescription section → duration, alerts, antibiotic usage; xs + light.
