# 23 - Pharmacy Module

## Goal
Manage formulary, drugs, batches, stock visibility, prescriptions, pharmacy orders, dispensing, returns/adjustments where supported, billing/payment gates, and medication handoff from OPD, IPD, emergency, and discharge.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for pharmacy scope.
- Use `opd-flow.md` for prescription/pharmacy routing and flexible payment timing.
- Use `ipd-flow.md` for inpatient medication orders, discharge medicines, billing, and pharmacy clearance.
- Use `01-policy.md` for simple modal actions, catalog-driven selection, role access, and partial UI updates.


## Current Implementation Baseline
- Current frontend status: `frontend/lib/features/pharmacy/` already has DTOs, repository, entities, controller, and `pharmacy_workspace_page.dart` using `AppWorkspace`, `AppListTable`, shared dialogs/forms, report actions, print templates, and async states.
- Required adjustment: extend this pharmacy workspace and inventory/order/dispense flows; do not create duplicate drug catalog, dispense, or print components when shared tables/dialogs/templates can be reused.
- UI similarity rule: pharmacy orders, batches, stock, dispensing, adverse events, and generated documents must use shared list/search/dialog/report patterns and targeted order/stock/dispense refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/drugs`
- `/api/v1/drug-batches`
- `/api/v1/formulary-items`
- `/api/v1/pharmacy-orders`
- `/api/v1/pharmacy-order-items`
- `/api/v1/dispense-logs`
- `/api/v1/adverse-events`
- `/api/v1/inventory-items`
- `/api/v1/inventory-stocks`
- `/api/v1/invoices`
- `/api/v1/payments`

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

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: prescription/order row, patient context header, drug/formulary selector, batch/stock selector, dispensing form, return/correction modal, medication handoff panel, and pharmacy status badge.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: prescriptions, pharmacy order items, stock/batch visibility, dispense logs, billing gate, medication administration handoff, discharge medicines, notifications, reports, and encounter/admission links must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

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

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppListTable<PharmacyOrder>` with order/prescription number, patient, source encounter/admission, medicine count, stock/billing/dispense status, priority, and next action. Use `AppSearchBar` for patient, order, drug, source, status, date, and priority filters. |
| Detail/display | Use patient/order detail with prescription items, formulary/stock availability, batches, substitutions, billing gate, dispense log, returns, and medication handoff. |
| CRUD/UI actions | Use `AppDialog` for dispense, partial dispense, substitution, return, stock warning acknowledgement, billing gate check, counseling note, cancellation, and prescription/receipt print. |
| RBAC/ABAC | Gate with pharmacy permissions, operations stock visibility where needed, clinical read where permitted, facility/pharmacy scope, and backend authorization. |
| Partial refresh | After pharmacy action update only pharmacy row, stock batch quantities, source encounter/admission/pharmacy status, billing badge, medication handoff, receipt/report preview, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


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
