# 21 - Laboratory Module

## Goal
Manage lab test catalog, panels, orders, samples, results, quality control, billing/authorization gates, result delivery, and return-to-doctor review where required.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for laboratory scope.
- Use `opd-flow.md` for OPD lab ordering, billing flexibility, sample/result workflow, and doctor result review.
- Use `ipd-flow.md` for inpatient lab orders, service routing, result review, and billing/authorization timing.
- Use `01-policy.md` for catalog-driven requests, modal actions, role access, and partial UI refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/lab-tests`
- `/api/v1/lab-panels`
- `/api/v1/lab-orders`
- `/api/v1/lab-order-items`
- `/api/v1/lab-samples`
- `/api/v1/lab-results`
- `/api/v1/lab-qc-logs`
- `/api/v1/invoices`
- `/api/v1/payments`

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

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: lab order row, patient context header, specimen/sample collection form, test/panel selector, result entry form, QC status badge, result release modal, and doctor-review routing panel.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: lab catalog, order items, samples, results, QC logs, billing gate, doctor review queue, notifications, reports, and encounter/admission links must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

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

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<LabOrder>` with order number, patient, source encounter/admission, tests/panel, billing/sample/result status, priority, requested time, and next action. Use `AppSearchBar` for patient, order, test, source, status, priority, and date filters. |
| Detail/display | Use patient/order detail with sample list, test items, results, verification, QC context, billing gate, source doctor review status, and result history. |
| CRUD/UI actions | Use `AppDialog` for sample collection, sample rejection, result entry, verification/release, QC note, billing gate check, cancellation, and lab report print. |
| RBAC/ABAC | Gate with lab permissions; allow clinical read-only result visibility where permitted; enforce facility/lab scope and backend authorization. |
| Partial refresh | After lab action update only lab order row, sample/result item, doctor review queue, OPD/IPD/clinical detail, billing badge, report preview, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


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
