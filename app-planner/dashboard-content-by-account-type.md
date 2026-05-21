# Strict Role-Based Home Dashboard Content

## Purpose

This document defines the home-screen dashboard content for HOSSPI HMS after login. The dashboard must be **strictly role based**: every summary, queue, alert, shortcut, and action shown on the home screen must be allowed by the logged-in user’s role, permissions, scope, and enabled modules.

The visual dashboard should remain reusable and consistent across all roles. The difference between roles is the **content contract**, not the layout.

---

## Current implementation baseline to correct

The current implementation already has these useful foundations:

- Canonical backend roles in `backend/src/config/roles.js`.
- Backend role permissions in `backend/src/config/permissions.js`.
- Frontend role and permission alignment in `frontend/lib/core/permissions/access_policy.dart`.
- A reusable dashboard response shape from `dashboard-workspace` with summary cards, queue, alerts, activity, highlights, and scope.
- Shared workspace patterns that can be reused for cards, queues, activity rows, shortcuts, empty states, and action tiles.

The current dashboard content must be tightened in these areas:

1. Do **not** append `opd_notifications_attention` to every staff role. OPD cards should only appear for roles with OPD/patient-flow responsibility.
2. Do **not** let admin roles see direct provider workflow actions by default. Admin dashboards should show oversight, configuration, reporting, and exception actions unless the user also has a provider role.
3. Do **not** let manager roles fall back to generic operations/admin content. Each manager role needs its own profile and scoped summary pack.
4. Do **not** let mortuary roles fall back to operations. Mortuary staff and mortuary manager dashboards must be mortuary-specific.
5. Do **not** use broad “account type” content. Use role profiles and permission-gated content.
6. Patient and fallback users must use safe, limited dashboards and must not call the staff dashboard endpoint.

---

## Universal dashboard layout

Use the same layout for every role.

| Section | Purpose | Strict role rule |
| --- | --- | --- |
| Role header | Confirms the user’s active role and scope. | Show active role, tenant/facility/unit/self scope, and date range. |
| Summary cards | Gives fast role-specific metrics. | Show only cards tied to the active role’s allowed domains. |
| Quick actions | Gives one-tap role work. | Show only actions the role can perform. Hide all others. |
| Primary queue | Shows the user’s pending work. | Queue items must be role-scoped and permission-gated. |
| Alerts | Shows blockers or urgent items. | Alerts must be actionable by the role or useful for role oversight. |
| Activity feed | Shows recent updates relevant to the role. | Do not expose restricted patient, financial, HR, or audit details. |
| Shortcuts | Links to allowed workspaces. | Route tiles must require matching permission and module entitlement. |
| Empty state | Guides the user safely. | Empty actions must also obey role and permission gates. |

---

## Strict dashboard content contract

Each role profile should use this structure:

```text
role_code
role_profile_id
role_label
home_title
home_subtitle
scope_rule
required_permissions[]
summary_cards[]
primary_queue[]
alerts[]
quick_actions[]
shortcuts[]
activity_events[]
empty_state
hidden_by_default[]
```

Every item must have a stable ID and a gate:

```text
id
label
required_permissions[]
required_modules[]
allowed_roles[]
scope
route_target
```

---

## Core access rules

### 1. Permission plus role, not permission alone

Some roles inherit broad permissions. The home screen must still respect the role’s job function.

Example: `TENANT_ADMIN` may have clinical permissions, but the tenant admin home should show organization oversight, setup, reporting, and exceptions. It should not show `start_consultation` unless the same user also has `DOCTOR`.

### 2. Scope must be enforced

| Role type | Allowed scope |
| --- | --- |
| `SUPER_ADMIN` | Platform-level. Tenant/facility operational data only after selecting tenant/facility context. |
| `TENANT_ADMIN` | Tenant-wide oversight across facilities. |
| `FACILITY_ADMIN` | Facility/branch-scoped oversight. |
| Clinical roles | Assigned patients, assigned queues, or facility clinical queue where permitted. |
| Department roles | Department queue only, such as lab, radiology, pharmacy, billing, HR, operations, biomed, housekeeping, mortuary. |
| Manager roles | Assigned unit/ward/ICU/theatre/team scope. |
| `PATIENT` | Self only. |
| `OTHER` | Profile and explicitly assigned links only. |

### 3. Multi-role users

For users with multiple roles:

1. Show one shared dashboard layout.
2. Choose the header profile from the highest-priority role.
3. Merge content from all assigned roles, but keep cards/actions grouped by role domain.
4. Never infer access from an admin role into a provider action.
5. Never show a queue unless at least one assigned role has the matching permission and scope.
6. Deduplicate actions by stable ID.
7. Prefer direct work-role content over admin oversight content when both exist.

Example: a user with `TENANT_ADMIN` and `UNIT_MANAGER` can see organization oversight plus unit roster summaries. They should not see doctor/nurse actions unless they also have `DOCTOR` or `NURSE`.

---

## Dashboard item gating rules

| Content type | Must check |
| --- | --- |
| Summary card | Role profile, required permission, module entitlement, scope. |
| Queue item | Role profile, required permission, assigned queue ownership, scope. |
| Alert | Role profile, required permission, severity relevance, scope. |
| Quick action | Role profile, write/approve permission, route permission, module entitlement. |
| Shortcut | Read permission, module entitlement, route access. |
| Activity event | Read permission, event domain, PHI/financial/HR/audit visibility. |

---

## Role access matrix

| Role | Profile ID | Dashboard domain | Primary summary scope | Primary action type |
| --- | --- | --- | --- | --- |
| `SUPER_ADMIN` | `super_admin` | Platform administration | Platform, tenants, subscriptions, security | Context, tenant, subscription, system actions |
| `TENANT_ADMIN` | `tenant_admin` | Organization administration | Tenant-wide operational oversight | Setup, configuration, reporting, exception review |
| `FACILITY_ADMIN` | `facility_admin` | Facility administration | Facility/branch operations | Facility setup, patient-flow support, reports, blockers |
| `DOCTOR` | `doctor` | Clinical care | Assigned consultations and clinical review | Consultation and clinical order actions |
| `NURSE` | `nurse` | Nursing care | Assigned nursing tasks and patient observations | Vitals, medication, handover, escalation actions |
| `LAB_TECH` | `lab_tech` | Laboratory | Lab queue and samples | Sample and result processing actions |
| `RADIOLOGY_TECH` | `radiology_tech` | Radiology | Imaging queue and studies | Study and report processing actions |
| `PHARMACIST` | `pharmacist` | Pharmacy | Medication orders and stock | Dispense and inventory actions |
| `RECEPTIONIST` | `receptionist` | Front desk | Registrations, appointments, arrivals | Register, check in, appointment actions |
| `BILLING` | `billing` | Billing and cashier | Invoices, payments, balances, claims | Invoice, payment, refund, closeout actions |
| `OPERATIONS` | `operations` | Operations | Beds, maintenance, compliance, readiness | Maintenance, readiness, compliance actions |
| `HR` | `hr` | Human resources | Staff, shifts, leave, rosters | Staff, leave, roster actions |
| `BIOMED` | `biomed` | Biomedical service | Equipment, work orders, incidents | Equipment service actions |
| `HOUSE_KEEPER` | `house_keeper` | Housekeeping staff | Assigned cleaning tasks | Assigned task actions only |
| `AMBULANCE_OPERATOR` | `ambulance_operator` | Ambulance dispatch | Dispatches, trips, handovers | Dispatch and trip actions |
| `UNIT_MANAGER` | `unit_manager` | Unit management | Unit staffing, rosters, coverage | Unit staffing and roster actions |
| `WARD_MANAGER` | `ward_manager` | Ward management | Ward census, handovers, nursing oversight | Assignment, review, roster actions |
| `ICU_MANAGER` | `icu_manager` | ICU management | ICU census, critical alerts, staffing | ICU oversight and escalation actions |
| `THEATRE_MANAGER` | `theatre_manager` | Theatre management | Theatre schedule, readiness, staffing | Theatre readiness and procedure status actions |
| `HOUSEKEEPING_MANAGER` | `housekeeping_manager` | Housekeeping management | Cleaning backlog, turnover, staff coverage | Cleaning assignment and room readiness actions |
| `BIOMED_MANAGER` | `biomed_manager` | Biomedical management | Equipment risk, workload, downtime | Technician assignment and risk actions |
| `MORTUARY_STAFF` | `mortuary_staff` | Mortuary operations | Cases, storage, custody, viewings | Custody, storage, viewing, billable event actions |
| `MORTUARY_MANAGER` | `mortuary_manager` | Mortuary management | Releases, capacity, custody compliance | Release approval, audit, export actions |
| `PATIENT` | `patient` | Patient portal | Self-care only | Self-service actions |
| `OTHER` | `other` | Limited access | Profile and assigned links only | Profile and explicitly assigned actions |

