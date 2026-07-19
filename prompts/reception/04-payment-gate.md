# Show All Outstanding OPD Charges at Reception

Update `/reception?section=payment-gate` into a read-only follow-up worklist for patients with any outstanding charge linked to an OPD encounter.

## Context

Receptionists coordinate patient movement but do not process or modify payments. Outstanding charges may cover consultation, laboratory, radiology, medicines, procedures, or other billed OPD services. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. Include patients with at least one pending, issued, unpaid, or partially paid OPD charge, regardless of the encounter’s current workflow stage.
2. Aggregate outstanding charges by patient and encounter without duplicate rows. Show patient identity, encounter reference, departments/services owed, per-service outstanding amounts, currency, and total outstanding.
3. Exclude paid, settled, cancelled, voided, waived, not-required, and unknown charges. Remove a patient when no outstanding OPD charge remains after synchronization.
4. Keep the worklist read-only. Row/card interaction may reveal a read-only detail panel or dialog, but must not navigate, collect payment, edit, delete, waive, cancel, or expose clinical results.
5. Apply identical data to search, service/status filters, sorting, responsive cards, column settings, tab count, and Reception’s unique-patient badge.

## Constraints

- Reuse authoritative billing/invoice data, normalization, OPD links, authorization, localization, and design-system components.
- Render only fields permitted to reception; hide unauthorized data and controls.
- Do not change billing state, backend contracts, or unrelated workflows.
- Support loading, empty, error, refresh-success, themes, and responsive states.

## Acceptance Criteria

- R1–R3: Consultation, lab, radiology, medicine, and other outstanding OPD charges appear accurately; resolved-only patients do not.
- R4: No Payment gate interaction mutates data or routes away.
- R5: Details, totals, filters, counts, and badges remain consistent after refresh.
- Add aggregation, authorization, widget, and responsive tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/`
- `frontend/lib/features/billing/`
- `frontend/lib/shared/opd_actions/`
- `frontend/test/features/reception/`