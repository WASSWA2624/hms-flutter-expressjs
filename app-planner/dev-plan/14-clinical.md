# 14 - Clinical Module

## Goal
Support provider consultation, documentation, diagnosis, orders, procedures, care plans, prescriptions, admission decisions, referrals, follow-up, and result review without forcing doctors to leave the clinical workspace unnecessarily.

## Source of Truth
- Use `app-write-up.md` for clinical module scope and boundaries.
- Use `opd-flow.md` for OPD consultation, lab/radiology/pharmacy routing, result review, admission, referral, and OPD completion.
- Use `ipd-flow.md` for admission handoff, inpatient doctor notes, ward rounds, inpatient orders, transfers, and discharge decisions.
- Use `01-policy.md` for modal-first actions, role access, report/print rules, responsive UI, and partial UI updates.

## Backend Routes To Align With
- `/api/v1/encounters`
- `/api/v1/clinical-notes`
- `/api/v1/diagnoses`
- `/api/v1/procedures`
- `/api/v1/care-plans`
- `/api/v1/clinical-terms`
- `/api/v1/follow-ups`
- `/api/v1/referrals`

## Implementation Scope
1. Provider worklist fed by OPD, triage, IPD, ICU, theater, emergency, referral, and result-review queues.
2. Consultation workspace with patient header, encounter context, triage summary, vitals, allergies, previous visits, notes, diagnosis, plan, orders, prescriptions, and final decision.
3. Simple modal actions for add note, add diagnosis, request lab, request radiology, prescribe, request procedure, refer, request admission, schedule follow-up, and complete consultation.
4. Result review flow where lab/radiology results return the patient to the doctor queue and can be reviewed without losing the original encounter context.
5. Clinical note templates and term search where backend supports them.
6. Audit-friendly save states, drafts, last-updated indicators, and clear failure recovery.

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Use a provider worklist plus patient consultation workspace. Keep queue filters compact: today, urgent, waiting review, in consultation, results ready, admitted/referred/completed. |
| Patient context | Always show patient name, age/sex where available, patient number, encounter number, allergies/alerts, current location/status, and source queue. |
| Ordering | Lab, radiology, procedure, and medication requests must use configured catalogs and searchable selects. Do not hard-code tests, scans, medicines, or fees. |
| Prescription | Provide formulary search plus flexible dose, route, frequency, duration, quantity, refill/repeat, notes, and instructions where permitted. |
| Decisions | Final actions must be clear: continue care, send to lab/radiology/pharmacy/procedure, return for review, admit to IPD, refer, follow-up, discharge/complete. |
| Responsiveness | On mobile use a focused one-column flow; on tablet/desktop use worklist plus detail area without congesting the screen. |
| Language | Use clinical labels staff understand. Hide raw API names and technical status codes. |

## Flow Synchronization Rules
- OPD consultation must update the OPD encounter status and relevant queues only.
- Lab/radiology requests must create service orders, trigger billing/authorization when required, and place the patient in the correct department queue.
- When results become available, the patient must return to doctor review if the OPD/IPD flow requires review.
- Admission requests must create or update the IPD admission request and preserve the source OPD/emergency/clinical encounter link.
- Prescriptions must move naturally to pharmacy and billing without duplicating patient or encounter records.
- Do not create separate patient journeys outside OPD/IPD encounter flow.

## Access and State Rules
- Doctors and permitted clinicians may document and decide next steps.
- Nurses, pharmacists, lab staff, radiology staff, billing users, and reception users should only see actions allowed by their roles and module entitlements.
- After saving, refresh only the affected note, order, prescription, queue row, status badge, notification badge, and patient summary.
- Use backend response data for final state instead of guessing status locally.

## Reports and Printing
Clinical print actions must use the shared report template from `35-reports-audit.md`. Supported outputs may include consultation summary, prescription, referral letter, admission request, procedure note, and patient report. Do not print the visible UI.

## Done Criteria
- Doctor can complete OPD consultation, IPD review, result review, prescription, referral, and admission request from one clean workspace.
- Lab/radiology/pharmacy/billing/IPD handoffs are traceable and synchronized with OPD/IPD flow.
- Order and prescription entry uses configured catalogs and remains quick.
- Actions, reports, and exports are permission-gated.
- UI updates are targeted and do not reload the whole app.

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
