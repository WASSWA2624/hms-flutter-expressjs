# Sync Start-OPD Payables into Billing

Surface every payable from Start OPD encounter in Billing. Follow `prompts/.cursor/prompt.mdc` and `.cursor/flows/opd-flow.mdc`.

## Context

Reception shows Payment due after Start OPD encounter, but Billing often omits those invoices. Billing owns consultation payment; Reception stays read-only.

## Requirements

1. On successful Start OPD encounter with required consultation payment, create or reuse one consultation invoice via the billing engine, linked to patient and encounter.
2. Publish billing workspace events so authorized Billing queues include that invoice immediately, without treating Payment gate as a filter.
3. Align Reception Current step, Next action, Payment gate, and counts to the same invoice and stage after start, cancel, waive, or not-required.
4. Drop Billing payables when payment is not required, the encounter is cancelled, or charges are voided or waived.
5. Do not add Reception controls that open `/billing` or collect payment; keep loading, empty, error, success, and validation feedback.

## Constraints

- Reuse encounter creation, `persistConsultationBilling`, invoice contracts, realtime groups, authorization, localization, and design-system components.
- Keep RBAC/ABAC authoritative; omit unauthorized UI. Do not invent stages or duplicate engines.

## Acceptance Criteria

- R1–R2: Required Start-OPD payables appear in Billing with matching patient, encounter, amount, and status.
- R3–R4: Reception and Billing stay aligned after create, cancel, waive, and not-required.
- R5: Reception never opens Billing or mutates payment; states stay visible.
- Add OPD billing-sync and Billing tests; run backend tests and Flutter analysis.

## Relevant Files

- `backend/src/modules/opd-flow/services/opd-flow.service.js`
- `backend/src/modules/billing/services/billing.service.js`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/features/billing/`
- `frontend/lib/features/reception/`
