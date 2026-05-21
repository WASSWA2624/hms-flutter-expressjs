# Home Dashboard Content by User Account Type

## Purpose

This document defines the home-screen dashboard content shown after login for every supported HOSSPI HMS account type. It uses the current implementation as the baseline:

- The backend already has canonical roles in `backend/src/config/roles.js`.
- The frontend mirrors those roles in `frontend/lib/core/permissions/access_policy.dart`.
- The backend already has a reusable `dashboard-workspace` response shape with `overview`, `queue`, `activity`, `insights`, `getting_started`, `status_strip`, and `quick_action_ids`.
- The current Flutter `HomePage` is still generic, so the home screen should be replaced with a role-aware dashboard that reuses the same layout and content sections for all account types.

The goal is maximum UI similarity: every account type sees the same home structure, but with role-specific cards, queues, alerts, actions, and shortcuts.

---

## Universal home dashboard structure

All account dashboards should use the same visual layout and the same reusable widgets.

| Section | Purpose | Content rules |
| --- | --- | --- |
| Hero/context header | Confirms where the user is working. | Show role label, tenant/facility/branch context, date range, and a short role-specific sentence. |
| Status strip | Fast summary of today’s work. | 4–6 compact cards. Use the same card component for every role. Hide cards the user cannot access. |
| Quick actions | One-tap entry into common work. | Show up to 4 primary actions first; move the rest into “More actions”. Disable or hide actions without permission/module entitlement. |
| Primary queue preview | Shows the user’s most important pending work. | Show up to 5 items with status, urgency, timestamp, and target route. Include “View all” deep link. |
| Alerts and insights | Shows risk, blockers, and reminders. | Use the same alert-card component. Keep alerts actionable and not noisy. |
| Activity feed | Recent updates relevant to the user. | Show up to 6 recent updates. Use neutral wording and do not expose restricted PHI. |
| Shortcuts | Stable links to common modules. | Role-gated route tiles using the same tile component. |
| Empty/getting-started state | Guides the user when there is no data. | Use one role-specific empty message and 1–3 safe next actions. |

### Reusable content contract

Use this structure for each role profile:

```text
role_profile_id
role_label
home_title
home_subtitle
status_cards[]
primary_queue[]
alerts[]
quick_actions[]
shortcuts[]
activity_feed[]
empty_state
```

### Multi-role users

When a user has multiple roles:

1. Use the current backend hierarchy to choose the main hero/profile.
2. Merge permitted quick actions and shortcuts from all roles.
3. Do not merge restricted queues unless the backend grants the matching permission and scope.
4. Keep the UI consistent by using the same layout, not a custom dashboard per role.

### Common cards available to all staff roles

These can appear where permitted:

| Card ID | Label | Used by |
| --- | --- | --- |
| `opd_notifications_attention` | OPD notifications pending attention | All staff roles with OPD visibility |
| `my_pending_tasks` | My pending tasks | All staff roles with assigned work |
| `critical_alerts` | Critical alerts | Clinical, nursing, admin, operations, emergency |
| `messages_unread` | Unread messages | Staff roles with communications access |
| `reports_ready` | Reports ready | Admin, billing, HR, operations, managers |

---

## Quick action library

These action IDs should be reused across the home dashboard. Each action should map to a route target and must be permission/module gated.

| Action ID | Label | Target module | Typical roles |
| --- | --- | --- | --- |
| `new_patient` | Register patient | Patients | Admin, receptionist, doctor, nurse |
| `appointment` | Book appointment | OPD / scheduling | Admin, receptionist, doctor, nurse |
| `start_consultation` | Start consultation | Clinical | Doctor |
| `record_vitals` | Record vitals | Triage / nursing | Nurse, doctor, emergency |
| `start_admission` | Start admission | IPD | Admin, doctor, nurse, ward/ICU managers |
| `lab_order` | Create lab order | Laboratory | Doctor, admin, lab where allowed |
| `radiology_order` | Create imaging order | Radiology | Doctor, admin, radiology where allowed |
| `invoice` | Create invoice | Billing | Admin, receptionist, billing |
| `receive_payment` | Receive payment | Billing | Billing, admin |
| `sale` | Pharmacy sale/dispense | Pharmacy | Pharmacist, admin |
| `staff_profile` | Add staff profile | HR | HR, tenant/facility admin, unit managers where allowed |
| `publish_roster` | Publish roster | HR / roster | HR, unit manager, ward manager, ICU manager, theatre manager |
| `report_maintenance_issue` | Report maintenance issue | Operations | Operations, housekeeping manager, facility admin |
| `report_equipment_issue` | Report equipment issue | Biomedical | Biomed, biomed manager, operations, admin |
| `cleaning_task` | Create cleaning task | Housekeeping | Housekeeping manager, operations |
| `dispatch_ambulance` | Dispatch ambulance | Emergency | Ambulance operator, emergency, admin |
| `mortuary_case` | Open mortuary case | Mortuary | Mortuary staff/manager |
| `release_authorisation` | Review release authorization | Mortuary | Mortuary manager |
| `run_report` | Run report | Reports | Admin, billing, HR, operations, managers |
| `manage_subscription` | Manage subscription | Subscriptions | Super admin, tenant admin, facility admin |
| `select_context` | Select tenant/facility | Dashboard context | Super admin |

