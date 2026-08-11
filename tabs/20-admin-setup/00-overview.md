# Admin setup workspace UI inventory

Source: `tabs-lister/20-admin-setup.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `TenantFacilitySetupPage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/admin/setup` (`AppRoutes.tenantFacilitySetup`)  
**Feature home:** `frontend/lib/features/tenant_facility/` (not `access_admin` — that module is **reused** for roles/permissions/users)  
**Page:** `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`  
**Helpers / visibility:** `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`  
**Sections enum:** `TenantFacilitySetupDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `tenants` | `tenants` | `tenant` | [01-tenants.md](01-tenants.md) |
| `facility` | `facility` | `facilities` | [02-facility.md](02-facility.md) |
| `departments` | `departments` | singulars/plurals via `fromQuery` | [03-departments.md](03-departments.md) |
| `units` | `units` | | [04-units.md](04-units.md) |
| `wards` | `wards` | | [05-wards.md](05-wards.md) |
| `rooms` | `rooms` | | [06-rooms.md](06-rooms.md) |
| `beds` | `beds` | | [07-beds.md](07-beds.md) |
| `roles` | `roles` | | [08-roles.md](08-roles.md) |
| `permissions` | `permissions` | | [09-permissions.md](09-permissions.md) |
| `users` | `users` | | [10-users.md](10-users.md) |
| `clinicalCatalog` | `clinical-services` | `clinical-catalog`, `clinical`, `catalog`, `services` | [11-clinical-catalog.md](11-clinical-catalog.md) |
| `subscriptionApprovals` | `subscription-approvals` | `subscription_approvals`, `approvals`, `account-approvals`, `registration-approvals` | [12-subscription-approvals.md](12-subscription-approvals.md) |
| `subscriptionActivations` | `subscription-activations` | `subscription_activations`, `activations`, `payment-activations` | [13-subscription-activations.md](13-subscription-activations.md) |

Helpers: `TenantFacilitySetupDeskSection.routeQueryValue` / `fromQuery` in `tenant_facility_setup_helpers.dart`. Query accepts `?section=` **or** `?tab=`.

Platform-admin only (`isElevated`): subscription approvals + activations.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_facility_setup.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_wizard.dart` (unused by desk)
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/manage_subscription_approvals_panel.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/manage_subscription_activations_panel.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart` (**reused**)
- `frontend/test/features/tenant_facility/`
