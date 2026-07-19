# Restrict the Reception Payment Gate to Pending Payments

Update `/reception?section=payment-gate` so the Payment gate is a focused worklist containing only patients whose consultation payment is still outstanding.

## Context

The Payment gate currently selects open OPD flows primarily by workflow stage. A paid or otherwise resolved payment can therefore remain visible when the flow stage has not yet synchronized. Follow `prompts/.cursor/prompt.mdc`.

## Requirements

1. Include an open, non-terminal OPD flow only when its normalized consultation billing state is **payment required**. This includes pending, issued/invoiced, and partially paid consultations.
2. Exclude flows whose consultation payment is paid, cleared, successful, approved, completed and settled, waived/not required, or otherwise not outstanding—even if their stage is still `WAITING_CONSULTATION_PAYMENT`.
3. Reuse the existing billing-state normalization as the source of truth. Do not duplicate raw-status mappings or infer a pending payment from workflow stage alone when authoritative payment data says it is resolved.
4. Apply the same membership rule to the table, mobile cards, Payment gate tab count, Reception unique-patient badge contribution, search, filters, sorting, and column settings.
5. Keep the displayed consultation fee, normalized payment status/detail, and authorized payment action accurate. After a successful payment or refresh, remove the patient from the worklist as soon as synchronized billing data marks the payment resolved.

## Constraints

- Reuse existing OPD synchronization, billing helpers, terminal-state helpers, authorization, localization, and design-system components.
- Do not change backend contracts, payment processing, clinical workflow transitions, or unrelated reception tabs.
- Do not treat missing or unknown billing data as a pending payment.
- Support loading, empty, error, light/dark theme, and mobile/tablet/desktop states.

## Acceptance Criteria

- Only open OPD flows with normalized billing state `required` appear in Payment gate.
- Paid, settled, not-required, and unknown-payment flows are absent even when their stage still indicates consultation payment.
- Pending and partially paid flows remain visible with the correct amount, status, and authorized payment action.
- Table/card results, search, filters, settings, tab count, and Reception unique-patient badge all use the same membership rule.
- Add or update domain and reception widget tests for pending, partial, paid-but-stale-stage, not-required, unknown, terminal, count, and post-payment refresh cases; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/domain/entities/reception_entities.dart`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/opd_actions/opd_billing_state.dart`
- `frontend/test/features/reception/`