---

## Account type summary matrix

| Account type | Recommended profile ID | Reusable pack | Primary home focus |
| --- | --- | --- | --- |
| `SUPER_ADMIN` | `super_admin` | Admin | Tenant selection, platform readiness, subscriptions, security, integrations. |
| `TENANT_ADMIN` | `tenant_admin` | Admin | Organization-wide operations, subscription health, module adoption, cross-facility performance. |
| `FACILITY_ADMIN` | `facility_admin` | Admin | Facility readiness, patient flow, staffing, billing, beds, operational blockers. |
| `DOCTOR` | `doctor` | Doctor | Consultations, results, admissions, clinical follow-up. |
| `NURSE` | `nurse` | Nurse | Nursing tasks, vitals, medication administration, admissions, handovers. |
| `LAB_TECH` | `lab_tech` | Lab tech | Lab orders, samples, pending results, critical results. |
| `RADIOLOGY_TECH` | `radiology_tech` | Radiology tech | Imaging orders, studies, draft/final reports, urgent imaging. |
| `PHARMACIST` | `pharmacist` | Pharmacist | Medication orders, dispensing, stock risk, returns. |
| `RECEPTIONIST` | `receptionist` | Receptionist | Registrations, appointments, OPD queue, front-desk billing. |
| `BILLING` | `billing` | Billing | Invoices, payments, overdue balances, claims, shift/day close. |
| `OPERATIONS` | `operations` | Operations | Beds, maintenance, housekeeping backlog, facility readiness. |
| `HR` | `hr` | HR | Staff profiles, leave, shifts, rosters, staffing gaps. |
| `BIOMED` | `biomed` | Biomed | Equipment work orders, incidents, downtime, service risk. |
| `HOUSE_KEEPER` | `house_keeper` | House keeper | Assigned cleaning tasks, turnover, overdue rooms, completion throughput. |
| `AMBULANCE_OPERATOR` | `ambulance_operator` | Ambulance | Dispatches, active trips, emergency handovers, fleet status. |
| `UNIT_MANAGER` | `unit_manager` | Manager/Nursing/HR | Unit census, staffing coverage, roster gaps, unit blockers. |
| `WARD_MANAGER` | `ward_manager` | Manager/Nursing | Ward census, bed pressure, nursing tasks, handover risks. |
| `ICU_MANAGER` | `icu_manager` | Manager/Nursing | ICU critical patients, bed pressure, staffing, escalation risks. |
| `THEATRE_MANAGER` | `theatre_manager` | Manager/Theatre | Theatre schedule, procedure readiness, cancellations, post-op handovers. |
| `HOUSEKEEPING_MANAGER` | `housekeeping_manager` | Manager/Housekeeping | Cleaning backlog, turnover readiness, staff coverage, room blockers. |
| `BIOMED_MANAGER` | `biomed_manager` | Manager/Biomed | Equipment risk, overdue maintenance, incidents, downtime, technician load. |
| `MORTUARY_STAFF` | `mortuary_staff` | Mortuary | Custody tasks, storage assignments, viewings, post-mortem requests. |
| `MORTUARY_MANAGER` | `mortuary_manager` | Mortuary manager | Release approvals, storage capacity, custody compliance, audit/export. |
| `PATIENT` | `patient` | Patient portal | Appointments, bills, prescriptions, results, profile. |
| `OTHER` | `other` | Limited | Profile, assigned accessible links, help, facility contact. |

---

# Detailed dashboard content by account type

## 1. `SUPER_ADMIN` — Platform administrator

**Home title:** Platform command center  
**Subtitle:** Select a tenant or review system-wide items that need attention.

| Section | Content |
| --- | --- |
| Status cards | Tenants active; Facilities active; Subscriptions needing review; Plan-limit warnings; Integration/API errors; Security/audit reviews. |
| Primary queue | Tenant setup queue; subscription changes; failed integrations; API key reviews; cross-tenant audit signals. |
| Alerts | Tenant context required; expiring/failed subscriptions; unusual access activity; integration failures; plan limits exceeded. |
| Quick actions | Select tenant/facility; Create tenant; Create facility; Manage subscription; Review audit; Manage integrations. |
| Shortcuts | Tenant/facility setup; Users and roles; Subscriptions; Reports and audit; Integrations; Settings. |
| Activity feed | Tenant created/updated; facility created/updated; subscription changed; role/permission changed; API key created/revoked; report export generated. |
| Empty state | “Choose a tenant to view operational dashboards.” Actions: Select tenant, Create tenant, Open subscriptions. |

Implementation note: when no tenant context exists, show the existing `tenant_context_required` state with a tenant selector instead of an empty operations dashboard.

---

## 2. `TENANT_ADMIN` — Organization administrator

