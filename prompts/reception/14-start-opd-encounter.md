# Sync Start-OPD Payables into Billing

When Reception starts an OPD encounter that requires payment, surface every payable charge in Billing. Follow `prompts/.cursor/prompt.mdc` and `.cursor/flows/opd-flow.mdc`.

## Context

Reception shows Payment due after Start OPD encounter, but Billing often omits those invoices. Billing owns consultation payment; Reception stays read-only.

## Requirements

1. On successful Start OPD encounter with required consultation payment, create or reuse one authoritative consultation invoice via the existing billing engine, linked to patient and encounter.
2. Publish billing workspace events so authorized Billing queues include that invoice immediately, without treating Payment gate as a filter.
3. Keep Reception Current step, Next action, Payment gate, and counts synchronized to the same invoice and flow stage after start, cancel, waive, or mark-not-required.
4. Drop Billing payables when payment is not required, the encounter is cancelled, or charges are voided or waived on existing authorized paths.
5. Do not add Reception controls that open `/billing` or collect payment; keep loading, empty, error, success, and validation feedback on start and sync failures.

## Constraints

- Reuse encounter creation, `persistConsultationBilling`, invoice contracts, realtime groups, authorization, localization, and design-system components.
- Keep RBAC/ABAC authoritative; omit unauthorized UI. Do not invent stages or duplicate invoice engines.

## Acceptance Criteria

- R1–R2: Required Start-OPD consultation payables appear in Billing with matching patient, encounter, amount, and status.
- R3–R4: Reception and Billing stay aligned after create, cancel, waive, and not-required outcomes.
- R5: Reception never opens Billing or mutates payment; states stay visible.
- Add or update OPD billing-sync and Billing workspace tests; run backend tests and Flutter analysis.

## Relevant Files

- `backend/src/modules/opd-flow/services/opd-flow.service.js`
- `backend/src/modules/billing/services/billing.service.js`
- `frontend/lib/shared/components/opd_encounter_dialog.dart`
- `frontend/lib/features/billing/presentation/controllers/`
- `frontend/lib/features/reception/`
- `backend/src/tests/modules/opd-flow/`
