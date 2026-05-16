# 02 - Current Codebase Map

## Goal
Understand what already exists before planning or implementing new HOSSPI HMS features, so implementation does not reinvent the wheel.

## Source of Truth
- Use `app-write-up.md` for module responsibilities and boundaries.
- Use `opd-flow.md` for outpatient and triage movement.
- Use `ipd-flow.md` for admission, bed, inpatient, transfer, and discharge movement.
- Use frontend/backend `app-rules` for implementation mechanics.
- Use this file only as the current codebase map and reuse checklist.

## Frontend Foundation Already Present
The Flutter frontend planner describes these reusable foundations. Confirm the actual files before implementation and extend them instead of replacing them.

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
- Starter/template identity may still appear in `pubspec.yaml`, localization labels, and starter home content.
- `ApiEndpoints` may still need HMS endpoint helpers.
- Routes may still only cover starter pages until module work is added.
- HMS modules need feature folders, routes, menu destinations, models, repositories, controllers, forms, worklists, detail panels, modals, permissions, report actions, and tests.
- Existing OPD/triage/patient registry work must be inspected and extended, not replaced.

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
A dedicated physiotherapy route/module is not visible in the current backend route map. Future frontend work must not invent backend endpoints. Physiotherapy can start only as a planned UI/workflow module and may reuse approved clinical endpoints such as encounters, procedures, care plans, notes, appointments, and follow-ups only if the backend contract supports that workflow. A dedicated backend physiotherapy module requires a separate backend-authorized task.

## Demo Seed Foundation Already Present
The backend already contains:
- `backend/scripts/setup-default-accounts.js`
- `backend/scripts/seed-demo-data.js`
- `backend/scripts/clear-demo-data.js`
- `backend/scripts/verify-demo-data.js`
- `backend/scripts/seeders/seed-catalog.js`
- seed packs for clinical, operations, subscriptions, communications, biomedical, mortuary, compliance, and governance.

## No-Reinvention Checklist
Before adding any module screen or component:
1. Search the frontend for an existing route, feature folder, shared component, form field, modal, responsive layout, table/list, detail panel, state provider, and repository pattern.
2. Reuse or extend existing correct work.
3. Do not create duplicate app shells, navigation systems, theme systems, modal components, API clients, permission utilities, or report templates.
4. Do not create endpoints or local models that conflict with backend contracts.
5. Keep data flow consistent: UI → controller/provider → repository → API client → backend.
6. Keep OPD/IPD flow updates attached to the correct encounter/admission.

## Output of This Step
Use this codebase map before creating routes or modules. The next implementation task should know exactly what exists, what is missing, what can be reused, and what must remain unchanged.

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
- `backend/src/app/router.js`
- `backend/scripts/seeders/seed-catalog.js`
- `frontend/lib/core/network/api_endpoints.dart`
- `frontend/lib/app/router/app_routes.dart`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