**Home title:** Organization overview  
**Subtitle:** Monitor patient flow, revenue, staffing, module readiness, and subscription health across your organization.

| Section | Content |
| --- | --- |
| Status cards | Patients registered today; Appointments today; Active admissions; Open invoices; Payments received today; OPD notifications pending attention. |
| Primary queue | Appointments; admissions; billing follow-up; lab/radiology results; pharmacy orders; maintenance/housekeeping tasks; staff leave requests. |
| Alerts | Overdue invoices; critical lab results; high bed occupancy; plan-limit pressure; subscription/module issues; pending staff approvals. |
| Quick actions | Register patient; Book appointment; Create invoice; Start admission; Create lab order; Pharmacy sale; Report equipment issue; Run report. |
| Shortcuts | Patients; OPD; IPD; Clinical; Lab; Radiology; Pharmacy; Billing; Claims; HR; Operations; Reports; Subscriptions; Settings. |
| Activity feed | Registrations; admissions; invoices/payments; lab/radiology result updates; pharmacy updates; staff leave updates; maintenance updates. |
| Empty state | “Start by setting up patients, staff, services, and billing.” Actions: Register patient, Add staff profile, Configure facility. |

---

## 3. `FACILITY_ADMIN` — Facility administrator

**Home title:** Facility operations dashboard  
**Subtitle:** Track today’s flow, bed readiness, staffing, revenue, and operational blockers for this facility.

| Section | Content |
| --- | --- |
| Status cards | Patients added today; Appointments today; Active admissions; Occupied beds; Open invoices; Payments received today. |
| Primary queue | OPD arrivals; admissions; discharge blockers; billing follow-up; housekeeping turnover; maintenance requests; critical lab/radiology results. |
| Alerts | Bed occupancy pressure; overdue invoices; critical diagnostics; housekeeping backlog; open maintenance; low-stock pressure. |
| Quick actions | Register patient; Book appointment; Create invoice; Start admission; Report maintenance issue; Report equipment issue; Run facility report. |
| Shortcuts | OPD; Patients; IPD; Nursing; Clinical; Billing; Pharmacy; Lab; Radiology; Housekeeping; Biomedical; Reports; Settings. |
| Activity feed | Queue movements; admissions/transfers; payments; room/bed changes; maintenance and housekeeping updates; staff schedule changes. |
| Empty state | “Facility setup is ready for daily work once patients, services, beds, and staff are configured.” Actions: Register patient, Add bed/ward, Add staff profile. |

---

## 4. `DOCTOR` — Doctor / clinician

**Home title:** Clinical worklist  
**Subtitle:** Review assigned consultations, results, admissions, and urgent follow-up.

| Section | Content |
| --- | --- |
| Status cards | Assigned consultations; Consultations in progress; Completed consultations; Active admissions; Critical lab signals; OPD notifications pending attention. |
| Primary queue | Waiting consultations; in-progress consultations; results ready for review; active admissions needing review; follow-up due. |
| Alerts | Critical labs; abnormal radiology; urgent triage; emergency case handover; discharge summary pending; unread OPD update. |
| Quick actions | Start consultation; Continue consultation; Record note; Order lab; Order radiology; Start admission; Review results. |
| Shortcuts | Clinical; OPD; Triage; IPD; ICU if permitted; Lab results; Radiology results; Discharge. |
| Activity feed | Patient assigned; vitals recorded; result posted; diagnosis/procedure updated; medication order updated; admission/discharge updated. |
| Empty state | “No assigned clinical work right now.” Actions: Open clinical queue, View OPD queue, Review results. |

---

## 5. `NURSE` — Nurse

**Home title:** Nursing work dashboard  
**Subtitle:** Coordinate patient observations, medications, ward tasks, and handovers.

| Section | Content |
| --- | --- |
| Status cards | Active inpatients; Medication administrations today; Transfer queue; Critical lab signals; Discharge pressure; OPD notifications pending attention. |
| Primary queue | Medication tasks; vitals/observations due; nursing care tasks; transfer requests; handovers; admissions needing nursing review. |
| Alerts | Overdue medication; critical observation; high-priority triage; transfer delay; discharge blocker; last-office task requiring attention. |
| Quick actions | Record vitals; Record nursing note; Mark medication administered; Create handover; Escalate to doctor; Start admission where allowed. |
| Shortcuts | Nursing; IPD; ICU where permitted; OPD/Triage; Clinical read-only context; Discharge; Last office. |
| Activity feed | Vitals recorded; medication administered; care task completed; handover created; transfer initiated; discharge checklist updated. |
| Empty state | “No nursing tasks are assigned right now.” Actions: Open nursing workspace, Review inpatients, Check handovers. |

---

## 6. `LAB_TECH` — Laboratory technologist

**Home title:** Laboratory queue  
**Subtitle:** Process samples, update results, and highlight critical findings.