---

## Quick action library

Actions must be reused across roles, but each action must still be permission-gated.

| Action ID | Label | Required gate | Primary roles |
| --- | --- | --- | --- |
| `select_context` | Select tenant/facility context | `system:admin` or `tenant:admin` | `SUPER_ADMIN`, `TENANT_ADMIN` |
| `create_tenant` | Create tenant | `system:admin` | `SUPER_ADMIN` |
| `create_facility` | Create facility | `tenant:admin` or `facility:admin` | `SUPER_ADMIN`, `TENANT_ADMIN`, `FACILITY_ADMIN` |
| `manage_subscription` | Manage subscription | `subscriptions:write` | `SUPER_ADMIN`, `TENANT_ADMIN`, `FACILITY_ADMIN` |
| `manage_users_roles` | Manage users and roles | `tenant:admin` or `facility:admin` | Admin roles, HR where allowed |
| `run_report` | Run report | `reports:read` | Admin, billing, operations, HR, managers |
| `review_audit` | Review audit/compliance | `compliance:review` or `evidence:export` | `SUPER_ADMIN`, `OPERATIONS`, `MORTUARY_MANAGER`, `BIOMED_MANAGER` |
| `register_patient` | Register patient | `patient:write` and patient module | `FACILITY_ADMIN`, `RECEPTIONIST`; other roles only if explicitly assigned |
| `book_appointment` | Book appointment | `patient:write` and scheduling/OPD module | `RECEPTIONIST`, `FACILITY_ADMIN`; other roles only if explicitly assigned |
| `check_in_patient` | Check in patient | `patient:write` and OPD module | `RECEPTIONIST`, `FACILITY_ADMIN` |
| `route_patient` | Route patient to service | `patient:write` and OPD module | `RECEPTIONIST`, `NURSE` where configured |
| `start_consultation` | Start consultation | `clinical:write` and `DOCTOR` role | `DOCTOR` |
| `continue_consultation` | Continue consultation | `clinical:write` and `DOCTOR` role | `DOCTOR` |
| `write_clinical_note` | Write clinical note | `clinical:write` and clinical role | `DOCTOR`, `NURSE`, `ICU_MANAGER`, `THEATRE_MANAGER` where configured |
| `order_lab` | Order lab test | `clinical:write` and clinical-order capability | `DOCTOR` |
| `order_radiology` | Order imaging | `clinical:write` and clinical-order capability | `DOCTOR` |
| `record_vitals` | Record vitals | `clinical:write` and nursing/clinical scope | `NURSE`, `DOCTOR`, `ICU_MANAGER` where configured |
| `mark_med_administered` | Mark medication administered | `clinical:write` and nursing scope | `NURSE` |
| `create_handover` | Create handover | `clinical:write` or manager handover capability | `NURSE`, `WARD_MANAGER`, `ICU_MANAGER`, `THEATRE_MANAGER` |
| `receive_sample` | Receive sample | `lab:write` | `LAB_TECH` |
| `enter_lab_result` | Enter lab result | `lab:write` | `LAB_TECH` |
| `flag_critical_lab` | Flag critical lab result | `lab:write` | `LAB_TECH` |
| `start_imaging_study` | Start imaging study | `radiology:write` | `RADIOLOGY_TECH` |
| `update_imaging_status` | Update imaging status | `radiology:write` | `RADIOLOGY_TECH` |
| `add_radiology_report` | Add imaging report | `radiology:write` | `RADIOLOGY_TECH` |
| `dispense_medication` | Dispense medication | `pharmacy:write` | `PHARMACIST` |
| `record_pharmacy_sale` | Record pharmacy sale | `pharmacy:write` | `PHARMACIST` |
| `receive_pharmacy_stock` | Receive pharmacy stock | `pharmacy:write` | `PHARMACIST` |
| `adjust_pharmacy_stock` | Adjust pharmacy stock | `pharmacy:write` | `PHARMACIST` |
| `create_invoice` | Create invoice | `billing:write` | `BILLING`, admin roles where acting as billing |
| `receive_payment` | Receive payment | `billing:write` | `BILLING` |
| `process_refund` | Process refund | `billing:write` plus approval rules | `BILLING` |
| `close_shift` | Close shift/day | `billing:write` | `BILLING` |
| `create_maintenance_request` | Create maintenance request | `operations:write` | `OPERATIONS`, `FACILITY_ADMIN` |
| `assign_maintenance` | Assign maintenance | `operations:write` | `OPERATIONS` |
| `update_bed_readiness` | Update bed/room readiness | `operations:write` | `OPERATIONS`, `HOUSEKEEPING_MANAGER` where configured |
| `create_cleaning_task` | Create cleaning task | `operations:write` | `HOUSEKEEPING_MANAGER`, `OPERATIONS` |
| `assign_cleaning_task` | Assign cleaning task | `operations:write` | `HOUSEKEEPING_MANAGER` |
| `start_cleaning_task` | Start assigned cleaning task | assigned-task capability | `HOUSE_KEEPER` |
| `complete_cleaning_task` | Complete assigned cleaning task | assigned-task capability | `HOUSE_KEEPER` |
| `mark_cleaning_blocked` | Mark cleaning task blocked | assigned-task capability | `HOUSE_KEEPER`, `HOUSEKEEPING_MANAGER` |
| `add_staff_profile` | Add staff profile | `hr:write` | `HR`, admin roles |
| `review_leave` | Review leave request | `hr:write` or roster approval capability | `HR`, managers |
| `create_shift` | Create shift | `roster:write` | `HR`, managers |
| `publish_roster` | Publish roster | `roster:publish` | `HR`, `UNIT_MANAGER`, `WARD_MANAGER`, `ICU_MANAGER`, `THEATRE_MANAGER` |
| `approve_roster` | Approve roster | `roster:approve` | `HR`, managers where configured |
| `report_equipment_issue` | Report equipment issue | `biomed:write` or configured issue-report access | `BIOMED`, `BIOMED_MANAGER`, admin roles |
| `acknowledge_work_order` | Acknowledge work order | `biomed:write` | `BIOMED` |
| `update_work_order` | Update work order | `biomed:write` | `BIOMED`, `BIOMED_MANAGER` |
| `assign_technician` | Assign technician | `biomed:write` and manager scope | `BIOMED_MANAGER` |
| `dispatch_ambulance` | Dispatch ambulance | `emergency:write` | `AMBULANCE_OPERATOR`, emergency admin where configured |
| `update_trip_status` | Update trip status | `emergency:write` | `AMBULANCE_OPERATOR` |
| `record_emergency_handover` | Record emergency handover | `emergency:write` | `AMBULANCE_OPERATOR` |
| `open_mortuary_case` | Open mortuary case | `mortuary:write` | `MORTUARY_STAFF`, `MORTUARY_MANAGER` |
| `assign_storage_slot` | Assign storage slot | `mortuary:manage_storage` | `MORTUARY_STAFF`, `MORTUARY_MANAGER` |
| `record_custody_event` | Record custody event | `mortuary:write` | `MORTUARY_STAFF`, `MORTUARY_MANAGER` |
| `schedule_viewing` | Schedule viewing | `mortuary:write` | `MORTUARY_STAFF`, `MORTUARY_MANAGER` |
| `add_mortuary_billable_event` | Add mortuary billable event | `mortuary:billing_event` | `MORTUARY_STAFF`, `MORTUARY_MANAGER` |
| `review_release_authorization` | Review release authorization | `mortuary:release` or `mortuary:approve` | `MORTUARY_MANAGER` |
| `approve_release` | Approve release | `mortuary:approve` | `MORTUARY_MANAGER` |
| `export_mortuary_evidence` | Export mortuary evidence | `mortuary:export` or `evidence:export` | `MORTUARY_MANAGER` |
| `update_own_profile` | Update my profile | `profile:update` | `PATIENT`, `RECEPTIONIST`, users with profile update |
| `view_my_care` | View my care information | patient-safe self endpoint | `PATIENT` |
| `contact_facility` | Contact facility | patient-safe or communications access | `PATIENT`, `OTHER` where enabled |

