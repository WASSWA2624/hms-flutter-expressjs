# 02 - Current Codebase Map

## Goal
Understand what already exists before planning or implementing new HOSSPI HMS features.

## Frontend Foundation Already Present
The Flutter frontend already includes these reusable foundations:

| Area | Existing path |
| --- | --- |
| App bootstrap | `frontend/lib/main.dart`, `frontend/lib/bootstrap.dart` |
| Root app | `frontend/lib/app/app.dart` |
| Router and guards | `frontend/lib/app/router/` |
| Startup flow | `frontend/lib/app/startup/` |
| Theme system | `frontend/lib/app/theme/` |
| Locale controller and generated localization | `frontend/lib/app/locale/`, `frontend/lib/l10n/` |
| Network client | `frontend/lib/core/network/` |
| Permissions foundation | `frontend/lib/core/permissions/` |
| Session and secure storage | `frontend/lib/core/security/`, `frontend/lib/core/storage/` |
| Responsive helpers | `frontend/lib/core/responsive/` |
| Shared UI components | `frontend/lib/shared/components/` |
| Shared layout | `frontend/lib/shared/layout/` |
| Settings page | `frontend/lib/features/settings/presentation/pages/settings_page.dart` |
| Home starter feature | `frontend/lib/features/home/` |

## Frontend Gaps To Address
- The app still carries starter/template identity in places such as `pubspec.yaml`, localization labels, and starter home content.
- `ApiEndpoints` currently contains only a sample endpoint helper.
- Routes currently cover the starter home/settings/status pages only.
- HMS modules need feature folders, routes, menu destinations, models, repositories, controllers, forms, tables, detail panels, modals, permissions, and tests.

## Backend Foundation Already Present
The backend exposes a broad `/api/v1` module surface. Important existing route families include:

| Area | Backend routes/modules |
| --- | --- |
| Auth/session | `/api/v1/auth`, `/api/v1/user-sessions` |
| Tenant/facility structure | `/api/v1/tenants`, `/facilities`, `/branches`, `/departments`, `/units`, `/rooms`, `/wards`, `/beds` |
| Users/access | `/users`, `/roles`, `/permissions`, `/role-permissions`, `/user-roles`, `/abac-policies`, `/api-keys` |
| Patient/OPD | `/patients`, `/appointments`, `/visit-queues`, `/triage`, `/opd-flows` |
| Clinical/IPD/ICU/theater | `/encounters`, `/clinical-notes`, `/diagnoses`, `/procedures`, `/care-plans`, `/admissions`, `/ipd-flows`, `/ward-rounds`, `/icu-stays`, `/icu-observations`, `/theatre-cases`, `/theatre-flows` |
| Pharmacy/inventory | `/drugs`, `/drug-batches`, `/formulary-items`, `/pharmacy`, `/pharmacy-orders`, `/dispense-logs`, `/inventory-items`, `/inventory-stocks` |
| Lab/radiology | `/lab`, `/lab-tests`, `/lab-orders`, `/lab-results`, `/radiology`, `/radiology-orders`, `/radiology-results`, `/imaging-studies` |
| Emergency/ambulance | `/emergency-cases`, `/triage-assessments`, `/emergency-responses`, `/ambulances`, `/ambulance-dispatches`, `/ambulance-trips` |
| Billing/claims | `/billing`, `/invoices`, `/invoice-items`, `/payments`, `/refunds`, `/coverage-plans`, `/insurance-claims`, `/pre-authorizations` |
| HR/operations | `/hr`, `/staff-profiles`, `/staff-positions`, `/staff-assignments`, `/staff-leaves`, `/shifts`, `/nurse-rosters`, `/housekeeping`, `/maintenance-requests` |
| Biomedical | `/biomedical`, `/equipment-registries`, `/equipment-work-orders`, `/equipment-calibration-logs`, `/equipment-safety-test-logs`, `/equipment-downtime-logs` |
| Mortuary | `/mortuary` plus mortuary data models and seed pack support |
| Subscriptions | `/subscriptions-workspace`, `/subscription-plans`, `/subscriptions`, `/subscription-invoices`, `/modules`, `/module-subscriptions`, `/licenses` |
| Notifications/reports/audit/integrations | `/notifications`, `/notification-deliveries`, `/dashboard-workspace`, `/reports-workspace`, `/audit-logs`, `/integrations`, `/webhook-subscriptions`, `/interop` |

## Backend Gap To Track
A dedicated physiotherapy route/module is not visible in the current backend route map. Future frontend work must not invent backend endpoints. Physiotherapy can start as a planned UI/workflow module and may reuse approved clinical endpoints such as encounters, procedures, care plans, notes, appointments, and follow-ups only if the backend contract supports that workflow. A dedicated backend physiotherapy module requires a separate backend-authorized task.

## Demo Seed Foundation Already Present
The backend already contains:
- `backend/scripts/setup-default-accounts.js`
- `backend/scripts/seed-demo-data.js`
- `backend/scripts/clear-demo-data.js`
- `backend/scripts/verify-demo-data.js`
- `backend/scripts/seeders/seed-catalog.js`
- seed packs for clinical, operations, subscriptions, communications, biomedical, mortuary, compliance, and governance.

## Output of This Step
Use this codebase map before creating routes or modules. Do not create duplicate foundations already present in the frontend.

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
- `frontend/app-planner/app-rules/feature_workflow.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`
- `backend/app-planner/app-rules/project-structure.md`
- `backend/app-planner/app-rules/prisma.md`
### Additional references
- `backend/src/app/router.js`
- `backend/scripts/seeders/seed-catalog.js`
- `frontend/lib/core/network/api_endpoints.dart`
- `frontend/lib/app/router/app_routes.dart`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
