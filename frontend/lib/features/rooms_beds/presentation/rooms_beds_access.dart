import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';

/// Module entitlement for the Rooms & beds workspace route and sections.
const String roomsBedsInpatientBedManagementModule = 'inpatient-bed-management';

const List<AppRole> _roomsBedsAdminRoles = <AppRole>[
  AppRole.platformAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

/// View / read UI (matrix ∪): `clinical:read` | `operations:read` |
/// `facility:admin` + `inpatient-bed-management`.
const AccessRequirement roomsBedsWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.operationsRead,
    AppPermissions.facilityAdmin,
  ],
  activeModules: <String>[roomsBedsInpatientBedManagementModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement roomsBedsReadRequirement =
    roomsBedsWorkspaceReadRequirement;

/// Catalog shell entry — unique atom from [RouteAccessCatalog.roomsBeds]
/// (∩ `rooms_beds:read` + module + facility context).
///
/// Prompt / [AppRoutes.roomsBeds] route entry is the broader ∪ below; keep
/// catalog for shell menus / badges per RouteAccessCatalog contract.
const AccessRequirement roomsBedsWorkspaceEntryRequirement =
    RouteAccessCatalog.roomsBedsEntry;

/// Prompt / AppRoutes route-entry ∪: `clinical:read` | `operations:read` |
/// `tenant:admin` | `facility:admin` | `platform:admin` + module.
///
/// Matches [AppRoutes.roomsBeds] `requiredAnyPermissions`. Catalog entry stays
/// [roomsBedsWorkspaceEntryRequirement] (`rooms_beds:read`).
const AccessRequirement roomsBedsWorkspaceRouteUnionRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.operationsRead,
        AppPermissions.tenantAdmin,
        AppPermissions.facilityAdmin,
        AppPermissions.platformAdmin,
      ],
      activeModules: <String>[roomsBedsInpatientBedManagementModule],
    );

/// Alias matching historical / prompt "route entry" naming when AppRoutes ∪
/// is intended (not the catalog `rooms_beds:read` atom).
const AccessRequirement roomsBedsWorkspaceAppRouteRequirement =
    roomsBedsWorkspaceRouteUnionRequirement;

/// Bed admin create / update / delete (rooms, beds, status, catalog).
///
/// Matrix lists ∩ `unit:manage` alone; product narrative and existing
/// `_canAdminBeds` use ∪ `unit:manage` | elevated facility/tenant/system
/// admin (+ roles + inpatient module). ∩ `unit:manage` alone would pull the
/// `hr-rosters` plan domain via [PermissionModuleMap] and exclude facility
/// admins — keep source ∪ and note mapping in tests.
const AccessRequirement roomsBedsAdminRequirement = AccessRequirement(
  anyRoles: _roomsBedsAdminRoles,
  anyPermissions: <AppPermission>[
    AppPermissions.unitManage,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.platformAdmin,
  ],
  activeModules: <String>[roomsBedsInpatientBedManagementModule],
);

/// Matrix create / update / delete aliases — same source admin ∪ gate.
const AccessRequirement roomsBedsWorkspaceCreateRequirement =
    roomsBedsAdminRequirement;
const AccessRequirement roomsBedsWorkspaceUpdateRequirement =
    roomsBedsAdminRequirement;
const AccessRequirement roomsBedsWorkspaceDeleteRequirement =
    roomsBedsAdminRequirement;
const AccessRequirement roomsBedsManageRequirement = roomsBedsAdminRequirement;

/// Assign / release / transfer occupancy (existing bed gates).
///
/// Prompt: ∪ `clinical:write` | `operations:write`. Prior UI checked
/// `clinical:write` only — expand to the documented union + module.
const AccessRequirement roomsBedsOccupancyWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[roomsBedsInpatientBedManagementModule],
);

/// Alias for historical `canIpdWrite` naming on the board.
const AccessRequirement roomsBedsIpdWriteRequirement =
    roomsBedsOccupancyWriteRequirement;

/// Cross-module navigate (Open housekeeping / operations / IPD admission).
///
/// Nested cross-module matrix rows are _(n/a)_ — board readers who reach the
/// chrome may navigate; destination routes enforce their own gates.
const AccessRequirement roomsBedsNavigationRequirement = AccessRequirement();

/// Effective capabilities for Rooms & beds chrome.
final class RoomsBedsCapabilities {
  const RoomsBedsCapabilities({
    required this.canRead,
    required this.canAdminBeds,
    required this.canOccupancyWrite,
  });

