# 30 - Biomedical

## Goal
Manage medical equipment lifecycle, maintenance, calibration, safety, downtime, incidents, recalls, spare parts, providers, warranties, and disposal/transfer.

## Backend Routes To Align With
- `/api/v1/biomedical`
- `/api/v1/equipment-categories`
- `/api/v1/equipment-registries`
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
1. Biomedical workspace dashboard.
2. Equipment registry and detail view.
3. Maintenance plan and work order workflows.
4. Calibration and safety test logs.
5. Downtime, incident, recall, warranty, service provider, spare part, utilization, and disposal/transfer views.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Biomedical users can manage equipment from the biomedical module.
- Maintenance lifecycle is traceable.
- Clinical equipment readiness is visible.
- Biomedical permissions are respected.

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
