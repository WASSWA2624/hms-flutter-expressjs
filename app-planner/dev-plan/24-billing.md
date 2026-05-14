# 24 - Billing and Cashier

## Goal
Manage invoices, invoice items, payments, receipts, refunds, adjustments, and cashier reconciliation.

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
1. Cashier worklist.
2. Invoice creation/review.
3. Payment capture modal.
4. Receipt view/print/export where supported.
5. Refund and adjustment workflows.
6. Shift close/day close indicators.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Cashier actions stay inside billing/cashier module.
- Invoice and payment states are clear.
- Financial actions are tightly permission-gated.
- Receipts/reconciliation are traceable.

## Rule References
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
- `frontend/app-planner/app-rules/localization_i18n.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
