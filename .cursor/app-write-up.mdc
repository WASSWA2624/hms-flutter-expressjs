# HOSSPI HMS App Write-Up

## Official Product Name
**HOSSPI HMS** means **HOSSPI Hospital Management System**.

## Product Scope
HOSSPI HMS is a full-stack, multi-tenant Hospital Management System for managing hospital administration, patient registration, outpatient flow, triage, clinical care, nursing, inpatient care, ICU, theater, pharmacy, laboratory, radiology, billing, insurance, claims, human resources, biomedical engineering, facility operations, housekeeping, mortuary services, subscriptions, notifications, reports, audit, and integrations.

This file defines product scope only: core functions, modules, and module responsibilities. Technical implementation rules remain in the backend and frontend `app-rules` folders. Chronological implementation work belongs in the root `app-planner/dev-plan` folder.

## Current Codebase Position
- The backend is treated as the current source of truth for available APIs, permissions, tenancy, subscriptions, feature flags, seed scripts, audit logging, and module contracts.
- The Flutter frontend already contains a reusable starter foundation for routing, shell layout, theme, localization readiness, networking, secure/session storage, responsive layout, shared components, settings, and state management.
- Root planning should build on the existing backend and Flutter foundation instead of recreating completed work.
- Backend source files, frontend source files, backend planner files, and frontend planner files must not be changed by product-scope documentation updates unless a future task explicitly allows it.

## Core Product Goals
- Give hospitals one secure system for daily clinical, operational, financial, and administrative work.
- Keep each module focused on the staff who use it.
- Support tenants, facilities, branches, departments, units, rooms, wards, and beds.
- Enforce role-based access control, action-based access control, tenant scope, facility scope, and module entitlements.
- Keep routine work inside the correct module without unnecessary cross-navigation.
- Use clean forms, searchable lists, readable detail panels, and modal-based actions where appropriate.
- Keep modules self-contained while sharing common patient, user, facility, billing, notification, report, subscription, and audit data.

## Main Setup Flow
1. Create or seed a default tenant.
2. Create or seed a default facility under the tenant.
3. Configure facility identity: name, logo, contacts, address, branches, departments, units, rooms, wards, and beds.
4. Create default admins: platform admin, tenant admin, facility admin, and facility-level admin users.
5. Create department-based demo users such as doctor, nurse, receptionist, cashier/billing, pharmacist, lab user, radiology user, HR user, operations user, biomedical user, housekeeping user, mortuary user, and other module users.
6. Assign roles, permissions, module entitlements, subscription plan, and license state.
7. Register patients and process work through the correct module-specific flows.
8. Review notifications, reports, dashboards, audit records, subscription state, and operational readiness.

## Core Modules

