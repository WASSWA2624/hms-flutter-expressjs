# 11 - Patient Registry

## Goal
Register and manage patients as the shared foundation for clinical and administrative workflows.

## Backend Routes To Align With
- `/api/v1/patients`
- `/api/v1/patient-identifiers`
- `/api/v1/patient-contacts`
- `/api/v1/patient-guardians`
- `/api/v1/patient-allergies`
- `/api/v1/patient-medical-histories`
- `/api/v1/patient-documents`
- `/api/v1/consents`

## Implementation Scope
1. Patient list with search, filters, pagination, and duplicate-safe lookup.
2. Create/edit patient modal or focused form.
3. Patient detail view with demographics, identifiers, contacts, guardians, allergies, documents, consent, and related visits.
4. Quick actions for appointment, triage, clinical visit, billing, or admission where permitted.
5. Respect patient privacy and PHI access rules.

## UX and Workflow Rules
- Keep this module self-contained.
- Use the shared workspace pattern from `10-workspace-ui.md`.
- Keep short actions in modals where safe.
- Use full pages only for complex or high-risk workflows.
- Show loading, empty, error, forbidden, offline, and success states.
- Respect tenant, facility, department/unit, role, permission, and module entitlement scope.

## Done Criteria
- Patients can be found quickly.
- Patient details are readable and not congested.
- Patient actions are permission-gated.
- PHI-related failures and forbidden states are handled safely.

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
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`
- `backend/app-planner/app-rules/compliance.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
