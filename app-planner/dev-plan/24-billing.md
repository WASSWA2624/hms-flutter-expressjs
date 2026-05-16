# 24 - Billing and Cashier Module

## Goal
Manage invoices, invoice items, cashier payments, receipts, refunds, billing adjustments, deposits, service billing gates, insurance/sponsor visibility, shift close, day close, and reconciliation using simple payment workflows.

## Source of Truth
- Use `app-write-up.md` for billing and cashier responsibilities.
- Use `opd-flow.md` for flexible OPD payment timing before or after consultation, lab, radiology, pharmacy, and procedures.
- Use `ipd-flow.md` for admission deposits, rolling inpatient charges, insurance authorization, final clearance, refunds, and discharge billing.
- Use `01-policy.md` for modal-based payments, role access, generated receipts, and targeted state refresh.

## Backend Routes To Align With
- `/api/v1/billing`
- `/api/v1/invoices`
- `/api/v1/invoice-items`
- `/api/v1/payments`
- `/api/v1/refunds`
- `/api/v1/billing-adjustments`
- `/api/v1/pricing-rules`
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