| Section | Content |
| --- | --- |
| Status cards | Lab orders today; Orders in process; Pending results; Critical results; Completed orders; OPD notifications pending attention. |
| Primary queue | New lab orders; samples awaiting collection/receipt; tests in process; pending result entry; critical/abnormal result review. |
| Alerts | Critical result pending acknowledgement; overdue sample; rejected sample; equipment/QC issue; high workload queue. |
| Quick actions | Receive sample; Update test status; Enter result; Mark critical result; Print lab report; Open lab queue. |
| Shortcuts | Lab orders; Samples; Results; Test catalog; Reports. |
| Activity feed | Order received; sample received; result entered; result finalized; critical result flagged; order completed. |
| Empty state | “No lab work is pending.” Actions: Open lab orders, Review completed results, Check test catalog. |

---

## 7. `RADIOLOGY_TECH` — Radiology / imaging technologist

**Home title:** Imaging worklist  
**Subtitle:** Track imaging requests, studies in progress, reports, and urgent imaging findings.

| Section | Content |
| --- | --- |
| Status cards | Radiology orders today; Studies in process; Draft reports; Final reports; Completed orders; OPD notifications pending attention. |
| Primary queue | New imaging orders; scheduled studies; studies in progress; draft reports; amended/urgent reports. |
| Alerts | Urgent imaging request; amended report; pending report finalization; delayed study; imaging asset/PACS issue. |
| Quick actions | Start study; Update study status; Add report; Finalize report where allowed; Open radiology queue. |
| Shortcuts | Radiology orders; Imaging studies; Reports; Test catalog; Reports/audit. |
| Activity feed | Order received; study started; report drafted; report finalized; amendment posted; order completed. |
| Empty state | “No imaging work is pending.” Actions: Open radiology orders, Review draft reports, Check completed studies. |

---

## 8. `PHARMACIST` — Pharmacist

**Home title:** Pharmacy workload  
**Subtitle:** Dispense medications, manage stock pressure, and review pending orders.

| Section | Content |
| --- | --- |
| Status cards | Medication orders today; Pending dispense workload; Dispensed today; Low stock pressure; Critical stock pressure; OPD notifications pending attention. |
| Primary queue | Medication orders awaiting dispense; partial dispenses; returns; low-stock items; expiring batch review. |
| Alerts | Critical stock; medication order overdue; partial dispense blocker; batch expiry risk; stock mismatch. |
| Quick actions | Dispense order; Record sale; Receive stock; Adjust stock where allowed; Review low stock; Open pharmacy queue. |
| Shortcuts | Pharmacy orders; Drugs/formulary; Inventory stock; Dispense logs; Billing link; Reports. |
| Activity feed | Order placed; item dispensed; stock adjusted; batch received; return recorded; low-stock alert updated. |
| Empty state | “No medication orders are waiting.” Actions: Open pharmacy orders, Review low stock, Open drug catalog. |

---

## 9. `RECEPTIONIST` — Reception / front desk

**Home title:** Front desk dashboard  
**Subtitle:** Manage registrations, appointments, arrivals, queue movement, and first billing steps.

| Section | Content |
| --- | --- |
| Status cards | Registrations today; Appointment desk queue; No-show pressure; Front billing queue; Appointments today; OPD notifications pending attention. |
| Primary queue | Scheduled appointments; arrivals/check-ins; patients waiting registration; OPD queue updates; invoices needing front-desk action. |
| Alerts | Late arrivals; no-show risk; missing patient details; billing pending before service; unread OPD routing update. |
| Quick actions | Register patient; Book appointment; Check in patient; Create invoice; Search patient; Open OPD board. |
| Shortcuts | Patients; OPD; Appointments; Billing; Profile/settings. |
| Activity feed | Patient registered; appointment booked/confirmed; arrival checked in; OPD status changed; invoice created. |
| Empty state | “No front-desk queue items right now.” Actions: Register patient, Book appointment, Open OPD board. |

---

## 10. `BILLING` — Billing / cashier

**Home title:** Billing workbench  
**Subtitle:** Manage invoices, payments, refunds, claims handoff, and daily closeout.

| Section | Content |
| --- | --- |
| Status cards | Invoices issued today; Overdue invoices; Open balances; Collections today; Refunds today; OPD notifications pending attention. |
| Primary queue | Draft invoices; invoices awaiting payment; overdue invoices; approval-required items; claims pending handoff; shift/day close reminders. |
| Alerts | Overdue balance; refund approval; claim billing blocker; unpaid discharge invoice; day close pending. |
| Quick actions | Create invoice; Receive payment; Issue receipt; Process refund where allowed; Close shift; Close day; Run billing report. |
| Shortcuts | Billing; Claims; Patients; Reports; Closeout; Audit/evidence export where permitted. |
| Activity feed | Invoice created/issued; payment posted; refund posted; claim updated; shift/day close completed. |
| Empty state | “No billing items need action.” Actions: Create invoice, Open payment queue, Review closeout. |

---

## 11. `OPERATIONS` — Facility operations

**Home title:** Operations readiness  
**Subtitle:** Track beds, maintenance, housekeeping blockers, stock pressure, and facility readiness.

