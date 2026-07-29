# UI Permission Prompts

Per-tab (and single-surface) prompts that deep-scan nested UI and enforce
permission-based access. Shared rules: [`_shared-rules.md`](_shared-rules.md).
Every prompt must follow [`../.cursor/prompt.mdc`](../.cursor/prompt.mdc)
(structure, states, verification, and AC↔requirement tracing).

Run via `run_prompts.py`, or one prompt at a time with the target tab’s file
as the agent instruction.

## Index

| Screen | Tab / surface | Prompt |
| --- | --- | --- |
| Patients registry | All patients | `patients/all-patients.md` |
| Patients registry | Active | `patients/active.md` |
| Patients registry | Admitted | `patients/admitted.md` |
| Patients registry | Balance due | `patients/balance-due.md` |
| Reception desk | Appointments | `reception/appointments.md` |
| Reception desk | Desk queue | `reception/desk-queue.md` |
| Reception desk | High priority | `reception/high-priority.md` |
| Reception desk | Active visits | `reception/active-visits.md` |
| Reception desk | Follow-ups | `reception/follow-ups.md` |
| Reception desk | Payment gate | `reception/payment-gate.md` |
| Billing workspace | All | `billing/all.md` |
| Billing workspace | Needs issue | `billing/needs-issue.md` |
| Billing workspace | Awaiting payment | `billing/awaiting-payment.md` |
| Billing workspace | Claims pending | `billing/claims-pending.md` |
| Billing workspace | Approval required | `billing/approval-required.md` |
| Billing workspace | Overdue | `billing/overdue.md` |
| Claims workspace | Authorizations | `claims/authorizations.md` |
| Claims workspace | Active Claims | `claims/active-claims.md` |
| Claims workspace | Settled | `claims/settled.md` |
| Claims workspace | Insurance Setup | `claims/insurance-setup.md` |
| Subscriptions workspace | Overview | `subscriptions/overview.md` |
| Subscriptions workspace | Plans | `subscriptions/plans.md` |
| Subscriptions workspace | Subscriptions | `subscriptions/subscriptions.md` |
| Subscriptions workspace | Invoices | `subscriptions/invoices.md` |
| Subscriptions workspace | Licenses | `subscriptions/licenses.md` |
| OPD workspace | All worklist | `opd/all-worklist.md` |
| OPD workspace | Arrivals | `opd/arrivals.md` |
| OPD workspace | Queue | `opd/queue.md` |
| OPD workspace | Triage | `opd/triage.md` |
| OPD workspace | Active | `opd/active.md` |
| OPD workspace | Follow-ups | `opd/follow-ups.md` |
| Emergency workspace | Active cases | `emergency/active-cases.md` |
| Emergency workspace | Critical | `emergency/critical.md` |
| Emergency workspace | Ambulance | `emergency/ambulance.md` |
| Emergency workspace | Handoff ready | `emergency/handoff-ready.md` |
| Emergency workspace | Closed | `emergency/closed.md` |
| Emergency workspace | All | `emergency/all.md` |
| IPD workspace | Admission Queue | `ipd/admission-queue.md` |
| IPD workspace | Active Patients | `ipd/active-patients.md` |
| IPD workspace | Transfers | `ipd/transfers.md` |
| IPD workspace | Discharge | `ipd/discharge.md` |
| IPD workspace | Bed board | `ipd/bed-board.md` |
| IPD workspace | Follow-ups | `ipd/follow-ups.md` |
| Rooms & beds | All beds | `rooms-beds/all-beds.md` |
| Rooms & beds | Available | `rooms-beds/available.md` |
| Rooms & beds | Occupied | `rooms-beds/occupied.md` |
| Rooms & beds | Turnover | `rooms-beds/turnover.md` |
| Rooms & beds | Out of service | `rooms-beds/out-of-service.md` |
| ICU workspace | Active ICU | `icu/active-icu.md` |
| ICU workspace | Critical alerts | `icu/critical-alerts.md` |
| ICU workspace | Transfers | `icu/transfers.md` |
| ICU workspace | Discharge ready | `icu/discharge-ready.md` |
| ICU workspace | Ended stays | `icu/ended-stays.md` |
| ICU workspace | All ICU | `icu/all-icu.md` |
| ICU workspace | Bed board | `icu/bed-board.md` |
| ICU workspace | Follow-ups | `icu/follow-ups.md` |
| Nursing workspace | All | `nursing/all.md` |
| Nursing workspace | Assigned ward | `nursing/assigned-ward.md` |
| Nursing workspace | Urgent | `nursing/urgent.md` |
| Nursing workspace | Medication due | `nursing/medication-due.md` |
| Nursing workspace | Handover pending | `nursing/handover-pending.md` |
| Nursing workspace | Transfer pending | `nursing/transfer-pending.md` |
| Nursing workspace | Discharge pending | `nursing/discharge-pending.md` |
| Clinical workspace | Follow-ups | `clinical/follow-ups.md` |
| Clinical workspace | All | `clinical/all.md` |
| Clinical workspace | Waiting review | `clinical/waiting-review.md` |
| Clinical workspace | Urgent | `clinical/urgent.md` |
| Clinical workspace | Results ready | `clinical/results-ready.md` |
| Clinical workspace | In consultation | `clinical/in-consultation.md` |
| Clinical workspace | Completed | `clinical/completed.md` |
| Physiotherapy workspace | Referrals | `physiotherapy/referrals.md` |
| Physiotherapy workspace | Today | `physiotherapy/today.md` |
| Physiotherapy workspace | Active plans | `physiotherapy/active-plans.md` |
| Physiotherapy workspace | Follow-up due | `physiotherapy/follow-up-due.md` |
| Physiotherapy workspace | Missed | `physiotherapy/missed.md` |
| Physiotherapy workspace | Completed | `physiotherapy/completed.md` |
| Physiotherapy workspace | Follow-ups | `physiotherapy/follow-ups.md` |
| Lab workspace | All | `lab/all.md` |
| Lab workspace | Awaiting results | `lab/awaiting-results.md` |
| Lab workspace | Processing | `lab/processing.md` |
| Lab workspace | Pending verification | `lab/pending-verification.md` |
| Lab workspace | Critical | `lab/critical.md` |
| Lab workspace | Verified | `lab/verified.md` |
| Lab workspace | Follow-ups | `lab/follow-ups.md` |
| Radiology workspace | Worklist | `radiology/worklist.md` |
| Radiology workspace | Reporting | `radiology/reporting.md` |
| Radiology workspace | Released | `radiology/released.md` |
| Radiology workspace | All orders | `radiology/all-orders.md` |
| Radiology workspace | Follow-ups | `radiology/follow-ups.md` |
| Pharmacy workspace | Ready | `pharmacy/ready.md` |
| Pharmacy workspace | Partial | `pharmacy/partial.md` |
| Pharmacy workspace | Pending payment | `pharmacy/pending-payment.md` |
| Pharmacy workspace | Completed | `pharmacy/completed.md` |
| Pharmacy workspace | All orders | `pharmacy/all-orders.md` |
| Operations workspace | All requests | `operations/all-requests.md` |
| Operations workspace | Open | `operations/open.md` |
| Operations workspace | In progress | `operations/in-progress.md` |
| Operations workspace | Completed | `operations/completed.md` |
| Operations workspace | Assets | `operations/assets.md` |
| Housekeeping workspace | Tasks | `housekeeping/tasks.md` |
| Housekeeping workspace | Schedules | `housekeeping/schedules.md` |
| Housekeeping workspace | Maintenance requests | `housekeeping/maintenance-requests.md` |
| HR workspace | Human resources | `hr/human-resources.md` |
| HR workspace | Leave requests | `hr/leave-requests.md` |
| HR workspace | Shifts | `hr/shifts.md` |
| HR workspace | Payroll drafts | `hr/payroll-drafts.md` |
| HR workspace | Manage users and roles | `hr/manage-users-roles.md` |
| Biomedical workspace | Registry | `biomedical/registry.md` |
| Biomedical workspace | Overview | `biomedical/overview.md` |
| Biomedical workspace | Preventive | `biomedical/preventive.md` |
| Biomedical workspace | Work orders | `biomedical/work-orders.md` |
| Biomedical workspace | Compliance | `biomedical/compliance.md` |
| Biomedical workspace | Support | `biomedical/support.md` |
| Biomedical workspace | Analytics | `biomedical/analytics.md` |
| Communications workspace | Messages | `communications/messages.md` |
| Communications workspace | Notifications | `communications/notifications.md` |
| Communications workspace | Deliveries | `communications/deliveries.md` |
| Communications workspace | Templates | `communications/templates.md` |
| Integrations workspace | Integrations | `integrations/integrations.md` |
| Integrations workspace | API keys | `integrations/api-keys.md` |
| Integrations workspace | Webhooks | `integrations/webhooks.md` |
| Integrations workspace | Logs | `integrations/logs.md` |
| Integrations workspace | Interop | `integrations/interop.md` |
| Discharge workspace | All patients | `discharge/all-patients.md` |
| Discharge workspace | Planned | `discharge/planned.md` |
| Discharge workspace | Pending clearance | `discharge/pending-clearance.md` |
| Discharge workspace | Completed | `discharge/completed.md` |
| Discharge workspace | Follow-ups | `discharge/follow-ups.md` |
| Theater workspace | Scheduled | `theater/scheduled.md` |
| Theater workspace | In theater | `theater/in-theater.md` |
| Theater workspace | Recovery | `theater/recovery.md` |
| Theater workspace | All cases | `theater/all-cases.md` |
| Theater workspace | Follow-ups | `theater/follow-ups.md` |
| Mortuary workspace | Overview | `mortuary/overview.md` |
| Mortuary workspace | Intake | `mortuary/intake.md` |
| Mortuary workspace | Storage | `mortuary/storage.md` |
| Mortuary workspace | Custody | `mortuary/custody.md` |
| Mortuary workspace | Release | `mortuary/release.md` |
| Mortuary workspace | Reports | `mortuary/reports.md` |
| Access admin | Directory | `admin-access/directory.md` |
| Access admin | Roles | `admin-access/roles.md` |
| Access admin | Permissions | `admin-access/permissions.md` |
| Access admin | Entitlements | `admin-access/entitlements.md` |
| Access admin | Registrations | `admin-access/registrations.md` |
| Access admin | Demo | `admin-access/demo.md` |
| Settings | Preferences | `settings/preferences.md` |
| Settings | Accessibility | `settings/accessibility.md` |
| Settings | Account and security | `settings/account-and-security.md` |
| Settings | Administration boundaries | `settings/administration-boundaries.md` |
| Settings | Configuration | `settings/configuration.md` |
| Settings | Administrative setup workspace | `settings/administrative-setup.md` |
| Home dashboard | Home (all atoms) | `_screens/home.md` |
| Reports workspace | Reports (all panels) | `_screens/reports.md` |
| Profile | Profile | `_screens/profile.md` |

Total prompts: **154**