---

# Role-specific dashboard content

## 1. `SUPER_ADMIN` — Platform administrator

**Home title:** Platform command center  
**Subtitle:** Manage tenants, subscriptions, platform security, and system readiness.

| Field | Strict content |
| --- | --- |
| Scope | Platform. Tenant/facility operational data requires selected context. |
| Required permissions | `system:admin`, `tenant:admin`, `subscriptions:*`, `reports:*`, `compliance:*`, `evidence:export` as applicable. |
| Summary cards | `tenants_active`; `facilities_active`; `subscriptions_at_risk`; `module_entitlement_issues`; `security_reviews_due`; `integration_errors`. |
| Primary queue | Tenant setup tasks; subscription changes; module entitlement issues; security/audit reviews; failed integrations; platform configuration issues. |
| Alerts | Missing tenant context; failed subscription payment; plan limits exceeded; unusual access activity; integration/API error; compliance review pending. |
| Quick actions | `select_context`; `create_tenant`; `create_facility`; `manage_subscription`; `review_audit`; `run_report`. |
| Shortcuts | Tenants; facilities; users and roles; subscriptions; platform reports; audit/compliance; integrations; settings. |
| Activity feed | Tenant created/updated; facility created/updated; subscription changed; role changed; audit reviewed; integration changed. |
| Hidden by default | Direct patient registration, consultation, nursing, lab result entry, pharmacy dispensing, billing cashier actions, and mortuary custody actions unless the user switches into a tenant/facility context and also has the matching operational role. |
| Empty state | “Select a tenant or create one to start reviewing operational dashboards.” Actions: `select_context`, `create_tenant`, `manage_subscription`. |

---

## 2. `TENANT_ADMIN` — Organization administrator

**Home title:** Organization overview  
**Subtitle:** Review tenant-wide readiness, facilities, subscription health, adoption, and operational exceptions.

| Field | Strict content |
| --- | --- |
| Scope | Tenant-wide, across all assigned facilities. |
| Required permissions | `tenant:admin`, `facility:admin`, `reports:read`, `subscriptions:read`, plus module read permissions for visible summaries. |
| Summary cards | `facilities_active`; `active_users`; `module_adoption`; `organization_patient_flow`; `organization_revenue_summary`; `staffing_exceptions`; `subscription_health`. |
| Primary queue | Facility setup gaps; module entitlement issues; high-level patient-flow exceptions; billing exceptions; staffing exceptions; compliance review items. |
| Alerts | Subscription issue; facility setup incomplete; high bed occupancy across facilities; unresolved compliance item; staffing coverage gap; plan-limit warning. |
| Quick actions | `create_facility`; `manage_users_roles`; `manage_subscription`; `add_staff_profile`; `run_report`; `review_audit`. |
| Shortcuts | Organization dashboard; facilities; users and roles; modules/subscriptions; reports; HR overview; billing overview; compliance; settings. |
| Activity feed | Facility created/updated; subscription changed; module enabled/disabled; staff profile created; report generated; compliance review updated. |
| Hidden by default | `start_consultation`, `record_vitals`, `enter_lab_result`, `dispense_medication`, `receive_payment`, `complete_cleaning_task`, `record_custody_event`. Show these only if the same user also has the matching role. |
| Empty state | “Set up facilities, users, modules, and reporting to activate the organization dashboard.” Actions: `create_facility`, `add_staff_profile`, `manage_subscription`. |

---

## 3. `FACILITY_ADMIN` — Facility administrator

**Home title:** Facility operations dashboard  
**Subtitle:** Review facility flow, staffing, beds, revenue, and operational blockers.

| Field | Strict content |
| --- | --- |
| Scope | Assigned facility or branch. |
| Required permissions | `facility:admin`, `patient:read`, `operations:read`, `billing:read`, `hr:read`, `reports:read`, plus module entitlements. |
| Summary cards | `patients_registered_today`; `appointments_today`; `active_admissions`; `bed_occupancy`; `open_invoices`; `staff_on_shift`; `open_facility_blockers`. |
| Primary queue | Arrivals needing admin support; admissions/discharge blockers; bed/room readiness blockers; billing follow-up; staffing gaps; maintenance blockers. |
| Alerts | Bed pressure; unpaid discharge blocker; maintenance issue affecting service; housekeeping turnover delay; staffing gap; critical diagnostic acknowledgment overdue. |
| Quick actions | `register_patient`; `book_appointment`; `check_in_patient`; `create_facility`; `create_maintenance_request`; `add_staff_profile`; `run_report`. |
| Shortcuts | Facility overview; patients; OPD/appointments; IPD/beds; billing overview; HR/staffing; operations; reports; settings. |
| Activity feed | Patient registered; arrival checked in; admission/discharge updated; bed status changed; invoice issued; staff shift updated; maintenance task updated. |
| Hidden by default | Direct provider actions such as `start_consultation`, `mark_med_administered`, `enter_lab_result`, `dispense_medication`, and `approve_release` unless the user also has the matching role. |
| Empty state | “Facility dashboard will populate once patients, staff, beds, and services are active.” Actions: `register_patient`, `add_staff_profile`, `run_report`. |

---

## 4. `DOCTOR` — Doctor / clinician

**Home title:** Clinical worklist  
**Subtitle:** Review assigned consultations, results, admissions, and urgent follow-up.

| Field | Strict content |
| --- | --- |
| Scope | Assigned consultations, assigned patients, and clinical queues the doctor is permitted to access. |
| Required permissions | `clinical:read`, `clinical:write`, `patient:read`, `patient:write`, `emergency:read`, `communications:*`, `break_glass:request`. |
| Summary cards | `assigned_consultations`; `consultations_in_progress`; `results_to_review`; `active_admissions_for_review`; `urgent_triage_cases`; `followups_due`. |
| Primary queue | Waiting consultations; in-progress consultations; lab/radiology results needing review; active inpatient reviews; emergency handovers; follow-up due list. |
| Alerts | Critical result; abnormal imaging; emergency handover; urgent triage; discharge summary pending; break-glass request status. |
| Quick actions | `start_consultation`; `continue_consultation`; `write_clinical_note`; `order_lab`; `order_radiology`; `create_handover`; `record_vitals` where configured. |
| Shortcuts | Clinical workspace; consultation queue; patient chart; results review; emergency cases; admissions review; communications. |
| Activity feed | Patient assigned; vitals posted; result finalized; order created; note added; diagnosis/procedure updated; admission/discharge updated. |
| Hidden by default | Patient registration, appointment desk, cashier actions, HR roster management, housekeeping tasks, equipment work orders, mortuary custody. |
| Empty state | “No assigned clinical work right now.” Actions: open clinical queue, review results, check emergency handovers. |