| Section | Content |
| --- | --- |
| Status cards | Occupied beds; Total beds; Open maintenance requests; Low stock pressure; Housekeeping backlog; OPD notifications pending attention. |
| Primary queue | Maintenance requests; room/bed readiness blockers; housekeeping backlog; discharge/turnover blockers; operational incidents. |
| Alerts | Bed pressure; open maintenance; utility/HVAC issue; housekeeping delay; safety/compliance review; break-glass review where allowed. |
| Quick actions | Report maintenance issue; Assign maintenance; Review bed readiness; Open housekeeping queue; Run operations report. |
| Shortcuts | Operations; Rooms/beds; Housekeeping; Biomedical; Reports; Compliance; Settings. |
| Activity feed | Maintenance request opened/updated; bed status changed; room turnover updated; stock warning posted; compliance review updated. |
| Empty state | “No operations blockers are active.” Actions: Open operations queue, Review beds, Create maintenance request. |

---

## 12. `HR` — Human resources

**Home title:** Workforce dashboard  
**Subtitle:** Manage staff profiles, leave, shifts, rosters, and staffing gaps.

| Section | Content |
| --- | --- |
| Status cards | Active staff profiles; Shifts today; Pending leave approvals; Staffing backlog; Unassigned shifts; OPD notifications pending attention. |
| Primary queue | Pending leave requests; unassigned shifts; draft rosters; missing staff profile information; upcoming coverage gaps. |
| Alerts | Understaffed unit; unapproved leave; roster not published; expired assignment; missing role/permission setup. |
| Quick actions | Add staff profile; Assign role; Create shift; Publish roster; Review leave; Run HR report. |
| Shortcuts | Staff profiles; Positions/assignments; Leave; Shifts; Rosters; Users/roles; Reports. |
| Activity feed | Staff profile created; leave requested/approved; shift assigned; roster published; role assignment updated. |
| Empty state | “No HR tasks are pending.” Actions: Add staff profile, Create roster, Review leave queue. |

---

## 13. `BIOMED` — Biomedical technician

**Home title:** Biomedical service queue  
**Subtitle:** Manage equipment work orders, incidents, downtime, and service-risk items.

| Section | Content |
| --- | --- |
| Status cards | Open work orders; Open incidents; Active downtime events; Critical service-risk indicators; High-priority work orders; OPD notifications pending attention. |
| Primary queue | Equipment work orders; acknowledged/in-progress jobs; safety incidents; downtime events; calibration/service due tasks. |
| Alerts | Critical equipment down; overdue calibration; high-priority work order; incident not closed; spare part shortage. |
| Quick actions | Report equipment issue; Acknowledge work order; Update work order; Record downtime; Add service note; Run equipment report. |
| Shortcuts | Equipment registry; Work orders; Incidents; Downtime; Maintenance plans; Reports. |
| Activity feed | Work order opened/updated; incident recorded; downtime started/ended; calibration completed; equipment status changed. |
| Empty state | “No biomedical work is pending.” Actions: Open work orders, Review equipment registry, Report equipment issue. |

---

## 14. `HOUSE_KEEPER` — Housekeeping staff

**Home title:** My cleaning tasks  
**Subtitle:** Complete assigned cleaning, turnover, and sanitation tasks.

| Section | Content |
| --- | --- |
| Status cards | Pending tasks; Tasks in progress; Overdue tasks; Tasks completed today; Completion throughput; OPD notifications pending attention. |
| Primary queue | Assigned cleaning tasks; room/bed turnover; ward cleaning; sanitation tasks; laundry coordination tasks where enabled. |
| Alerts | Overdue cleaning; urgent room turnover; isolation/special cleaning task; blocked room; missed checklist. |
| Quick actions | Start task; Complete task; Mark blocked; Add note/photo where allowed; Open assigned tasks. |
| Shortcuts | My tasks; Housekeeping queue; Room readiness; Profile. |
| Activity feed | Task assigned; task started; task completed; room marked ready; blocker added/resolved. |
| Empty state | “No cleaning tasks are assigned right now.” Actions: Open housekeeping queue, Review completed tasks. |

---

## 15. `AMBULANCE_OPERATOR` — Ambulance / emergency transport

**Home title:** Ambulance dispatch board  
**Subtitle:** Track dispatches, active trips, emergency handovers, and fleet availability.

| Section | Content |
| --- | --- |
| Status cards | Dispatches today; Active trips; Critical emergencies; Fleet available; Fleet out of service; OPD notifications pending attention. |
| Primary queue | New dispatches; active trips; emergency cases awaiting transport; handover pending; fleet readiness issues. |
| Alerts | Critical case; delayed dispatch; vehicle out of service; missing handover; high-severity emergency update. |
| Quick actions | Accept dispatch; Update trip status; Record handover; Report fleet issue; Open emergency queue. |
| Shortcuts | Emergency cases; Ambulance dispatches; Trips; Fleet status; Communications. |
| Activity feed | Dispatch created; trip started; handover completed; emergency severity updated; vehicle status changed. |
| Empty state | “No ambulance dispatches are active.” Actions: Open emergency queue, Review fleet status. |

---

