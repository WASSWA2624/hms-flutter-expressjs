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
// Preferences (`/settings?tab=preferences`)
// ---------------------------------------------------------------------------

/// Preferences tab (`/settings?tab=preferences`) atom → permission map.
///
/// Authenticated profile prefs. Reuses [profileReadRequirement] /
/// [profileUpdateRequirement]. No nested dialogs. Create/delete ∩
/// `facility:admin` are documented but **not mounted**. View ∪ / nested
/// cross-module rows are _(n/a)_. Profile rights are core/platform (not
/// plan-module mapped); subscription stripping does not apply. Own-scoped
/// via local theme prefs for the current user.
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Tab strip / section chrome | read | `profile:read` ∩ ([tab]) |
/// | App theme current value | read | `profile:read` ∩ ([themeModeValue]) |
/// | App theme radio group | update | `profile:update` ∩ ([themeMode]) |
/// | Save-error snackbar | visible feedback | update path ([success]/[validation]) |
/// | Create / delete affordances | create/delete | ∩ facility:admin — **not mounted** |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
abstract final class SettingsPreferencesAtomPermissions {
  static const AccessRequirement tab = profileReadRequirement;
  static const AccessRequirement read = profileReadRequirement;
  static const AccessRequirement listChrome = profileReadRequirement;
  static const AccessRequirement themeModeValue = profileReadRequirement;
  static const AccessRequirement loading = profileReadRequirement;
  static const AccessRequirement empty = profileReadRequirement;
  static const AccessRequirement retry = profileReadRequirement;
  static const AccessRequirement update = profileUpdateRequirement;
  static const AccessRequirement themeMode = profileUpdateRequirement;
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
// Account and security (`/settings?tab=account`)
// ---------------------------------------------------------------------------

/// Account and security tab atom → permission mapping (inventory + matrix).
///
/// Settings accordion tab `account` (`/settings?tab=account`). Reuses profile
/// feature helpers [profileReadRequirement] / [profileUpdateRequirement] for
/// view ∩ `profile:read` and update ∩ `profile:update`. Matrix create/delete
/// ∩ `facility:admin` are documented here but **not mounted** on this tab.
/// Nested cross-module and view ∪ rows are _(n/a)_. Profile rights are
/// core/platform (not plan-module mapped); subscription stripping does not
/// apply. Surface is own-scoped via the current-user profile API.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Account and security strip tab | navigate | read ∩ ([tab]) |
/// | Section title / body chrome | read chrome | ([listChrome]) |
/// | Profile summary (identity) | read | ([summary]) |
/// | Account / professional detail panels | read | ([detail]) |
/// | Roles / permissions badges | read | ([roles] / [permissions]) |
/// | Empty roles / permissions copy | read chrome | ([empty]) |
/// | Loading / error / retry | read chrome | ([loading] / [retry]) |
/// | Copy user id / staff number | read chrome | ([copyIdentifier]) |
/// | Change password (toolbar + dialog) | update | ∩ profile:update ([changePassword]) |
/// | Edit profile (toolbar + dialog) | update | ∩ profile:update ([editProfile]) |
/// | Success / validation snackbars | visible feedback | update ∩ (authorized) |
/// | Deep link `panel=change-password` | update | ∩ profile:update; forbidden when denied |
/// | Create / delete affordances | create/delete | ∩ facility:admin — **not mounted** |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Settings route entry | navigate | authenticated core ([routeEntry]) |
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

/// Accessibility tab (`/settings?tab=accessibility`) atom → permission map.
///
/// Authenticated profile prefs. Reuses [profileReadRequirement] /
/// [profileUpdateRequirement]. No nested dialogs. Create/delete ∩
/// `facility:admin` are documented but **not mounted**. View ∪ / nested
/// cross-module rows are _(n/a)_. Profile rights are core/platform (not
/// plan-module mapped); subscription stripping does not apply. Own-scoped
/// via local accessibility prefs for the current user.
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Tab strip / section chrome | read | `profile:read` ∩ ([tab] / [listChrome]) |
/// | Reduce motion / Bold text / Text size values | read | `profile:read` ∩ |
/// | Reduce motion / Bold text checkboxes | update | `profile:update` ∩ |
/// | Text size select | update | `profile:update` ∩ |
/// | Save-error snackbar | visible feedback | update path ([success]/[validation]) |
/// | Create / delete affordances | create/delete | ∩ facility:admin — **not mounted** |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
abstract final class SettingsAccessibilityAtomPermissions {
  static const AccessRequirement tab = profileReadRequirement;
  static const AccessRequirement read = profileReadRequirement;
  static const AccessRequirement listChrome = profileReadRequirement;
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
/// Settings accordion tab `administration` (`/settings?tab=administration`).
/// View = `profile:read` ∩ admin ∪. Navigate tiles reuse [RouteAccessCatalog]
/// sources (documented mapping vs tab admin ∪). Create / update / delete and
/// nested cross-module write rows are matrix-documented but **not mounted**
/// on this navigate-only surface. Admin / profile keys are core/platform;
/// subscriptions navigate applies `subscription-controls` plan module +
/// destination ABAC (setup: facility; access admin: tenant).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Administration boundaries strip tab | navigate | read ∩∪ ([tab]) |
/// | Section title / body chrome | read chrome | ([read] / [listChrome]) |
/// | Tenant and facility setup tile | navigate | catalog setup ([tenantFacilitySetup]) |
/// | Subscription plans tile | navigate | catalog subscriptions ([subscriptions]) |
/// | Users and access tile | navigate | catalog access admin ([accessAdmin]) |
/// | Loading / empty / error / retry | read chrome | ([loading] / [empty] / [retry]) — empty collapses when no destinations |
/// | Create / update / delete affordances | create/update/delete | matrix ∩ — **not mounted** |
/// | Nested cross-module panels | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Success / validation snackbars | visible feedback | N/A (no mutations on tab) |
/// | Settings route entry | navigate | authenticated core ([routeEntry]) |
abstract final class SettingsAdministrationAtomPermissions {
  static const AccessRequirement tab = settingsAdministrationReadRequirement;
  static const AccessRequirement read = settingsAdministrationReadRequirement;
  static const AccessRequirement listChrome =
      settingsAdministrationReadRequirement;
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
  static const AccessRequirement success =
      settingsAdministrationReadRequirement;
  static const AccessRequirement validation =
      settingsAdministrationReadRequirement;
  static const AccessRequirement routeEntry =
      RouteAccessCatalog.authenticatedCore;
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

// ---------------------------------------------------------------------------
// Administrative setup workspace (`/settings?tab=workspace`)
// ---------------------------------------------------------------------------

/// Matrix view ∪ keys for Administrative setup (admin ∪ ∪ `hr:read`).
const List<AppPermission> settingsWorkspaceViewAnyPermissions =
    <AppPermission>[
      AppPermissions.facilityAdmin,
      AppPermissions.tenantAdmin,
      AppPermissions.systemAdmin,
      AppPermissions.hrRead,
    ];

/// Matrix view / read UI:
/// `profile:read` ∩ (`facility:admin` ∪ `tenant:admin` ∪ `system:admin` ∪ `hr:read`).
///
/// Admin / profile keys are core/platform; `hr:read` is plan-scoped to
/// `hr-rosters` via [PermissionModuleMap] when that union arm is used.
const AccessRequirement settingsWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
  anyPermissions: settingsWorkspaceViewAnyPermissions,
);

/// Source admin workspace gate (backend SETTINGS_WORKSPACE admin scopes +
/// roles + tenant ABAC). Aligned with matrix ∩ `profile:read`; admin ∪ omits
/// `hr:read` (HR path is [settingsWorkspaceHrRequirement]).
const AccessRequirement settingsWorkspaceAdminRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
  anyPermissions: settingsAdminAnyPermissions,
  anyRoles: <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ],
  requiresTenantContext: true,
);

