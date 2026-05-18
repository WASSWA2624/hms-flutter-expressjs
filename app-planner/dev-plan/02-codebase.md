# 02 - Current Codebase Map

## Goal
Understand what already exists before planning or implementing new HOSSPI HMS features, so implementation does not reinvent the wheel.

## Source of Truth
- `app-write-up.md`, `opd-flow.md`, and `ipd-flow.md` are the single product/flow source of truth for this implementation plan; backend/frontend planner files and rules are alignment references only.
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

## Frontend Implementation Inventory
The current frontend already contains several HMS feature folders and routes. Treat these as partial app implementations to complete and normalize, not as disposable starter code.

| Status | Feature folders/routes |
| --- | --- |
| Present and must be extended | `auth`, `profile`, `settings`, `tenant_facility`, `patients`, `opd`, `emergency`, `clinical`, `nursing`, `ipd`, `icu`, `theater`, `discharge`, `lab`, `radiology`, `pharmacy`, `billing`, and `claims` |
| Still missing or needing new feature folders | `access_control`, `hr`, `rooms_beds`, `biomedical`, `operations`, `housekeeping`, `subscriptions`, `notifications`/`communications`, `reports_audit`, `integrations`, `physiotherapy`, and `mortuary` |
| Needs normalization while completing modules | Any list search still built with ad hoc `AppTextField`, any local modal/dialog variant, any duplicated list/table pattern, any hard-coded user-facing label, and any action not routed through `AppAccessGate`/`AppAccessActionGate` |

## Frontend Gaps To Address
- Complete and polish existing feature folders instead of replacing them.
- Add missing module feature folders only where absent, using the same `data/domain/presentation` shape.
- Normalize all list data to `AppListTable`/`AppPaginatedListTable`/`AppSearchablePaginatedListTable` and `AppSearchBar`/`AppListTableSearch`.
- Normalize CRUD, UI actions, approvals, payments, status changes, print/export options, and short detailed display to `AppDialog`.
- Ensure all app routes, menus, badges, row actions, modals, reports, and exports are permission/entitlement aware.
- Ensure module state changes update only affected providers/state slices and preserve filters, pagination, selected rows, and scroll position.
- Existing OPD, clinical, nursing, IPD, emergency, diagnostics, pharmacy, billing, claims, and patient registry work must be inspected and extended, not replaced.


## Reusable Foundation To Extend
| Pattern | Reuse or create once for | Must not contain |
| --- | --- | --- |
| Form fields and form shell | Registration, triage, notes, orders, payments, facility setup, HR, reports, and module settings | Feature-specific business rules or direct API calls |
| Modal/dialog shell | Quick create/edit, status updates, approvals, confirmations, payments, print/export actions, and short request flows | Nested workflow complexity that belongs on a full page |
| Patient context display | OPD, triage, clinical, nursing, IPD, ICU, theater, discharge, emergency, diagnostics, pharmacy, billing, claims, physiotherapy, and mortuary | Module-specific mutation logic |
| Worklist/table/list pattern | Queues, catalogs, registries, reports, audit logs, claims, assets, staff, rooms, and beds | Hard-coded module statuses or raw backend labels |
| Status badge/chip pattern | Encounter, admission, billing, order, result, bed, claim, task, equipment, notification, and report states | Frontend-only statuses not returned or accepted by backend |
| Async/permission state views | Loading, empty, error, forbidden, offline, success, and duplicate-submit states | Feature-specific routing or authorization bypasses |
| Report/print action pattern | Generated reports, summaries, receipts, discharge documents, exports, and audit extracts | Visible-screen printing or unauthorized data exposure |

Every repeated UI pattern must be checked against this foundation before a feature folder adds new widgets.

## Backend Foundation Already Present
The backend is expected to expose versioned `/api/v1` route families. Confirm actual route availability from the backend router before wiring frontend calls. Important confirmed/planned route groups to align with include:

