import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/operations/presentation/operations_access.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/features/theater/presentation/theater_next_action.dart';

/// Module entitlement for the theater workspace route and board tabs.
const String theaterTheatreAnesthesiaModule = 'theatre-anesthesia';

/// View / read UI (matrix ∪): `clinical:read` | `patient:read` + module.
///
/// Billing / operations route entry alone does **not** satisfy tab chrome —
/// see [theaterWorkspaceAppRoutesEntryRequirement] vs [tab] requirements.
const AccessRequirement theaterWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
  ],
  activeModules: <String>[theaterTheatreAnesthesiaModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement theaterReadRequirement = theaterWorkspaceReadRequirement;

/// Route entry — [RouteAccessCatalog.theaterEntry] is ∩ `theater:read` +
/// `theatre-anesthesia` (catalog source of truth).
///
/// Prompt / [AppRoutes.theater] document ∪ `patient:read` | `clinical:read` |
/// `billing:read` | `operations:read` + module — keep catalog here and expose
/// the AppRoutes union as [theaterWorkspaceAppRoutesEntryRequirement]; note
/// the mapping in tests.
const AccessRequirement theaterWorkspaceEntryRequirement =
    RouteAccessCatalog.theaterEntry;

/// Prompt / AppRoutes route-entry ∪ (not catalog `theater:read`).
const AccessRequirement theaterWorkspaceAppRoutesEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.patientRead,
        AppPermissions.clinicalRead,
        AppPermissions.billingRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>[theaterTheatreAnesthesiaModule],
    );

/// Alias matching historical catalog call sites.
const AccessRequirement theaterWorkspaceRouteUnionRequirement =
    theaterWorkspaceEntryRequirement;

/// Create / update / delete / stage mutations (matrix ∩ `clinical:write`).
///
/// Schedule case, stage updates, readiness, anesthesia, post-op, handover,
/// finalize, and cancel need this gate + `theatre-anesthesia`. Aligns with
/// patient-registry [patientTheaterWriteRequirement] (same clinical:write +
/// module; that helper uses `anyPermissions` with a single key).
const AccessRequirement theaterWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[theaterTheatreAnesthesiaModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement theaterWriteRequirement = theaterWorkspaceWriteRequirement;

/// Delete / cancel case — matrix ∩ `clinical:write` (no dedicated delete key).
const AccessRequirement theaterWorkspaceDeleteRequirement =
    theaterWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement theaterDeleteRequirement =
    theaterWorkspaceDeleteRequirement;

/// Navigation chrome (Open IPD / Open Emergency) — no write.
const AccessRequirement theaterNavigationRequirement = AccessRequirement();

/// Schedule-form billing holds / charge panel (prompt: billing holds need
/// `billing:read`). Reuses [billingReadRequirement]
/// (`billing:read` ∩ `billing-payments`).
const AccessRequirement theaterBillingHoldReadRequirement =
    billingReadRequirement;

/// Room / asset operations context (prompt: may need `operations:read`).
///
/// Reuses [operationsReadRequirement]. All-cases room column / room filter
/// stay on workspace read (core OR assignment); this gate documents nested
/// operations context and optional room-context atoms.
const AccessRequirement theaterRoomContextReadRequirement =
    operationsReadRequirement;

/// Follow-ups tab / panel read on theater host (matrix ∪ board read).
const AccessRequirement theaterFollowUpsRequirement =
    theaterWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — matrix ∩ `clinical:write`.
const AccessRequirement theaterFollowUpsWriteRequirement =
    theaterWorkspaceWriteRequirement;

bool canReadTheater(AppAccessPolicy policy) {
  return theaterWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteTheater(AppAccessPolicy policy) {
  return theaterWorkspaceWriteRequirement.isAllowed(policy);
}

bool canDeleteTheater(AppAccessPolicy policy) {
  return theaterWorkspaceDeleteRequirement.isAllowed(policy);
}

bool canEnterTheaterWorkspace(AppAccessPolicy policy) {
  return theaterWorkspaceEntryRequirement.isAllowed(policy);
}

bool canEnterTheaterViaAppRoutes(AppAccessPolicy policy) {
  return theaterWorkspaceAppRoutesEntryRequirement.isAllowed(policy);
}

bool canViewTheaterBillingHolds(AppAccessPolicy policy) {
  return theaterBillingHoldReadRequirement.isAllowed(policy);
}

bool canViewTheaterRoomContext(AppAccessPolicy policy) {
  return theaterRoomContextReadRequirement.isAllowed(policy);
}

/// Per-tab strip gate. Case-board tabs share ∪ clinical|patient read until
/// section-specific scans land; All uses [TheaterAllAtomPermissions.tab].
AccessRequirement theaterBoardTabRequirement(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.tab,
    TheaterSection.followUps => TheaterAllAtomPermissions.followUpsTab,
    TheaterSection.scheduled ||
    TheaterSection.inTheater ||
    TheaterSection.recovery => theaterWorkspaceReadRequirement,
  };
}

bool canViewTheaterTab(AppAccessPolicy policy, TheaterSection section) {
  return theaterBoardTabRequirement(section).isAllowed(policy);
}

bool canViewTheaterAll(AppAccessPolicy policy) {
  return TheaterAllAtomPermissions.tab.isAllowed(policy);
}

bool canViewTheaterFollowUps(AppAccessPolicy policy) {
  return theaterFollowUpsRequirement.isAllowed(policy);
}

bool canWriteTheaterFollowUps(AppAccessPolicy policy) {
  return theaterFollowUpsWriteRequirement.isAllowed(policy);
}

/// Write ∩ for the active board section.
AccessRequirement theaterWriteRequirementForSection(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.write,
    TheaterSection.followUps => theaterFollowUpsWriteRequirement,
    TheaterSection.scheduled ||
    TheaterSection.inTheater ||
    TheaterSection.recovery => theaterWorkspaceWriteRequirement,
  };
}