  final bool canRead;
  final bool canAdminBeds;
  final bool canOccupancyWrite;

  /// Historical name used by next-action / detail call sites.
  bool get canIpdWrite => canOccupancyWrite;

  factory RoomsBedsCapabilities.fromPolicy(AppAccessPolicy policy) {
    return RoomsBedsCapabilities(
      canRead: canReadRoomsBeds(policy),
      canAdminBeds: canAdminRoomsBeds(policy),
      canOccupancyWrite: canWriteRoomsBedsOccupancy(policy),
    );
  }
}

bool canEnterRoomsBedsWorkspace(AppAccessPolicy policy) {
  return roomsBedsWorkspaceEntryRequirement.isAllowed(policy) ||
      roomsBedsWorkspaceRouteUnionRequirement.isAllowed(policy);
}

bool canReadRoomsBeds(AppAccessPolicy policy) {
  return roomsBedsWorkspaceReadRequirement.isAllowed(policy);
}

bool canAdminRoomsBeds(AppAccessPolicy policy) {
  return roomsBedsAdminRequirement.isAllowed(policy);
}

bool canWriteRoomsBedsOccupancy(AppAccessPolicy policy) {
  return roomsBedsOccupancyWriteRequirement.isAllowed(policy);
}

/// Per-section tab strip gate. Sections share workspace read until a tab
/// prompt documents a narrower requirement.
AccessRequirement roomsBedsSectionTabRequirement(RoomsBedsSection section) {
  return switch (section) {
    RoomsBedsSection.all => RoomsBedsAllBedsAtomPermissions.tab,
    RoomsBedsSection.available => RoomsBedsAvailableAtomPermissions.tab,
    RoomsBedsSection.occupied => RoomsBedsOccupiedAtomPermissions.tab,
    RoomsBedsSection.turnover => RoomsBedsTurnoverAtomPermissions.tab,
    RoomsBedsSection.outOfService => RoomsBedsOutOfServiceAtomPermissions.tab,
  };
}

