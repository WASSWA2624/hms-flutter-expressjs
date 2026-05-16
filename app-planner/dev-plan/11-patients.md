# 11 - Patient Registry

## Goal
Register and manage patients as the shared foundation for clinical and administrative workflows without duplicating patient records across OPD, IPD, billing, pharmacy, lab, radiology, reports, or claims.

## Source of Truth
- Use `app-write-up.md` for patient registry responsibility and privacy expectations.
- Use `opd-flow.md` for new/walk-in, appointment, emergency, and follow-up arrival paths.
- Use `ipd-flow.md` for admission and transfer-in patient verification.
- Use `01-policy.md` and `10-workspace-ui.md` for modal-first actions, role access, and simple UI.

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
2. Quick registration modal for routine OPD/IPD arrival.
3. Emergency quick-registration path with minimal required details and later completion.
4. Patient detail view with demographics, identifiers, contacts, guardians, allergies, documents, consent, and related visits.
5. Quick actions for appointment, OPD check-in, triage, clinical visit, billing, admission request, or patient report where permitted.
6. Patient merge/duplicate warning workflow only if backend supports it.
7. Respect patient privacy and PHI access rules.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Search | Patient lookup must be fast and obvious by name, patient number, phone, or identifier where supported. |
| Registration | Keep the first form short; collect only required information, then allow completion later. |
| Emergency | Permit safe quick registration without delaying urgent triage/care. |
| Detail | Use sections/tabs; avoid showing everything at once. |
| Actions | Use modals for quick edit, add contact, add guardian, add allergy, upload document, consent, OPD check-in, and admission request. |
| Privacy | Gate PHI fields and patient documents by permission and audit where backend supports it. |

## Flow Synchronization Rules
- Patient registry must not create OPD or IPD flows by itself except through allowed quick actions.
- OPD encounter creation belongs to OPD flow.
- IPD admission creation belongs to IPD/admission flow.
- Reports should use structured patient data and the shared print template, not the visible UI.
- After patient edits, refresh only patient header, patient row, patient detail section, and dependent encounter/admission context.

## Done Criteria
- Patients can be found quickly.
- New patients can be registered without creating duplicates.
- Emergency quick registration is supported where allowed.
- Patient details are readable and not congested.
- Patient actions are permission-gated.
- PHI-related failures and forbidden states are handled safely.

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

### Additional references
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `backend/app-planner/app-rules/compliance.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
