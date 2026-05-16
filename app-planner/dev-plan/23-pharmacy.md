# 23 - Pharmacy Module

## Goal
Manage formulary, drugs, batches, stock visibility, prescriptions, pharmacy orders, dispensing, returns/adjustments where supported, billing/payment gates, and medication handoff from OPD, IPD, emergency, and discharge.

## Source of Truth
- Use `app-write-up.md` for pharmacy scope.
- Use `opd-flow.md` for prescription/pharmacy routing and flexible payment timing.
- Use `ipd-flow.md` for inpatient medication orders, discharge medicines, billing, and pharmacy clearance.
- Use `01-policy.md` for simple modal actions, catalog-driven selection, role access, and partial UI updates.

## Backend Routes To Align With
- `/api/v1/pharmacy`
- `/api/v1/drugs`
- `/api/v1/drug-batches`
- `/api/v1/formulary-items`
- `/api/v1/pharmacy-orders`
- `/api/v1/pharmacy-order-items`
- `/api/v1/dispense-logs`
- `/api/v1/inventory-items`
- `/api/v1/inventory-stocks`

## Implementation Scope
1. Pharmacy queue for waiting payment/authorization, ready to dispense, partial stock, dispensed, returned/cancelled, and discharge medicine pending.
2. Prescription detail with patient/encounter context, medicines, dose instructions, stock/batch availability, payer/payment status, and dispensing history.
3. Modal actions for dispense, partial dispense, substitute where permitted, hold, cancel, return, and print receipt/medication instructions.
4. Formulary/drug search and stock visibility using configured catalog and inventory data.
5. Discharge pharmacy clearance connected to discharge workflow.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a pharmacy order queue with simple filters: pending payment, ready, partial stock, urgent, discharge, completed. |
| Prescription view | Show medicines in readable lines: drug, strength, dose, route, frequency, duration, quantity, instructions, stock state, and dispense state. |
| Dispensing | Use a modal to confirm quantities, batches, substitutions, notes, payment clearance, and receipt/label options. |
| Flexibility | Prescription data should support formulary items and permitted free-text/non-formulary instructions without making routine prescribing slow. |
| Billing | Payment blockers are visible; cashier actions remain in billing unless pharmacy has permitted payment collection. |
| Responsiveness | Mobile supports quick queue and dispense modal; desktop supports queue plus detail panel. |

## Flow Synchronization Rules
- Prescriptions must attach to the correct OPD encounter, IPD admission, emergency case, or discharge record.
- Dispensing must update pharmacy order status, stock, billing/receipt state where applicable, and source encounter/admission/discharge queue.
- Partial dispensing must keep remaining items visible without closing the pharmacy order incorrectly.
- Discharge medicines must update discharge pharmacy clearance.

## Access and State Rules
- Pharmacists and pharmacy staff dispense according to role and facility scope.
- Clinicians can view prescription/dispense status where permitted but should not get pharmacy-only stock actions unless allowed.
- After mutation, refresh only the pharmacy order row, stock/batch indicator, source patient row, clearance item, and notification badge.

## Reports and Printing
Medication labels, prescription printouts, dispense receipts, return notes, and discharge medicine lists must use generated report templates from `35-reports-audit.md`.

## Done Criteria
- Pharmacy queue is easy to search and act on.
- Prescriptions remain flexible but simple.
- Dispensing, stock, billing, and discharge clearance stay synchronized.
- Pharmacy printouts are generated, professional, and permission-aware.

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
