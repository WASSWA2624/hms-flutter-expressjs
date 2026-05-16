# 22 - Radiology and Imaging Module

## Goal
Manage radiology/imaging catalog, orders, scheduling, performance, reports, imaging assets/PACS links, billing/authorization gates, result delivery, and doctor review.

## Source of Truth
- Use `app-write-up.md` for radiology module scope.
- Use `opd-flow.md` for OPD imaging order, flexible payment, radiology workflow, and doctor result review.
- Use `ipd-flow.md` for inpatient imaging orders, service routing, and result review.
- Use `01-policy.md` for catalog-driven ordering, simple UI, role access, generated reports, and partial refresh.

## Backend Routes To Align With
- `/api/v1/radiology`
- `/api/v1/radiology-tests`
- `/api/v1/radiology-orders`
- `/api/v1/radiology-results`
- `/api/v1/imaging-studies`
- `/api/v1/imaging-assets`
- `/api/v1/pacs-links`

## Implementation Scope
1. Radiology catalog view for configured imaging studies where permitted.
2. Radiology order queue filtered by waiting payment/authorization, scheduled, waiting imaging, in progress, report pending, verified/released, and cancelled.
3. Scheduling and room/modality assignment where backend supports it.
4. Imaging result/report entry with asset/PACS link display.
5. Result release and return-to-doctor review notification.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Ordering | Doctors request imaging through a catalog-search modal with study, urgency, clinical notes, body area/context where supported, and required payer/billing visibility. |
| Queue | Radiology staff see patient, order number, study, priority, payment/authorization status, schedule/status, and next action. |
| Reporting | Use a focused report form/editor; keep technical imaging metadata secondary. |
| Assets | Show imaging assets/PACS links only when available and permitted. |
| Result review | Released reports notify the requesting doctor and update OPD/IPD review status. |
| Responsiveness | Mobile supports status updates; desktop supports queue plus detail/report panel. |

## Flow Synchronization Rules
- Radiology orders attach to the correct OPD encounter, IPD admission, emergency case, or authorized source.
- Payment/authorization clearance updates radiology readiness without reloading unrelated screens.
- Released reports update the source clinical queue and notification badge.
- If imaging is cancelled, postponed, or rescheduled, the source module receives clear status.

## Access and State Rules
- Clinicians request imaging; radiology staff schedule/perform/report/release according to permission.
- Billing users clear payment but do not edit reports.
- After mutation, update only the affected radiology order, schedule slot, report state, source queue row, and notification counters.

## Reports and Printing
Radiology reports must use the generated template from `35-reports-audit.md` with facility header, patient/encounter context, study details, findings, impression, image links/references where supported, signer, and page numbers. Do not print UI screens.

## Done Criteria
- Imaging requests are simple, catalog-driven, and consistent with OPD/IPD flow.
- Radiology queue clearly shows payment/authorization, schedule, performance, and report status.
- Results return to clinicians for review when needed.
- Reports are professional, permission-aware, and generated from data.

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
