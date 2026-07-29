# Billing & Sections — Shared Rules

Canonical rules for every prompt under `prompts/billing-and-sections/`. Tab prompts refine financial and section focus; they must not contradict this file or `prompts/.cursor/prompt.mdc`.

## Prompt compliance (`prompts/.cursor/prompt.mdc`)

Every tab prompt must:

- Stay under 1001 words; begin with an H1 and a one-sentence objective.
- Include `Context`, `Requirements`, `Constraints`, `Acceptance Criteria`, and `Relevant Files`.
- Number requirements; make acceptance criteria observable and trace each to numbered requirements (e.g. `AC2 (Req 3)`).
- Use imperative language; put shared definitions here—tab prompts reference this file instead of restating everything.
- State `Optional enhancements: none` unless a tab truly needs a named, non-blocking enhancement.
- Name permission, loading, empty, error, success, validation, and visible-feedback states for authorized paths.
- Name verification: frontend + backend tests covering integration, reuse, authorization, synchronization, UI states, viewports, themes, and flat sections.

## Objectives

1. Every financially relevant action across HMS must create, update, settle, or reconcile a record in the **Billing** module. Module-local “paid” flags without a Billing ledger entry are defects.
2. Titled **section** chrome must stay flat: sections may be siblings under a layout parent, never nested inside another section.

## Financial action classes

| Class | Examples | Must result in |
| --- | --- | --- |
| Create charge | Order lab/radiology/pharmacy/consult/procedure/bed/day, mortuary fees | Invoice line(s) via Billing / clinical-request billing |
| Settle | Receive payment, co-pay collect, deposit apply | Payment row + recalculated balances |
| Adjust | Discount, waive, write-off, credit note, price correction | Adjustment with approval when required |
| Reverse | Refund, payment reversal, void invoice, dispense return | Reversal/credit linked to original; no orphan negatives |
| Defer | Emergency deferral, pay-later gate | Explicit outstanding / deferred status still in Billing |
| Not billable | True no-charge protocol, internal ops | Audited `NOT_BILLED` / `NOT_REQUIRED` / `NO_CHARGE` |

## System of record

- Patient/clinical revenue: `backend/src/modules/billing/` + `backend/src/lib/billing/*`.
- Request-time clinical charges: `clinical-request-billing.js` (idempotent).
- Pricing: `price-resolver.js`. Insurance splits: `coverage-split.js`. Money math: `financials.js`.
- Frontend canonical UX: billing workspace dialogs + shared helpers (`clinical_request_billing_*`, `patient_billing_quick_dialog`, pharmacy/OPD billing helpers).
- Commercial SaaS invoices (subscriptions) stay on the subscriptions invoice path and must not corrupt patient ledgers.

## Payment methods

Normalize with shared validators. Full set: `CASH`, `CREDIT_CARD`, `DEBIT_CARD`, `PREPAID_CARD`, `GIFT_CARD`, `VOUCHER`, `BANK_CHECK`, `MOBILE_MONEY`, `BANK_TRANSFER`, `INSURANCE`, `OTHER`. UI exposes facility-enabled subset (`billingPaymentMethods`). Collection, refund, and reconciliation must accept the same normalized methods.

## Consistency rules

- Backend remains authoritative; frontend hides unauthorized financial controls (see `prompts/ui-permissions/_shared-rules.md`).
- Post-mutation sync is mandatory: lists, gates, badges, and balances update without manual refresh.
- Idempotency keys required on payment and charge creation to prevent duplicates.
- Do not duplicate Billing logic inside clinical modules; call shared services.
- Flow ownership in `.cursor/flows/*` still applies (e.g. Billing owns payment gates; ICU clinical actions are not cashier-driven).

## Leakage checklist (every tab)

1. Fulfilled service with no invoice line
2. Payment taken outside Billing
3. Refund/adjustment without ledger row
4. Insurance remittance not applied to patient balance
5. Discharge/dispense/proceed despite unpaid required charges (unless deferred in Billing)
6. Double charge from retry or dual UI entry points
7. Balance shown in module UI ≠ Billing balance

## Flat sections (no nesting)

Section components are titled chrome that wraps a content region:

- `AppScreenSection`
- Titled `AppSectionPanel` (title set)
- `AppWorkspaceDetailPanel`
- Feature wrappers that build any of the above

Rules:

- A section’s child tree must **not** contain another section component.
- Sibling sections may align vertically, horizontally, in grids, or responsive wraps under a **non-section** parent (`Column`, `Row`, `Wrap`, `Flex`, workspace/dialog body).
- Inventory untitled content groups that deserve titled chrome; wrap each in one section without nesting.
- Prefer promoting nested sections to siblings over collapsing distinct groups into one opaque section.
- Lists, tables, form fields, chips, and untitled `AppContentPanel` / tone panels inside a section are fine; nested *sections* are not.
- Untitled `AppSectionPanel` / `AppContentPanel` used only as tone/padding chrome (no title) are not sections for nesting rules—but do not use them to smuggle nested titled sections.

## Verification (every tab prompt)

Tests must prove posting, no-bypass, status parity, idempotency, authorization, and flat sections, plus:

- Integration with Billing routes/services
- Reuse of shared billing helpers (no second engine)
- Authorization (RBAC ∩ subscription ∩ ABAC)
- Post-mutation synchronization / realtime
- Authorized UI states
- Representative mobile and desktop viewports
- Light and dark themes
- Widget-tree / finder checks that no section contains another section on this tab

## Related

- `prompts/.cursor/prompt.mdc`
- `prompts/ui-permissions/_shared-rules.md`
- `.cursor/api-contract.mdc`, `.cursor/flows/*`
- `backend/src/lib/billing/`
- `frontend/lib/features/billing/`
- `frontend/lib/shared/layout/app_screen_section.dart`
- `frontend/lib/shared/components/app_content_panel.dart`
- `frontend/lib/shared/layout/app_workspace.dart`