---

## 5. `NURSE` — Nurse

**Home title:** Nursing work dashboard  
**Subtitle:** Complete assigned observations, medications, care tasks, and handovers.

| Field | Strict content |
| --- | --- |
| Scope | Assigned ward/unit patients, assigned nursing tasks, and permitted emergency/triage tasks. |
| Required permissions | `clinical:read`, `clinical:write`, `patient:read`, `patient:write`, `emergency:*`, `last_office:read`, `last_office:write`, `communications:*`. |
| Summary cards | `assigned_nursing_tasks`; `vitals_due`; `medications_due`; `handover_items`; `patient_alerts`; `last_office_tasks`. |
| Primary queue | Medication administration tasks; vitals/observation tasks; nursing care tasks; handovers; transfer/admission nursing review; last-office nursing tasks. |
| Alerts | Overdue medication; critical observation; urgent triage update; transfer delay; unresolved handover; last-office task requiring attention. |
| Quick actions | `record_vitals`; `mark_med_administered`; `write_clinical_note`; `create_handover`; `route_patient` where configured; escalate to doctor. |
| Shortcuts | Nursing workspace; assigned patients; medication administration; observations; handovers; triage/emergency; last office. |
| Activity feed | Vitals recorded; medication administered; nursing note added; care task completed; handover created; transfer updated. |
| Hidden by default | Appointment booking, cashier actions, lab result entry, imaging reports, pharmacy stock, HR roster publishing, operations maintenance, mortuary approvals. |
| Empty state | “No nursing tasks are assigned right now.” Actions: open nursing workspace, review handovers, check assigned patients. |

---

## 6. `LAB_TECH` — Laboratory technologist

**Home title:** Laboratory queue  
**Subtitle:** Process samples, enter results, and flag critical findings.

| Field | Strict content |
| --- | --- |
| Scope | Laboratory orders, samples, tests, and results within assigned facility/lab scope. |
| Required permissions | `lab:read`, `lab:write`, `communications:*`, `profile:read`. |
| Summary cards | `lab_orders_today`; `samples_awaiting_receipt`; `tests_in_process`; `results_pending_entry`; `critical_results`; `rejected_samples`. |
| Primary queue | New lab orders; samples awaiting collection/receipt; tests in process; pending result entry; critical/abnormal result flagging; rejected samples. |
| Alerts | Critical result not acknowledged; overdue sample; rejected sample; analyzer/QC issue; high workload queue. |
| Quick actions | `receive_sample`; `enter_lab_result`; `flag_critical_lab`; update sample status; print lab report; message ordering clinician. |
| Shortcuts | Lab workspace; orders; samples; results; test catalog; lab reports. |
| Activity feed | Order received; sample received; result entered; result finalized; critical result flagged; order completed. |
| Hidden by default | Creating clinical orders for patients, consultation notes, nursing tasks, pharmacy dispensing, billing payments, HR, operations, mortuary. |
| Empty state | “No lab work is pending.” Actions: open lab orders, review pending samples, check completed results. |

---

## 7. `RADIOLOGY_TECH` — Radiology / imaging technologist

**Home title:** Imaging worklist  
**Subtitle:** Process imaging studies, update statuses, and manage reports.

| Field | Strict content |
| --- | --- |
| Scope | Radiology/imaging orders, studies, assets, and reports within assigned facility/radiology scope. |
| Required permissions | `radiology:read`, `radiology:write`, `patient:read`, `communications:*`, `profile:read`. |
| Summary cards | `radiology_orders_today`; `studies_waiting`; `studies_in_process`; `draft_reports`; `urgent_imaging`; `completed_studies`. |
| Primary queue | New imaging orders; scheduled studies; studies in progress; asset upload pending; draft reports; urgent/amended reports. |
| Alerts | Urgent imaging request; delayed study; amended report; pending finalization; imaging/PACS issue. |
| Quick actions | `start_imaging_study`; `update_imaging_status`; attach study asset; `add_radiology_report`; request/finalize report where permitted. |
| Shortcuts | Radiology workspace; imaging orders; study list; reports; imaging catalog; radiology reports. |
| Activity feed | Order received; study started; asset uploaded; report drafted; report finalized; amendment posted; order completed. |
| Hidden by default | Patient registration, clinical consultation, lab result entry, pharmacy dispensing, billing cashier actions, HR, operations, mortuary. |
| Empty state | “No imaging work is pending.” Actions: open radiology orders, review draft reports, check completed studies. |

---

## 8. `PHARMACIST` — Pharmacist

**Home title:** Pharmacy workload  
**Subtitle:** Dispense medication orders and manage pharmacy stock pressure.

| Field | Strict content |
| --- | --- |
| Scope | Pharmacy orders, dispense workflow, returns, and inventory within assigned pharmacy/facility scope. |
| Required permissions | `pharmacy:read`, `pharmacy:write`, `communications:*`, `profile:read`. |
| Summary cards | `medication_orders_today`; `pending_dispense`; `prepared_dispenses`; `dispensed_today`; `low_stock_items`; `expiring_batches`. |
| Primary queue | Medication orders awaiting dispense; partial dispenses; dispense attestations; returns; low stock; expiring batch review. |
| Alerts | Critical stock; medication order overdue; partial dispense blocker; batch expiry risk; stock mismatch. |
| Quick actions | `dispense_medication`; `record_pharmacy_sale`; `receive_pharmacy_stock`; `adjust_pharmacy_stock`; record return; review low stock. |
| Shortcuts | Pharmacy workspace; medication orders; dispensing; drugs/formulary; inventory; returns; pharmacy reports. |
| Activity feed | Order placed; item prepared; item dispensed; stock adjusted; batch received; return recorded; low-stock alert updated. |
| Hidden by default | Clinical notes, nursing tasks, lab/radiology result entry, patient registration, billing payment collection, HR, operations, mortuary. |
| Empty state | “No medication orders are waiting.” Actions: open pharmacy orders, review low stock, open drug catalog. |

---

## 9. `RECEPTIONIST` — Reception / front desk

**Home title:** Front desk dashboard  
**Subtitle:** Manage registration, appointments, arrivals, and patient routing.

| Field | Strict content |
| --- | --- |
| Scope | Front-desk patient registration, appointment desk, arrival/check-in, and permitted OPD routing for assigned facility/branch. |
| Required permissions | `patient:read`, `patient:write`, `operations:read`, `last_office:read`, `last_office:write`, `communications:*`, `profile:update`. |
| Summary cards | `registrations_today`; `appointments_today`; `arrivals_waiting`; `checkins_completed`; `missing_demographics`; `front_desk_messages`. |
| Primary queue | Scheduled appointments; arrivals/check-ins; patients waiting registration; missing patient details; OPD routing updates; last-office front-desk tasks where enabled. |
| Alerts | Late arrival; no-show risk; missing demographics; duplicate patient warning; unread routing update; pending front-desk handoff. |
| Quick actions | `register_patient`; `book_appointment`; `check_in_patient`; `route_patient`; update demographics; search patient. |
| Shortcuts | Patients; appointments; OPD board; arrivals; patient search; communications; profile/settings. |
| Activity feed | Patient registered; appointment booked/changed; arrival checked in; patient routed; demographic details updated; message received. |
| Hidden by default | Invoice/payment actions unless `billing:write` is also granted; clinical notes; lab result entry; pharmacy dispensing; HR; operations maintenance; mortuary. |
| Empty state | “No front-desk items need action.” Actions: `register_patient`, `book_appointment`, open arrivals. |

---

## 10. `BILLING` — Billing / cashier

**Home title:** Billing workbench  
**Subtitle:** Manage invoices, payments, refunds, claims handoff, and closeout.

