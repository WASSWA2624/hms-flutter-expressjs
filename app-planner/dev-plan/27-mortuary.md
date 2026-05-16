# 27 - Mortuary Module

## Goal
Manage deceased profiles, mortuary cases, storage units/slots, custody events, viewings, post-mortem requests, release authorization, billing, documents, and respectful handover.

## Source of Truth
- Use `app-write-up.md` for mortuary scope.
- Use `ipd-flow.md` where a mortuary case originates from an inpatient outcome or facility handover.
- Use `01-policy.md` for respectful simple UI, permissions, generated reports, and partial state refresh.

## Backend Routes To Align With
- `/api/v1/mortuary`

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