/// Detail read for the active board section.
AccessRequirement theaterDetailReadRequirement(TheaterSection section) {
  return switch (section) {
    TheaterSection.all => TheaterAllAtomPermissions.detail,
    TheaterSection.followUps => theaterFollowUpsRequirement,
    TheaterSection.scheduled ||
    TheaterSection.inTheater ||
    TheaterSection.recovery => theaterWorkspaceReadRequirement,
  };
}

/// Whether the Next action column mounts for [section].
///
/// All-cases next-actions are write ∩ only — omit the column for read-only
/// users so mutation affordances do not mount (status text remains via other
/// columns). Follow-ups has no row next-action.
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
    TheaterDetailPanel.resources => theaterWorkspaceWriteRequirement,
  };
}

/// Tabs the user may open; empty when no board read passes.
List<TheaterSection> theaterAllowedBoardSections(AppAccessPolicy policy) {
  return TheaterSection.values
      .where((TheaterSection section) => canViewTheaterTab(policy, section))
      .toList(growable: false);
}

TheaterSection? theaterFallbackSection(AppAccessPolicy policy) {
  final List<TheaterSection> allowed = theaterAllowedBoardSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(TheaterSection.all)) {
    return TheaterSection.all;
  }
  return allowed.first;
}

/// Whether [AppRoutes.theater] `requiredAnyPermissions` match the documented
/// AppRoutes entry ∪ helper (catalog keeps `theater:read` separately).
bool theaterAppRoutesEntryMatchesAppRoutes() {
  final Set<AppPermission> route = AppRoutes.theater.requiredAnyPermissions
      .toSet();
  final Set<AppPermission> helper = theaterWorkspaceAppRoutesEntryRequirement
      .anyPermissions
      .toSet();
  return route.length == helper.length && route.containsAll(helper);
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
/// is [appRoutesEntry]. Tab chrome stays ∪ `clinical:read` | `patient:read`.
/// Open IPD / Open Emergency remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All cases tab / count badge | navigate | read ∪ ([tab]) |
/// | Schedule case (toolbar) | create | write ∩ ([scheduleCase]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Status / stage filters (All only) | read chrome | ([filters]) |
/// | Room / surgeon / anesthetist filters | read chrome | ([filters] / room id) |
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
  static const AccessRequirement success = theaterWorkspaceWriteRequirement;
  static const AccessRequirement validation = theaterWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = theaterWorkspaceReadRequirement;
  static const AccessRequirement detail = theaterWorkspaceReadRequirement;
  static const AccessRequirement create = theaterWorkspaceWriteRequirement;
  static const AccessRequirement update = theaterWorkspaceWriteRequirement;
  static const AccessRequirement delete = theaterWorkspaceDeleteRequirement;
  static const AccessRequirement write = theaterWorkspaceWriteRequirement;
  static const AccessRequirement scheduleCase = theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextActionUpdateReadiness =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartCase =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAnesthesia =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextActionPostOp =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandover =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement reschedule = theaterWorkspaceWriteRequirement;
  static const AccessRequirement updateStage = theaterWorkspaceWriteRequirement;
  static const AccessRequirement assignResource =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement updateReadiness =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement anesthesia = theaterWorkspaceWriteRequirement;
  static const AccessRequirement postOp = theaterWorkspaceWriteRequirement;
  static const AccessRequirement handover = theaterWorkspaceWriteRequirement;
  static const AccessRequirement finalize = theaterWorkspaceWriteRequirement;
  static const AccessRequirement cancelCase = theaterWorkspaceWriteRequirement;
  static const AccessRequirement billingHolds =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement scheduleBilling =
      theaterBillingHoldReadRequirement;
  static const AccessRequirement roomContext =
      theaterRoomContextReadRequirement;
  static const AccessRequirement roomColumn = theaterWorkspaceReadRequirement;
  static const AccessRequirement roomFilter = theaterWorkspaceReadRequirement;
  static const AccessRequirement navigation = theaterNavigationRequirement;
  static const AccessRequirement openIpd = theaterNavigationRequirement;
  static const AccessRequirement openEmergency = theaterNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses theater write/read only.
  static const AccessRequirement nestedWrite = theaterWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = theaterWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      theaterWorkspaceWriteRequirement;
  static const AccessRequirement entry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = theaterWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      theaterWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.theaterEntry;
  static const AccessRequirement appRoutesEntry =
      theaterWorkspaceAppRoutesEntryRequirement;
}

/// Requirement for a resolved next-action kind on All cases.
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
