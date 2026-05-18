# 25 - Insurance and Claims Module

## Goal
Manage coverage plans, eligibility/coverage visibility, pre-authorizations, claim preparation, claim submission, approvals, rejections, resubmissions, and insurance-linked billing follow-up.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for insurance and claims scope.
- Use `opd-flow.md` for OPD service authorization and flexible billing timing.
- Use `ipd-flow.md` for admission authorization, inpatient billing, discharge clearance, deposit adjustment, and final claim handling.
- Use `01-policy.md` for simple modal actions, role access, reports, and partial state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/coverage-plans`
- `/api/v1/insurance-claims`
- `/api/v1/pre-authorizations`
- `/api/v1/invoices`
- `/api/v1/invoice-items`
- `/api/v1/payments`
- `/api/v1/refunds`

## Implementation Scope
1. Claims workspace for pre-authorization queue, claim queue, rejected/resubmission queue, approved claims, and pending follow-up.
2. Coverage/plan detail where permitted, linked to patient billing context.
3. Modal actions for request pre-authorization, update authorization status, prepare claim, submit claim, record response, resubmit, and close claim.
4. Integration with invoice/billing status and patient service clearance.
5. Claim reports and generated documents where required.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use clear queues: authorization pending, approved, rejected, claim draft, submitted, rejected, resubmission, paid/closed. |
| Claim detail | Show patient, payer, policy/coverage, invoice/encounter/admission, amount, required documents, status, and next action. |
| Actions | Use modals for status updates, submission, resubmission, document request, and response recording. |
| Billing link | Show billing impact in plain language: authorized, partially authorized, not covered, pending, patient balance. |
| Responsiveness | Mobile supports status/action modals; desktop supports queue plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: claim list/table, patient context header, coverage plan selector, pre-authorization modal, claim review form, rejection/appeal modal, payer status badge, and invoice linkage panel.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: coverage, pre-authorizations, invoices, claim status, billing clearance, payer responses, notifications, reports, and audit records must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- OPD/IPD service clearance must reflect authorization status where required.
- IPD discharge clearance must consider pending claim/insurance finalization based on backend policy.
- Claim updates must update billing, invoice, and patient queue state only where relevant.
- Rejections must show simple next steps for billing/insurance staff without exposing technical claim payload details.

## Access and State Rules
- Insurance/claims users manage authorizations and claims.
- Billing users can view claim impact and balances where permitted.
- Clinical users should see only service clearance information, not full financial claim details unless permitted.
- After claim mutation, refresh only the claim row, invoice status, authorization badge, and affected patient queue item.

## Reports and Printing
Claim forms, pre-authorization letters, claim statements, rejection/resubmission notes, and payer summaries must use generated report templates from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<Claim>` with claim/preauth number, patient, payer, coverage plan, invoice/admission, claim amount, status, age, and next action. Use `AppSearchBar` for patient, claim, payer, status, date, and invoice filters. |
| Detail/display | Use claim detail with coverage, pre-authorization, invoice links, documents, approvals/rejections, resubmission notes, and financial/audit history. |
| CRUD/UI actions | Use `AppDialog` for coverage check, preauth request/update, claim submit, attach document note, approval/rejection response, resubmission, and claim document print/export. |
| RBAC/ABAC | Gate with billing permissions, financial approve, evidence export, payer/tenant/facility scope, and backend authorization. |
| Partial refresh | After claim action update only claim row, invoice/coverage badge, patient billing detail, dashboard counts, report/export status, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Coverage, authorization, claim, invoice, and patient flow states remain aligned.
- Claim actions are simple, modal-based, and permission-aware.
- Discharge/billing clearance can see insurance blockers clearly.
- Claim documents are generated from data and printable/exportable.

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
