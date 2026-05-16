# 19 - Discharge Module

## Goal
Prepare, coordinate, print, and complete safe discharge using clinical summary, medicines, nursing clearance, billing/insurance clearance, follow-up, document handover, patient exit, and bed release.

## Source of Truth
- Use `app-write-up.md` for discharge module scope.
- Use `ipd-flow.md` as the primary discharge workflow reference.
- Use `opd-flow.md` for OPD completion, referral, prescription, and follow-up summaries.
- Use `01-policy.md` and `35-reports-audit.md` for modal actions, permissions, partial refresh, and generated print templates.

## Backend Routes To Align With
- `/api/v1/discharge-summaries`
- `/api/v1/admissions`
- `/api/v1/ipd-flows`
- `/api/v1/billing`
- `/api/v1/invoices`

## Implementation Scope
1. Discharge worklist for planned, summary pending, pharmacy pending, nursing pending, billing pending, insurance pending, documents ready, and completed discharges.
2. Discharge detail with patient/admission context, diagnosis, treatment summary, medicines, instructions, follow-up, pending orders, checklist, billing, and documents.
3. Modal actions for start discharge plan, assign tasks, update checklist, request final billing, request pharmacy discharge medicines, mark document ready, confirm patient exit, and complete discharge.
4. Focused summary editor for discharge summary when content is too long for a modal.
5. Print/preview generated discharge documents using the shared template.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a discharge queue with clear next action, pending blocker, patient, ward/bed, consultant, and target discharge time. |
| Summary editor | Keep sections simple: final diagnosis, treatment given, medicines, advice, follow-up, warning signs, doctor/nurse signature blocks. |
| Clearance | Show checklist cards for doctor, nursing, pharmacy, billing, insurance, documents, and bed release. |
| Actions | Routine clearance updates use modals; final completion requires confirmation. |
| Printing | Print generated documents only, never the UI screen. |
| Responsiveness | Mobile should focus on checklist and summary; desktop can show queue plus detail panel. |

## Flow Synchronization Rules
- Discharge planning may start before all services are complete, but final discharge must respect required clearance rules.
- Pharmacy discharge medicines must route to pharmacy and billing where required.
- Billing/insurance finalization must update discharge readiness without closing clinical summary prematurely.
- Patient exit must trigger bed release/cleaning and notify housekeeping/bed management.
- Completed discharge must close the admission only after required clinical and financial steps are complete.

## Access and State Rules
- Doctors complete clinical summary and discharge decision.
- Nurses complete nursing discharge checklist and handover.
- Pharmacy clears medicines.
- Billing/insurance clears final financial status.
- Discharge desk or permitted role completes patient exit/document handover.
- After a clearance update, refresh only the checklist item, discharge row, admission status, bed status, and notification counters affected.

## Reports and Printing
Discharge summary, prescription, follow-up note, billing clearance, patient report, and discharge instruction sheet must use the multi-page report template from `35-reports-audit.md` with facility header, logo, contacts, page numbers, and signature blocks.

## Done Criteria
- Discharge is treated as a workflow, not a single button.
- Staff can see exactly what is pending and who owns it.
- Printed discharge documents are professional, multi-page safe, and generated from data.
- Admission, billing, pharmacy, nursing, housekeeping, and bed statuses remain synchronized.

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