/// Source HR workspace gate. Matrix view ∪ lists `hr:read`; source also
/// accepts `hr:write` and requires HR role pack + tenant/facility ABAC.
const AccessRequirement settingsWorkspaceHrRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileRead],
  anyPermissions: <AppPermission>[
    AppPermissions.hrRead,
    AppPermissions.hrWrite,
  ],
  anyRoles: <AppRole>[AppRole.hr],
  requiresTenantContext: true,
  requiresFacilityContext: true,
);

/// Matrix create ∩ `facility:admin`.
const AccessRequirement settingsWorkspaceCreateRequirement =
    settingsFacilityAdminRequirement;

/// Source HR create for department/unit setup. Backend
/// `canWriteSetupModule` uses `hr:write` ∪ `unit:manage`; matrix create is
/// `facility:admin` ∩ — keep source and note the mapping in tests.
const AccessRequirement settingsWorkspaceHrCreateRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.hrWrite,
        AppPermissions.unitManage,
      ],
      requiresTenantContext: true,
      requiresFacilityContext: true,
    );

/// Matrix update ∩ `profile:update` — no update atoms on this surface
/// (search/filters/context selectors are read chrome).
const AccessRequirement settingsWorkspaceUpdateRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.profileUpdate],
);

/// Matrix delete ∩ `facility:admin` — no delete atoms on this surface.
const AccessRequirement settingsWorkspaceDeleteRequirement =
    settingsFacilityAdminRequirement;

