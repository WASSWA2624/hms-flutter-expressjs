# 00 - Root Development Plan Index

## Purpose
This root development plan defines the chronological implementation order for **HOSSPI HMS** (**HOSSPI Hospital Management System**). It is focused mainly on completing the Flutter frontend on top of the current backend and the existing Flutter foundation.

## Naming Standard
All root `dev-plan` files must use short, descriptive, numeric names:

```text
00-name.md
01-name.md
02-name.md
03-name.md
```

Do not use suffixes such as `01A-name.md`, `01B-name.md`, or `01C-name.md`.

## Replacement Note
The previous root `dev-plan` used long names and letter suffixes. Replace the previous root `app-planner/dev-plan` contents with this numbered plan so obsolete letter-suffix files do not remain beside the new files.

## Chronological Plan
| Step | File | Focus |
| --- | --- | --- |
| 00 | `00-index.md` | Plan index and chronological order |
| 01 | `01-policy.md` | Execution policy and safe-change boundaries |
| 02 | `02-codebase.md` | Current backend/frontend foundation map |
| 03 | `03-brand-shell.md` | HOSSPI HMS identity, logo, app shell, and screen shell |
| 04 | `04-api-data.md` | API contracts, repositories, DTOs, and backend alignment |
| 05 | `05-auth.md` | Authentication, session, user avatar, and user dropdown |
| 06 | `06-settings.md` | Theme, language, app bar indicators, and general settings |
| 07 | `07-tenant-facility.md` | Tenant and facility setup |
| 08 | `08-access-control.md` | RBAC, ABAC, permissions, module entitlements, and action guards |
| 09 | `09-demo-seed.md` | Default tenant, facility, admins, department users, and demo data |
| 10 | `10-workspace-ui.md` | Reusable module workspace pattern |
| 11 | `11-patients.md` | Patient registry |
| 12 | `12-opd-flow.md` | Appointments, queues, OPD, and outpatient flow |
| 13 | `13-triage.md` | OPD triage and routing |
| 14 | `14-clinical.md` | Clinical consultation and provider workflow |
| 15 | `15-nursing.md` | Nursing workflow |
| 16 | `16-inpatient.md` | Admissions, beds, ward rounds, IPD progress, and transfers |
| 17 | `17-icu.md` | ICU stays, observations, alerts, and transfer/discharge readiness |
| 18 | `18-theater.md` | Theater/theatre workflow, anesthesia, post-op, and handover |
| 19 | `19-discharge.md` | Discharge summary, checks, instructions, and episode closure |
| 20 | `20-emergency.md` | Emergency and ambulance workflow |
| 21 | `21-lab.md` | Laboratory workflow |
| 22 | `22-radiology.md` | Radiology and imaging workflow |
| 23 | `23-pharmacy.md` | Pharmacy and medication dispensing |
| 24 | `24-billing.md` | Billing, cashier, receipts, refunds, and reconciliation |
| 25 | `25-claims.md` | Insurance, coverage, pre-authorization, and claims |
| 26 | `26-physiotherapy.md` | Physiotherapy workflow |
| 27 | `27-mortuary.md` | Mortuary workflow |
| 28 | `28-hr.md` | Human resources, shifts, leave, rosters, and payroll |
| 29 | `29-rooms-beds.md` | Rooms, wards, beds, and occupancy readiness |
| 30 | `30-biomedical.md` | Biomedical equipment lifecycle |
| 31 | `31-operations.md` | Electrical, plumbing, water, power, HVAC, and maintenance |
| 32 | `32-housekeeping.md` | Cleaning, schedules, turnover, and sanitation readiness |
| 33 | `33-subscriptions.md` | Plans, subscriptions, module subscriptions, licenses, and invoices |
| 34 | `34-notifications.md` | Notifications, conversations, badges, and in-app indicators |
| 35 | `35-reports-audit.md` | Dashboards, reports, analytics, audit, and compliance evidence |
| 36 | `36-integrations.md` | API keys, webhooks, integrations, and interoperability |
| 37 | `37-quality-release.md` | Validation, testing, release readiness, and final checklist |

## Current Implementation Strategy
- Do not rebuild the backend.
- Do not rebuild the Flutter starter foundation.
- Inspect existing frontend files first, then implement only missing app-specific screens, routes, models, repositories, controllers, forms, and module workspaces.
- Use backend routes, permissions, feature flags, module subscriptions, and response formats as the source of truth.
- Keep each module small enough to implement, test, and review independently.

## Obsolete Root Dev-Plan Files To Remove When Replacing The Folder
- `app-planner/dev-plan/index.md`
- `app-planner/dev-plan/00-execution-policy.md`
- `app-planner/dev-plan/01-app-identity-branding-and-foundation.md`
- `app-planner/dev-plan/02-backend-contract-and-data-foundation.md`
- `app-planner/dev-plan/03-authentication-session-and-user-menu.md`
- `app-planner/dev-plan/04-general-settings-and-shell-experience.md`
- `app-planner/dev-plan/05-tenant-facility-setup-and-access-control.md`
- `app-planner/dev-plan/06-workspace-patterns-and-shared-ui.md`
- `app-planner/dev-plan/07-patient-registry-opd-triage-outpatient-flow.md`
- `app-planner/dev-plan/07A-patient-registry.md`
- `app-planner/dev-plan/07B-opd-triage.md`
- `app-planner/dev-plan/07C-opd-outpatient-flow-management.md`
- `app-planner/dev-plan/08-clinical-nursing-inpatient-and-discharge.md`
- `app-planner/dev-plan/08A-clinical-module.md`
- `app-planner/dev-plan/08B-nursing-module.md`
- `app-planner/dev-plan/08C-inpatient-management.md`
- `app-planner/dev-plan/08D-icu-module.md`
- `app-planner/dev-plan/08E-theater-module.md`
- `app-planner/dev-plan/08F-discharge-module.md`
- `app-planner/dev-plan/09-pharmacy-billing-insurance-and-claims.md`
- `app-planner/dev-plan/09A-pharmacy-module.md`
- `app-planner/dev-plan/09B-billing-and-cashier-module.md`
- `app-planner/dev-plan/09C-insurance-and-claims-module.md`
- `app-planner/dev-plan/10-hr-rooms-biomedical-and-operations.md`
- `app-planner/dev-plan/10A-hr-module.md`
- `app-planner/dev-plan/10B-rooms-wards-and-beds.md`
- `app-planner/dev-plan/10C-biomedical-module.md`
- `app-planner/dev-plan/10D-operations-module.md`
- `app-planner/dev-plan/10E-housekeeping-module.md`
- `app-planner/dev-plan/11-notifications-reports-audit-and-integrations.md`
- `app-planner/dev-plan/11A-notifications-and-alerts.md`
- `app-planner/dev-plan/11B-reports-dashboards-and-audit.md`
- `app-planner/dev-plan/11C-integrations.md`
- `app-planner/dev-plan/12-final-validation-and-release-readiness.md`

## Rule References
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
- `frontend/app-planner/app-rules/localization_i18n.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`
### Additional references
- `app-planner/app-write-up.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
