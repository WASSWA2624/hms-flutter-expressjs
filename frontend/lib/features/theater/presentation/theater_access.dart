import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/operations/presentation/operations_access.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_next_action.dart';

/// Module entitlement for the Theater workspace route and board tabs.
const String theaterTheatreAnesthesiaModule = 'theatre-anesthesia';

/// View / read UI (matrix ∪): `clinical:read` | `patient:read` + module.
///
/// Billing / operations alone may satisfy [theaterWorkspaceRouteUnionRequirement]
/// via AppRoutes, but All cases / Follow-ups / board chrome still requires this ∪.
const AccessRequirement theaterWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
  ],
  activeModules: <String>[theaterTheatreAnesthesiaModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement theaterReadRequirement = theaterWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.theater]
/// (∩ `theater:read` + `theatre-anesthesia`).
///
/// Prompt / AppRoutes also list ∪ `patient:read` | `clinical:read` |
/// `billing:read` | `operations:read`; catalog keeps the unique `theater:read`
/// key so other modules cannot leak into Theater — keep source.
const AccessRequirement theaterWorkspaceEntryRequirement =
    RouteAccessCatalog.theaterEntry;

/// Prompt / AppRoutes route-entry ∪ (`patient:read` | `clinical:read` |
/// `billing:read` | `operations:read`). Shell gate remains
/// [theaterWorkspaceEntryRequirement] (`theater:read`) for unique destination
/// isolation.
const AccessRequirement theaterWorkspaceRouteUnionRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.billingRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>[theaterTheatreAnesthesiaModule],
    );

/// Alias for AppRoutes ∪ call sites / All-cases tests.
const AccessRequirement theaterWorkspaceAppRoutesEntryRequirement =
    theaterWorkspaceRouteUnionRequirement;

/// Alias for historical / catalog call sites.
const AccessRequirement theaterWorkspaceRouteEntryRequirement =
    theaterWorkspaceEntryRequirement;

/// Matrix create / update / delete ∩ `clinical:write` + module.
///
/// Schedule case / stage updates use this theater write gate. Plan also
/// requires `encounters-vitals` via [PermissionModuleMap] for `clinical:write`.
/// Aligns with patient-registry schedule create (clinical:write + module).
const AccessRequirement theaterClinicalWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[theaterTheatreAnesthesiaModule],
);

/// Alias matching matrix create/update/delete when clinical ∩ is intended.
const AccessRequirement theaterWriteRequirement = theaterClinicalWriteRequirement;

/// Alias for workspace write when clinical ∩ is the verb.
const AccessRequirement theaterWorkspaceWriteRequirement =
    theaterClinicalWriteRequirement;

/// Delete / cancel — matrix ∩ `clinical:write` (no dedicated delete key).
const AccessRequirement theaterWorkspaceDeleteRequirement =
    theaterClinicalWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement theaterDeleteRequirement =
    theaterWorkspaceDeleteRequirement;

/// Navigation chrome (Open IPD / Open Emergency) — no write.
const AccessRequirement theaterNavigationRequirement = AccessRequirement();

/// Follow-ups tab / panel read (matrix ∪): `clinical:read` | `patient:read`.
///
/// Shared [FollowUpWorklistPanel] defaults to reception ∪; Theater overrides
/// with this requirement (see Follow-ups tab permission scan).
const AccessRequirement theaterFollowUpsRequirement =
    theaterWorkspaceReadRequirement;

/// Follow-ups complete / reschedule / delete — matrix ∩ `clinical:write`.
const AccessRequirement theaterFollowUpsWriteRequirement =
    theaterClinicalWriteRequirement;

/// Schedule-form billing holds / charge panel (prompt: billing holds need
/// `billing:read`). Reuses [billingReadRequirement]
/// (`billing:read` ∩ `billing-payments`).
const AccessRequirement theaterBillingHoldReadRequirement =
    billingReadRequirement;

/// Room / asset operations context (prompt: may need `operations:read`).
///
/// Reuses [operationsReadRequirement]. All-cases room column / room filter
/// stay on workspace read (core OR assignment); this gate documents nested
/// operations context atoms.
const AccessRequirement theaterRoomContextReadRequirement =
    operationsReadRequirement;

