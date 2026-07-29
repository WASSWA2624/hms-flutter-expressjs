import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/profile/presentation/profile_access.dart';

/// Product label from UI-permission prompts (`administration` / admin setup).
const String settingsAdministrationModuleLabel = 'settings / admin setup';

/// Matrix create/delete ∩ `facility:admin` — reserved on Preferences /
/// Accessibility / Account / Administration when those surfaces have no
/// create/delete atoms.
const AccessRequirement settingsFacilityAdminRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.facilityAdmin],
);

// ---------------------------------------------------------------------------
// Account and security (`/settings?tab=account`)
// ---------------------------------------------------------------------------

/// Account and security tab atom → permission mapping (inventory + matrix).
///
/// Reuses [profileReadRequirement] / [profileUpdateRequirement]. Matrix
/// create/delete ∩ `facility:admin` are documented but **not mounted**.
abstract final class SettingsAccountAtomPermissions {
  static const AccessRequirement tab = profileReadRequirement;
  static const AccessRequirement listChrome = profileReadRequirement;
  static const AccessRequirement summary = profileReadRequirement;
  static const AccessRequirement detail = profileReadRequirement;
  static const AccessRequirement roles = profileReadRequirement;
  static const AccessRequirement permissions = profileReadRequirement;
  static const AccessRequirement empty = profileReadRequirement;
  static const AccessRequirement loading = profileReadRequirement;
  static const AccessRequirement retry = profileReadRequirement;
  static const AccessRequirement copyIdentifier = profileReadRequirement;
  static const AccessRequirement read = profileReadRequirement;

  /// Matrix ∩ `profile:update`.
  static const AccessRequirement update = profileUpdateRequirement;
  static const AccessRequirement changePassword = profileUpdateRequirement;
  static const AccessRequirement editProfile = profileUpdateRequirement;
  static const AccessRequirement success = profileUpdateRequirement;
  static const AccessRequirement validation = profileUpdateRequirement;

  /// Matrix ∩ `facility:admin` — no create control on this tab.
  static const AccessRequirement create = settingsFacilityAdminRequirement;

  /// Matrix ∩ `facility:admin` — no delete control on this tab.
  static const AccessRequirement delete = settingsFacilityAdminRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses account read ∩ / update ∩.
  static const AccessRequirement nestedRead = profileReadRequirement;
  static const AccessRequirement nestedWrite = profileUpdateRequirement;

  static const AccessRequirement routeEntry =
      RouteAccessCatalog.authenticatedCore;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.authenticatedCore;
}

/// Alias kept for older call sites / tests.
const AccessRequirement settingsAccountCreateRequirement =
    settingsFacilityAdminRequirement;

/// Alias kept for older call sites / tests.
const AccessRequirement settingsAccountDeleteRequirement =
    settingsFacilityAdminRequirement;

// ---------------------------------------------------------------------------
// Accessibility (`/settings?tab=accessibility`)
// ---------------------------------------------------------------------------

/// Accessibility tab atom → permission mapping.
abstract final class SettingsAccessibilityAtomPermissions {
  static const AccessRequirement tab = profileReadRequirement;
  static const AccessRequirement read = profileReadRequirement;
  static const AccessRequirement reduceMotionValue = profileReadRequirement;
  static const AccessRequirement boldTextValue = profileReadRequirement;
  static const AccessRequirement textScaleValue = profileReadRequirement;
  static const AccessRequirement loading = profileReadRequirement;
  static const AccessRequirement empty = profileReadRequirement;
  static const AccessRequirement retry = profileReadRequirement;
  static const AccessRequirement update = profileUpdateRequirement;
  static const AccessRequirement reduceMotion = profileUpdateRequirement;
  static const AccessRequirement boldText = profileUpdateRequirement;
  static const AccessRequirement textScale = profileUpdateRequirement;
  static const AccessRequirement success = profileUpdateRequirement;
  static const AccessRequirement validation = profileUpdateRequirement;
  static const AccessRequirement create = settingsFacilityAdminRequirement;
  static const AccessRequirement delete = settingsFacilityAdminRequirement;
  static const AccessRequirement nestedRead = profileReadRequirement;
  static const AccessRequirement nestedWrite = profileUpdateRequirement;
  static const AccessRequirement routeEntry =
      RouteAccessCatalog.authenticatedCore;
}

// ---------------------------------------------------------------------------
// Administration boundaries (`/settings?tab=administration`)
// ---------------------------------------------------------------------------

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
/// Admin keys are core/platform (not plan-module mapped). Nested navigate
/// destinations add their own [RouteAccessCatalog] gates (and subscription
/// modules where documented).
const AccessRequirement settingsAdministrationReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.profileRead],
      anyPermissions: settingsAdminAnyPermissions,
    );

/// Create (matrix ∩ `facility:admin`) — no create atoms on this navigate-only
/// tab; reserved for ∩ denial / future write chrome.
const AccessRequirement settingsAdministrationCreateRequirement =
    settingsFacilityAdminRequirement;

/// Update (matrix ∩ `profile:update`) — no update atoms on this tab.
const AccessRequirement settingsAdministrationUpdateRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.profileUpdate],
    );

/// Delete (matrix ∩ `facility:admin`) — no delete atoms on this tab.
const AccessRequirement settingsAdministrationDeleteRequirement =
    settingsFacilityAdminRequirement;

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

/// Administration boundaries tab atom → permission mapping.
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Tab strip / section chrome | read | [tab] |
/// | Tenant and facility setup tile | navigate | catalog setup |
/// | Subscription plans tile | navigate | catalog subscriptions |
/// | Users and access tile | navigate | catalog access admin |
/// | Create / update / delete | — | matrix keys; **not mounted** |
abstract final class SettingsAdministrationAtomPermissions {
  static const AccessRequirement tab = settingsAdministrationReadRequirement;
  static const AccessRequirement read = settingsAdministrationReadRequirement;
  static const AccessRequirement loading = settingsAdministrationReadRequirement;
  static const AccessRequirement empty = settingsAdministrationReadRequirement;
  static const AccessRequirement retry = settingsAdministrationReadRequirement;
  static const AccessRequirement tenantFacilitySetup =
      settingsAdministrationTenantFacilityNavigateRequirement;
  static const AccessRequirement subscriptions =
      settingsAdministrationSubscriptionsNavigateRequirement;
  static const AccessRequirement accessAdmin =
      settingsAdministrationAccessAdminNavigateRequirement;
  static const AccessRequirement create =
      settingsAdministrationCreateRequirement;
  static const AccessRequirement update =
      settingsAdministrationUpdateRequirement;
  static const AccessRequirement delete =
      settingsAdministrationDeleteRequirement;
  static const AccessRequirement nestedRead =
      settingsAdministrationReadRequirement;
  static const AccessRequirement nestedWrite =
      settingsAdministrationUpdateRequirement;
}

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
