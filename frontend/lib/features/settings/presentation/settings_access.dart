import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';

/// Product label from UI-permission prompts (`administration` / admin setup).
const String settingsAdministrationModuleLabel = 'settings / admin setup';

/// Admin any-of keys shared by Administration boundaries, Configuration, and
/// Administrative setup (matrix ∪).
const List<AppPermission> settingsAdminAnyPermissions = <AppPermission>[
  AppPermissions.facilityAdmin,
  AppPermissions.tenantAdmin,
  AppPermissions.systemAdmin,
];

/// View / read UI for Administration boundaries:
/// `profile:read` ∩ (`facility:admin` ∪ `tenant:admin` ∪ `system:admin`).
///
/// Admin keys are core/platform (not [PermissionModuleMap]-scoped). Nested
/// navigate destinations add their own [RouteAccessCatalog] gates (and
/// subscription modules where documented).
const AccessRequirement settingsAdministrationReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.profileRead],
      anyPermissions: settingsAdminAnyPermissions,
    );

/// Create (matrix ∩ `facility:admin`) — no create atoms on this navigate-only
/// tab; reserved for ∩ denial / future write chrome.
const AccessRequirement settingsAdministrationCreateRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.facilityAdmin],
    );

/// Update (matrix ∩ `profile:update`) — no update atoms on this tab.
const AccessRequirement settingsAdministrationUpdateRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.profileUpdate],
    );

/// Delete (matrix ∩ `facility:admin`) — no delete atoms on this tab.
const AccessRequirement settingsAdministrationDeleteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.facilityAdmin],
    );

/// Navigate → tenant/facility setup. Source [RouteAccessCatalog.setupEntry]
/// (`setup:read` ∩ facility context) differs from the tab admin ∪ matrix;
/// keep catalog and note the mapping in tests.
const AccessRequirement settingsAdministrationTenantFacilityNavigateRequirement =
    RouteAccessCatalog.setupEntry;

/// Navigate → subscriptions. Source [RouteAccessCatalog.subscriptionsEntry]
/// (`subscriptions:read` ∩ `subscription-controls`).
const AccessRequirement settingsAdministrationSubscriptionsNavigateRequirement =
    RouteAccessCatalog.subscriptionsEntry;

/// Navigate → access admin. Source [RouteAccessCatalog.accessAdminEntry]
/// (`access_admin:read` ∩ tenant context).
const AccessRequirement settingsAdministrationAccessAdminNavigateRequirement =
    RouteAccessCatalog.accessAdminEntry;

/// True when the Administration boundaries strip may appear: tab read gate
/// plus at least one authorized navigate destination for the current mode.
///
/// When [settingsWorkspaceVisible] is true, tenant/facility and access-admin
/// entry points live under Administrative setup; only subscriptions remain.
bool settingsAdministrationSectionVisible(
  AppAccessPolicy policy, {
  required bool settingsWorkspaceVisible,
}) {
  if (!settingsAdministrationReadRequirement.isAllowed(policy)) {
    return false;
  }
  return settingsAdministrationNavigateDestinations(
    settingsWorkspaceVisible: settingsWorkspaceVisible,
  ).any((AccessRequirement requirement) => requirement.isAllowed(policy));
}

/// Ordered navigate requirements exposed on this tab for the given mode.
List<AccessRequirement> settingsAdministrationNavigateDestinations({
  required bool settingsWorkspaceVisible,
}) {
  if (settingsWorkspaceVisible) {
    return const <AccessRequirement>[
      settingsAdministrationSubscriptionsNavigateRequirement,
    ];
  }
  return const <AccessRequirement>[
    settingsAdministrationTenantFacilityNavigateRequirement,
    settingsAdministrationSubscriptionsNavigateRequirement,
    settingsAdministrationAccessAdminNavigateRequirement,
  ];
}