| Field | Strict content |
| --- | --- |
| Scope | Billing records, patient balances, claims handoff, cashier sessions, and financial reports for assigned facility/branch. |
| Required permissions | `billing:read`, `billing:write`, `financial:approve`, `evidence:export`, `reports:read`, `communications:*`, `profile:read`. |
| Summary cards | `invoices_issued_today`; `payments_received_today`; `open_balances`; `overdue_invoices`; `refunds_pending`; `claims_pending_handoff`; `closeout_status`. |
| Primary queue | Draft invoices; invoices awaiting payment; overdue balances; refunds needing approval; claims billing blockers; shift/day close reminders. |
| Alerts | Unpaid discharge invoice; overdue balance; refund approval required; claim billing blocker; closeout pending; suspicious adjustment. |
| Quick actions | `create_invoice`; `receive_payment`; issue receipt; `process_refund`; `close_shift`; run billing report; export evidence where permitted. |
| Shortcuts | Billing workspace; invoices; payments; refunds; claims; closeout; financial reports; audit/evidence. |
| Activity feed | Invoice created/issued; payment posted; receipt issued; refund posted; claim updated; shift/day closed; evidence exported. |
| Hidden by default | Clinical/nursing actions, lab/radiology processing, pharmacy dispensing, HR rosters, maintenance tasks, mortuary custody. |
| Empty state | “No billing items need action.” Actions: `create_invoice`, `receive_payment`, review closeout. |

---

## 11. `OPERATIONS` — Facility operations

**Home title:** Operations readiness  
**Subtitle:** Track facility readiness, maintenance, beds, compliance, and operational blockers.

| Field | Strict content |
| --- | --- |
| Scope | Facility operations, rooms/beds, maintenance, readiness, compliance, break-glass review, and last-office operational tasks. |
| Required permissions | `operations:read`, `operations:write`, `last_office:*`, `compliance:*`, `break_glass:review`, `break_glass:approve`, `evidence:export`, `reports:read`, `communications:*`. |
| Summary cards | `occupied_beds`; `available_beds`; `open_maintenance_requests`; `room_readiness_blockers`; `compliance_reviews_due`; `break_glass_reviews`; `last_office_items`. |
| Primary queue | Maintenance requests; room/bed readiness blockers; facility incidents; compliance review items; break-glass requests; last-office operational follow-up. |
| Alerts | Bed pressure; critical maintenance issue; utility/HVAC issue; room readiness delay; compliance review overdue; break-glass approval pending. |
| Quick actions | `create_maintenance_request`; `assign_maintenance`; `update_bed_readiness`; review compliance; approve break-glass; `run_report`. |
| Shortcuts | Operations workspace; rooms/beds; maintenance; incidents; compliance; break-glass review; reports. |
| Activity feed | Maintenance request opened/updated; room status changed; bed status changed; incident updated; compliance review completed; break-glass reviewed. |
| Hidden by default | Direct patient care, appointment desk, billing payment collection, lab/radiology result entry, pharmacy dispensing, HR leave approvals unless also HR. |
| Empty state | “No operations blockers are active.” Actions: open operations queue, review bed readiness, create maintenance request. |

---

## 12. `HR` — Human resources

**Home title:** Workforce dashboard  
**Subtitle:** Manage staff profiles, leave, shifts, rosters, and staffing gaps.

| Field | Strict content |
| --- | --- |
| Scope | Staff, assignments, leave, shifts, rosters, units, and workforce reports for assigned tenant/facility scope. |
| Required permissions | `hr:read`, `hr:write`, `unit:read`, `unit:manage`, `roster:*`, `reports:read`, `communications:*`, `profile:read`. |
| Summary cards | `active_staff_profiles`; `shifts_today`; `pending_leave_requests`; `unassigned_shifts`; `draft_rosters`; `coverage_gaps`; `role_setup_gaps`. |
| Primary queue | Pending leave; unassigned shifts; draft rosters; missing staff profile details; expired assignments; coverage gaps; role/permission setup gaps. |
| Alerts | Understaffed unit; roster not published; leave approval overdue; expired assignment; missing role setup; unassigned critical shift. |
| Quick actions | `add_staff_profile`; `manage_users_roles`; `review_leave`; `create_shift`; `publish_roster`; `approve_roster`; `run_report`. |
| Shortcuts | Staff profiles; positions/assignments; leave; shifts; rosters; units; users/roles; HR reports. |
| Activity feed | Staff profile created; leave requested/approved; shift assigned; roster published; role/permission updated; unit assignment changed. |
| Hidden by default | Patient clinical details, billing payments, lab/radiology processing, pharmacy dispensing, maintenance tasks, mortuary custody. |
| Empty state | “No HR tasks are pending.” Actions: `add_staff_profile`, create roster, review leave queue. |

---

## 13. `BIOMED` — Biomedical technician

**Home title:** Biomedical service queue  
**Subtitle:** Manage assigned equipment work orders, incidents, downtime, and service tasks.

| Field | Strict content |
| --- | --- |
| Scope | Biomedical equipment, assigned work orders, service incidents, downtime, and maintenance plans. |
| Required permissions | `biomed:read`, `biomed:write`, `evidence:export`, `communications:*`, `profile:read`. |
| Summary cards | `assigned_work_orders`; `high_priority_work_orders`; `open_incidents`; `active_downtime`; `maintenance_due`; `calibration_due`. |
| Primary queue | Assigned work orders; acknowledged/in-progress jobs; equipment incidents; downtime events; calibration/service due tasks. |
| Alerts | Critical equipment down; overdue calibration; high-priority work order; incident not closed; spare part shortage. |
| Quick actions | `acknowledge_work_order`; `update_work_order`; record downtime; add service note; update equipment status; `report_equipment_issue`. |
| Shortcuts | Biomedical workspace; equipment registry; work orders; incidents; downtime; maintenance plans; service reports. |
| Activity feed | Work order opened/assigned/updated; incident recorded; downtime started/ended; calibration completed; equipment status changed. |
| Hidden by default | Patient care queues, billing, HR roster approvals, housekeeping task completion, pharmacy inventory, mortuary releases. |
| Empty state | “No biomedical work is pending.” Actions: open work orders, review equipment registry, report equipment issue. |

---

## 14. `HOUSE_KEEPER` — Housekeeping staff

**Home title:** My cleaning tasks  
**Subtitle:** Complete assigned cleaning, turnover, and sanitation tasks.

| Field | Strict content |
| --- | --- |
| Scope | Assigned cleaning tasks only. Room/bed context should be minimal and task-focused. |
| Required permissions | Current mapping gives `operations:read`, `communications:read`, `profile:read`, `patient:read`. Task completion actions require an assigned-task update capability or a backend route that explicitly allows assigned housekeeping users to update their own tasks. |
| Summary cards | `my_pending_cleaning_tasks`; `my_in_progress_tasks`; `my_overdue_tasks`; `my_completed_today`; `blocked_tasks`. |
| Primary queue | Assigned cleaning tasks; urgent room turnover; sanitation task; blocked task; task note/checklist follow-up. |
| Alerts | Overdue assigned cleaning; urgent room turnover; isolation/special cleaning; blocked room; missed checklist. |
| Quick actions | `start_cleaning_task`; `complete_cleaning_task`; `mark_cleaning_blocked`; add task note/checklist response where allowed. |
| Shortcuts | My tasks; assigned housekeeping queue; room readiness read-only view; profile. |
| Activity feed | Task assigned; task started; task completed; blocker added/resolved; room marked ready by authorized user. |
| Hidden by default | Patient clinical details, billing, staff rosters, maintenance assignment, facility-wide operations reports, mortuary, biomed. |
| Empty state | “No cleaning tasks are assigned right now.” Actions: open my tasks, review completed tasks. |

