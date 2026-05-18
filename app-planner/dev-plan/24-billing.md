# 24 - Billing and Cashier Module

## Goal
Manage invoices, invoice items, cashier payments, receipts, refunds, billing adjustments, deposits, service billing gates, insurance/sponsor visibility, shift close, day close, and reconciliation using simple payment workflows.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for billing and cashier responsibilities.
- Use `opd-flow.md` for flexible OPD payment timing before or after consultation, lab, radiology, pharmacy, and procedures.
- Use `ipd-flow.md` for admission deposits, rolling inpatient charges, insurance authorization, final clearance, refunds, and discharge billing.
- Use `01-policy.md` for modal-based payments, role access, generated receipts, and targeted state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/invoices`
- `/api/v1/invoice-items`
- `/api/v1/payments`
- `/api/v1/refunds`
- `/api/v1/billing-adjustments`
- `/api/v1/pricing-rules`
- `/api/v1/coverage-plans`
- `/api/v1/insurance-claims`
- `/api/v1/pre-authorizations`
- `/api/v1/shift-closes`
- `/api/v1/day-closes`

## Implementation Scope
1. Billing workspace for invoices, pending payments, deposits, refunds, cashier shifts, day close, and reconciliation.
2. Simple patient billing view showing open invoice, paid amount, balance, payer, payment status, and service clearance.
3. Modal actions for receive payment, add deposit, process refund, adjust invoice where permitted, cancel/void, print receipt, and close shift/day.
4. Billing gate integration with OPD, lab, radiology, pharmacy, procedures, IPD admission, theater, discharge, mortuary, and other billable services.
5. Payment method support using configured methods where backend supports them: cash, card, mobile money, bank transfer, insurance, sponsor/credit, or other configured methods.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use simple queues: awaiting payment, partially paid, cleared, refund pending, shift close, day close. |
| Payment modal | Show patient, invoice, amount due, amount received, method, reference, payer, change/balance, and receipt option. |
| Invoice detail | Keep line items readable. Do not expose internal pricing-rule technicalities to cashier users. |
| Service clearance | Clearly show whether a service is cleared, deferred, insured, pending authorization, or blocked. |
| Receipts | Use generated receipt output, not UI print. |
| Responsiveness | Mobile supports cashier payment modal; desktop supports invoice queue plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: invoice list/table, patient context header, charge item form, payment modal, refund modal, deposit panel, billing gate badge, receipt/report action, and cashier shift/day-close cards.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: invoices, invoice items, payments, refunds, deposits, billing adjustments, coverage/claim status, OPD/IPD gates, receipts, reports, and audit events must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- OPD and IPD billing gates must be flexible: payment before service, after service, deposit, insurance authorization, deferred emergency billing, or discharge billing based on policy/backend.
- Payment success must update the invoice, service clearance, source queue, receipt state, and notification badge.
- Refunds and adjustments must be permission-gated and auditable.
- Shift/day close must not block unrelated patient care screens.

## Access and State Rules
- Cashier/billing users receive payments and refunds according to role and shift permissions.
- Clinical users see payment/clearance status only where relevant; they should not receive cashier controls unless permitted.
- After payment/refund/adjustment, refresh only the invoice, payment row, source service order, patient status badge, and queue counters.

## Reports and Printing
Invoices, receipts, refund notes, deposit slips, statement of account, shift close, day close, and discharge billing clearance must use the generated report template from `35-reports-audit.md` with facility header, receipt/reference number, cashier, payer, payment method, amount, and page-safe layout.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<BillingItem>` with invoice number, patient/payer, source encounter/admission/order, amount due, status, cashier/shift, date, and next action. Attach `AppSearchBar`; replace ad hoc search fields during completion. |
| Detail/display | Use invoice/payment detail with line items, charges, deposits, refunds, receipts, payer/coverage, shift/day-close links, and audit-safe activity. |
| CRUD/UI actions | Use `AppDialog` for payment, deposit, refund request/approval where short, invoice adjustment, receipt print, coverage check, void/cancel confirmation, and shift close confirmation. |
| RBAC/ABAC | Gate with billing read/write, financial approve, evidence export, tenant/facility/cashier scope, and backend authorization. |
| Partial refresh | After billing mutation update only invoice/payment/refund row, OPD/IPD/order billing gate, cashier totals, receipt/report preview, claim state, and notification count. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Payment collection is simple and fast.
- OPD/IPD/lab/radiology/pharmacy/discharge billing gates update correctly.
- Cashier actions are modal-based, permission-aware, and auditable.
- Receipts and invoices are generated from data and can span multiple pages.

## Rule References

### Product and flow references
- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

### Frontend rules
- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/state_management.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
