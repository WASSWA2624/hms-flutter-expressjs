# 09 - Demo and Seed Data

## Goal
Plan safe default/demo data so HOSSPI HMS can be tested, demonstrated, and initialized consistently across OPD, IPD, billing, clinical, service departments, reports, notifications, and access control.

## Source of Truth
- Use `app-write-up.md` for demo and seed expectations.
- Use `opd-flow.md` for sample OPD journeys.
- Use `ipd-flow.md` for sample IPD journeys.
- Use backend seed scripts and seed catalog as the source of truth for current support.

## Current Backend Seed Support
The current backend already includes:
- `backend/scripts/setup-default-accounts.js`
- `backend/scripts/seed-demo-data.js`
- `backend/scripts/clear-demo-data.js`
- `backend/scripts/verify-demo-data.js`
- `backend/scripts/seeders/seed-catalog.js`
- seed packs for subscriptions, clinical data, operations, communications, biomedical, mortuary, compliance, governance, and filler data.

## Current Default Demo Accounts In Seed Catalog
The current seed catalog includes these key demo users:

| Purpose | Email |
| --- | --- |
| Default platform admin | `super.admin@hosspi.com` |
| Default tenant admin | `tenant.admin@hosspi.com` |
| Default facility admin | `facility.admin@hosspi.com` |
| Default doctor | `doctor@hosspi.com` |
| Default nurse | `nurse@hosspi.com` |
| Default lab user | `lab@hosspi.com` |
| Default pharmacist | `pharmacy@hosspi.com` |
| Default receptionist/front office | `reception@hosspi.com` |
| Default billing/cashier | `billing@hosspi.com` |
| Default operations user | `operations@hosspi.com` |
| Default HR user | `hr@hosspi.com` |
| Default biomedical user | `biomed@hosspi.com` |
| Default housekeeping user | `housekeeping@hosspi.com` |
| Default mortuary staff | `mortuary.staff@hosspi.com` |
| Default mortuary manager | `mortuary.manager@hosspi.com` |
| Default ambulance user | `ambulance@hosspi.com` |
| Default patient portal user | `patient.portal@hosspi.com` |

## Required Demo Data Coverage
The database seed should cover:
- default tenant, facility, facility logo/contact data, departments, units, wards, rooms, and beds;
- default subscription plan, active subscription, module subscriptions, and license;
- default platform, tenant, facility, and department users;
- default doctor, nurse, pharmacy, lab, radiology, billing/cashier, front office, HR, biomedical, operations, housekeeping, mortuary, emergency/ambulance, and other enabled department accounts;
- configured catalogs: lab tests, radiology tests, formulary/drugs, billing services/fees, payment methods, coverage plans, wards/beds, providers, and common clinical terms where backend supports them;
- sample OPD flows: emergency arrival, new/walk-in patient, appointment patient, triage, doctor consultation, lab/radiology order, pharmacy, billing, referral, admission, and completed visit;
- sample IPD flows: admission request, bed allocation, ward handover, nursing admission, inpatient orders, ward rounds, transfer, discharge, billing clearance, bed cleaning, and closure;
- sample invoices, payments, claims, maintenance requests, housekeeping tasks, biomedical assets, mortuary cases, notifications, generated reports, audit records, and PHI access logs.

## Physiotherapy Gap
A dedicated physiotherapy role/account and backend physiotherapy module are not visible in the current backend route map. Plan a future default account such as `physiotherapy@hosspi.com` only after backend role, permission, and API support are approved. Until then, do not fake physiotherapy seed records against non-existing endpoints.

## Frontend Responsibilities
- Show demo data only in development/demo environments.
- Never expose default passwords in production UI.
- Provide clear demo login guidance only in a controlled demo build or documentation area.
- Build admin screens so seeded tenants, facilities, users, subscriptions, modules, catalogs, and worklists can be viewed and tested.
- Ensure seeded module data appears in the correct module dashboards.
- Ensure seeded OPD/IPD scenarios can be followed end-to-end without manual database work.

## Safety Rules
- Seed scripts must not run in production by accident.
- Demo data must be clearly marked.
- Clear/reseed workflows must be protected and restricted.
- Default credentials must be rotated or disabled before real deployment.
- Demo records must still obey access control, tenant scope, facility scope, and module entitlement rules.

## Done Criteria
- Demo setup can create tenant, facility, admins, department users, subscriptions, catalogs, and module data.
- Demo users can log in and reach their module workspaces based on roles/permissions.
- OPD and IPD demo flows can be tested from arrival/admission through completion/discharge.
- Verification script passes after demo seed.
- Missing role/API gaps are documented instead of hidden.

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

### Additional references
- `frontend/app-planner/app-rules/environment_configuration.md`
- `frontend/app-planner/app-rules/documentation_standards.md`
- `backend/scripts/seed-demo-data.js`
- `backend/scripts/setup-default-accounts.js`
- `backend/scripts/verify-demo-data.js`
- `backend/scripts/seeders/seed-catalog.js`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