Implementation note: do not expose facility-wide operations actions to `HOUSE_KEEPER` just because the role has `operations:read`.

---

## 15. `AMBULANCE_OPERATOR` — Ambulance / emergency transport

**Home title:** Ambulance dispatch board  
**Subtitle:** Track dispatches, active trips, emergency handovers, and fleet availability.

| Field | Strict content |
| --- | --- |
| Scope | Emergency transport dispatches, assigned ambulance trips, handovers, and fleet readiness visible to the operator. |
| Required permissions | `emergency:read`, `emergency:write`, `communications:*`, `profile:read`. |
| Summary cards | `dispatches_today`; `active_trips`; `pending_handovers`; `critical_emergency_cases`; `fleet_available`; `fleet_out_of_service`. |
| Primary queue | New dispatches; active trips; emergency cases awaiting transport; handover pending; fleet readiness issues. |
| Alerts | Critical emergency dispatch; delayed dispatch; vehicle out of service; missing handover; high-severity case update. |
| Quick actions | `dispatch_ambulance` where allowed; accept dispatch; `update_trip_status`; `record_emergency_handover`; report fleet issue. |
| Shortcuts | Emergency cases; ambulance dispatches; active trips; handovers; fleet status; communications. |
| Activity feed | Dispatch created; trip accepted/started/completed; handover completed; emergency severity updated; vehicle status changed. |
| Hidden by default | Clinical consultation notes outside emergency handover, billing, HR, pharmacy, lab/radiology processing, mortuary, subscriptions. |
| Empty state | “No ambulance dispatches are active.” Actions: open dispatch board, review fleet status. |

---

## 16. `UNIT_MANAGER` — Unit manager

**Home title:** Unit management dashboard  
**Subtitle:** Monitor unit coverage, rosters, staffing exceptions, and assigned unit blockers.

| Field | Strict content |
| --- | --- |
| Scope | Assigned unit/team scope. No patient clinical details by default. |
| Required permissions | `hr:read`, `unit:read`, `unit:manage`, `roster:read`, `roster:write`, `roster:publish`, `roster:approve`, `reports:read`, `profile:read`. |
| Summary cards | `unit_staff_on_shift`; `unit_unassigned_shifts`; `pending_leave_for_unit`; `draft_roster_status`; `coverage_gaps`; `unit_task_blockers`. |
| Primary queue | Unit staffing gaps; roster approvals; pending leave; unassigned shifts; expired assignments; unit blocker follow-up. |
| Alerts | Understaffed unit; roster not published; leave conflict; uncovered shift; unresolved unit blocker. |
| Quick actions | assign staff; `review_leave`; `create_shift`; `publish_roster`; `approve_roster`; `run_report`. |
| Shortcuts | Unit dashboard; staff coverage; rosters; leave; shifts; unit reports. |
| Activity feed | Shift assigned; roster published; leave requested/approved; unit blocker added/resolved; staff assignment changed. |
| Hidden by default | Patient clinical queues, billing, pharmacy, lab/radiology, housekeeping tasks, equipment service, mortuary. |
| Empty state | “No unit management items need action.” Actions: review roster, check staff coverage, open unit report. |

---

## 17. `WARD_MANAGER` — Ward manager / charge nurse

**Home title:** Ward command view  
**Subtitle:** Track ward census, handovers, nursing workload, bed movement, and staffing coverage.

| Field | Strict content |
| --- | --- |
| Scope | Assigned ward. Clinical visibility is read-oriented unless another role grants write access. |
| Required permissions | `patient:read`, `clinical:read`, `hr:read`, `unit:read`, `unit:manage`, `roster:*`, `reports:read`, `last_office:read`, `profile:read`. |
| Summary cards | `ward_census`; `occupied_ward_beds`; `pending_nursing_tasks`; `handover_risks`; `staff_on_shift`; `discharge_or_transfer_blockers`. |
| Primary queue | Ward admissions/transfers for review; overdue nursing tasks for oversight; handovers; bed readiness issues; staffing gaps; last-office items. |
| Alerts | Bed pressure; overdue medication or observation for review; discharge delay; staffing gap; unresolved handover; last-office alert. |
| Quick actions | assign nurse; review ward board; review handovers; `publish_roster`; `review_leave`; open ward report. |
| Shortcuts | Ward board; nursing oversight; IPD/beds; handovers; roster; leave; ward reports; last office. |
| Activity feed | Admission/transfer updated; bed changed; nursing task completed; handover created; discharge checklist updated; roster changed. |
| Hidden by default | Writing clinical notes or administering medication unless the user also has `NURSE`; billing, lab/radiology processing, pharmacy, maintenance assignment, mortuary. |
| Empty state | “No ward issues are currently pending.” Actions: open ward board, review handovers, check staffing. |

---

## 18. `ICU_MANAGER` — ICU manager

**Home title:** ICU oversight dashboard  
**Subtitle:** Monitor ICU census, critical alerts, transfers, handovers, and staffing coverage.

| Field | Strict content |
| --- | --- |
| Scope | Assigned ICU. Clinical write actions allowed only inside ICU manager workflow and configured clinical scope. |
| Required permissions | `patient:read`, `clinical:read`, `clinical:write`, `hr:read`, `unit:read`, `unit:manage`, `roster:*`, `reports:read`, `last_office:read`, `profile:read`. |
| Summary cards | `icu_census`; `critical_patient_alerts`; `icu_beds_occupied`; `transfer_readiness`; `staff_coverage`; `open_escalations`. |
| Primary queue | ICU stays needing review; critical observation alerts; transfer-out readiness; handover risks; ICU roster gaps; last-office ICU follow-up. |
| Alerts | Critical observation; ICU capacity pressure; transfer delay; staffing gap; unresolved escalation; overdue handover. |
| Quick actions | open ICU board; review critical alerts; assign staff; `create_handover`; update ICU status where permitted; `publish_roster`; run ICU report. |
| Shortcuts | ICU board; clinical review; handovers; transfers; roster; leave; ICU reports; last office. |
| Activity feed | ICU observation posted; escalation opened/closed; transfer updated; handover created; staff assigned; roster changed. |
| Hidden by default | Billing, lab/radiology result entry, pharmacy dispensing, housekeeping task assignment, biomed work orders unless a biomed/operations role is also assigned. |
| Empty state | “No ICU oversight items need action.” Actions: open ICU board, review alerts, check staff coverage. |

---

## 19. `THEATRE_MANAGER` — Theatre manager

**Home title:** Theatre schedule dashboard  
**Subtitle:** Coordinate procedure readiness, theatre flow, handovers, and staffing.

| Field | Strict content |
| --- | --- |
| Scope | Assigned theatre/surgical unit. Clinical write actions only for configured theatre workflow. |
| Required permissions | `patient:read`, `clinical:read`, `clinical:write`, `hr:read`, `unit:read`, `unit:manage`, `roster:*`, `reports:read`, `profile:read`. |
| Summary cards | `procedures_today`; `ready_for_theatre`; `in_theatre`; `post_op_handovers_pending`; `cancellations_or_delays`; `theatre_staff_coverage`. |
| Primary queue | Scheduled procedures; pre-theatre readiness checks; active cases; post-op handovers; cancelled/delayed cases; theatre staffing gaps. |
| Alerts | Missing pre-op checklist; theatre delay; staffing gap; anesthesia/pre-op blocker; post-op handover overdue; procedure cancellation. |
| Quick actions | open theatre board; confirm readiness; assign theatre staff; update procedure status; `create_handover`; `publish_roster`; run theatre report. |
| Shortcuts | Theatre schedule; readiness board; procedure list; handovers; roster; theatre reports. |
| Activity feed | Procedure booked; readiness updated; procedure started/completed; handover created; cancellation logged; staff assigned. |
| Hidden by default | Billing, lab/radiology result entry, pharmacy dispensing, operations maintenance, biomed work orders, mortuary, subscriptions. |
| Empty state | “No theatre cases need action.” Actions: open theatre schedule, review readiness, check team roster. |

