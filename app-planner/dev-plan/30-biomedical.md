# 30 - Biomedical Module

## Goal
Manage medical equipment registry, categories, assignments, maintenance plans, work orders, calibration, safety tests, downtime, incidents, recalls, spare parts, warranties, service providers, utilization, and disposal/transfer.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
- Use `app-write-up.md` for biomedical scope.
- Use `ipd-flow.md` indirectly for equipment readiness in ICU, wards, beds, theater, and patient care areas.
- Use `01-policy.md` for simple workflow UI, role access, reports, and partial state refresh.

## Backend Routes To Align With

Use these route families only after confirming they exist in the current backend router/API contract. If a listed route is absent, record it as a backend gap and do not create a frontend-only endpoint, fake status, or local-only workflow.
- `/api/v1/equipment-categories`
- `/api/v1/equipment-registries`
- `/api/v1/equipment-location-histories`
- `/api/v1/equipment-maintenance-plans`
- `/api/v1/equipment-work-orders`
- `/api/v1/equipment-calibration-logs`
- `/api/v1/equipment-safety-test-logs`
- `/api/v1/equipment-downtime-logs`
- `/api/v1/equipment-spare-parts`
- `/api/v1/equipment-warranty-contracts`
- `/api/v1/equipment-service-providers`
- `/api/v1/equipment-incident-reports`
- `/api/v1/equipment-recall-notices`
- `/api/v1/equipment-utilization-snapshots`
- `/api/v1/equipment-disposal-transfers`

## Implementation Scope
1. Equipment registry with search, filters, status, location, category, owner unit, maintenance state, calibration state, and downtime.
2. Equipment detail with identity, assignment/location, maintenance plan, work orders, calibration, safety tests, incidents, recalls, warranties, spare parts, and utilization.
3. Modal actions for add/edit equipment, assign/transfer location, create work order, update work order, record calibration, record safety test, record downtime, close downtime, log incident, and dispose/transfer.
4. Equipment readiness visibility for wards, ICU, theater, radiology, lab, and other departments where supported.
5. Reports for equipment status and maintenance compliance.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use searchable equipment list and status filters. Show next due action clearly. |
| Detail view | Use sections for registry, location, work orders, maintenance, calibration, safety, incidents, and documents. |
| Actions | Use modals for routine registry, work order, calibration, safety, and status changes. |
| Technical data | Keep detailed technical fields inside sections; do not clutter the main list. |
| Responsiveness | Mobile supports quick updates; desktop supports list plus detail panel. |

## Reusable Components and Sync Contract
- Reuse `10-workspace-ui.md` workspace layout, shared form fields, shared modal/dialog shell, responsive detail panels, status badges, search/filter/table/list controls, async state views, and permission-gated action patterns before adding module-specific widgets.
- Use or create shared components for: equipment registry list, equipment detail card, maintenance plan form, work-order modal, calibration/safety test form, downtime badge, incident/recall modal, and spare-part/contract panels.
- Keep common form layout, field behavior, validation-error display, server-error mapping, loading state, disabled state, and duplicate-submit protection shared; keep module-specific validation and submit mapping in feature controllers/repositories.
- Keep modal actions focused and return users to the same worklist/detail context after success; refresh only backend-backed affected rows, badges, panels, queues, counters, report previews, or form sections.
- Backend/frontend sync required: equipment registry, location history, maintenance, calibration, safety tests, downtime, incidents, recalls, warranty/service provider data, notifications, reports, and audit events must stay synchronized.
- Do not create duplicate patient, encounter, admission, order, invoice, payment, report, notification, status, or action components when an existing shared pattern can represent the same job.

## Flow Synchronization Rules
- Equipment downtime/maintenance should update room/ward/theater/ICU readiness where backend supports it.
- Maintenance requests can link to operations if the issue is facility-related.
- Equipment location changes must update only the affected equipment record and location summaries.
- Critical recall/incidents should generate notifications for permitted roles.

## Access and State Rules
- Biomedical users manage equipment and technical records.
- Department users may view equipment readiness or report issues where permitted.
- After mutation, refresh only the equipment row, work order, location readiness badge, notification counter, and relevant dashboard card.

## Reports and Printing
Equipment register, maintenance schedule, calibration certificate/log, safety test log, downtime report, incident report, recall notice, and disposal/transfer document must use generated report templates from `35-reports-audit.md`.

## Concrete Implementation Contract
| Slice | Required implementation |
| --- | --- |
| Worklist/list data | Use `AppWorkspace` + `AppPaginatedListTable<BiomedicalAsset>` with asset tag, equipment, category, location, risk/criticality, maintenance/calibration/downtime status, owner, and next action. Use `AppSearchBar` for asset tag, equipment, category, location, status, date, and provider filters. |
| Detail/display | Use asset detail with registry, location history, maintenance plans/work orders, calibration/safety logs, downtime, spare parts, warranty/provider, incidents, recalls, utilization, and disposal/transfer. |
| CRUD/UI actions | Use `AppDialog` for register/edit asset, schedule maintenance, create/update work order, record calibration/safety test, report downtime/incident, acknowledge recall, transfer/dispose, and print asset/service report. |
| RBAC/ABAC | Gate with biomed read/write, evidence export, operations, facility/location scope, and backend authorization. |
| Partial refresh | After biomedical mutation update only asset row, location/status badge, maintenance due count, downtime list, recall badge, reports, and notifications. |

Implementation must reuse `AppWorkspace`, `AppListTable`/`AppPaginatedListTable`, `AppSearchBar`/`AppListTableSearch`, `AppDialog`, shared form fields, `AppStateView`/`AsyncStateScaffold`, and access gates before adding feature-local UI. Do not reload the full workspace after modal actions.


## Done Criteria
- Equipment lifecycle is searchable, traceable, and easy to update.
- Biomedical status can support care-area readiness without duplicating room/bed data.
- Actions are modal-based and permission-aware.
- Reports are generated and professional.

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