## 16. `UNIT_MANAGER` — Unit manager

**Home title:** Unit management dashboard  
**Subtitle:** Monitor unit workload, staff coverage, rosters, and operational blockers.

| Section | Content |
| --- | --- |
| Status cards | Unit census; Staff on shift; Unassigned shifts; Pending leave requests; Unit blockers; OPD notifications pending attention. |
| Primary queue | Unit staffing gaps; roster approvals; pending leave; patient flow blockers; overdue unit tasks. |
| Alerts | Understaffed unit; roster not published; high bed/workload pressure; unresolved blocker; overdue handover. |
| Quick actions | Publish roster; Assign staff; Review leave; Open unit report; Add handover note. |
| Shortcuts | Unit dashboard; HR roster; Staff profiles; IPD/Nursing where permitted; Reports. |
| Activity feed | Shift assigned; roster published; leave requested; unit blocker added/resolved; patient flow update. |
| Empty state | “No unit management items need action.” Actions: Review roster, Check staff coverage, Open unit report. |

Implementation note: this role currently needs a dedicated home profile instead of falling back to a generic operations profile.

---

## 17. `WARD_MANAGER` — Ward manager / charge nurse

**Home title:** Ward command view  
**Subtitle:** Track ward census, bed movement, nursing work, handovers, and staffing coverage.

| Section | Content |
| --- | --- |
| Status cards | Ward census; Occupied beds; Pending nursing tasks; Handover risks; Staff on shift; OPD notifications pending attention. |
| Primary queue | Ward admissions/transfers; medication/vitals overdue; discharge blockers; handovers; bed readiness issues. |
| Alerts | Bed pressure; overdue medication; critical observation; discharge delay; staffing gap; last-office task. |
| Quick actions | Review ward board; Assign nurse; Create handover; Record ward note; Review discharge blockers; Publish roster. |
| Shortcuts | Nursing; IPD; Rooms/beds; Discharge; Roster; Reports. |
| Activity feed | Admission/transfer updated; bed changed; nursing task completed; handover created; discharge checklist updated. |
| Empty state | “No ward issues are currently pending.” Actions: Open ward board, Review handovers, Check staffing. |

---

## 18. `ICU_MANAGER` — ICU manager

**Home title:** ICU oversight dashboard  
**Subtitle:** Monitor critical patients, ICU bed pressure, staffing, escalations, and transfer readiness.

| Section | Content |
| --- | --- |
| Status cards | ICU census; Critical patients; ICU beds occupied; Escalations open; Staff coverage; OPD notifications pending attention. |
| Primary queue | ICU stays needing review; critical observation alerts; transfer-out readiness; equipment/bed blockers; ICU roster gaps. |
| Alerts | Critical observation; bed capacity pressure; ventilator/equipment downtime; staffing gap; transfer delay. |
| Quick actions | Open ICU board; Review critical alerts; Assign staff; Create handover; Review transfer readiness; Run ICU report. |
| Shortcuts | ICU; Nursing; Clinical; Rooms/beds; Biomedical; Roster; Reports. |
| Activity feed | ICU observation posted; escalation opened/closed; transfer updated; bed status changed; staff assigned. |
| Empty state | “No ICU oversight items need action.” Actions: Open ICU board, Review alerts, Check staff coverage. |

---

## 19. `THEATRE_MANAGER` — Theatre manager

**Home title:** Theatre schedule dashboard  
**Subtitle:** Coordinate procedure readiness, theatre flow, staffing, and post-operative handovers.

| Section | Content |
| --- | --- |
| Status cards | Procedures today; Ready for theatre; In theatre; Post-op handovers pending; Cancellations/delays; OPD notifications pending attention. |
| Primary queue | Scheduled procedures; pre-theatre checks; in-progress cases; post-op handovers; cancelled/delayed cases; theatre staffing gaps. |
| Alerts | Missing pre-op checklist; theatre delay; equipment issue; anesthesia/pre-op blocker; post-op handover overdue. |
| Quick actions | Open theatre board; Confirm readiness; Assign theatre/team; Update procedure status; Create handover; Run theatre report. |
| Shortcuts | Theatre; Clinical; Nursing; IPD/ICU; Biomedical; Roster; Reports. |
| Activity feed | Procedure booked; readiness updated; procedure started/completed; handover created; cancellation logged. |
| Empty state | “No theatre cases need action.” Actions: Open theatre schedule, Review readiness, Check team roster. |

---

## 20. `HOUSEKEEPING_MANAGER` — Housekeeping manager

**Home title:** Housekeeping control dashboard  
**Subtitle:** Manage cleaning workload, turnover readiness, staff coverage, and blocked rooms.