---

## 20. `HOUSEKEEPING_MANAGER` — Housekeeping manager

**Home title:** Housekeeping control dashboard  
**Subtitle:** Manage cleaning workload, room turnover, blockers, and staff coverage.

| Field | Strict content |
| --- | --- |
| Scope | Housekeeping tasks, room turnover, assigned staff coverage, and housekeeping reports for facility/unit scope. |
| Required permissions | `operations:read`, `operations:write`, `hr:read`, `unit:read`, `unit:manage`, `roster:read`, `roster:write`, `reports:read`, `last_office:read`, `profile:read`. |
| Summary cards | `pending_cleaning_tasks`; `unassigned_cleaning_tasks`; `in_progress_cleaning_tasks`; `overdue_cleaning_tasks`; `rooms_ready`; `housekeeping_staff_on_shift`. |
| Primary queue | Unassigned cleaning tasks; urgent turnovers; blocked rooms; overdue sanitation tasks; staff workload balancing; last-office cleaning tasks. |
| Alerts | Discharge turnover overdue; isolation/special cleaning required; room blocked; staffing gap; repeated checklist failure. |
| Quick actions | `create_cleaning_task`; `assign_cleaning_task`; `mark_cleaning_blocked`; `update_bed_readiness`; create shift; run housekeeping report. |
| Shortcuts | Housekeeping workspace; task board; room readiness; staff coverage; roster; reports. |
| Activity feed | Task created/assigned; task completed; room marked ready; blocker added/resolved; staff assignment changed; roster updated. |
| Hidden by default | Clinical details, billing, lab/radiology processing, pharmacy, biomed service work, mortuary custody, subscriptions. |
| Empty state | “No housekeeping backlog is pending.” Actions: open task board, create task, check room readiness. |

---

## 21. `BIOMED_MANAGER` — Biomedical manager

**Home title:** Biomedical risk dashboard  
**Subtitle:** Oversee equipment risk, technician workload, incidents, downtime, and maintenance compliance.

| Field | Strict content |
| --- | --- |
| Scope | Biomedical department, technician workload, equipment risk, incidents, downtime, maintenance plans, and evidence exports. |
| Required permissions | `biomed:read`, `biomed:write`, `hr:read`, `unit:read`, `unit:manage`, `roster:read`, `roster:write`, `reports:read`, `evidence:export`, `profile:read`. |
| Summary cards | `open_work_orders`; `high_priority_work_orders`; `active_downtime`; `open_incidents`; `overdue_maintenance`; `technician_load`. |
| Primary queue | High-priority work orders; unassigned work orders; overdue calibration; open incidents; downtime events; technician assignment gaps; warranty/service follow-up. |
| Alerts | Critical equipment unavailable; safety incident; overdue preventive maintenance; recurring downtime; unassigned urgent work order. |
| Quick actions | `assign_technician`; create work order; `update_work_order`; review incident; close downtime; run equipment report; export evidence. |
| Shortcuts | Biomedical dashboard; equipment registry; work orders; incidents; downtime; maintenance plans; technician workload; reports. |
| Activity feed | Work order assigned; incident updated; downtime resolved; maintenance completed; equipment status changed; evidence exported. |
| Hidden by default | Patient care workflow, billing, HR leave approvals outside biomed team scope, housekeeping, pharmacy, mortuary releases. |
| Empty state | “No biomedical risk items need action.” Actions: open work orders, review maintenance due, check equipment registry. |

---

## 22. `MORTUARY_STAFF` — Mortuary staff

**Home title:** Mortuary work queue  
**Subtitle:** Manage custody, storage, viewings, post-mortem requests, and mortuary billable events.

| Field | Strict content |
| --- | --- |
| Scope | Mortuary cases, deceased profiles, storage slots, custody chain, viewings, post-mortem requests, and mortuary billable events. |
| Required permissions | `mortuary:read`, `mortuary:write`, `mortuary:manage_storage`, `mortuary:post_mortem_request`, `mortuary:billing_event`, `patient:read`, `reports:read`, `profile:read`. |
| Summary cards | `active_mortuary_cases`; `storage_assignments`; `custody_events_due`; `viewings_today`; `post_mortem_requests`; `billable_events_to_capture`. |
| Primary queue | New mortuary cases; storage assignment tasks; custody events to record; scheduled viewings; post-mortem requests; billable event capture. |
| Alerts | Missing custody event; storage slot issue; viewing due; incomplete case details; post-mortem request pending; billable event missing. |
| Quick actions | `open_mortuary_case`; `assign_storage_slot`; `record_custody_event`; `schedule_viewing`; `add_mortuary_billable_event`; request post-mortem. |
| Shortcuts | Mortuary workspace; cases; deceased profiles; storage units/slots; custody events; viewings; post-mortem requests; billable events. |
| Activity feed | Case opened; custody event recorded; storage assigned; viewing scheduled/completed; post-mortem requested; billable event added. |
| Hidden by default | Active clinical care, OPD, billing cashier actions, HR, operations maintenance, biomed, subscriptions, release approval/export unless manager permissions are also present. |
| Empty state | “No mortuary tasks are pending.” Actions: open cases, review storage, record custody event. |

---

## 23. `MORTUARY_MANAGER` — Mortuary manager

**Home title:** Mortuary oversight dashboard  
**Subtitle:** Oversee releases, custody compliance, storage capacity, audit, and export readiness.

| Field | Strict content |
| --- | --- |
| Scope | Mortuary department oversight, release authorization, custody audit, storage capacity, post-mortem workflow, evidence export. |
| Required permissions | `mortuary:read`, `mortuary:write`, `mortuary:release`, `mortuary:manage_storage`, `mortuary:post_mortem_request`, `mortuary:approve`, `mortuary:billing_event`, `mortuary:export`, `mortuary:audit`, `reports:read`, `evidence:export`, `patient:read`, `profile:read`. |
| Summary cards | `active_mortuary_cases`; `storage_occupancy`; `releases_awaiting_approval`; `custody_exceptions`; `pending_post_mortem_requests`; `audit_exports_due`. |
| Primary queue | Release authorizations; custody exceptions; storage capacity issues; pending post-mortem requests; audit/export tasks; billable events needing review. |
| Alerts | Release approval required; custody chain incomplete; storage near capacity; overdue viewing/post-mortem step; missing billing event; audit evidence due. |
| Quick actions | `review_release_authorization`; `approve_release`; review custody chain; manage storage; run mortuary report; `export_mortuary_evidence`. |
| Shortcuts | Mortuary dashboard; release authorizations; custody audit; storage; post-mortem requests; reports; exports. |
| Activity feed | Release approved/rejected; custody event corrected; storage changed; post-mortem updated; report/export generated; case closed. |
| Hidden by default | Clinical care queues, general patient registration, cashier collection, HR, operations maintenance, biomed service work, subscriptions. |
| Empty state | “No mortuary approvals need action.” Actions: review active cases, check storage capacity, open release queue. |

---

## 24. `PATIENT` — Patient portal account

**Home title:** My care dashboard  
**Subtitle:** View your own appointments, released results, prescriptions, bills, and profile information.