bool canViewRoomsBedsSection(AppAccessPolicy policy, RoomsBedsSection section) {
  return roomsBedsSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the policy may show in the workspace tab strip.
List<RoomsBedsSection> roomsBedsAllowedSections(AppAccessPolicy policy) {
  return <RoomsBedsSection>[
    for (final RoomsBedsSection section in RoomsBedsSection.values)
      if (canViewRoomsBedsSection(policy, section)) section,
  ];
}

/// First authorized section (prefer All beds), or null when none are visible.
RoomsBedsSection? roomsBedsFallbackSection(AppAccessPolicy policy) {
  final List<RoomsBedsSection> sections = roomsBedsAllowedSections(policy);
  if (sections.isEmpty) {
    return null;
  }
  if (sections.contains(RoomsBedsSection.all)) {
    return RoomsBedsSection.all;
  }
  return sections.first;
}

/// All beds tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All beds tab | navigate | read ∪ clinical\|operations\|facility:admin |
/// | Create room / bed / Manage catalog | create | _(n/a)_ workspace — Tenant setup → Facility |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Status filter (All beds only) | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / form validation | feedback | occupancy write ∪ / admin ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Assign / Release / Complete transfer | update | occupancy write ∪ |
/// | Next action Mark available | update | admin ∪ |
/// | Next action Open housekeeping / operations | navigate | _(n/a)_ board readers |
/// | Detail status mutations (reserve/clean/…) | update | admin ∪ |
/// | Detail Assign / Release / Transfer / Manage transfer | update | occupancy write ∪ |
/// | Detail Open IPD admission | navigate | _(n/a)_ |
/// | Nested assign / release / transfer dialogs | update | occupancy write ∪ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (catalog) | navigate | catalog ∩ rooms_beds:read |
/// | Route entry (AppRoutes ∪) | navigate | clinical\|operations\|admins |
///
/// Matrix create ∩ `unit:manage` alone maps to source admin ∪ (see
/// [roomsBedsAdminRequirement]). Occupancy expands prior clinical-only check
/// to ∪ clinical\|operations write.
abstract final class RoomsBedsAllBedsAtomPermissions {
  static const AccessRequirement tab = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement search = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement filters = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement columns = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement settings = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement pagination = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement empty = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement loading = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement retry = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement success = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement validation =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement rowSelect = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement detail = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement nextAction = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement create = roomsBedsAdminRequirement;
  static const AccessRequirement update = roomsBedsAdminRequirement;
  static const AccessRequirement delete = roomsBedsAdminRequirement;
  static const AccessRequirement write = roomsBedsAdminRequirement;
  static const AccessRequirement manage = roomsBedsAdminRequirement;
  static const AccessRequirement createRoom = roomsBedsAdminRequirement;
  static const AccessRequirement createBed = roomsBedsAdminRequirement;
  static const AccessRequirement manageCatalog = roomsBedsAdminRequirement;
  static const AccessRequirement updateBedStatus = roomsBedsAdminRequirement;
  static const AccessRequirement markAvailable = roomsBedsAdminRequirement;
  static const AccessRequirement assign = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement release = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement transfer = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement completeTransfer =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement occupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement navigateCrossModule =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openOperations =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openHousekeeping =
      roomsBedsNavigationRequirement;
  static const AccessRequirement nestedWrite = roomsBedsAdminRequirement;
  static const AccessRequirement nestedOccupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement nestedRead = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement entry = roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeUnion =
      roomsBedsWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.roomsBedsEntry;
}

/// Available tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Available tab | navigate | read ∪ clinical\|operations\|facility:admin |
/// | Create room / bed / Manage catalog | create | _(n/a)_ workspace — Tenant setup → Facility |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / form validation | feedback | occupancy write ∪ / admin ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Assign | update | occupancy write ∪ |
/// | Detail Reserve / status mutations | update | admin ∪ |
/// | Detail Assign (when not board twin) | update | occupancy write ∪ |
/// | Detail Open IPD admission | navigate | _(n/a)_ when admission linked |
/// | Detail Open housekeeping / operations | navigate | _(n/a)_ under admin chrome |
/// | Nested assign dialog | update | occupancy write ∪ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (catalog) | navigate | catalog ∩ rooms_beds:read + facility ABAC |
/// | Route entry (AppRoutes ∪) | navigate | clinical\|operations\|admins |
///
/// Matrix create ∩ `unit:manage` alone maps to source admin ∪ (see
/// [roomsBedsAdminRequirement]). Occupancy is ∪ clinical\|operations write.
/// Never show admin create to clinical-read-only.
abstract final class RoomsBedsAvailableAtomPermissions {
  static const AccessRequirement tab = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement search = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement filters = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement columns = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement settings = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement pagination = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement empty = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement loading = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement retry = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement success = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement validation =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement rowSelect = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement detail = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement create = roomsBedsAdminRequirement;
  static const AccessRequirement update = roomsBedsAdminRequirement;
  static const AccessRequirement delete = roomsBedsAdminRequirement;
  static const AccessRequirement write = roomsBedsAdminRequirement;
  static const AccessRequirement manage = roomsBedsAdminRequirement;
  static const AccessRequirement createRoom = roomsBedsAdminRequirement;
  static const AccessRequirement createBed = roomsBedsAdminRequirement;
  static const AccessRequirement manageCatalog = roomsBedsAdminRequirement;
  static const AccessRequirement updateBedStatus = roomsBedsAdminRequirement;
  static const AccessRequirement markAvailable = roomsBedsAdminRequirement;
  static const AccessRequirement assign = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement release = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement transfer = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement completeTransfer =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement occupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement navigateCrossModule =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openOperations =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openHousekeeping =
      roomsBedsNavigationRequirement;
  static const AccessRequirement nestedWrite = roomsBedsAdminRequirement;
  static const AccessRequirement nestedOccupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement nestedRead = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement entry = roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeUnion =
      roomsBedsWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.roomsBedsEntry;
}

/// Occupied tab atom → permission mapping (inventory + matrix).
///
/// Target: `/rooms-beds?section=occupied`. Release / transfer for occupancy
/// writers; bed-admin create room/bed is not a strip primary on this tab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Occupied tab | navigate | read ∪ clinical\|operations\|facility:admin |
/// | Tab primary / Create / Manage catalog | — | _(n/a)_ workspace — Tenant setup → Facility |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / form validation | feedback | occupancy write ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Release | update | occupancy write ∪ |
/// | Next action Manage / complete transfer | update | occupancy write ∪ |
/// | Next action column | progressive disclosure | occupancy write ∪ |
/// | Next action Assign / Mark available | update | occupancy write ∪ / admin ∪ (not primary on occupied) |
/// | Detail info / assignment history | read | read ∪ |
/// | Detail Open IPD admission | navigate | _(n/a)_ board readers |
/// | Detail Release / Request transfer / Manage transfer | update | occupancy write ∪ |
/// | Detail Assign / status mutations | update | occupancy write ∪ / admin ∪ |
/// | Nested release / transfer dialogs | update | occupancy write ∪ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (catalog) | navigate | catalog ∩ rooms_beds:read |
/// | Route entry (AppRoutes ∪) | navigate | clinical\|operations\|admins |
///
/// Matrix create/update/delete ∩ `unit:manage` alone maps to source admin ∪
/// ([roomsBedsAdminRequirement]). Occupancy write is ∪ `clinical:write` |
/// `operations:write` + module. Never show admin create to clinical-read-only.
abstract final class RoomsBedsOccupiedAtomPermissions {
  static const AccessRequirement tab = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement search = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement filters = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement columns = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement settings = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement pagination = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement empty = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement loading = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement retry = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement success = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement validation =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement rowSelect = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement detail = roomsBedsWorkspaceReadRequirement;
  /// Occupied primary next-actions are Release / complete transfer only.
  static const AccessRequirement nextAction =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement create = roomsBedsAdminRequirement;
  static const AccessRequirement update = roomsBedsAdminRequirement;
  static const AccessRequirement delete = roomsBedsAdminRequirement;
  static const AccessRequirement write = roomsBedsAdminRequirement;
  static const AccessRequirement manage = roomsBedsAdminRequirement;
  static const AccessRequirement createRoom = roomsBedsAdminRequirement;
  static const AccessRequirement createBed = roomsBedsAdminRequirement;
  static const AccessRequirement manageCatalog = roomsBedsAdminRequirement;
  static const AccessRequirement updateBedStatus = roomsBedsAdminRequirement;
  static const AccessRequirement assign = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement release = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement transfer = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement completeTransfer =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement occupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement navigateCrossModule =
      roomsBedsNavigationRequirement;
  static const AccessRequirement nestedWrite = roomsBedsAdminRequirement;
  static const AccessRequirement nestedOccupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement nestedRead = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement entry = roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeUnion =
      roomsBedsWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.roomsBedsEntry;
}

/// Turnover tab atom → permission mapping (inventory + matrix).
///
/// Target: `/rooms-beds?section=turnover`. Housekeeping turnover
/// (reserved / cleaning / maintenance). operations:write may apply via
/// occupancy write ∪; bed status mutations use admin ∪.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Turnover tab | navigate | read ∪ clinical\|operations\|facility:admin |
/// | Tab primary / Create / Manage catalog | — | _(n/a)_ workspace — Tenant setup → Facility |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / form validation | feedback | admin ∪ / occupancy write ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Mark available (reserved/cleaning) | update | admin ∪ |
/// | Next action Open operations (maintenance) | navigate | _(n/a)_ board readers |
/// | Detail info / assignment history | read | read ∪ |
/// | Detail status mutations (available/clean/maintain/block) | update | admin ∪ |
/// | Detail Assign / Release / Transfer | update | occupancy write ∪ |
/// | Detail Open housekeeping / operations | navigate | admin chrome (existing) |
/// | Nested occupancy dialogs | update | occupancy write ∪ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (catalog) | navigate | catalog ∩ rooms_beds:read |
/// | Route entry (AppRoutes ∪) | navigate | clinical\|operations\|admins |
///
/// Matrix create/update/delete ∩ `unit:manage` alone maps to source admin ∪
/// ([roomsBedsAdminRequirement]). Occupancy write is ∪ `clinical:write` |
/// `operations:write` + module. Never show admin create to clinical-read-only.
abstract final class RoomsBedsTurnoverAtomPermissions {
  static const AccessRequirement tab = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement search = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement filters = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement columns = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement settings = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement pagination = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement empty = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement loading = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement retry = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement success = roomsBedsAdminRequirement;
  static const AccessRequirement validation = roomsBedsAdminRequirement;
  static const AccessRequirement rowSelect = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement detail = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement nextAction = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement create = roomsBedsAdminRequirement;
  static const AccessRequirement update = roomsBedsAdminRequirement;
  static const AccessRequirement delete = roomsBedsAdminRequirement;
  static const AccessRequirement write = roomsBedsAdminRequirement;
  static const AccessRequirement manage = roomsBedsAdminRequirement;
  static const AccessRequirement createRoom = roomsBedsAdminRequirement;
  static const AccessRequirement createBed = roomsBedsAdminRequirement;
  static const AccessRequirement manageCatalog = roomsBedsAdminRequirement;
  static const AccessRequirement updateBedStatus = roomsBedsAdminRequirement;
  static const AccessRequirement markAvailable = roomsBedsAdminRequirement;
  static const AccessRequirement assign = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement release = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement transfer = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement completeTransfer =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement occupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement navigateCrossModule =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openOperations =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openHousekeeping =
      roomsBedsNavigationRequirement;
  static const AccessRequirement nestedWrite = roomsBedsAdminRequirement;
  static const AccessRequirement nestedOccupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement nestedRead = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement entry = roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeUnion =
      roomsBedsWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.roomsBedsEntry;
}

/// Out of service tab atom → permission mapping (inventory + matrix).
///
/// Target: `/rooms-beds?section=out-of-service`. Mark in/out of service and
/// status resolution need bed admin (manage/write); strip has no create
/// primary.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Out of service tab | navigate | read ∪ clinical\|operations\|facility:admin |
/// | Tab primary / Create / Manage catalog | — | _(n/a)_ workspace — Tenant setup → Facility |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / form validation | feedback | admin ∪ / occupancy write ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Mark available (blocked) | update | admin ∪ |
/// | Next action Open operations (outOfService) | navigate | _(n/a)_ board readers |
/// | Detail info / assignment history | read | read ∪ |
/// | Detail Open IPD admission | navigate | _(n/a)_ when admission linked |
/// | Detail Mark available / cleaning / maintenance / blocked | update | admin ∪ |
/// | Detail Open housekeeping / operations | navigate | _(n/a)_ under admin chrome |
/// | Detail Assign / Release / Transfer | update | occupancy write ∪ |
/// | Nested status update (mark available) | update | admin ∪ |
/// | Nested assign / release / transfer dialogs | update | occupancy write ∪ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (catalog) | navigate | catalog ∩ rooms_beds:read |
/// | Route entry (AppRoutes ∪) | navigate | clinical\|operations\|admins |
///
/// Matrix create/update/delete ∩ `unit:manage` alone maps to source admin ∪
/// ([roomsBedsAdminRequirement]). Never show admin create/manage to
/// clinical-read-only. Occupancy write is ∪ `clinical:write` |
/// `operations:write` + module.
abstract final class RoomsBedsOutOfServiceAtomPermissions {
  static const AccessRequirement tab = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement search = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement filters = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement columns = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement settings = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement pagination = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement empty = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement loading = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement retry = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement success = roomsBedsAdminRequirement;
  static const AccessRequirement validation = roomsBedsAdminRequirement;
  static const AccessRequirement rowSelect = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement detail = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement nextAction = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement create = roomsBedsAdminRequirement;
  static const AccessRequirement update = roomsBedsAdminRequirement;
  static const AccessRequirement delete = roomsBedsAdminRequirement;
  static const AccessRequirement write = roomsBedsAdminRequirement;
  static const AccessRequirement manage = roomsBedsAdminRequirement;
  static const AccessRequirement createRoom = roomsBedsAdminRequirement;
  static const AccessRequirement createBed = roomsBedsAdminRequirement;
  static const AccessRequirement manageCatalog = roomsBedsAdminRequirement;
  static const AccessRequirement updateBedStatus = roomsBedsAdminRequirement;
  static const AccessRequirement markAvailable = roomsBedsAdminRequirement;
  static const AccessRequirement markOutOfService = roomsBedsAdminRequirement;
  static const AccessRequirement assign = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement release = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement transfer = roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement completeTransfer =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement occupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement navigateCrossModule =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openOperations =
      roomsBedsNavigationRequirement;
  static const AccessRequirement openHousekeeping =
      roomsBedsNavigationRequirement;
  static const AccessRequirement nestedWrite = roomsBedsAdminRequirement;
  static const AccessRequirement nestedOccupancyWrite =
      roomsBedsOccupancyWriteRequirement;
  static const AccessRequirement nestedRead = roomsBedsWorkspaceReadRequirement;
  static const AccessRequirement entry = roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      roomsBedsWorkspaceEntryRequirement;
  static const AccessRequirement routeUnion =
      roomsBedsWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry =
      RouteAccessCatalog.roomsBedsEntry;
}
