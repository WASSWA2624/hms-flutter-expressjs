# 21 - Laboratory Module

## Goal
Manage lab test catalog, panels, orders, samples, results, quality control, billing/authorization gates, result delivery, and return-to-doctor review where required.

## Source of Truth
- Use `app-write-up.md` for laboratory scope.
- Use `opd-flow.md` for OPD lab ordering, billing flexibility, sample/result workflow, and doctor result review.
- Use `ipd-flow.md` for inpatient lab orders, service routing, result review, and billing/authorization timing.
- Use `01-policy.md` for catalog-driven requests, modal actions, role access, and partial UI refresh.

## Backend Routes To Align With
- `/api/v1/lab`
- `/api/v1/lab-tests`
- `/api/v1/lab-panels`
- `/api/v1/lab-orders`
- `/api/v1/lab-order-items`
- `/api/v1/lab-samples`
- `/api/v1/lab-results`
- `/api/v1/lab-qc-logs`

## Implementation Scope
1. Lab catalog view for tests and panels where permitted.
2. Lab order queue filtered by waiting payment/authorization, waiting sample, in progress, result pending, verified, released, and cancelled.
3. Sample collection workflow with barcode/reference where backend supports it.
4. Result entry, verification, release, and return-to-doctor notification.
5. Patient-facing and clinician-facing result views using generated report templates.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Ordering | Clinical users request tests through a simple catalog-search modal with panels, favorites/recent items where supported, urgency, notes, and diagnosis/context. |
| Lab queue | Lab staff see only actionable orders with patient, order number, tests, priority, payment/authorization status, sample status, and next action. |
| Result entry | Use structured fields from test definitions where available; allow notes/comments only where appropriate. |
| Billing | Show payment/authorization blocker clearly but do not expose technical billing codes. |
| Result review | Released results should notify the requesting doctor and update OPD/IPD review status when required. |
| Responsiveness | Mobile supports sample/result quick actions; desktop supports queue plus order detail. |

## Flow Synchronization Rules
- Lab orders must attach to the correct OPD encounter, IPD admission, emergency case, or other authorized source.
- Lab orders must not duplicate patient or encounter records.
- Payment/authorization changes must update lab queue readiness.
- Released results must update clinical result-review queues and notification badges.
- Cancelled/rejected samples must return clear next steps to the source queue.

## Access and State Rules
- Doctors/clinicians request tests; lab staff collect/process/verify/release based on permissions.
- Billing users handle payment clearance, not clinical result editing.
- After mutation, update only the affected lab order, sample, result, source patient row, queue count, and notification badge.

## Reports and Printing
Lab result reports must use the shared multi-page template from `35-reports-audit.md` with facility header, patient/encounter context, specimen/sample details where available, result table, reference ranges where supported, verification/signature block, and page numbers. Do not print the UI.

## Done Criteria
- Lab requests are simple, catalog-driven, and fast.
- Lab queue supports sample, processing, result, verification, and release states.
- Results return to the requesting clinician and patient flow correctly.
- Lab reports are professional, generated, permission-aware, and printable/exportable.

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