/// Alias matching Follow-ups narrative naming.
const AccessRequirement theaterOperationsReadRequirement =
    theaterRoomContextReadRequirement;

/// Schedule case primary — matrix ∩ `clinical:write`.
const AccessRequirement theaterScheduleCaseRequirement =
    theaterClinicalWriteRequirement;

/// Per-section tab strip gate.
///
/// All / In theater / Follow-ups use matrix read ∪. Scheduled / Recovery are
/// not yet permission-scanned — keep visible once the route is entered
/// (`AccessRequirement()`).
AccessRequirement theaterBoardTabRequirement(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.tab,
    TheaterSection.inTheater => TheaterInTheaterAtomPermissions.tab,
    TheaterSection.followUps => TheaterFollowUpsAtomPermissions.tab,
    TheaterSection.scheduled ||
    TheaterSection.recovery => const AccessRequirement(),
  };
}

/// Alias used by Follow-ups / shared call sites.
AccessRequirement theaterSectionTabRequirement(TheaterSection section) {
  return theaterBoardTabRequirement(section);
}

bool canViewTheaterTab(AppAccessPolicy policy, TheaterSection section) {
  return theaterBoardTabRequirement(section).isAllowed(policy);
}

bool canViewTheaterAll(AppAccessPolicy policy) {
  return TheaterAllAtomPermissions.tab.isAllowed(policy);
}

bool canViewTheaterInTheater(AppAccessPolicy policy) {
  return TheaterInTheaterAtomPermissions.tab.isAllowed(policy);
}

bool canReadTheaterInTheater(AppAccessPolicy policy) {
  return TheaterInTheaterAtomPermissions.tab.isAllowed(policy);
}

bool canWriteTheaterInTheater(AppAccessPolicy policy) {
  return TheaterInTheaterAtomPermissions.write.isAllowed(policy);
}

bool canViewTheaterFollowUps(AppAccessPolicy policy) {
  return TheaterFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadTheaterFollowUps(AppAccessPolicy policy) {
  return theaterFollowUpsRequirement.isAllowed(policy);
}

bool canWriteTheaterFollowUps(AppAccessPolicy policy) {
  return theaterFollowUpsWriteRequirement.isAllowed(policy);
}

bool canReadTheater(AppAccessPolicy policy) {
  return theaterWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteTheater(AppAccessPolicy policy) {
  return theaterClinicalWriteRequirement.isAllowed(policy);
}

bool canWriteTheaterClinical(AppAccessPolicy policy) {
  return theaterClinicalWriteRequirement.isAllowed(policy);
}

bool canDeleteTheater(AppAccessPolicy policy) {
  return theaterWorkspaceDeleteRequirement.isAllowed(policy);
}

bool canScheduleTheaterCase(AppAccessPolicy policy) {
  return theaterScheduleCaseRequirement.isAllowed(policy);
}

bool canEnterTheaterWorkspace(AppAccessPolicy policy) {
  return theaterWorkspaceEntryRequirement.isAllowed(policy);
}

bool canEnterTheaterViaAppRoutes(AppAccessPolicy policy) {
  return theaterWorkspaceRouteUnionRequirement.isAllowed(policy);
}

bool canViewTheaterBillingHolds(AppAccessPolicy policy) {
  return theaterBillingHoldReadRequirement.isAllowed(policy);
}

bool canViewTheaterRoomContext(AppAccessPolicy policy) {
  return theaterRoomContextReadRequirement.isAllowed(policy);
}

List<TheaterSection> theaterAllowedSections(AppAccessPolicy policy) {
  return TheaterSection.values
      .where((TheaterSection section) => canViewTheaterTab(policy, section))
      .toList(growable: false);
}

/// Alias used by All-cases call sites.
List<TheaterSection> theaterAllowedBoardSections(AppAccessPolicy policy) {
  return theaterAllowedSections(policy);
}

TheaterSection? theaterFallbackSection(AppAccessPolicy policy) {
  final List<TheaterSection> allowed = theaterAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(TheaterSection.all)) {
    return TheaterSection.all;
  }
  if (allowed.contains(TheaterSection.scheduled)) {
    return TheaterSection.scheduled;
  }
  return allowed.first;
}

/// Write ∩ for the active board section.
AccessRequirement theaterWriteRequirementForSection(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.write,
    TheaterSection.inTheater => TheaterInTheaterAtomPermissions.write,
    TheaterSection.followUps => TheaterFollowUpsAtomPermissions.write,
    TheaterSection.scheduled ||
    TheaterSection.recovery => theaterClinicalWriteRequirement,
  };
}

