import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';

/// Module entitlement for the housekeeping workspace route and sections.
const String housekeepingFacilitiesMaintenanceModule = 'facilities-maintenance';

/// Alias used by tests and newer call sites.
const String housekeepingFacilitiesModule =
    housekeepingFacilitiesMaintenanceModule;

/// Alias used by newer call sites / tests.
const String housekeepingActiveModule = housekeepingFacilitiesMaintenanceModule;

/// View / read UI (matrix ∩ `operations:read`).
///
/// Facility ABAC is enforced on route entry ([housekeepingWorkspaceEntryRequirement]);
/// in-page atoms reuse module + permission only (same pattern as biomedical).
const AccessRequirement housekeepingWorkspaceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.operationsRead],
      activeModules: <String>[housekeepingFacilitiesMaintenanceModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement housekeepingReadRequirement =
    housekeepingWorkspaceReadRequirement;

/// Create / update / delete mutations (matrix ∩ `operations:write`).
///
/// Source inventory `canManage` — create task/schedule, assign, cancel,
/// triage, complete/cancel maintenance request.
const AccessRequirement housekeepingWorkspaceManageRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.operationsWrite],
      activeModules: <String>[housekeepingFacilitiesMaintenanceModule],
    );

/// Alias matching matrix create / update / delete ∩.
const AccessRequirement housekeepingWorkspaceWriteRequirement =
    housekeepingWorkspaceManageRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement housekeepingWriteRequirement =
    housekeepingWorkspaceManageRequirement;

/// Alias matching historical `canManage` naming.
const AccessRequirement housekeepingManageRequirement =
    housekeepingWorkspaceManageRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.housekeeping].
///
/// Matches [AppRoutes.housekeeping] ∪ `operations:read` | `operations:write`
/// plus `facilities-maintenance` and facility ABAC.
const AccessRequirement housekeepingWorkspaceEntryRequirement =
    RouteAccessCatalog.housekeepingEntry;

/// Report summary secondary (source inventory `canReport`):
/// ∪ `reports:read` | `operations:read`.
const AccessRequirement housekeepingWorkspaceReportRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.reportsRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>[housekeepingFacilitiesMaintenanceModule],
    );

/// Alias used by tab atom maps.
const AccessRequirement housekeepingReportRequirement =
    housekeepingWorkspaceReportRequirement;

/// Effective capabilities for housekeeping chrome (source inventory gates).
///
/// - [canManage]: matrix create/update/delete ∩ `operations:write`
/// - [canUpdateTasks]: source — manage **or** housekeeper roles (start/complete
///   tasks; Request maintenance primary). Matrix create is write-only; source
///   keeps housekeeper create for maintenance requests — note mapping in tests.
/// - [canReport]: source ∪ reports|operations read
/// - [canRead]: matrix view ∩ `operations:read`
final class HousekeepingCapabilities {
  const HousekeepingCapabilities({
    required this.canManage,
    required this.canUpdateTasks,
    required this.canReport,
    required this.canRead,
  });

  final bool canManage;
  final bool canUpdateTasks;
  final bool canReport;
  final bool canRead;

  factory HousekeepingCapabilities.fromPolicy(AppAccessPolicy policy) {
    final bool canManage = canManageHousekeeping(policy);
    final bool canRead = canReadHousekeeping(policy);
    final bool isHousekeepingRole =
        policy.hasRole(AppRole.houseKeeper) ||
        policy.hasRole(AppRole.housekeepingManager);
    return HousekeepingCapabilities(
      canManage: canManage,
      canUpdateTasks: canManage || (isHousekeepingRole && canRead),
      canReport: canReportHousekeeping(policy),
      canRead: canRead,
    );
  }
}

