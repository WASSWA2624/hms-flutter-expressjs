# Instant Billing Update After Receive Payment

Make Billing **Receive payment** update the acting user immediately and persist paid state without a full workspace reload. Follow `prompts/.cursor/prompt.mdc` and `frontend/.cursor/instant_ui_sync.mdc`.

## Context

Receive payment succeeds, but Billing status, queues, and OPD Payment-due labels lag before the UI shows paid.

## Requirements

1. On successful **Receive payment**, immediately patch the Billing work item, queues, amounts, statuses, counts, and badges from the mutation response or typed local delta—no blanket GET wait.
2. Persist payment and invoice state in the same mutation; emit standard billing realtime events so other authorized sessions converge.
3. Synchronize linked OPD consultation payment fields and Current step when payment clears Payment due; update Reception Payment gate in the same sync pass.
4. Keep loading, validation, error, success, and empty-queue feedback; prevent duplicate submission while saving.
5. On cancel or failure, apply no optimistic patch; show the failure and leave unpaid state intact.

## Constraints

- Reuse Billing controllers, invoice/payment contracts, authorization, localization, theme tokens, and design-system components.
- Keep Backend RBAC/ABAC authoritative; omit unauthorized payment actions.
- Do not invent payment statuses or bypass billing recalculation rules.

## Acceptance Criteria

- R1–R3: After success, Billing and linked OPD/Payment gate show paid/cleared state in the same frame or next rebuild.
- R4–R5: Loading and failure states behave correctly; failed receives leave unpaid rows unchanged.
- Add controller patch, realtime, authorization, and widget tests; run Flutter analysis and billing tests.

## Relevant Files

- `frontend/lib/features/billing/`
- `frontend/lib/features/reception/`
- `backend/src/modules/billing/`
- `backend/src/modules/opd-flow/`
