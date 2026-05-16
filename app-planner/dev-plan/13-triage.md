# 13 - OPD Triage

## Goal
Capture triage information before consultation when needed and route patients safely based on urgency, risk, policy, and OPD flow.

## Source of Truth
- Use `opd-flow.md` for triage role in OPD routing.
- Use `20-emergency.md` for emergency escalation and urgent handover.
- Use `14-clinical.md` for doctor handoff and triage summary visibility.
- Use `01-policy.md` and `10-workspace-ui.md` for simple modal-first triage capture and targeted UI refresh.

## Backend Routes To Align With
- `/api/v1/triage`
- `/api/v1/triage-assessments`
- `/api/v1/vital-signs`
- `/api/v1/clinical-alerts`
- `/api/v1/clinical-alert-thresholds`

## Implementation Scope
1. Triage queue filtered by waiting, urgent, emergency, routine, and service-only states.
2. Vitals capture form.
3. Chief complaint, symptoms, pain/severity indicator, allergies, risk flags, emergency indicators, triage notes, and urgency level.
4. Route decision to priority doctor, normal doctor, emergency care, admission, referral, or direct protocol service where allowed.
5. Clear abnormal vital indicators.
6. Triage summary visible to doctor during consultation.

## Triage Outputs
| Output | Meaning | Next Step |
| --- | --- | --- |
| Immediate | Patient needs urgent attention. | Priority doctor or emergency care. |
| Urgent | Patient should be seen before routine queue. | Priority doctor queue. |
| Routine | Stable OPD patient. | Normal doctor queue. |
| Service-only | Valid direct order, refill, or protocol service. | Lab, radiology, pharmacy, or procedure queue. |
| Not fit for OPD | Needs admission, emergency transfer, or referral. | Admission, emergency, or referral workflow. |

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Triage worklist with urgency, wait time, arrival type, chief complaint, and next action. |
| Capture | Use a fast modal or focused form with required vitals and route decision. |
| Alerts | Show abnormal values clearly without visual clutter. |
| Routing | Allowed next destinations must come from OPD flow and permissions. |
| Handoff | Doctor sees triage summary, vitals, urgency, alerts, and route history. |

## Flow Synchronization Rules
- Triage attaches to the active OPD encounter or emergency encounter.
- Updating triage should update the encounter status, queue position, urgency badge, and doctor queue only.
- Emergency escalation must not be delayed by billing.
- Skipping triage must be an explicit allowed action with reason/policy where needed.
- Abnormal values and alerts must be visible in clinical consultation, nursing, emergency, and IPD handoff where applicable.

## Done Criteria
- Triage can be completed quickly.
- Abnormal values are visible.
- Routing decision is recorded.
- Clinical staff can see triage summary during consultation.
- Emergency and priority patients are moved forward without unnecessary steps.
- UI updates are targeted to the queue row, status badge, and patient context.

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
