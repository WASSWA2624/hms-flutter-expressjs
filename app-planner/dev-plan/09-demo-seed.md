# 09 - Demo and Seed Data

## Goal
Plan safe default/demo data so HOSSPI HMS can be tested, demonstrated, and initialized consistently.

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
- default tenant;
- default facility;
- default subscription plan;
- default active subscription;
- default module subscriptions;
- default license;
- default platform admin;
- default tenant admin;
- default facility admin;
- default department-based users;
- default doctor and nurse accounts;
- default accounts for pharmacy, lab, radiology, billing/cashier, front office, HR, biomedical, operations, housekeeping, mortuary, emergency/ambulance, and other enabled departments;
- sample departments, units, wards, rooms, beds, patients, appointments, triage records, encounters, admissions, pharmacy orders, invoices, claims, maintenance requests, housekeeping tasks, biomedical assets, mortuary cases, notifications, reports, and audit records.

## Physiotherapy Gap
A dedicated physiotherapy role/account and backend physiotherapy module are not visible in the current backend route map. Plan a future default account such as `physiotherapy@hosspi.com` only after backend role, permission, and API support are approved. Until then, do not fake physiotherapy seed records against non-existing endpoints.

## Frontend Responsibilities
- Show demo data only in development/demo environments.
- Never expose default passwords in production UI.
- Provide clear demo login guidance only in a controlled demo build or documentation area.
- Build admin screens so seeded tenants, facilities, users, subscriptions, and modules can be viewed and tested.
- Ensure seeded module data appears in the correct module dashboards.

## Safety Rules
- Seed scripts must not run in production by accident.
- Demo data must be clearly marked.
- Clear/reseed workflows must be protected and restricted.
- Default credentials must be rotated or disabled before real deployment.

## Done Criteria
- Demo setup can create tenant, facility, admins, department users, subscriptions, and module data.
- Demo users can log in and reach their module workspaces based on roles/permissions.
- Verification script passes after demo seed.
- Missing role/API gaps are documented instead of hidden.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/security.md`
- `frontend/app-planner/app-rules/environment_configuration.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/documentation_standards.md`
### Backend rules
- `backend/app-planner/app-rules/constants-env.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/prisma.md`
- `backend/app-planner/app-rules/testing.md`
- `backend/app-planner/app-rules/compliance.md`
### Additional references
- `backend/scripts/seed-demo-data.js`
- `backend/scripts/setup-default-accounts.js`
- `backend/scripts/verify-demo-data.js`
- `backend/scripts/seeders/seed-catalog.js`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