| Module | Core responsibility |
| --- | --- |
| App identity and shell | Manage HOSSPI HMS name, logo, app shell, screen shell, responsive navigation, app bar, user menu, notification badge, and in-app status indicators. |
| Authentication and session | Manage login, logout, registration, session restoration, password changes, secure session handling, and authenticated route guards. |
| General settings | Manage user-level app preferences such as theme mode, language, local behavior, and accessibility-friendly preferences. |
| Tenant settings | Manage tenant profile, subscription relationship, tenant-wide settings, enabled modules, tenant admins, and tenant access scope. |
| Facility settings | Manage facility name, logo, contacts, address, departments, units, branches, facility defaults, and operational service points. |
| Users, roles, and permissions | Manage staff accounts, default demo accounts, roles, permission groups, action permissions, role assignment, activation, and access scope. |
| Subscription management | Manage subscription plans, active subscriptions, module subscriptions, licenses, subscription invoices, entitlement visibility, renewal state, and plan limits. |
| Rooms, wards, and beds | Manage physical care spaces, room readiness, wards, beds, occupancy, assignments, and bed-status visibility. |
| Patient registry | Register patients and manage demographics, identifiers, contacts, guardians, allergies, documents, consent, and patient lookup. |
| Appointment and OPD flow | Manage appointments, arrivals, visit queues, outpatient routing, service movement, consultation readiness, and outpatient completion. |
| OPD triage | Capture vital signs, chief complaint, priority, triage notes, emergency indicators, and routing decisions before consultation. |
| Clinical module | Manage consultations, encounters, clinical notes, diagnoses, procedures, care plans, treatment decisions, orders, and follow-up instructions. |
| Nursing module | Manage nursing notes, medication administration, care tasks, handovers, observations, and nursing activity across outpatient, inpatient, ICU, and ward workflows. |
| Inpatient management | Manage admitted patients, bed assignment, IPD flow, ward rounds, inpatient progress, transfers, and inpatient nursing coordination. |
| ICU module | Manage ICU stays, ICU bed assignment, critical-care observations, escalation, critical alerts, ICU rounds, transfer-out, and ICU discharge readiness. |
| Theater module | Manage theater bookings, theater flow, pre-theater checks, anesthesia records, procedure status, post-op notes, and handover back to ward, ICU, or outpatient care. |
| Discharge | Prepare discharge summaries, complete discharge checks, record instructions, close care episodes, and trigger final billing where required. |
| Emergency and ambulance | Manage emergency cases, triage assessments, emergency response records, ambulances, dispatch, trips, and handover into OPD/IPD/ICU/theater. |
| Laboratory | Manage lab tests, panels, orders, samples, results, quality control, and lab workspace actions. |
| Radiology and imaging | Manage radiology tests, orders, results, imaging studies, imaging assets, PACS links, and radiology workspace actions. |
| Physiotherapy | Manage therapy referrals, assessment, therapy plans, treatment sessions, exercise instructions, progress notes, attendance, and outcome review. |
| Pharmacy | Manage drugs, formulary items, batches, pharmacy orders, dispensing, returns, stock visibility, and medication-related events. |
| Billing and cashier | Manage invoices, invoice items, payments, receipts, refunds, billing adjustments, cashier workflow, and shift/day close support. |
| Insurance and claims | Manage coverage plans, pre-authorizations, claim preparation, submission, approval, rejection, resubmission, and claim tracking. |
| Human resources | Manage staff profiles, positions, assignments, leave, availability, shifts, rosters, payroll runs, and workforce administration. |
| Biomedical | Manage medical equipment registry, categories, maintenance plans, work orders, calibration, safety testing, downtime, incidents, recalls, spare parts, service providers, warranties, utilization, and disposal/transfer. |
| Operations | Manage non-clinical facility work such as electrical, plumbing, water, power backup, HVAC/air-conditioning, general maintenance, safety checks, maintenance requests, and operational readiness. |
| Housekeeping | Manage cleaning tasks, schedules, room/bed turnover, ward cleaning, sanitation readiness, laundry coordination, housekeeping requests, and cleanliness status. |
| Mortuary | Manage deceased profiles, mortuary cases, storage units/slots, custody events, viewings, post-mortem requests, release authorization, and billable mortuary events. |
| Notifications and communications | Manage in-app notifications, delivery state, unread indicators, conversations, messages, alerts, workflow reminders, and user-facing notification badges. |
| Reports, dashboards, and audit | Provide dashboards, report definitions, report runs, scheduled reports, exports, audit logs, PHI access logs, data processing logs, compliance evidence, and activity review. |
| Integrations | Manage API keys, integrations, integration logs, webhooks, interoperability configuration, and external system status. |
| Demo and seed data | Provide safe development/demo data for tenant, facility, admins, departments, users, roles, permissions, subscriptions, modules, patients, operations, biomedical, mortuary, and clinical workflows. |