/// True when the Administrative setup workspace strip may appear.
bool settingsWorkspaceSectionVisible(AppAccessPolicy policy) {
  return settingsWorkspaceAdminRequirement.isAllowed(policy) ||
      settingsWorkspaceHrRequirement.isAllowed(policy);
}

/// Whether a module Create affordance may mount (matrix create ∪ source HR
/// create), after backend `can_create` has already been applied.
bool settingsWorkspaceCanCreate(AppAccessPolicy policy) {
  return settingsWorkspaceCreateRequirement.isAllowed(policy) ||
      settingsWorkspaceHrCreateRequirement.isAllowed(policy);
}

/// Administrative setup workspace atom → permission mapping.
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Tab strip / section chrome | read | [tab] (admin ∨ HR source) |
/// | Loading / empty / error / retry | read chrome | [loading] / [empty] / [retry] |
/// | Tenant context required + selectors | read chrome | [contextSelector] |
/// | Search / group / state / actionable filters | read chrome | [search] / [filters] |
/// | Module groups + row metadata | read | [moduleList] / [moduleRow] |
/// | Open (navigate to setup / access admin) | navigate | [open] + backend `can_read` |
/// | Create (navigate to create route) | create | [create] ∪ [hrCreate] + `can_create` |
/// | Update / delete affordances | — | matrix keys; **not mounted** |
/// | Nested cross-module panels | nested | _(n/a)_ |
abstract final class SettingsWorkspaceAtomPermissions {
  static const AccessRequirement tab = settingsWorkspaceReadRequirement;
  static const AccessRequirement read = settingsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = settingsWorkspaceReadRequirement;
  static const AccessRequirement loading = settingsWorkspaceReadRequirement;
  static const AccessRequirement empty = settingsWorkspaceReadRequirement;
  static const AccessRequirement retry = settingsWorkspaceReadRequirement;
  static const AccessRequirement contextSelector =
      settingsWorkspaceReadRequirement;
  static const AccessRequirement search = settingsWorkspaceReadRequirement;
  static const AccessRequirement filters = settingsWorkspaceReadRequirement;
  static const AccessRequirement moduleList = settingsWorkspaceReadRequirement;
  static const AccessRequirement moduleRow = settingsWorkspaceReadRequirement;
  static const AccessRequirement open = settingsWorkspaceReadRequirement;
  static const AccessRequirement success = settingsWorkspaceReadRequirement;
  static const AccessRequirement validation = settingsWorkspaceReadRequirement;

  /// Matrix ∩ `facility:admin`.
  static const AccessRequirement create = settingsWorkspaceCreateRequirement;

  /// Source HR create (`hr:write` ∪ `unit:manage` + facility ABAC).
  static const AccessRequirement hrCreate =
      settingsWorkspaceHrCreateRequirement;

  /// Matrix ∩ `profile:update` — not mounted on this tab.
  static const AccessRequirement update = settingsWorkspaceUpdateRequirement;

  /// Matrix ∩ `facility:admin` — not mounted on this tab.
  static const AccessRequirement delete = settingsWorkspaceDeleteRequirement;

  /// Nested cross-module — matrix _(n/a)_.
  static const AccessRequirement nestedRead = settingsWorkspaceReadRequirement;
  static const AccessRequirement nestedWrite = settingsWorkspaceCreateRequirement;

  /// Source gates reused by the settings page strip.
  static const AccessRequirement adminGate = settingsWorkspaceAdminRequirement;
  static const AccessRequirement hrGate = settingsWorkspaceHrRequirement;
}

// ---------------------------------------------------------------------------
// Configuration (`/settings?tab=configuration`)
// ---------------------------------------------------------------------------