| Area | Backend route families to verify and reuse |
| --- | --- |
| Auth/session | `/api/v1/auth`, `/api/v1/user-sessions` |
| Tenant/facility structure | `/api/v1/tenants`, `/api/v1/facilities`, `/api/v1/branches`, `/api/v1/departments`, `/api/v1/units`, `/api/v1/rooms`, `/api/v1/wards`, `/api/v1/beds` |
| Users/access | `/api/v1/users`, `/api/v1/user-profiles`, `/api/v1/roles`, `/api/v1/permissions`, `/api/v1/role-permissions`, `/api/v1/user-roles`, `/api/v1/abac-policies`, `/api/v1/break-glass-access`, `/api/v1/break-glass-reviews`, `/api/v1/api-keys`, `/api/v1/api-key-permissions` |
| Patient/scheduling/queues | `/api/v1/patients`, `/api/v1/patient-identifiers`, `/api/v1/patient-contacts`, `/api/v1/patient-guardians`, `/api/v1/patient-allergies`, `/api/v1/patient-medical-histories`, `/api/v1/patient-documents`, `/api/v1/consents`, `/api/v1/appointments`, `/api/v1/provider-schedules`, `/api/v1/availability-slots`, `/api/v1/visit-queues` |
| Clinical/OPD/IPD/ICU/theater | `/api/v1/encounters`, `/api/v1/clinical-notes`, `/api/v1/diagnoses`, `/api/v1/procedures`, `/api/v1/vital-signs`, `/api/v1/care-plans`, `/api/v1/referrals`, `/api/v1/follow-ups`, `/api/v1/admissions`, `/api/v1/bed-assignments`, `/api/v1/ward-rounds`, `/api/v1/nursing-notes`, `/api/v1/medication-administrations`, `/api/v1/discharge-summaries`, `/api/v1/transfer-requests`, `/api/v1/icu-stays`, `/api/v1/icu-observations`, `/api/v1/critical-alerts`, `/api/v1/theatre-cases`, `/api/v1/anesthesia-records`, `/api/v1/post-op-notes`, `/api/v1/triage-assessments`, `/api/v1/emergency-cases`, `/api/v1/emergency-responses` |
| Diagnostics/pharmacy | `/api/v1/lab-tests`, `/api/v1/lab-panels`, `/api/v1/lab-orders`, `/api/v1/lab-order-items`, `/api/v1/lab-samples`, `/api/v1/lab-results`, `/api/v1/lab-qc-logs`, `/api/v1/radiology-tests`, `/api/v1/radiology-orders`, `/api/v1/radiology-results`, `/api/v1/imaging-studies`, `/api/v1/imaging-assets`, `/api/v1/pacs-links`, `/api/v1/drugs`, `/api/v1/drug-batches`, `/api/v1/formulary-items`, `/api/v1/pharmacy-orders`, `/api/v1/pharmacy-order-items`, `/api/v1/dispense-logs`, `/api/v1/adverse-events` |
| Billing/claims | `/api/v1/invoices`, `/api/v1/invoice-items`, `/api/v1/payments`, `/api/v1/refunds`, `/api/v1/pricing-rules`, `/api/v1/coverage-plans`, `/api/v1/insurance-claims`, `/api/v1/pre-authorizations`, `/api/v1/billing-adjustments`, `/api/v1/shift-closes`, `/api/v1/day-closes` |
| HR/workforce | `/api/v1/staff-positions`, `/api/v1/staff-profiles`, `/api/v1/staff-assignments`, `/api/v1/staff-leaves`, `/api/v1/shifts`, `/api/v1/shift-assignments`, `/api/v1/shift-swap-requests`, `/api/v1/nurse-rosters`, `/api/v1/shift-templates`, `/api/v1/roster-day-offs`, `/api/v1/staff-availabilities`, `/api/v1/payroll-runs`, `/api/v1/payroll-items` |
| Operations/biomedical/housekeeping | `/api/v1/inventory-items`, `/api/v1/inventory-stocks`, `/api/v1/stock-movements`, `/api/v1/suppliers`, `/api/v1/purchase-requests`, `/api/v1/purchase-orders`, `/api/v1/goods-receipts`, `/api/v1/stock-adjustments`, `/api/v1/housekeeping-tasks`, `/api/v1/housekeeping-schedules`, `/api/v1/maintenance-requests`, `/api/v1/assets`, `/api/v1/asset-service-logs`, `/api/v1/equipment-categories`, `/api/v1/equipment-registries`, `/api/v1/equipment-work-orders`, `/api/v1/equipment-calibration-logs`, `/api/v1/equipment-safety-test-logs`, `/api/v1/equipment-downtime-logs`, `/api/v1/equipment-incident-reports`, `/api/v1/equipment-recall-notices` |
| Mortuary/closeout | `/api/v1/mortuary` workspace with `panel`, `resource`, `queue`, search, status, date, and id filters; resources include mortuary cases, storage units/slots/assignments, custody events, viewings, post-mortem requests, release authorisations, and billable events. Also reuse `/api/v1/office-contexts`, `/api/v1/handovers`, `/api/v1/custody-snapshots`, and `/api/v1/closeout-packs` where relevant. Do not call non-mounted mortuary entity routes directly. |
| Notifications/reports/integrations | `/api/v1/notifications`, `/api/v1/notification-deliveries`, `/api/v1/conversations`, `/api/v1/messages`, `/api/v1/templates`, `/api/v1/template-variables`, `/api/v1/report-definitions`, `/api/v1/report-runs`, `/api/v1/dashboard-widgets`, `/api/v1/kpi-snapshots`, `/api/v1/analytics-events`, `/api/v1/integrations`, `/api/v1/integration-logs`, `/api/v1/webhook-subscriptions` |

## Backend Gap To Track
Future frontend work must not invent backend endpoints. Before wiring frontend calls, verify the route in `backend/src/app/router.js`, the schema/service contract, the permission requirement, and the frontend enum in `frontend/lib/core/network/api_endpoints.dart`.

Known items to treat carefully:
- Physiotherapy has no dedicated route family in the current route map. Start only from approved clinical endpoints such as encounters, procedures, care plans, notes, appointments, and follow-ups when the workflow is supported. A dedicated physiotherapy backend module requires a separate backend-authorized task.
- Mortuary is currently exposed as `/api/v1/mortuary` workspace/list/lookups. Do not call separate mortuary entity routes unless they are mounted in the backend router in a future authorized backend change.
- If a backend route exists but the frontend `HmsApiResource` enum lacks it, extend the central enum/helper first. Do not scatter raw paths inside widgets.
- If the frontend enum lists a route but the backend router does not mount it, record a route-contract gap before building UI around it.

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
3. Do not create duplicate app shells, navigation systems, theme systems, form fields, modal/dialog components, patient display components, status badges, list/table patterns, API clients, permission utilities, or report templates.
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