| Section | Content |
| --- | --- |
| Status cards | Pending cleaning tasks; In-progress tasks; Overdue tasks; Rooms ready; Staff on shift; OPD notifications pending attention. |
| Primary queue | Unassigned cleaning tasks; urgent turnovers; blocked rooms; overdue sanitation tasks; staff workload balancing. |
| Alerts | Discharge turnover overdue; isolation cleaning required; room blocked; staffing gap; repeated checklist failure. |
| Quick actions | Create cleaning task; Assign staff; Mark room blocked/ready; Review turnover board; Run housekeeping report. |
| Shortcuts | Housekeeping; Rooms/beds; Operations; Roster; Reports. |
| Activity feed | Task created/assigned; task completed; room marked ready; blocker added/resolved; staff assignment changed. |
| Empty state | “No housekeeping backlog is pending.” Actions: Open task board, Create task, Check room readiness. |

---

## 21. `BIOMED_MANAGER` — Biomedical manager

**Home title:** Biomedical risk dashboard  
**Subtitle:** Oversee equipment risk, technician workload, incidents, downtime, and maintenance compliance.

| Section | Content |
| --- | --- |
| Status cards | Open work orders; High-priority work orders; Active downtime; Open incidents; Overdue maintenance/calibration; OPD notifications pending attention. |
| Primary queue | High-priority work orders; overdue calibration; open incidents; downtime events; technician assignment gaps; warranty/service follow-up. |
| Alerts | Critical equipment unavailable; safety incident; overdue preventive maintenance; recurring downtime; unassigned urgent work order. |
| Quick actions | Assign technician; Create work order; Review incident; Close downtime; Run equipment report; Export evidence where permitted. |
| Shortcuts | Biomedical; Equipment registry; Work orders; Incidents; Downtime; Maintenance plans; Reports. |
| Activity feed | Work order assigned; incident updated; downtime resolved; maintenance completed; equipment status changed. |
| Empty state | “No biomedical risk items need action.” Actions: Open work orders, Review maintenance due, Check equipment registry. |

---

## 22. `MORTUARY_STAFF` — Mortuary staff

**Home title:** Mortuary work queue  
**Subtitle:** Manage custody, storage, viewings, post-mortem requests, and billable events.

| Section | Content |
| --- | --- |
| Status cards | Active mortuary cases; Storage assignments; Viewings today; Post-mortem requests; Release tasks pending; OPD notifications pending attention. |
| Primary queue | New mortuary cases; storage assignment tasks; custody events to record; scheduled viewings; post-mortem requests; billable event capture. |
| Alerts | Missing custody event; storage slot capacity issue; viewing due; release paperwork incomplete; post-mortem request pending. |
| Quick actions | Open mortuary case; Assign storage slot; Record custody event; Schedule viewing; Add billable event. |
| Shortcuts | Mortuary cases; Deceased profiles; Storage units/slots; Custody events; Viewings; Post-mortem requests. |
| Activity feed | Case opened; custody event recorded; storage assigned; viewing scheduled/completed; billable event added. |
| Empty state | “No mortuary tasks are pending.” Actions: Open cases, Review storage, Record custody event. |

Implementation note: mortuary staff should receive a dedicated content profile instead of reusing the generic operations dashboard.

---

## 23. `MORTUARY_MANAGER` — Mortuary manager

**Home title:** Mortuary oversight dashboard  
**Subtitle:** Oversee custody compliance, storage capacity, release authorization, audit, and export readiness.

| Section | Content |
| --- | --- |
| Status cards | Active cases; Storage occupancy; Releases awaiting approval; Pending post-mortem requests; Custody exceptions; OPD notifications pending attention. |
| Primary queue | Release authorizations; custody exceptions; storage capacity issues; pending post-mortem requests; audit/export tasks; billable events needing review. |
| Alerts | Release approval required; custody chain incomplete; storage near capacity; overdue viewing/post-mortem step; missing billing event. |
| Quick actions | Review release authorization; Approve release; Review custody chain; Run mortuary report; Export mortuary evidence. |
| Shortcuts | Mortuary dashboard; Cases; Storage; Custody events; Release authorizations; Audit; Reports. |
| Activity feed | Release approved/rejected; custody event corrected; storage changed; report/export generated; case closed. |
| Empty state | “No mortuary approvals need action.” Actions: Review active cases, Check storage capacity, Open release queue. |

---

## 24. `PATIENT` — Patient portal account

**Home title:** My care dashboard  
**Subtitle:** View upcoming visits, care updates, bills, prescriptions, and personal profile information.

| Section | Content |
| --- | --- |
| Status cards | Upcoming appointments; Open bills; Prescriptions/medications; Lab/radiology results available; Messages/notifications. |
| Primary queue | Upcoming appointments; bills awaiting payment; results ready to view if released; prescriptions ready; profile/consent updates. |
| Alerts | Appointment reminder; unpaid bill; released result available; medication ready; profile information missing. |
| Quick actions | View appointments; Update profile; View bills; View prescriptions; View released results; Contact facility where enabled. |
| Shortcuts | My profile; Appointments; Bills/receipts; Prescriptions; Released results; Messages/help. |
| Activity feed | Appointment booked/changed; payment posted; result released; prescription updated; profile updated. |
| Empty state | “Your care updates will appear here.” Actions: View profile, Check appointments, Contact facility. |

