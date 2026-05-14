# HOSSPI HMS App Write-Up

## Official Product Name
**HOSSPI HMS** means **HOSSPI Hospital Management System**.

## Purpose
HOSSPI HMS is a full-stack Hospital Management System for managing hospital administration, patient flow, clinical work, nursing work, inpatient care, ICU care, theater workflows, pharmacy, billing, insurance, claims, human resources, biomedical services, facility operations, housekeeping, notifications, reports, and audit tracking.

This file defines product scope only: core functions, modules, and module responsibilities. Technical rules belong in `app-rules`. Chronological implementation steps belong in `dev-plan`.

## Core Product Goals
- Help a health facility manage daily operations from one secure system.
- Keep every module simple, focused, and practical for the staff who use it.
- Support multi-tenant and multi-facility usage.
- Enforce role-based and action-based access control.
- Keep routine work inside the correct module without unnecessary navigation.
- Use clean forms, clear tables, focused dashboards, and modal-based actions where appropriate.
- Allow modules to work as self-contained workspaces while still sharing patient, user, facility, billing, permission, notification, and audit data.

## Main User Flow
1. A tenant account is created.
2. The tenant configures the organization and facility profile.
3. Facility users, roles, and permissions are created.
4. Rooms, wards, beds, departments, service units, and operational service points are configured.
5. Patients are registered and managed through outpatient, triage, clinical, nursing, pharmacy, billing, insurance, inpatient, ICU, theater, and discharge workflows where applicable.
6. Staff work inside module-specific workspaces based on their roles and permissions.
7. Managers review notifications, reports, audit records, operational performance, and compliance evidence.

## Core Modules

| Module | Core responsibility |
| --- | --- |
| Authentication and access control | Manage login, logout, registration, session restoration, password changes, user identity, roles, permissions, and action-level access. |
| General settings | Manage app preferences such as theme mode, language, user preferences, and local app behavior. |
| Tenant settings | Manage tenant profile, enabled modules, tenant users, and tenant-wide access rules. |
| Facility settings | Manage facility name, logo, contacts, address, departments, service units, branches, and facility defaults. |
| Users and permissions | Manage staff accounts, invitations, roles, permission groups, action permissions, activation, and access scope. |
| Rooms, wards, and beds | Manage physical care spaces, rooms, wards, beds, bed readiness, occupancy status, and service-point structure. |
| Patient registry | Register patients and manage demographics, contacts, identifiers, guardians, documents, allergies, and patient lookup. |
| OPD triage | Capture vitals, chief complaint, priority, triage notes, and routing decisions before consultation. |
| OPD and outpatient flow management | Manage appointments, arrivals, queues, service routing, consultation readiness, patient movement, and outpatient completion. |
| Clinical module | Manage consultations, clinical notes, diagnoses, procedures, treatment plans, orders, follow-up instructions, and clinical reviews. |
| Nursing module | Manage nursing notes, observations, medication administration records, care tasks, handovers, and ward nursing activity. |
| Inpatient management | Manage admissions, bed assignment, inpatient episode tracking, ward rounds, inpatient nursing coordination, transfers, and inpatient progress. |
| ICU module | Manage ICU admissions, ICU bed assignment, critical-care observations, ICU rounds, monitoring records, escalation notes, transfer-out, and ICU discharge readiness. |
| Theater module | Manage theater bookings, procedure schedules, pre-theater checks, theater room allocation, procedure status, post-theater notes, and handover back to ward/ICU/outpatient care. |
| Discharge | Prepare discharge summaries, complete discharge checks, record instructions, close care episodes, and trigger final billing where required. |
| Pharmacy | Manage drugs, formulary items, batches, pharmacy orders, dispensing, returns, stock visibility, and medication-related events. |
| Billing and cashier | Manage invoices, invoice items, payments, refunds, adjustments, receipts, cashier workflows, and payment reconciliation. |
| Insurance and claims | Manage coverage plans, pre-authorizations, claim preparation, submission, approval, rejection, resubmission, and claim tracking. |
| Human resources | Manage staff profiles, positions, assignments, leave, shifts, rosters, availability, and workforce administration. |
| Biomedical | Manage clinical equipment records, maintenance plans, work orders, calibration, downtime, safety testing, incidents, recalls, spare parts, service providers, and equipment lifecycle status. |
| Operations | Manage facility operations such as electrical, plumbing, water, power backup, HVAC/air-conditioning, general maintenance, safety checks, maintenance requests, and operational readiness. |
| Housekeeping | Manage cleaning tasks, room/bed turnover, ward cleaning, sanitation schedules, laundry coordination, housekeeping requests, and cleanliness readiness. |
| Notifications | Show in-app alerts, notification badges, unread indicators, delivery status, task reminders, and workflow indicators. |
| Reports, dashboards, and audit | Provide operational dashboards, reports, exports, audit logs, user activity trails, and compliance evidence. |
| Integrations | Manage API keys, webhooks, external service configuration, integration logs, and integration status where supported by the backend. |