/// Detail read for the active board section.
AccessRequirement theaterDetailReadRequirement(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.detail,
    TheaterSection.inTheater => TheaterInTheaterAtomPermissions.detail,
    TheaterSection.followUps => TheaterFollowUpsAtomPermissions.detail,
    TheaterSection.scheduled ||
    TheaterSection.recovery => theaterWorkspaceReadRequirement,
  };
}

/// Whether the Next action column mounts for [section].
///
/// In theater / All-cases next-actions are write ∩ only — omit the column for
/// read-only users so mutation affordances do not mount. Follow-ups has no row
/// next-action. Unscanned tabs keep write ∩ gating for next-action chrome.
bool theaterBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  TheaterSection section,
) {
  if (section.isFollowUps) {
    return false;
  }
  if (!canViewTheaterTab(policy, section)) {
    return false;
  }
  return theaterWriteRequirementForSection(section).isAllowed(policy);
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement theaterFocusedPanelRequirement(TheaterDetailPanel panel) {
  return switch (panel) {
    TheaterDetailPanel.checklist ||
    TheaterDetailPanel.anesthesia ||
    TheaterDetailPanel.postop ||
    TheaterDetailPanel.resources => theaterClinicalWriteRequirement,
  };
}

/// Whether AppRoutes theater any-of keys match
/// [theaterWorkspaceRouteUnionRequirement].
bool theaterRouteEntryMatchesAppRoutes() {
  final Set<AppPermission> routeKeys = AppRoutes.theater.requiredAnyPermissions
      .toSet();
  final Set<AppPermission> atomKeys =
      theaterWorkspaceRouteUnionRequirement.anyPermissions.toSet();
  return routeKeys.containsAll(atomKeys) && atomKeys.containsAll(routeKeys);
}

/// Alias used by All-cases tests.
bool theaterAppRoutesEntryMatchesAppRoutes() {
  return theaterRouteEntryMatchesAppRoutes();
}

/// Requirement for a resolved next-action kind (board write ∩).
AccessRequirement theaterNextActionRequirement(TheaterNextActionKind kind) {
  return switch (kind) {
    TheaterNextActionKind.updateReadiness =>
      TheaterAllAtomPermissions.nextActionUpdateReadiness,
    TheaterNextActionKind.startCase =>
      TheaterAllAtomPermissions.nextActionStartCase,
    TheaterNextActionKind.anesthesia =>
      TheaterAllAtomPermissions.nextActionAnesthesia,
    TheaterNextActionKind.postOp => TheaterAllAtomPermissions.nextActionPostOp,
    TheaterNextActionKind.handover =>
      TheaterAllAtomPermissions.nextActionHandover,
  };
}

/// All cases tab atom → permission mapping (inventory + matrix).
///
/// Unfiltered cases (`/theater` or `?section=all`). Schedule / stage / cancel
/// need matrix ∩ `clinical:write` + `theatre-anesthesia`. Nested cross-module
/// matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse theater
/// write/read only. Billing holds on schedule form need [billingHolds]
/// (`billing:read`). Room/asset operations context documents [roomContext]
/// (`operations:read`); core room column/filter stay on workspace read.
/// Route entry keeps catalog ∩ `theater:read` ([catalogEntry]); AppRoutes ∪
/// is [routeEntryUnion] / [appRoutesEntry]. Tab chrome stays ∪ `clinical:read`
/// | `patient:read`. Open IPD / Open Emergency remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All cases tab / count badge | navigate | read ∪ ([tab]) |
/// | Schedule case (toolbar) | create | write ∩ ([scheduleCase]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Status / stage filters (All only) | read chrome | ([filters]) |
/// | Room / surgeon / anesthetist filters | read chrome | ([filters]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → case detail | read | ([detail]) |
/// | Next action readiness / start / anesthesia / post-op / handover | update | write ∩ |
/// | Detail complementary writes (reschedule, stage, resource, cancel, …) | create / update / delete | write ∩ |
/// | Detail Open IPD / Open Emergency | navigate | [navigation] |
/// | Schedule billing holds panel | nested read | ([billingHolds]) |
/// | Nested mutation dialogs / `panel=` deep link | create / update | write ∩ ([panelDeepLink]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — cancel uses update |
/// | Route entry (catalog) | navigate | ∩ theater:read ([catalogEntry]) |
/// | Route entry (AppRoutes) | navigate | ∪ patient\|clinical\|billing\|operations:read ([appRoutesEntry]) |
abstract final class TheaterAllAtomPermissions {
  static const AccessRequirement tab = theaterWorkspaceReadRequirement;
  static const AccessRequirement followUpsTab = theaterFollowUpsRequirement;
  static const AccessRequirement listChrome = theaterWorkspaceReadRequirement;
  static const AccessRequirement search = theaterWorkspaceReadRequirement;
  static const AccessRequirement filters = theaterWorkspaceReadRequirement;
  static const AccessRequirement settings = theaterWorkspaceReadRequirement;
  static const AccessRequirement empty = theaterWorkspaceReadRequirement;
  static const AccessRequirement loading = theaterWorkspaceReadRequirement;
  static const AccessRequirement retry = theaterWorkspaceReadRequirement;
  static const AccessRequirement success = theaterClinicalWriteRequirement;
  static const AccessRequirement validation = theaterClinicalWriteRequirement;
  static const AccessRequirement rowSelect = theaterWorkspaceReadRequirement;
  static const AccessRequirement detail = theaterWorkspaceReadRequirement;
  static const AccessRequirement create = theaterClinicalWriteRequirement;
  static const AccessRequirement update = theaterClinicalWriteRequirement;
  static const AccessRequirement delete = theaterWorkspaceDeleteRequirement;
  static const AccessRequirement write = theaterClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = theaterClinicalWriteRequirement;
  static const AccessRequirement scheduleCase = theaterScheduleCaseRequirement;
  static const AccessRequirement nextAction = theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionUpdateReadiness =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionStartCase =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionAnesthesia =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionPostOp =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionHandover =
      theaterClinicalWriteRequirement;
  static const AccessRequirement reschedule = theaterClinicalWriteRequirement;
  static const AccessRequirement updateStage = theaterClinicalWriteRequirement;
  static const AccessRequirement assignResource =
      theaterClinicalWriteRequirement;
  static const AccessRequirement updateReadiness =
      theaterClinicalWriteRequirement;
  static const AccessRequirement anesthesia = theaterClinicalWriteRequirement;
  static const AccessRequirement postOp = theaterClinicalWriteRequirement;
  static const AccessRequirement handover = theaterClinicalWriteRequirement;
  static const AccessRequirement finalize = theaterClinicalWriteRequirement;
  static const AccessRequirement cancelCase = theaterClinicalWriteRequirement;
  static const AccessRequirement billingHolds =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement scheduleBilling =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement billingHold = theaterBillingHoldReadRequirement;
  static const AccessRequirement roomContext =
      theaterRoomContextReadRequirement;
  static const AccessRequirement operationsRead =
      theaterOperationsReadRequirement;
  static const AccessRequirement roomColumn = theaterWorkspaceReadRequirement;
  static const AccessRequirement roomFilter = theaterWorkspaceReadRequirement;
  static const AccessRequirement navigation = theaterNavigationRequirement;
  static const AccessRequirement openIpd = theaterNavigationRequirement;
  static const AccessRequirement openEmergency = theaterNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses theater write/read only.
  static const AccessRequirement nestedWrite = theaterClinicalWriteRequirement;
  static const AccessRequirement nestedRead = theaterWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      theaterClinicalWriteRequirement;
  static const AccessRequirement entry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.theaterEntry;
  static const AccessRequirement appRoutesEntry =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement read = theaterWorkspaceReadRequirement;
}

/// In theater tab atom → permission mapping (inventory + matrix).
///
/// Intra-op board (`/theater?section=in-theater`). Schedule / stage / anesthesia
/// / post-op / handover / cancel need matrix ∩ `clinical:write` +
/// `theatre-anesthesia`. Nested cross-module matrix rows are _(n/a)_ —
/// [nestedWrite] / [nestedRead] reuse theater write/read only. Billing holds
/// on schedule form need [billingHolds] (`billing:read`). Room/asset operations
/// context documents [roomContext] (`operations:read`); core room column /
/// room filter stay on workspace read. Route entry keeps catalog ∩
/// `theater:read` ([catalogEntry]); AppRoutes ∪ is [routeEntryUnion]. Tab
/// chrome stays ∪ `clinical:read` | `patient:read`. Open IPD / Open Emergency
/// remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | In theater tab / count badge | navigate | read ∪ ([tab]) |
/// | Schedule case (toolbar) | create | write ∩ ([scheduleCase]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Room / surgeon / anesthetist filters | read chrome | ([filters]) |
/// | Room column (default) | read | ([roomColumn]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → case detail | read | ([detail]) |
/// | Next action anesthesia / post-op / handover / readiness | update | write ∩ |
/// | Detail complementary writes (reschedule, stage, resource, cancel, …) | create / update / delete | write ∩ |
/// | Detail Open IPD / Open Emergency | navigate | [navigation] |
/// | Schedule billing holds panel | nested read | ([billingHolds]) |
/// | Nested mutation dialogs / `panel=` deep link | create / update | write ∩ ([panelDeepLink]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — cancel uses update |
/// | Route entry (catalog) | navigate | ∩ theater:read ([catalogEntry]) |
/// | Route entry (AppRoutes) | navigate | ∪ patient\|clinical\|billing\|operations:read ([appRoutesEntry]) |
abstract final class TheaterInTheaterAtomPermissions {
  static const AccessRequirement tab = theaterWorkspaceReadRequirement;
  static const AccessRequirement listChrome = theaterWorkspaceReadRequirement;
  static const AccessRequirement search = theaterWorkspaceReadRequirement;
  static const AccessRequirement filters = theaterWorkspaceReadRequirement;
  static const AccessRequirement settings = theaterWorkspaceReadRequirement;
  static const AccessRequirement empty = theaterWorkspaceReadRequirement;
  static const AccessRequirement loading = theaterWorkspaceReadRequirement;
  static const AccessRequirement retry = theaterWorkspaceReadRequirement;
  static const AccessRequirement success = theaterClinicalWriteRequirement;
  static const AccessRequirement validation = theaterClinicalWriteRequirement;
  static const AccessRequirement rowSelect = theaterWorkspaceReadRequirement;
  static const AccessRequirement detail = theaterWorkspaceReadRequirement;
  static const AccessRequirement create = theaterClinicalWriteRequirement;
  static const AccessRequirement update = theaterClinicalWriteRequirement;
  static const AccessRequirement delete = theaterWorkspaceDeleteRequirement;
  static const AccessRequirement write = theaterClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = theaterClinicalWriteRequirement;
  static const AccessRequirement scheduleCase = theaterScheduleCaseRequirement;
  static const AccessRequirement nextAction = theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionUpdateReadiness =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionStartCase =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionAnesthesia =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionPostOp =
      theaterClinicalWriteRequirement;
  static const AccessRequirement nextActionHandover =
      theaterClinicalWriteRequirement;
  static const AccessRequirement reschedule = theaterClinicalWriteRequirement;
  static const AccessRequirement updateStage = theaterClinicalWriteRequirement;
  static const AccessRequirement assignResource =
      theaterClinicalWriteRequirement;
  static const AccessRequirement updateReadiness =
      theaterClinicalWriteRequirement;
  static const AccessRequirement anesthesia = theaterClinicalWriteRequirement;
  static const AccessRequirement postOp = theaterClinicalWriteRequirement;
  static const AccessRequirement handover = theaterClinicalWriteRequirement;
  static const AccessRequirement finalize = theaterClinicalWriteRequirement;
  static const AccessRequirement cancelCase = theaterClinicalWriteRequirement;
  static const AccessRequirement billingHolds =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement scheduleBilling =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement billingHold = theaterBillingHoldReadRequirement;
  static const AccessRequirement roomContext =
      theaterRoomContextReadRequirement;
  static const AccessRequirement operationsRead =
      theaterOperationsReadRequirement;
  static const AccessRequirement roomColumn = theaterWorkspaceReadRequirement;
  static const AccessRequirement roomFilter = theaterWorkspaceReadRequirement;
  static const AccessRequirement navigation = theaterNavigationRequirement;
  static const AccessRequirement openIpd = theaterNavigationRequirement;
  static const AccessRequirement openEmergency = theaterNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses theater write/read only.
  static const AccessRequirement nestedWrite = theaterClinicalWriteRequirement;
  static const AccessRequirement nestedRead = theaterWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      theaterClinicalWriteRequirement;
  static const AccessRequirement entry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.theaterEntry;
  static const AccessRequirement appRoutesEntry =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement read = theaterWorkspaceReadRequirement;
}

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Theater Follow-ups (`/theater?section=follow-ups`) hosts shared
/// [FollowUpWorklistPanel] with Theater read/write overrides. Nested
/// cross-module matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse
/// Theater write ∩ / read ∪ only. Billing hold / operations room context are
/// documented for reuse and are not mounted on this panel. Schedule case
/// primary is absent on this tab. Route entry catalog ∩ is [routeEntry];
/// AppRoutes ∪ is [routeEntryUnion]. Tab chrome stays ∪ `clinical:read` |
/// `patient:read`. No row next-action / case detail on this tab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups tab / count badge | navigate | read ∪ ([tab]) |
/// | Schedule case (toolbar) | create | write ∩ — not mounted ([scheduleCase]) |
/// | Search / Clear / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Billing hold / room-asset context | nested read | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | catalog ∩ / AppRoutes ∪ |
abstract final class TheaterFollowUpsAtomPermissions {
  static const AccessRequirement tab = theaterFollowUpsRequirement;
  static const AccessRequirement listChrome = theaterFollowUpsRequirement;
  static const AccessRequirement search = theaterFollowUpsRequirement;
  static const AccessRequirement settings = theaterFollowUpsRequirement;
  static const AccessRequirement empty = theaterFollowUpsRequirement;
  static const AccessRequirement loading = theaterFollowUpsRequirement;
  static const AccessRequirement retry = theaterFollowUpsRequirement;

  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = theaterFollowUpsWriteRequirement;

  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation = theaterFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = theaterFollowUpsRequirement;
  static const AccessRequirement detail = theaterFollowUpsRequirement;
  static const AccessRequirement close = theaterFollowUpsRequirement;
  static const AccessRequirement create = theaterFollowUpsWriteRequirement;
  static const AccessRequirement update = theaterFollowUpsWriteRequirement;
  static const AccessRequirement delete = theaterFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = theaterFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted = theaterFollowUpsWriteRequirement;
  static const AccessRequirement complete = theaterFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp = theaterFollowUpsWriteRequirement;
  static const AccessRequirement write = theaterFollowUpsWriteRequirement;
  static const AccessRequirement clinicalWrite = theaterClinicalWriteRequirement;
  static const AccessRequirement scheduleCase = theaterScheduleCaseRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses clinical write ∩ / read ∪.
  static const AccessRequirement nestedWrite = theaterFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = theaterFollowUpsRequirement;
  static const AccessRequirement billingHold = theaterBillingHoldReadRequirement;
  static const AccessRequirement operationsRead =
      theaterOperationsReadRequirement;
  static const AccessRequirement entry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.theaterEntry;
  static const AccessRequirement read = theaterFollowUpsRequirement;
}
