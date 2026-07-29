# Billing Integration Scan — Physiotherapy workspace / Active plans (`/physiotherapy?…=active-plans`)

Deep-scan every financially relevant action on this tab (frontend + backend) and ensure each charge, payment, refund, adjustment, claim, waiver, deposit, or balance change creates, updates, settles, or reconciles a Billing record—eliminating revenue leakage and bypasses.

## Context

- Screen inventory: `screens/physiotherapy.md` (reachable controls).
- Target tab: **Active plans** (`active-plans`).
- Feature code: `frontend/lib/features/physiotherapy/`
- Module entitlement: `physiotherapy`
- Billing system of record: `frontend/lib/features/billing/`, `backend/src/modules/billing/`, `backend/src/lib/billing/` (clinical-request billing, price-resolver, coverage-split, financials, realtime).
- Supported payment methods (normalize via shared validators): `CASH`, `CREDIT_CARD`, `DEBIT_CARD`, `PREPAID_CARD`, `GIFT_CARD`, `VOUCHER`, `BANK_CHECK`, `MOBILE_MONEY`, `BANK_TRANSFER`, `INSURANCE`, `OTHER` (UI may expose the facility-enabled subset from `billingPaymentMethods`).
- Financial focus for this tab: Therapy session packs, individual sessions, missed-session fees (if policy), and referral acceptance that starts a paid plan must create Billing records and settle before or per package rules. Tab role: Active therapy plans.
- Shared rules: `prompts/billing-integration/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc`.
- Permissions remain enforced (`prompts/ui-permissions/`); do not weaken gates while wiring Billing.

## Requirements

1. Inventory every action reachable from this tab (chrome, rows, next-actions, detail, nested dialogs/workflows) that can request a paid service/product, collect payment, issue/generate an invoice, take a deposit/prepayment, refund, reverse, adjust, write off, waive, discount, issue a credit note, split insurance/co-pay, or change an outstanding balance. Classify each as create-charge, settle, adjust, reverse, defer, or not-billable (explicit `NOT_BILLED` / `NOT_REQUIRED` / `NO_CHARGE` with audit).
2. For each billable action, verify frontend and backend both call shared Billing APIs/services (no parallel cash ledgers, local-only paid flags, or module-private amount fields that never post). Wire gaps through existing billing controllers, clinical-request billing, receive-payment, adjustment, and claims handoff paths—reuse, do not fork.
3. Enforce realtime consistency: successful mutations must create/update Billing records immediately; UI lists, badges, payment gates, and balances on this tab must reflect backend state without manual refresh (providers/realtime/invalidation already used by Billing).
4. Apply supported payment methods end-to-end where collection occurs: validate method, amount, idempotency keys, partial payments, refunds/reversals, and reconciliation so duplicates and orphan receipts cannot occur.
5. Close leakage classes on this tab: missing invoices, unbilled fulfilled services, double charges, unpaid required care progressing when policy forbids, discharge/dispense without clearance, and claim settlements that never update patient responsibility.
6. UX: keep payment/billing affordances clean—minimal copy, only task-needed amounts/status/method, progressive disclosure for ledger detail, consistent design-system payment dialogs; remove redundant pay/issue entry points that duplicate Billing.
7. Preserve authorized UI states: permission-filtered chrome, loading, empty, error/retry, validation, success, and visible feedback. Honor RBAC ∩ subscription ∩ ABAC; unauthorized financial controls must not render.
8. Add/update tests: frontend widget/unit tests under `frontend/test/features/physiotherapy/` and backend tests under `backend/src/tests/` proving (a) billable action posts a Billing record, (b) bypass paths are gone, (c) payment status matches across module UI and Billing, (d) idempotent replay does not duplicate, (e) unauthorized users cannot collect/adjust. Cover integration, reuse of billing helpers, authorization, sync, UI states, one mobile + one desktop viewport, light + dark.

## Constraints

- Scope: this tab’s UI tree, nested dialogs opened from it, and the backend handlers those actions call. Do not redesign unrelated workspaces.
- Reuse Billing module services, clinical-request billing, price-resolver, coverage-split, receive-payment/adjustment dialogs, and feature billing helpers; no second billing engine.
- Optional enhancements: none. Do not expand into unrelated refactors.
- Theme tokens; responsive mobile/tablet/desktop; backend RBAC/ABAC authoritative; no secrets in tests.
- Follow `.cursor/flows/*` ownership: Billing owns payment; clinical modules must not invent cashier logic.

## Acceptance Criteria

- AC1 (Req 1): Every financially relevant atom on this tab is inventoried and classified (billable vs explicit not-billable).
- AC2 (Req 2-5): No billable action bypasses Billing; fulfilled paid services have traceable invoice/payment/adjustment rows; duplicates and leakage paths identified in the scan are fixed.
- AC3 (Req 3-4): After mutations, this tab and Billing show the same payment/balance status without manual refresh; supported methods work for collect/refund/reconcile where applicable.
- AC4 (Req 6-7): Payment UX stays minimal and consistent; unauthorized financial controls absent; loading/empty/error/success/validation/feedback remain observable.
- AC5 (Req 8): Frontend and backend tests prove posting, no-bypass, cross-module status parity, idempotency, and authorization for representative flows on this tab.

## Relevant Files

- `screens/physiotherapy.md`
- `frontend/lib/features/physiotherapy/`
- `frontend/lib/features/billing/`
- `frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart`
- `frontend/lib/shared/patient_actions/patient_billing_quick_dialog.dart`
- `backend/src/modules/physiotherapy/`
- `backend/src/lib/billing/`
- `backend/src/lib/billing/clinical-request-billing.js`
- `backend/src/lib/billing/financials.js`
- `prompts/billing-integration/_shared-rules.md`
- `prompts/.cursor/prompt.mdc`
- `frontend/test/features/physiotherapy/`
- Matching `backend/src/tests/` for handlers touched by this tab