/// View / read UI for Configuration:
/// `profile:read` ∩ (`facility:admin` ∪ `tenant:admin` ∪ `system:admin`).
const AccessRequirement settingsConfigurationReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.profileRead],
      anyPermissions: settingsAdminAnyPermissions,
    );

/// Tenant defaults panel — source gate (differs from matrix update ∩
/// `facility:admin`): `tenant:admin` ∪ `system:admin` + tenant context.
const AccessRequirement settingsConfigurationTenantRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.tenantAdmin,
        AppPermissions.systemAdmin,
      ],
      anyRoles: <AppRole>[AppRole.superAdmin, AppRole.tenantAdmin],
      requiresTenantContext: true,
    );

/// Facility defaults panel — source gate (includes matrix `facility:admin`
/// within admin ∪) + facility context.
const AccessRequirement settingsConfigurationFacilityRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.tenantAdmin,
        AppPermissions.facilityAdmin,
        AppPermissions.systemAdmin,
      ],
      anyRoles: <AppRole>[
        AppRole.superAdmin,
        AppRole.tenantAdmin,
        AppRole.facilityAdmin,
      ],
      requiresFacilityContext: true,
    );

/// Create (matrix ∩ `facility:admin`) — no create atoms on this tab.
const AccessRequirement settingsConfigurationCreateRequirement =
    settingsFacilityAdminRequirement;

/// Update (matrix ∩ `facility:admin`). Mounted Save/Reset use source panel
/// gates ([settingsConfigurationTenantRequirement] /
/// [settingsConfigurationFacilityRequirement]); note mapping in tests.
const AccessRequirement settingsConfigurationUpdateRequirement =
    settingsFacilityAdminRequirement;

/// Delete (matrix ∩ `facility:admin`) — no delete atoms; Reset clears via
/// update/save under panel write gates.
const AccessRequirement settingsConfigurationDeleteRequirement =
    settingsFacilityAdminRequirement;

/// Configuration tab atom → permission mapping.
///
/// | Atom | Intent | Gate |
/// | --- | --- | --- |
/// | Tab strip / section chrome | read | [tab] |
/// | Loading / empty / error / retry | read | [tab] |
/// | Tenant defaults panel + fields | update | source tenant |
/// | Facility defaults panel + fields | update | source facility |
/// | Save configuration | update | source panel write |
/// | Reset to default (+ confirm dialog) | update | source panel write |
/// | Create / delete | — | matrix ∩; **not mounted** |
abstract final class SettingsConfigurationAtomPermissions {
  static const AccessRequirement tab = settingsConfigurationReadRequirement;
  static const AccessRequirement read = settingsConfigurationReadRequirement;
  static const AccessRequirement loading = settingsConfigurationReadRequirement;
  static const AccessRequirement empty = settingsConfigurationReadRequirement;
  static const AccessRequirement retry = settingsConfigurationReadRequirement;
  static const AccessRequirement tenantPanel =
      settingsConfigurationTenantRequirement;
  static const AccessRequirement facilityPanel =
      settingsConfigurationFacilityRequirement;
  static const AccessRequirement tenantSave =
      settingsConfigurationTenantRequirement;
  static const AccessRequirement tenantReset =
      settingsConfigurationTenantRequirement;
  static const AccessRequirement facilitySave =
      settingsConfigurationFacilityRequirement;
  static const AccessRequirement facilityReset =
      settingsConfigurationFacilityRequirement;
  static const AccessRequirement success =
      settingsConfigurationFacilityRequirement;
  static const AccessRequirement validation =
      settingsConfigurationFacilityRequirement;
  static const AccessRequirement create =
      settingsConfigurationCreateRequirement;
  static const AccessRequirement update =
      settingsConfigurationUpdateRequirement;
  static const AccessRequirement delete =
      settingsConfigurationDeleteRequirement;
  static const AccessRequirement nestedRead =
      settingsConfigurationReadRequirement;
  static const AccessRequirement nestedWrite =
      settingsConfigurationUpdateRequirement;
}

/// True when the Configuration strip may appear: tab read gate plus at least
/// one authorized tenant/facility panel for the current ABAC scope.
bool settingsConfigurationSectionVisible(AppAccessPolicy policy) {
  if (!settingsConfigurationReadRequirement.isAllowed(policy)) {
    return false;
  }
  return settingsConfigurationTenantRequirement.isAllowed(policy) ||
      settingsConfigurationFacilityRequirement.isAllowed(policy);
}
