# 27 - Mortuary Module

## Goal
Manage deceased profiles, mortuary cases, storage units/slots, custody events, viewings, post-mortem requests, release authorization, billing, documents, and respectful handover.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for mortuary scope.
- Use `ipd-flow.md` where a mortuary case originates from an inpatient outcome or facility handover.
- Use `01-policy.md` for respectful simple UI, permissions, generated reports, and partial state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/mortuary`
  - Use query parameters supported by the current backend workspace contract: `panel`, `resource`, `queue`, `search`, `status`, `identification_status`, `facility_id`, `storage_unit_id`, `storage_slot_id`, `date_preset`, `id`, and `action`.
  - Supported workspace resources include `mortuary-cases`, `mortuary-storage-units`, `mortuary-storage-slots`, `mortuary-storage-assignments`, `mortuary-custody-events`, `mortuary-viewings`, `mortuary-post-mortem-requests`, `mortuary-release-authorisations`, and `mortuary-billable-events`.
  - Do not call separate mortuary entity routes unless they are mounted in the backend router in a future authorized backend change.

## Implementation Scope
1. Mortuary case list with active, pending storage, in storage, viewing scheduled, post-mortem pending, release pending, billing pending, and released statuses where supported.
2. Mortuary case detail with deceased identity, source encounter/admission where available, storage slot, custody log, viewing requests, post-mortem status, billing, release documents, and notes.
3. Modal actions for receive case, assign storage slot, record custody event, schedule viewing, request/record post-mortem step, request billing, approve release, confirm release, and print documents.
4. Storage slot board linked to configured mortuary spaces where backend supports it.
5. Strict permission, privacy, and audit handling.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a respectful, simple case list with search and status filters. Avoid unnecessary clinical details in the list. |
| Case detail | Use sections for identity, storage, custody, viewing, post-mortem, billing, release, and documents. |
| Actions | Use modals for custody, storage assignment, viewing, release, and print actions. |
| Language | Use clear respectful labels and avoid technical codes. |
| Responsiveness | Mobile supports focused case actions; desktop supports case list plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: deceased/person context header, mortuary case card, storage unit/slot selector, custody event form, viewing appointment form, post-mortem request panel, release authorization modal, and billable event card.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: mortuary case, deceased profile, storage assignment, custody chain, viewing, post-mortem request, release authorization, billing events, reports, and audit records must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Mortuary cases originating from IPD/emergency must preserve source patient/encounter/admission context where available.
- Storage slot changes must update occupancy/status only for the affected slot.
- Billing clearance must update release readiness without closing the case prematurely.
- Release completion must close the mortuary case and update source records where backend supports it.

## Access and State Rules
- Mortuary staff and permitted admins manage cases.
- Sensitive patient/deceased details, documents, and release actions require strict permission.
- After mutation, refresh only the case row, storage slot, custody log, billing badge, and notification badge.

## Reports and Printing
Mortuary intake form, custody log, viewing note, post-mortem request/summary where applicable, release authorization, and billing clearance must use generated report templates from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<MortuaryWorkspaceItem>` sourced from `/api/v1/mortuary` with resource/queue filters. Columns should show case/reference, deceased/person context, source encounter/admission, storage/release/billing status, date, and next action. Use `AppSearchBar` for case, name, resource, queue, status, facility, and date filters. |
| Detail/display | Use respectful detail sections for identity, source context, storage, custody, viewing, post-mortem, release, billing, documents, and audit activity; use `AppDialog` for short detailed display on compact screens. |
| CRUD/UI actions | Use `AppDialog` for receive case, assign storage, record custody, schedule viewing, request/record post-mortem step, request billing, approve/confirm release, and print documents where backend action support exists. |
| RBAC/ABAC | Gate with mortuary read/write/release/manage-storage/post-mortem/approve/billing/export/audit permissions and facility scope. Backend authorization remains final. |
| Partial refresh | After mortuary action update only affected workspace row/resource list, storage slot, custody log, release/billing badge, source record where supported, report preview, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Mortuary workflow is respectful, simple, and auditable.
- Storage, custody, billing, and release statuses remain synchronized.
- Actions are permission-gated and modal-based where safe.
- Documents are generated from data, not UI printouts.

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
