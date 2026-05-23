# OPD Patient Flow Blueprint

This file is the direct OPD flow source of truth for the HMS implementation plan. It should stay aligned with the backend OPD flow module and the Flutter OPD workspace.

## 1. Goal

Make outpatient movement simple and traceable from arrival to consultation, diagnostics, pharmacy, admission, referral, or discharge. The OPD encounter is the central outpatient record and must not be duplicated while an active OPD encounter already exists for the same patient.

## 2. Supported Entry Paths

| Entry path | Expected handling |
|---|---|
| Walk-in / new patient | Search existing patient first, register if needed, create or reuse active OPD encounter, capture visit type/payer, then route to the correct stage. |
| Appointment check-in | Verify appointment, check in, create or reuse active OPD encounter, confirm payer/provider, and route to vitals, doctor, or payment gate. |
| Follow-up / review | Link to previous context where available, create or reuse active OPD encounter, then route to doctor or service queue. |
| Emergency-to-OPD handoff | Accept only where backend flow supports it, preserve the emergency context, and avoid creating a duplicate OPD encounter. |

## 3. Backend Stage Contract

Frontend labels, filters, summary cards, badges, dialogs, and actions must use the backend OPD stages below as the canonical workflow states.

| Backend OPD stage | User meaning | Primary owner |
|---|---|---|
| `WAITING_CONSULTATION_PAYMENT` | Patient must complete consultation/payment gate if required. | Reception / Billing |
| `WAITING_VITALS` | Patient is ready for vitals. | Nurse |
| `WAITING_DOCTOR_ASSIGNMENT` | Patient needs doctor/provider assignment. | Reception / Nurse |
| `WAITING_DOCTOR_REVIEW` | Patient is waiting for consultation. | Doctor |
| `LAB_REQUESTED` | Patient has pending lab work. | Lab |
| `RADIOLOGY_REQUESTED` | Patient has pending imaging. | Radiology |
| `LAB_AND_RADIOLOGY_REQUESTED` | Patient has pending diagnostics. | Lab / Radiology |
| `PHARMACY_REQUESTED` | Patient has pending pharmacy action. | Pharmacy |
| `WAITING_DISPOSITION` | Doctor must decide final outcome. | Doctor |
| `ADMITTED` | Patient has moved to IPD/admission flow. | OPD / IPD handoff |
| `DISCHARGED` | OPD visit is complete. | Reception / Clinical |

## 4. Worklist Contract

The OPD worklist should show enough information for staff to know what happens next without opening several pages:

| Field | Purpose |
|---|---|
| Patient identity | Confirms the correct patient. |
| Encounter / visit information | Shows the OPD visit context and avoids duplicate active encounters. |
| Visit type | Distinguishes walk-in, appointment, review, follow-up, or emergency handoff where available. |
| Queue / stage / status | Shows the current backend stage with user-friendly wording. |
| Provider or department | Shows who is assigned or where the patient is routed. |
| Billing/payment state | Shows payment-gate relevance without replacing the billing module. |
| Arrival or waiting time | Helps prioritize queues. |
| Next required action | Explains the next step in hospital language. |
| Responsible role/team | Shows who should act next. |

## 5. Role and Action Rules

| Role/team | Allowed OPD responsibility |
|---|---|
| Reception | Registration, appointment check-in, encounter/queue creation, provider assignment, payment-gate handoff, and reception-level OPD updates. |
| Billing | Consultation/payment gate and billing/payment actions only. |
| Nurse | Vitals and nursing-supported queue/provider assignment steps. |
| Doctor | Consultation review, clinical disposition, admission/referral/follow-up/discharge decisions. |
| Lab | Lab workspace/service work only; no OPD clinical or billing actions. |
| Radiology | Radiology workspace/service work only; no OPD clinical or billing actions. |
| Pharmacy | Pharmacy workspace/service work only; no OPD clinical or billing actions. |
| Patient / housekeeping / unrelated roles | No staff OPD workspace actions. |
| Admin roles | Broad access according to the permission model. |

Actions must be visible only when both the current backend stage and current user role make the action valid. Do not show buttons that the backend would reject.

## 6. UI Rules

- Use `AppWorkspace`, compact summary cards, `AppListTable`, search/filter controls, status badges, detail panels, and focused dialogs.
- Use hospital workflow language in labels; do not expose enum names to normal users.
- Summary cards must filter the current worklist, not open modal lists.
- Hide zero-value summary cards where the workspace summary-card pattern expects that behavior.
- Keep role/team ownership visible for each patient row.
- Refresh only the affected row, detail panel, counts, and related badges after small modal actions where the controller supports it.

## 7. OPD-to-IPD Handoff

When the doctor decides admission, OPD should clearly show that the outpatient visit has moved to `ADMITTED` and hand over to the IPD/admission flow without losing the source OPD encounter. IPD should then own bed allocation, ward handover, inpatient notes/orders, discharge planning, and bed release.

## 8. Completion Rules

An OPD visit is complete when the patient is discharged from OPD, admitted to IPD, referred out, or otherwise closed by a valid backend disposition. Completed rows should not remain mixed with active action queues unless the user deliberately filters for completed records.
