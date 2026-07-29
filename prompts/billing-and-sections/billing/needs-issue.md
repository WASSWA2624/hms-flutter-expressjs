# Billing & Sections Scan — Billing workspace / Needs issue (`/billing?…=needs-issue`)

Deep-scan this tab for billing leakage and nested section chrome: wire every financial action into Billing, and keep titled sections flat (siblings only—never nested).

## Context

- Screen inventory: `screens/billing.md` (reachable controls).
- Target tab: **Needs issue** (`needs-issue`).
- Feature code: `frontend/lib/features/billing/`
- Module entitlement: `billing-payments`
- Billing system of record: `frontend/lib/features/billing/`, `backend/src/modules/billing/`, `backend/src/lib/billing/` (clinical-request billing, price-resolver, coverage-split, financials, realtime).
- Payment methods: facility-enabled subset of shared validators (`billingPaymentMethods`); full set in shared rules.
- Section chrome: `AppScreenSection`, titled `AppSectionPanel`, `AppWorkspaceDetailPanel` (and wrappers). Flat-section rules in shared rules.
- Financial focus for this tab: Primary focus: invoice issuance from draft/unbilled clinical charges without losing line provenance or creating duplicates. This is the Billing system of record. Validate issue, receive payment, refund, adjust, waive, void, credit note, claim handoff, approval, dunning, shift/day close, ledger, and reconciliation end-to-end with supported payment methods and realtime UI sync. Tab role: Invoices awaiting issue; Issue action needs billing:write.
- Shared rules: `prompts/billing-and-sections/_shared-rules.md`. Follow `prompts/.cursor/prompt.mdc`.
- Permissions remain enforced (`prompts/ui-permissions/`); do not weaken gates while wiring Billing or flattening sections.

## Requirements

1. Inventory every action reachable from this tab (chrome, rows, next-actions, detail, nested dialogs/workflows) that can request a paid service/product, collect payment, issue/generate an invoice, take a deposit/prepayment, refund, reverse, adjust, write off, waive, discount, issue a credit note, split insurance/co-pay, or change an outstanding balance. Classify each as create-charge, settle, adjust, reverse, defer, or not-billable (explicit `NOT_BILLED` / `NOT_REQUIRED` / `NO_CHARGE` with audit).
2. For each billable action, verify frontend and backend both call shared Billing APIs/services (no parallel cash ledgers, local-only paid flags, or module-private amount fields that never post). Wire gaps through existing billing controllers, clinical-request billing, receive-payment, adjustment, and claims handoff paths—reuse, do not fork.
3. Enforce realtime consistency: successful mutations must create/update Billing records immediately; UI lists, badges, payment gates, and balances on this tab must reflect backend state without manual refresh (providers/realtime/invalidation already used by Billing).
4. Apply supported payment methods end-to-end where collection occurs: validate method, amount, idempotency keys, partial payments, refunds/reversals, and reconciliation so duplicates and orphan receipts cannot occur.
5. Close leakage classes on this tab: missing invoices, unbilled fulfilled services, double charges, unpaid required care progressing when policy forbids, discharge/dispense without clearance, and claim settlements that never update patient responsibility.
6. UX: keep payment/billing affordances clean—minimal copy, only task-needed amounts/status/method, progressive disclosure for ledger detail, consistent design-system payment dialogs; remove redundant pay/issue entry points that duplicate Billing.
7. Preserve authorized UI states: permission-filtered chrome, loading, empty, error/retry, validation, success, and visible feedback. Honor RBAC ∩ subscription ∩ ABAC; unauthorized financial controls must not render.
8. Flat sections: inventory every section on this tab and dialogs from it; un-nest so no section contains another—siblings only under non-section parents (`Column`/`Row`/`Wrap`/`Flex`/workspace body). Identify content that needs sectioning; wrap each group without nesting; prefer promoting nested sections to siblings.
9. Add/update tests under `frontend/test/features/billing/` and `backend/src/tests/` proving (a) billable action posts a Billing record, (b) no bypass, (c) payment status parity with Billing, (d) idempotent replay, (e) unauthorized users cannot collect/adjust, (f) no section-in-section nesting on authorized UI. Cover integration, reuse, authorization, sync, UI states, one mobile + one desktop viewport, light + dark.

## Constraints

- Scope: this tab’s UI tree, nested dialogs opened from it, and the backend handlers those actions call. Do not redesign unrelated workspaces.
- Reuse Billing module services, clinical-request billing, price-resolver, coverage-split, receive-payment/adjustment dialogs, and feature billing helpers; no second billing engine.
- Reuse existing section chrome (`AppScreenSection`, titled `AppSectionPanel`, `AppWorkspaceDetailPanel`); do not invent a parallel section widget.
- Optional enhancements: none. Do not expand into unrelated refactors.
- Theme tokens; responsive mobile/tablet/desktop; backend RBAC/ABAC authoritative; no secrets in tests.
- Follow `.cursor/flows/*` ownership: Billing owns payment; clinical modules must not invent cashier logic.

## Acceptance Criteria

- AC1 (Req 1): Every financially relevant atom on this tab is inventoried and classified (billable vs explicit not-billable).
- AC2 (Req 2-5): No billable action bypasses Billing; fulfilled paid services have traceable invoice/payment/adjustment rows; duplicates and leakage paths identified in the scan are fixed.
- AC3 (Req 3-4): After mutations, this tab and Billing show the same payment/balance status without manual refresh; supported methods work for collect/refund/reconcile where applicable.
- AC4 (Req 6-7): Payment UX stays minimal and consistent; unauthorized financial controls absent; loading/empty/error/success/validation/feedback remain observable.
- AC5 (Req 8): No nested sections on this tab; content that needs sectioning lives in sibling sections under non-section layout parents.
- AC6 (Req 9): Frontend and backend tests prove posting, no-bypass, cross-module status parity, idempotency, authorization, and flat (non-nested) section layout for representative flows on this tab.

## Relevant Files

- `screens/billing.md`
- `frontend/lib/features/billing/`
- `frontend/lib/shared/clinical_actions/clinical_request_billing_state.dart`
- `frontend/lib/shared/patient_actions/patient_billing_quick_dialog.dart`
- `frontend/lib/shared/layout/app_screen_section.dart`
- `frontend/lib/shared/components/app_content_panel.dart`
- `frontend/lib/shared/layout/app_workspace.dart`
- `backend/src/modules/billing/`
- `backend/src/modules/billing-adjustment/`
- `backend/src/lib/billing/`
- `backend/src/lib/billing/clinical-request-billing.js`
- `backend/src/lib/billing/financials.js`
- `prompts/billing-and-sections/_shared-rules.md`
- `prompts/.cursor/prompt.mdc`
- `frontend/test/features/billing/`
- Matching `backend/src/tests/` for handlers touched by this tab