## Module Boundaries
- OPD triage owns pre-consultation triage capture and routing decisions.
- OPD/outpatient flow owns appointment arrival, queues, service routing, visit movement, and outpatient completion.
- Clinical owns consultations, diagnoses, treatment plans, clinical orders, and provider review notes.
- Nursing owns nursing observations, medication administration records, care tasks, and handovers.
- Inpatient management owns admissions, bed assignment, ward rounds, inpatient progress, ward transfers, and inpatient coordination.
- ICU owns ICU-specific admission, ICU bed assignment, intensive monitoring records, ICU rounds, and ICU transfer/discharge readiness.
- Theater owns procedure scheduling, theater allocation, pre-theater checks, procedure status, and post-theater handover.
- Discharge owns discharge summaries, discharge checks, instructions, and care episode closure.
- Billing owns invoices, payments, refunds, cashier actions, and financial reconciliation.
- Insurance and claims own coverage, pre-authorization, claim submission, review status, and follow-up.
- Pharmacy owns medication stock visibility, pharmacy orders, dispensing, and medicine-related returns.
- Facility settings own facility profile, departments, service units, branches, rooms, wards, and beds.
- HR owns staff records, assignments, leave, shifts, rosters, and workforce planning.
- Biomedical owns clinical equipment lifecycle and technical maintenance workflows.
- Operations owns non-clinical facility maintenance such as electrical, plumbing, water, power, HVAC, and safety readiness.
- Housekeeping owns cleaning, turnover, sanitation, laundry coordination, and cleanliness readiness.
- Reports and audit read from other modules but do not replace module-owned workflows.

## Access Control Expectations
- Every screen, menu item, button, and action must respect the logged-in user's roles and permissions.
- Users may have more than one role.
- Access checks must consider tenant, facility, department, unit, ward, room, bed, and action scope where applicable.
- A user should only see actions they are allowed to perform.
- Hidden or disabled actions must never be the only protection; backend authorization remains mandatory.

## UX Expectations
- Each module should be easy to understand without training-heavy navigation.
- Staff should complete routine work inside the relevant module.
- Short forms, quick edits, approvals, confirmations, and status updates should use modals where appropriate.
- Full-page flows should be reserved for long, high-risk, or multi-step processes.
- Screens should avoid congestion by separating lists, filters, details, and actions clearly.
- Forms should be clean, validated, and grouped into logical sections.
- Dashboards should show only useful summaries and direct workflow entry points.

## Product Completion Standard
The system is ready when:
- account creation leads naturally into tenant and facility setup;
- facility admins can configure users, roles, permissions, facility profile, departments, rooms, wards, beds, and service units;
- staff can perform module-specific work without unnecessary navigation;
- patient flow works from registration through OPD, triage, clinical care, nursing, pharmacy, billing, insurance, inpatient care, ICU, theater, and discharge where applicable;
- operations, housekeeping, biomedical, HR, reports, notifications, audit, and settings support daily hospital work;
- frontend menus, routes, forms, actions, and permissions match backend modules, permissions, and available APIs.