Implementation note: patient accounts are excluded from the current staff `dashboard-workspace` route. They need a separate patient-safe home response or a limited frontend-only composition from permitted patient/profile endpoints.

---

## 25. `OTHER` — Limited/fallback account

**Home title:** Account home  
**Subtitle:** Access the areas assigned to your account.

| Section | Content |
| --- | --- |
| Status cards | Profile status; Assigned links; Unread messages where permitted; Facility notices where permitted. |
| Primary queue | Only explicitly assigned/permission-granted items. Do not show clinical, billing, or operational queues by default. |
| Alerts | Missing profile details; access not configured; facility notice; session/security reminder. |
| Quick actions | Open profile; Update profile; Open assigned module; Contact administrator. |
| Shortcuts | Profile; Settings; Any permitted module route. |
| Activity feed | Profile updated; permission/role changed; message received where permitted. |
| Empty state | “Your account has limited access. Contact an administrator if you need more modules.” Actions: Open profile, Open settings. |

---

# Shared dashboard behavior rules

## Permissions and module entitlements

- Never show a shortcut or quick action unless the user has the required permission and the module is active.
- A disabled action is acceptable only when the user can understand why it is disabled, such as “Module not enabled” or “Requires billing permission”.
- Backend authorization remains mandatory even when the frontend hides actions.

## Content density

- Keep the home dashboard useful but not crowded.
- Show 4–6 status cards, 3–4 quick actions, 5 queue items, and 4–6 activity items by default.
- Use “View all” links for full module workspaces.
- Avoid duplicating full module dashboards on the home screen.

## Routing targets

Use route targets instead of hard-coded paths where possible:

| Target module | Examples |
| --- | --- |
| `patients` | patient registry, patient details, patient creation |
| `scheduling` / `opd` | appointments, arrivals, OPD board |
| `clinical` | consultations, encounter detail, orders |
| `nursing` | nursing tasks, medication administration, handovers |
| `ipd` | admissions, beds, transfers |
| `icu` | ICU board, ICU stay detail |
| `theatre` | theatre schedule, procedure readiness |
| `lab` | lab orders, samples, results |
| `radiology` | imaging orders, studies, results |
| `pharmacy` | orders, dispensing, stock |
| `billing` | invoices, payments, refunds, closeout |
| `claims` | claim preparation, approval, submission |
| `hr` | staff profiles, leave, rosters |
| `operations` | maintenance, readiness, incidents |
| `housekeeping` | cleaning tasks, room turnover |
| `biomedical` | equipment, work orders, incidents |
| `mortuary` | cases, storage, custody, release |
| `reports` | reports, exports, audit |
| `subscriptions` | plans, modules, licenses |
| `settings` | tenant/facility/user settings |

## Recommended backend profile mapping updates

The current backend dashboard summary only maps a subset of roles to dedicated profiles. To avoid manager and mortuary accounts falling into generic content, add these profile mappings and reuse existing data packs until more specific metrics are available.

| Role | Add profile ID | Temporary data pack | Desired future pack |
| --- | --- | --- | --- |
| `UNIT_MANAGER` | `unit_manager` | `hr` or `operations` | `unit_manager` |
| `WARD_MANAGER` | `ward_manager` | `nurse` | `ward_manager` |
| `ICU_MANAGER` | `icu_manager` | `nurse` | `icu_manager` |
| `THEATRE_MANAGER` | `theatre_manager` | `operations` | `theatre_manager` |
| `HOUSEKEEPING_MANAGER` | `housekeeping_manager` | `house_keeper` or `operations` | `housekeeping_manager` |
| `BIOMED_MANAGER` | `biomed_manager` | `biomed` | `biomed_manager` |
| `MORTUARY_STAFF` | `mortuary_staff` | `operations` | `mortuary_staff` |
| `MORTUARY_MANAGER` | `mortuary_manager` | `operations` | `mortuary_manager` |
| `PATIENT` | `patient` | patient-safe endpoint | `patient` |
| `OTHER` | `other` | limited/profile endpoint | `other` |

## Suggested frontend implementation shape

- Replace the generic home content with `HomeDashboardPage` using the same shared components already used across workspaces.
- Fetch staff home content from `/api/v1/dashboard-workspace/workspace` when the role is not `PATIENT` or `OTHER`.
- For `PATIENT`, fetch a patient-safe dashboard from profile/patient-facing endpoints.
- For `OTHER`, render the limited fallback dashboard from session/profile data.
- Keep all dashboard strings localizable.
- Keep all cards/action labels driven by stable IDs so backend and frontend can share the same content model.

## Acceptance checklist

- Every canonical role has a defined home dashboard profile.
- Manager and mortuary accounts no longer fall into a generic operations/admin dashboard without specific copy.
- Patient and fallback accounts have safe, limited dashboards.
- The same visual sections appear across all account types.
- Actions, queues, alerts, and shortcuts are permission-gated.
- Dashboard content links back to module workspaces instead of duplicating full module workflows.
- Empty states guide the user to one or two safe next actions.
- Multi-role users receive a coherent merged dashboard without leaking unauthorized data.
