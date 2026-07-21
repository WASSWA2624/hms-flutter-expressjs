# Sync Payment-Due OPD Visits into Billing

Ensure every **Payment due** visit has a matching unpaid invoice in Billing **Awaiting payment** and **All billing work items**. Follow prompts/.cursor/prompt.mdc and .cursor/flows/opd-flow.mdc.

## Context

Reception can show **Payment due** while Billing omits that patient, risking revenue leakage. Payment gate and Billing must share the same outstanding OPD charges.

## Requirements

1. Treat **Payment due** as an open OPD/Emergency visit waiting on unpaid consultation or other required OPD charges (WAITING_CONSULTATION_PAYMENT or equivalent).
2. When a visit enters Payment due, create or retain the unpaid invoice so Billing lists include patient, encounter, amount, and currency.
3. Keep Reception Payment gate on the same outstanding charges; do not invent a second billing source.
4. After encounter start, fee change, payment, cancel, close, or supersede, synchronize OPD Current step, Payment gate, Billing queues, counts, and badges.
5. Cover permission, loading, empty, validation, error, success, and mismatch-recovery feedback; omit unauthorized payment collection from Reception.

## Constraints

- Reuse OPD billing contracts, invoice engine, authorization, localization, theme tokens, and design-system components.
- Billing remains the payment mutation surface; do not invent stages or bypass backend billing rules.

## Acceptance Criteria

- R1–R3: Every Payment-due visit appears in Billing with matching amounts; Payment gate stays consistent.
- R4: Mutations update OPD labels and billing lists without orphan Payment-due rows.
- R5: Authorization and UI states tested; run Flutter analysis and billing/OPD tests.

## Relevant Files

- frontend/lib/shared/opd_actions/
- frontend/lib/features/reception/
- frontend/lib/features/billing/
- backend/src/modules/opd-flow/
- backend/src/lib/billing/
