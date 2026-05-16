# 12 - OPD and Outpatient Flow

## Goal
Manage appointments, arrivals, queues, OPD encounters, flexible billing gates, service routing, consultation readiness, result review, pharmacy handoff, admission/referral, and outpatient completion.

## Source of Truth
- Use `app-planner/opd-flow.md` as the direct OPD flow source of truth.
- Use `app-write-up.md` for module boundaries.
- Use `13-triage.md`, `14-clinical.md`, `21-lab.md`, `22-radiology.md`, `23-pharmacy.md`, `24-billing.md`, and `16-inpatient.md` for connected module implementation.
- Use `01-policy.md` and `10-workspace-ui.md` for modal-first actions, simple UI, role access, and targeted UI refresh.

## Backend Routes To Align With
- `/api/v1/appointments`
- `/api/v1/appointment-participants`
- `/api/v1/appointment-reminders`
- `/api/v1/provider-schedules`
- `/api/v1/availability-slots`
- `/api/v1/visit-queues`
- `/api/v1/opd-flows`
- `/api/v1/follow-ups`
- `/api/v1/referrals`

## Implementation Scope
1. Appointment and walk-in arrival lists.
2. Emergency, new/walk-in, appointment, follow-up, and review patient entry paths.
3. Reception workflow for patient lookup, quick registration, arrival/check-in, OPD encounter creation, payer capture, queue assignment, and service routing.
4. OPD queue board for waiting, payment required, waiting triage, waiting doctor, in consultation, waiting lab/radiology/pharmacy, results ready, review, completed, referred, admitted, and cancelled states.
5. Flexible billing gate that supports upfront payment, service payment, pharmacy payment, end-of-visit payment, insurance/credit, and emergency deferred billing.
6. Provider readiness view that links to triage and clinical consultation.
7. Modal-based updates for arrival, quick registration, assign doctor, queue movement, payment check, reschedule, cancellation, referral, admission request, and print summary.
8. Direct service routes only when a valid order/refill/protocol exists.

## Arrival Paths
| Patient Type | OPD Handling |
| --- | --- |
| Emergency | Quick registration if needed → create encounter → immediate triage/stabilization → priority doctor/emergency care → billing later where allowed. |
| New/walk-in | Search first → register if not found → create encounter → select department/service/provider/payer → payment gate if required → triage/doctor/direct service. |
| Appointment | Verify appointment/provider/time → check in → create/activate encounter → confirm payer → triage if required or assigned doctor queue. |
| Follow-up/review | Find patient/previous context → create or link visit as supported → route to doctor or service queue based on reason. |

## UI and Workflow Contract
| Area | Requirement |
| --- | --- |
| Main screen | Active OPD worklist with clear status, patient, time, provider, queue, payer, and next action. |
| Row action | Click/tap opens patient action modal or detail panel; do not navigate away for quick actions. |
| Reception actions | Register, check in, create encounter, assign doctor, route, take payment, cancel, reschedule, print token/summary. |
| Billing | Show only simple payment status and action; detailed billing remains in billing module. |
| Routing | Allow triage, doctor, lab, radiology, pharmacy, procedure, admission, referral, follow-up, or completion based on current state and permission. |
| Turnaround time | Avoid unnecessary steps; keep queues live and update only affected patient rows/status badges. |

## Flow Synchronization Rules
- The OPD encounter is the central outpatient record.
- Triage notes, vitals, consultation notes, diagnoses, orders, prescriptions, invoices, payments, referral, admission request, discharge/completion, and print history attach to the OPD encounter.
- Lab/radiology results return to doctor review only when review is required.
- Pharmacy handoff follows prescription/order/payment status.
- Admission requests must hand over to IPD while preserving the OPD source encounter.
- Do not create duplicate OPD encounters for the same active visit.

## Done Criteria
- Reception can manage OPD without jumping to unrelated modules.
- Emergency, new, appointment, follow-up, and review patients have clear entry paths.
- Queue state and next action are clear.
- Billing gates are flexible and do not block emergency care unsafely.
- OPD handoff into triage, clinical, lab, radiology, pharmacy, billing, referral, and admission is traceable.
- Actions are permission-gated and update only affected UI state.

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