bool canEnterHousekeepingWorkspace(AppAccessPolicy policy) {
  return housekeepingWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadHousekeeping(AppAccessPolicy policy) {
  return housekeepingWorkspaceReadRequirement.isAllowed(policy);
}

bool canManageHousekeeping(AppAccessPolicy policy) {
  return housekeepingWorkspaceManageRequirement.isAllowed(policy);
}

bool canWriteHousekeeping(AppAccessPolicy policy) {
  return canManageHousekeeping(policy);
}

bool canUpdateHousekeepingTasks(AppAccessPolicy policy) {
  return HousekeepingCapabilities.fromPolicy(policy).canUpdateTasks;
}

bool canReportHousekeeping(AppAccessPolicy policy) {
  return housekeepingWorkspaceReportRequirement.isAllowed(policy);
}

/// Per-section tab strip gate. Sections share workspace read until a tab
/// prompt documents a narrower requirement.
AccessRequirement housekeepingSectionTabRequirement(
  HousekeepingSection section,
) {
  return switch (section) {
    HousekeepingSection.tasks => HousekeepingTasksAtomPermissions.tab,
    HousekeepingSection.schedules => HousekeepingSchedulesAtomPermissions.tab,
    HousekeepingSection.maintenance =>
      HousekeepingMaintenanceRequestsAtomPermissions.tab,
  };
}

bool canViewHousekeepingSection(
  AppAccessPolicy policy,
  HousekeepingSection section,
) {
  return housekeepingSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the policy may show in the workspace tab strip.
List<HousekeepingSection> housekeepingAllowedSections(AppAccessPolicy policy) {
  return <HousekeepingSection>[
    for (final HousekeepingSection section in HousekeepingSection.values)
      if (canViewHousekeepingSection(policy, section)) section,
  ];
}

/// First authorized section (prefer tasks), or null when none are visible.
HousekeepingSection? housekeepingFallbackSection(AppAccessPolicy policy) {
  final List<HousekeepingSection> sections = housekeepingAllowedSections(policy);
  if (sections.isEmpty) {
    return null;
  }
  if (sections.contains(HousekeepingSection.tasks)) {
    return HousekeepingSection.tasks;
  }
  return sections.first;
}

/// Tasks tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Tasks tab | navigate | read ∩ `operations:read` |
/// | Create task (tab primary) | create | manage ∩ `operations:write` |
/// | Report summary | read | report ∪ `reports:read` \| `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | read ∩ / write ∩ |
/// | Row select → detail | read | read ∩ |
/// | Next action column chrome | progressive disclosure | read ∩ |
/// | Next action Assign | update | manage ∩ |
/// | Next action Start / Complete | update | source `canUpdateTasks` |
/// | Next action View details | navigate | read ∩ |
/// | Detail complementary Assign / Cancel | update / delete | manage ∩ |
/// | Detail complementary Start / Complete | update | source `canUpdateTasks` |
/// | Nested assign / cancel / create dialogs | create / update / delete | as above |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Matrix nested cross-module rows are _(n/a)_. Start / Complete keep source
/// `canUpdateTasks` (manage **or** housekeeper + read) rather than matrix
/// update ∩ `operations:write` alone — note mapping in tests. Assign / Cancel /
/// Create stay matrix write ∩ via [canManageHousekeeping].
abstract final class HousekeepingTasksAtomPermissions {
  static const AccessRequirement tab = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement search = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement filters = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement settings =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement empty = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement loading = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement retry = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement success =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement validation =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement rowSelect =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement detail = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement create = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement update = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement delete = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement write = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement manage = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement createTask =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement assign = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement cancel = housekeepingWorkspaceManageRequirement;
  /// Matrix update ∩ write; UI Start/Complete use source [canUpdateHousekeepingTasks].
  static const AccessRequirement updateTask =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement startTask =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement completeTask =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement report = housekeepingWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement nestedRead =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement entry = housekeepingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      housekeepingWorkspaceEntryRequirement;
}

/// Schedules tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Schedules tab | navigate | read ∩ `operations:read` |
/// | Create schedule (tab primary) | create | manage ∩ `operations:write` |
/// | Report summary | read | report ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading / validation | read chrome | read ∩ / write ∩ |
/// | Row select → detail | read | read ∩ |
/// | Next action Review schedule | navigate | read ∩ |
/// | Detail identity tiles (no schedule writes) | read | read ∩ |
/// | Nested create schedule dialog | create | manage ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Matrix nested cross-module rows are _(n/a)_. Schedules have no update/delete
/// UI atoms today; create/update/delete still map to manage ∩ for matrix
/// completeness. Create schedule stays matrix write ∩ (`canManage`) — unlike
/// Request maintenance, housekeeper + read alone does **not** unlock create.
/// Facility ABAC is enforced on route entry only (same pattern as biomedical /
/// Tasks); in-page atoms reuse module + permission. Report summary uses source
/// ∪ `reports:read` | `operations:read`.
abstract final class HousekeepingSchedulesAtomPermissions {
  static const AccessRequirement tab = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement search = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement filters = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement settings =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement empty = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement loading = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement retry = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement success =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement validation =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement rowSelect =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement detail = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement create = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement update = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement delete = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement write = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement manage = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement createSchedule =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement report = housekeepingWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement nestedRead =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement entry = housekeepingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      housekeepingWorkspaceEntryRequirement;
}

/// Maintenance requests tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Maintenance requests tab | navigate | read ∩ `operations:read` |
/// | Request maintenance (tab primary) | create | source `canUpdateTasks` (matrix create ∩ write — keep source) |
/// | Report summary | read | report ∪ `reports:read` \| `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading / validation | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Next action Triage | update | manage ∩ `operations:write` |
/// | Next action View details | navigate | read ∩ |
/// | Detail Complete request | update | manage ∩ |
/// | Detail Cancel request | delete | manage ∩ |
/// | Detail Triage (complementary; omitted when next-action) | update | manage ∩ |
/// | Nested triage / create / cancel-request dialogs | create / update / delete | as above |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Matrix nested cross-module rows are _(n/a)_. Request maintenance keeps
/// source `canUpdateTasks` (manage **or** housekeeper + read) rather than
/// matrix create ∩ `operations:write` alone — note mapping in tests.
/// Facility ABAC is enforced on route entry only (same pattern as biomedical /
/// Tasks tab); in-page atoms reuse module + permission.
abstract final class HousekeepingMaintenanceRequestsAtomPermissions {
  static const AccessRequirement tab = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement search = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement filters = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement settings =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement empty = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement loading = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement retry = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement success =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement validation =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement rowSelect =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement detail = housekeepingWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      housekeepingWorkspaceReadRequirement;
  /// Matrix create ∩ write; UI create primary uses source [canUpdateTasks].
  static const AccessRequirement create = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement update = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement delete = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement write = housekeepingWorkspaceManageRequirement;
  static const AccessRequirement manage = housekeepingWorkspaceManageRequirement;
  /// Alias for matrix create — tests note source Request maintenance gate.
  static const AccessRequirement requestMaintenance =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement triage =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement completeRequest =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement cancelRequest =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement report = housekeepingWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      housekeepingWorkspaceManageRequirement;
  static const AccessRequirement nestedRead =
      housekeepingWorkspaceReadRequirement;
  static const AccessRequirement entry = housekeepingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      housekeepingWorkspaceEntryRequirement;
}