| Field | Strict content |
| --- | --- |
| Scope | Self only. Never show staff dashboards, facility queues, or other patients. |
| Required permissions | `profile:read`, `profile:update`, patient-safe self access. Staff `dashboard-workspace` must not be used. |
| Summary cards | `my_upcoming_appointments`; `my_open_bills`; `my_prescriptions`; `my_released_results`; `my_messages`; `my_profile_status`. |
| Primary queue | Upcoming appointment; bill awaiting payment where patient billing endpoint exists; released result to view; prescription ready; missing profile/consent item. |
| Alerts | Appointment reminder; released result available; unpaid bill; prescription ready; profile information missing. |
| Quick actions | `update_own_profile`; view appointments; view released results; view prescriptions; view bills/receipts; `contact_facility`. |
| Shortcuts | My profile; appointments; bills/receipts; prescriptions; released results; messages/help. |
| Activity feed | Appointment booked/changed; payment posted; result released; prescription updated; profile updated; message received. |
| Hidden by default | All staff queues, all admin summaries, other patients, clinical staff actions, billing cashier actions, HR, operations, lab/radiology processing, pharmacy inventory, mortuary. |
| Empty state | “Your care updates will appear here.” Actions: update profile, check appointments, contact facility. |

Implementation note: build this from patient-safe endpoints or a separate patient dashboard endpoint. Do not reuse staff `dashboard-workspace`.

---

## 25. `OTHER` — Limited/fallback account

**Home title:** Account home  
**Subtitle:** Access only the areas explicitly assigned to your account.

| Field | Strict content |
| --- | --- |
| Scope | Profile and explicitly assigned modules only. |
| Required permissions | `profile:read`; any additional content requires explicit permission and module entitlement. |
| Summary cards | `profile_status`; `assigned_links`; `unread_messages` where allowed; `facility_notices` where allowed. |
| Primary queue | Only explicitly assigned items. No clinical, billing, operational, HR, mortuary, or patient registry queue by default. |
| Alerts | Missing profile details; access not configured; facility notice; session/security reminder. |
| Quick actions | open profile; `update_own_profile` where allowed; open assigned module; contact administrator. |
| Shortcuts | Profile; settings; explicitly assigned module routes only. |
| Activity feed | Profile updated; permission changed; assigned message received; facility notice posted. |
| Hidden by default | Everything not explicitly granted. Do not show patient registry just because fallback mapping includes `patient:read`; require a real role or explicit module assignment. |
| Empty state | “Your account has limited access. Contact an administrator if you need more modules.” Actions: open profile, contact administrator. |

---

# Backend update requirements

## 1. Add role profile IDs for every canonical role

Current profile mapping should be expanded so no supported role falls back to generic `operations` or `admin` content.

| Role | Required profile ID | Required pack |
| --- | --- | --- |
| `SUPER_ADMIN` | `super_admin` | `super_admin` |
| `TENANT_ADMIN` | `tenant_admin` | `tenant_admin` |
| `FACILITY_ADMIN` | `facility_admin` | `facility_admin` |
| `DOCTOR` | `doctor` | `doctor` |
| `NURSE` | `nurse` | `nurse` |
| `LAB_TECH` | `lab_tech` | `lab_tech` |
| `RADIOLOGY_TECH` | `radiology_tech` | `radiology_tech` |
| `PHARMACIST` | `pharmacist` | `pharmacist` |
| `RECEPTIONIST` | `receptionist` | `receptionist` |
| `BILLING` | `billing` | `billing` |
| `OPERATIONS` | `operations` | `operations` |
| `HR` | `hr` | `hr` |
| `BIOMED` | `biomed` | `biomed` |
| `HOUSE_KEEPER` | `house_keeper` | `house_keeper` |
| `AMBULANCE_OPERATOR` | `ambulance_operator` | `ambulance_operator` |
| `UNIT_MANAGER` | `unit_manager` | `unit_manager` |
| `WARD_MANAGER` | `ward_manager` | `ward_manager` |
| `ICU_MANAGER` | `icu_manager` | `icu_manager` |
| `THEATRE_MANAGER` | `theatre_manager` | `theatre_manager` |
| `HOUSEKEEPING_MANAGER` | `housekeeping_manager` | `housekeeping_manager` |
| `BIOMED_MANAGER` | `biomed_manager` | `biomed_manager` |
| `MORTUARY_STAFF` | `mortuary_staff` | `mortuary_staff` |
| `MORTUARY_MANAGER` | `mortuary_manager` | `mortuary_manager` |
| `PATIENT` | `patient` | `patient_safe` |
| `OTHER` | `other` | `limited` |

## 2. Replace pack-level quick actions with role-level actions

Current `QUICK_ACTION_IDS_BY_PACK` should be replaced or wrapped by role-specific action resolution.

Required behavior:

```text
quick_actions = actions
  .filter(action.allowed_roles includes active role OR action.allowed_roles intersects user roles)
  .filter(action.required_permissions are granted)
  .filter(action.required_modules are enabled)
  .filter(action.scope matches user context)
  .dedupeBy(action.id)
  .take(primary limit)
```

## 3. Stop globally appending OPD notifications

`opd_notifications_attention` should be generated only for roles with patient-flow responsibility:

- `FACILITY_ADMIN`
- `RECEPTIONIST`
- `DOCTOR`
- `NURSE`
- `WARD_MANAGER` where OPD/ward handoff applies
- Other roles only when they have explicit OPD/patient-flow assignment

Do not show OPD notification cards to lab, radiology, pharmacy, billing, HR, biomed, housekeeping, ambulance, mortuary, or fallback users unless explicitly assigned.

## 4. Return role-safe metadata

The dashboard response should include enough metadata for the frontend to render without guessing:

```json
{
  "roleProfile": {
    "id": "doctor",
    "role": "DOCTOR",
    "pack": "doctor",
    "scopeType": "assigned_clinical"
  },
  "summaryCards": [
    {
      "id": "assigned_consultations",
      "label": "Assigned consultations",
      "value": 0,
      "requiredPermissions": ["clinical:read"],
      "routeTarget": "clinical.consultations"
    }
  ],
  "quickActionIds": ["start_consultation", "write_clinical_note"],
  "hiddenReasonMap": {
    "create_invoice": "Requires BILLING role and billing:write"
  }
}
```

## 5. Patient and fallback routing

- `PATIENT` must not use `/api/v1/dashboard-workspace/workspace`.
- `OTHER` should use a limited profile/session-based dashboard unless explicit permissions are assigned.
- Staff dashboard endpoint should continue excluding `PATIENT` and `OTHER` unless separate role-safe behavior is implemented.

---

# Frontend update requirements

## 1. Use one reusable dashboard component

Create or update `HomeDashboardPage` so every role uses the same components:

- `RoleHeaderCard`
- `SummaryCardStrip`
- `QuickActionGrid`
- `RoleQueuePreview`
- `RoleAlertList`
- `ActivityFeed`
- `ShortcutGrid`
- `RoleEmptyState`

## 2. Do not hard-code broad account dashboards

Frontend should not infer content like “all staff see OPD notifications.” It should render backend-provided role-safe cards and locally filter route visibility using `AppAccessPolicy`.

## 3. Route-gate every action

Before rendering an action, check:

```text
accessPolicy.hasAnyRole(action.allowedRoles)
accessPolicy.grantsAll(action.requiredPermissions)
accessPolicy.moduleEnabled(action.requiredModules)
routeExists(action.routeTarget)
```

## 4. Display hidden/disabled actions carefully

Prefer hiding unauthorized actions. Show disabled actions only when the user is close to having access and the reason is harmless, such as “Module not enabled.” Do not reveal sensitive routes or records through disabled action labels.

---

# Acceptance checklist

- Every canonical role has a dedicated dashboard profile.
- Every summary card is tied to a role, permission, module, and scope.
- Every quick action is tied to a role, permission, module, and route target.
- Admin dashboards show oversight/configuration actions, not direct provider workflow actions by default.
- Manager dashboards use manager-specific content, not generic operations/admin content.
- Mortuary roles use mortuary-specific content.
- `PATIENT` sees self-only patient-safe content.
- `OTHER` sees only profile and explicitly assigned links.
- OPD notifications are not appended to unrelated roles.
- Multi-role users get a merged dashboard without leaking data across role boundaries.
- Same UI components are reused for all roles.
- Backend authorization remains mandatory even when frontend hides unauthorized content.