## Module Boundaries
- Tenant and facility settings own organizational structure; modules should consume this structure instead of redefining it.
- Users and permissions own account access; individual modules should only request permissions and display allowed actions.
- OPD flow owns appointment arrival, queues, service movement, and outpatient completion.
- OPD triage owns pre-consultation triage capture and routing decisions.
- Clinical owns provider consultation, diagnoses, procedures, care plans, treatment decisions, and clinical orders.
- Nursing owns nursing observations, medication administration, care tasks, ward activity, and handover.
- Inpatient owns admission, bed assignment, ward rounds, inpatient tracking, and ward transfer coordination.
- ICU owns intensive-care stays, monitoring, critical alerts, ICU rounds, and ICU transfer/discharge readiness.
- Theater owns procedure scheduling, theater allocation, anesthesia capture, intra/post-op tracking, and handover.
- Physiotherapy owns therapy assessment, treatment sessions, exercise plans, attendance, and progress review.
- Discharge owns discharge summary, discharge checks, instructions, and care episode closure.
- Billing owns invoices, payments, refunds, receipts, cashier actions, and financial reconciliation.
- Insurance and claims own coverage, pre-authorization, claim submission, review status, and follow-up.
- Pharmacy owns medicine catalogs, stock visibility, dispensing, and medication-related returns.
- HR owns staff records, assignments, shifts, rosters, leave, and workforce planning.
- Biomedical owns clinical equipment lifecycle and technical maintenance workflows.
- Operations owns non-clinical maintenance such as electrical, plumbing, water, power, HVAC, and safety readiness.
- Housekeeping owns cleaning, sanitation, turnover, laundry coordination, and cleanliness readiness.
- Mortuary owns deceased custody, storage, viewing, post-mortem, release, and mortuary billing events.
- Reports and audit read from modules but must not replace module-owned workflows.

## Demo and Seed Data Expectations
The system should support safe, repeatable demo seeding for development, testing, onboarding, and product demonstrations.

Required demo data should include:
- default tenant;
- default facility;
- default subscription plan, subscription, module subscriptions, and license state;
- default platform admin;
- default tenant admin;
- default facility admin;
- default admin/facility admin account for general setup;
- default doctor account;
- default nurse account;
- default receptionist/front-office account;
- default billing/cashier account;
- default pharmacist account;
- default laboratory account;
- default radiology account where the module is enabled;
- default HR account;
- default biomedical account;
- default operations account;
- default housekeeping account;
- default mortuary staff and mortuary manager accounts;
- default ambulance/emergency account where the module is enabled;
- default physiotherapy account when a dedicated physiotherapy role/API contract is available;
- default department records, service units, rooms, wards, beds, patients, visits, clinical records, pharmacy records, billing records, claims records, operations records, housekeeping records, biomedical records, mortuary records, notifications, reports, and audit samples.

Seed data must be clearly marked as demo data, must not run in production by accident, and must be safe to clear or recreate.

## Access Control Expectations
- Every screen, menu item, button, modal action, API call, report, export, and workflow transition must respect the logged-in user's role, permission, tenant scope, facility scope, and module entitlement.
- Users may have more than one role.
- Access checks must consider tenant, facility, department, unit, ward, room, bed, and action scope where applicable.
- Users should only see actions they are allowed to perform.
- Frontend hiding or disabling is not enough; backend authorization remains mandatory.

## UX Expectations
- Each module should be easy to understand without training-heavy navigation.
- Staff should complete routine work inside the relevant module.
- Short forms, quick edits, approvals, confirmations, and status updates should use modals where appropriate.
- Full-page flows should be reserved for long, high-risk, or multi-step processes.
- Screens should avoid congestion by separating lists, filters, details, and actions clearly.
- Forms should be validated, grouped into logical sections, and kept short where possible.
- Dashboards should show useful summaries and direct workflow entry points only.

## Product Completion Standard
HOSSPI HMS is ready when:
- account creation leads naturally into tenant and facility setup;
- admins can configure tenant, facility, users, roles, permissions, subscriptions, modules, departments, rooms, wards, beds, and service units;
- demo/seed data supports safe testing and product demonstrations;
- staff can perform module-specific work without unnecessary navigation;
- patient flow works from registration through OPD, triage, clinical care, nursing, pharmacy, lab/radiology, billing, insurance, inpatient care, ICU, theater, physiotherapy, mortuary, and discharge where applicable;
- operations, housekeeping, biomedical, HR, reports, notifications, audit, integrations, and settings support daily hospital work;
- frontend menus, routes, forms, actions, permissions, and module visibility match backend routes, permissions, feature flags, subscriptions, and APIs.
