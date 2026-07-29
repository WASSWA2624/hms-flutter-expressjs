import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';

/// Module entitlement for the ICU workspace route and board tabs.
const String icuCriticalCareModule = 'icu-critical-care';

/// View / read UI (matrix ∪): `clinical:read` | `emergency:read` + module.
///
/// Emergency-origin cases may satisfy visibility via `emergency:read`.
const AccessRequirement icuWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.emergencyRead,
  ],
  activeModules: <String>[icuCriticalCareModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement icuReadRequirement = icuWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.icu]
/// (∪ `clinical:read` | `emergency:read` | `operations:read` + module).
///
/// Matches [AppRoutes.icu] `requiredAnyPermissions`. Matrix view chrome still
/// uses [icuWorkspaceReadRequirement] (no `operations:read` alone for Active).
const AccessRequirement icuWorkspaceEntryRequirement =
    RouteAccessCatalog.icuEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement icuWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.icuEntry;

/// Alias for Critical / historical call sites.
const AccessRequirement icuWorkspaceRouteEntryRequirement =
    icuWorkspaceEntryRequirement;

/// Create / update / end-stay mutations.
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/icu.md`)
/// documents [IcuWorkspaceWriteRequirement] as ∪ `clinical:write` |
/// `emergency:write` + `icu-critical-care` — keep source.
const AccessRequirement icuWorkspaceWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.emergencyWrite,
  ],
  activeModules: <String>[icuCriticalCareModule],
);

/// Alias matching historical [IcuWorkspaceWriteRequirement.writeRequirement].
const AccessRequirement icuWriteRequirement = icuWorkspaceWriteRequirement;

/// Delete / void — matrix ∩ `clinical:write` via source write ∪.
/// No hard-delete control mounts on Active/Critical today; gate kept so
/// read-only staff never see delete chrome if one is added later.
const AccessRequirement icuWorkspaceDeleteRequirement =
    icuWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement icuDeleteRequirement = icuWorkspaceDeleteRequirement;

/// Navigation chrome (Open IPD / billing / discharge clearance) — no write.
const AccessRequirement icuNavigationRequirement = AccessRequirement();

/// Follow-ups tab / panel read on ICU host (matrix ∪ board read).
///
/// Shared [FollowUpWorklistPanel] defaults to reception ∪; ICU overrides with
/// this requirement (see Follow-ups tab permission scan).
const AccessRequirement icuFollowUpsRequirement = icuWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — source write ∪.
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/icu.md`)
/// documents workspace write as ∪ `clinical:write` | `emergency:write` +
/// `icu-critical-care` — keep source (same as clinical Follow-ups host).
const AccessRequirement icuFollowUpsWriteRequirement =
    icuWorkspaceWriteRequirement;

/// Bed board → Rooms & beds manage (IPD / rooms-beds admin gates).
///
/// Prompt note: manage follows rooms-beds admin. Mirrors IPD
/// `_ipdBedManageRequirement` (roles ∪ admin perms + inpatient module).
/// IPD nested matrix also lists `unit:manage` — keep IPD source (no
/// `unit:manage`) so manage stays on rooms-beds admin, not HR unit packs.
const AccessRequirement icuBedBoardManageRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    AppRole.superAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ],
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ],
  activeModules: <String>['inpatient-bed-management'],
);

/// Historical write-gate helper kept for call-site compatibility.
abstract final class IcuWorkspaceWriteRequirement {
  const IcuWorkspaceWriteRequirement._();

  static const AccessRequirement writeRequirement =
      icuWorkspaceWriteRequirement;
}

bool canReadIcu(AppAccessPolicy policy) {
  return icuWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteIcu(AppAccessPolicy policy) {
  return icuWorkspaceWriteRequirement.isAllowed(policy);
}

bool canDeleteIcu(AppAccessPolicy policy) {
  return icuWorkspaceDeleteRequirement.isAllowed(policy);
}

bool canEnterIcuWorkspace(AppAccessPolicy policy) {
  return icuWorkspaceEntryRequirement.isAllowed(policy);
}

/// Per-tab strip gate. Patient-board tabs share ∪ clinical|emergency read;
/// Active / Critical / Transfers / Discharge / Ended / All / Bed board /
/// Follow-ups use their atom `tab` requirements.
AccessRequirement icuBoardTabRequirement(IcuWorkspaceSection section) {
  return switch (section) {
    IcuWorkspaceSection.active => IcuActiveIcuAtomPermissions.tab,
    IcuWorkspaceSection.critical => IcuCriticalAtomPermissions.tab,
    IcuWorkspaceSection.all => IcuAllAtomPermissions.tab,
    IcuWorkspaceSection.discharge => IcuDischargeReadyAtomPermissions.tab,
    IcuWorkspaceSection.followUps => IcuFollowUpsAtomPermissions.tab,
    IcuWorkspaceSection.beds => IcuBedBoardAtomPermissions.tab,
    IcuWorkspaceSection.ended => IcuEndedStaysAtomPermissions.tab,
    IcuWorkspaceSection.transfers => IcuTransfersAtomPermissions.tab,
  };
}

/// Alias used by Active ICU / shared call sites.
AccessRequirement icuSectionTabRequirement(IcuWorkspaceSection section) {
  return icuBoardTabRequirement(section);
}

bool canViewIcuTab(AppAccessPolicy policy, IcuWorkspaceSection section) {
  return icuBoardTabRequirement(section).isAllowed(policy);
}

bool canViewIcuSection(AppAccessPolicy policy, IcuWorkspaceSection section) {
  return canViewIcuTab(policy, section);
}

bool canViewIcuActive(AppAccessPolicy policy) {
  return IcuActiveIcuAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuAll(AppAccessPolicy policy) {
  return IcuAllAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuCritical(AppAccessPolicy policy) {
  return IcuCriticalAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuDischargeReady(AppAccessPolicy policy) {
  return IcuDischargeReadyAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuBedBoard(AppAccessPolicy policy) {
  return IcuBedBoardAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuEndedStays(AppAccessPolicy policy) {
  return IcuEndedStaysAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuTransfers(AppAccessPolicy policy) {
  return IcuTransfersAtomPermissions.tab.isAllowed(policy);
}

bool canViewIcuFollowUps(AppAccessPolicy policy) {
  return IcuFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadIcuFollowUps(AppAccessPolicy policy) {
  return icuFollowUpsRequirement.isAllowed(policy);
}

bool canWriteIcuFollowUps(AppAccessPolicy policy) {
  return icuFollowUpsWriteRequirement.isAllowed(policy);
}

bool canManageIcuBedBoard(AppAccessPolicy policy) {
  return IcuBedBoardAtomPermissions.manageBeds.isAllowed(policy);
}

/// Case detail / print / Open-IPD chrome for the active board section.
AccessRequirement icuDetailReadRequirement(IcuWorkspaceSection section) {
  return switch (section) {
    IcuWorkspaceSection.active => IcuActiveIcuAtomPermissions.detail,
    IcuWorkspaceSection.all => IcuAllAtomPermissions.detail,
    IcuWorkspaceSection.critical => IcuCriticalAtomPermissions.detail,
    IcuWorkspaceSection.discharge => IcuDischargeReadyAtomPermissions.detail,
    IcuWorkspaceSection.ended => IcuEndedStaysAtomPermissions.detail,
    IcuWorkspaceSection.transfers => IcuTransfersAtomPermissions.detail,
    IcuWorkspaceSection.beds => IcuBedBoardAtomPermissions.detail,
    IcuWorkspaceSection.followUps => IcuFollowUpsAtomPermissions.detail,
    _ => icuWorkspaceReadRequirement,
  };
}

/// Create / update write ∪ for the active board section.
AccessRequirement icuWriteRequirementForSection(IcuWorkspaceSection section) {
  return switch (section) {
    IcuWorkspaceSection.active => IcuActiveIcuAtomPermissions.write,
    IcuWorkspaceSection.all => IcuAllAtomPermissions.write,
    IcuWorkspaceSection.critical => IcuCriticalAtomPermissions.write,
    IcuWorkspaceSection.discharge => IcuDischargeReadyAtomPermissions.write,
    IcuWorkspaceSection.ended => IcuEndedStaysAtomPermissions.write,
    IcuWorkspaceSection.transfers => IcuTransfersAtomPermissions.write,
    IcuWorkspaceSection.beds => IcuBedBoardAtomPermissions.write,
    IcuWorkspaceSection.followUps => IcuFollowUpsAtomPermissions.write,
    _ => icuWorkspaceWriteRequirement,
  };
}

/// Whether the Next action column mounts for [section].
///
/// Critical / Transfers stage next-actions are write ∪ only — omit the column
/// for read-only users. Discharge ready / Ended stays keep the column so
/// navigate next-actions (**Open discharge clearance** / **Open IPD**) remain
/// for readers; write buttons hide via [AppAccessActionGate]. Bed board /
/// Follow-ups have no row next-action.
bool icuBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  IcuWorkspaceSection section,
) {
  if (section.isBedBoard || section.isFollowUps) {
    return false;
  }
  if (!canViewIcuTab(policy, section)) {
    return false;
  }
  if (section == IcuWorkspaceSection.critical ||
      section == IcuWorkspaceSection.transfers) {
    return canWriteIcu(policy);
  }
  return true;
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement icuFocusedPanelRequirement(IcuDetailPanel panel) {
  return switch (panel) {
    IcuDetailPanel.vitals ||
    IcuDetailPanel.alerts ||
    IcuDetailPanel.observations ||
    IcuDetailPanel.orders ||
    IcuDetailPanel.transfer ||
    IcuDetailPanel.discharge => icuWorkspaceWriteRequirement,
  };
}

/// Tabs the user may open; empty when no board read passes.
List<IcuWorkspaceSection> icuAllowedBoardSections(AppAccessPolicy policy) {
  return IcuWorkspaceSection.values
      .where((IcuWorkspaceSection section) => canViewIcuTab(policy, section))
      .toList(growable: false);
}

/// Alias used by Active ICU / shared call sites.
List<IcuWorkspaceSection> icuAllowedSections(AppAccessPolicy policy) {
  return icuAllowedBoardSections(policy);
}

IcuWorkspaceSection? icuFallbackSection(AppAccessPolicy policy) {
  final List<IcuWorkspaceSection> allowed = icuAllowedBoardSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(IcuWorkspaceSection.active)) {
    return IcuWorkspaceSection.active;
  }
  return allowed.first;
}

/// Active ICU tab atom → permission mapping (inventory + matrix).
///
/// Active stays worklist (`/icu` or `?section=active`). Nested cross-module
/// matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse ICU write/read
/// only. Write keeps source ∪ `clinical:write` | `emergency:write` rather than
/// matrix ∩ `clinical:write` alone. Route entry ∪ is [routeEntry]. Navigation
/// (Open IPD / billing / discharge clearance) and print remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active ICU tab / count badge | navigate | read ∪ `clinical:read` \| `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∪ ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → stay detail | read | read ∪ ([detail]) |
/// | Next action Start stay / Acknowledge / Transfer / Assign bed / Observation / Readiness | create / update | write ∪ ([nextAction]) |
/// | Next action Open IPD / discharge clearance | navigate | [navigation] (no write) |
/// | Detail complementary writes (vitals, alert, round, orders, end stay, …) | create / update / delete | write ∪ |
/// | Detail Open billing / Open IPD / clearance | navigate | [navigation] |
/// | Nested mutation dialogs / `panel=` deep link | create / update | write ∪ ([panelDeepLink]) |
/// | Print summary | export / read | read ∪ ([printSummary]) |
/// | Route entry (deep link) | navigate | clinical \| emergency \| operations:read ([routeEntry]) |
abstract final class IcuActiveIcuAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartStay =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAcknowledgeAlert =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionManageTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionRequestTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionMarkReadiness =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAssignBed =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionRecordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionOpenIpd = icuNavigationRequirement;
  static const AccessRequirement nextActionOpenDischargeClearance =
      icuNavigationRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
}

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Shared follow-up worklist (`/icu?section=follow-ups`). Hosted via
/// [FollowUpWorklistPanel] with ICU read/write overrides. Nested cross-module
/// matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse ICU write/read
/// only. Write keeps source ∪ `clinical:write` | `emergency:write` rather than
/// matrix ∩ `clinical:write` alone. Route entry ∪ is [routeEntry]. Tab chrome
/// stays ∪ `clinical:read` | `emergency:read`. No row next-action / stay detail
/// on this tab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∪ ([reschedule]) |
/// | Mark completed | update | write ∪ ([markCompleted]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∪ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∪ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuFollowUpsAtomPermissions {
  static const AccessRequirement tab = icuFollowUpsRequirement;
  static const AccessRequirement listChrome = icuFollowUpsRequirement;
  static const AccessRequirement search = icuFollowUpsRequirement;
  static const AccessRequirement settings = icuFollowUpsRequirement;
  static const AccessRequirement empty = icuFollowUpsRequirement;
  static const AccessRequirement loading = icuFollowUpsRequirement;
  static const AccessRequirement retry = icuFollowUpsRequirement;
  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = icuFollowUpsWriteRequirement;
  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation = icuFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = icuFollowUpsRequirement;
  static const AccessRequirement detail = icuFollowUpsRequirement;
  static const AccessRequirement close = icuFollowUpsRequirement;
  static const AccessRequirement create = icuFollowUpsWriteRequirement;
  static const AccessRequirement update = icuFollowUpsWriteRequirement;
  static const AccessRequirement delete = icuFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = icuFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted = icuFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp = icuFollowUpsWriteRequirement;
  static const AccessRequirement write = icuFollowUpsWriteRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = icuFollowUpsRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// All ICU tab atom → permission mapping (inventory + matrix).
///
/// Unfiltered board (`/icu?section=all`). Stays / alerts / transfers need
/// source write ∪ `clinical:write` | `emergency:write` (matrix ∩
/// `clinical:write` alone — keep source). Nested cross-module matrix rows are
/// _(n/a)_. Route entry keeps AppRoutes ∪ `clinical:read` | `emergency:read` |
/// `operations:read` ([routeEntry]). Tab chrome stays ∪ `clinical:read` |
/// `emergency:read`. Open IPD / discharge clearance / print remain without
/// write. Bed board manage follows rooms-beds admin gates elsewhere.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All ICU tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ |
/// | Row select → stay detail | read | ([detail]) |
/// | Next action start stay / acknowledge / transfer / bed / observation / readiness | create / update | write ∪ |
/// | Next action Open IPD / discharge clearance | navigate | [navigation] |
/// | Detail complementary writes (vitals / alert / round / orders / end stay / …) | create / update | write ∪ |
/// | Detail Open billing / Open IPD / clearance | navigate | [navigation] |
/// | Detail Print summary | export / read | read ∪ ([printSummary]) |
/// | Nested mutation dialogs | create / update | write ∪ |
/// | Panel deep link `?panel=` | create / update | write ∪ ([panelDeepLink]) |
/// | Hard delete / void | delete | write ∪ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuAllAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartStay =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAcknowledgeAlert =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionManageTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionRequestTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionMarkReadiness =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAssignBed =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionRecordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionNavigate = icuNavigationRequirement;
  static const AccessRequirement nextActionOpenIpd = icuNavigationRequirement;
  static const AccessRequirement nextActionOpenDischargeClearance =
      icuNavigationRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement navigate = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write/read only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Discharge ready tab atom → permission mapping (inventory + matrix).
///
/// Discharge-ready / step-down queue (`/icu?section=discharge`). Stage
/// next-action is **Mark readiness** (write ∪) or **Open discharge clearance**
/// (navigate when already planned). Nested cross-module matrix rows are
/// _(n/a)_ — [nestedWrite] / [nestedRead] reuse ICU write/read only. Write
/// keeps source ∪ `clinical:write` | `emergency:write` rather than matrix ∩
/// `clinical:write` alone. Route entry ∪ is [routeEntry]. Tab chrome stays ∪
/// `clinical:read` | `emergency:read`. Open clearance / IPD / billing / print
/// remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Discharge ready tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → stay detail | read | ([detail]) |
/// | Next action Mark readiness | update | write ∪ ([nextActionMarkReadiness]) |
/// | Next action Open discharge clearance | navigate | [navigate] (no write) |
/// | Detail complementary writes (vitals, alert, round, orders, transfer, end stay, …) | create / update | write ∪ |
/// | Detail Mark readiness (when not row next-action) | update | write ∪ ([markReadiness]) |
/// | Detail Open clearance / Open IPD / Open billing | navigate | [navigate] |
/// | Detail Print summary | export / read | read ∪ ([printSummary]) |
/// | Nested readiness / mutation dialogs | create / update | write ∪ |
/// | Deep link `?panel=discharge` | update | write ∪ ([panelDeepLink]) |
/// | Hard delete / void | delete | write ∪ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuDischargeReadyAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionMarkReadiness =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionOpenDischargeClearance =
      icuNavigationRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  static const AccessRequirement navigate = icuNavigationRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Ended stays tab atom → permission mapping (inventory + matrix).
///
/// Historical stays (`/icu?section=ended`). Prefer read-only: stage next-action
/// is **Open IPD** (navigate, no write). Nested cross-module matrix rows are
/// _(n/a)_. Write keeps source ∪ `clinical:write` | `emergency:write` rather
/// than matrix ∩ `clinical:write` alone (ineligible stay mutations stay absent
/// via `canRecordIcuAction` / start-stay eligibility). Route entry ∪ is
/// [routeEntry]. Tab chrome stays ∪ `clinical:read` | `emergency:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Ended stays tab / count badge | navigate | read ∪ `clinical:read` \| `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ / form |
/// | Row select → stay detail | read | read ∪ |
/// | Next action Open IPD | navigate | navigate (no write) |
/// | Detail complementary writes (when eligible) | create / update | write ∪ |
/// | Detail Open billing / Open IPD / clearance | navigate | navigate |
/// | Detail Print summary | export / read | read ∪ |
/// | Deep link `?panel=` mutation | create / update | write ∪ |
/// | Hard delete / void | delete | write ∪ — not mounted |
/// | Route entry (deep link) | navigate | clinical \| emergency \| operations:read |
abstract final class IcuEndedStaysAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuNavigationRequirement;
  static const AccessRequirement nextActionOpenIpd = icuNavigationRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Critical alerts tab atom → permission mapping (inventory + matrix).
///
/// Critical alert queue (`/icu?section=critical`). Acknowledge alert is the
/// stage next-action. Nested cross-module matrix rows are _(n/a)_ —
/// [nestedWrite] / [nestedRead] reuse ICU write/read only. Write keeps source
/// ∪ `clinical:write` | `emergency:write` (matrix ∩ `clinical:write` alone).
/// Route entry keeps AppRoutes ∪ ([routeEntry]). Tab chrome stays ∪
/// `clinical:read` | `emergency:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Critical alerts tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Alert column / critical row highlight | read | ([alertColumn]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ |
/// | Row select → stay detail | read | ([detail]) |
/// | Next action Acknowledge alert | update | write ∪ ([nextActionAcknowledge]) |
/// | Detail Raise alert / Acknowledge / complementary writes | create / update | write ∪ |
/// | Detail End stay | update / delete-like | write ∪ ([endStay]) |
/// | Nested mutation dialogs (vitals / alert / …) | create / update | write ∪ |
/// | Deep link `panel=` | create / update | write ∪ ([panelDeepLink]) |
/// | Print summary | export / read | read ∪ ([printSummary]) |
/// | Open IPD / billing / discharge clearance | navigate | [navigate] |
/// | Hard delete / void | delete | write ∪ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuCriticalAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement alertColumn = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionAcknowledge =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  static const AccessRequirement navigate = icuNavigationRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Transfers tab atom → permission mapping (inventory + matrix).
///
/// ICU transfers queue (`/icu?section=transfers`). Stage next-action is
/// **Manage transfer** (open request) or **Request transfer** (no open
/// request) — both write ∪. Nested cross-module matrix rows are _(n/a)_ —
/// [nestedWrite] / [nestedRead] reuse ICU write/read only. Write keeps source
/// ∪ `clinical:write` | `emergency:write` (matrix ∩ `clinical:write` alone —
/// keep source). Route entry keeps AppRoutes ∪ ([routeEntry]). Tab chrome
/// stays ∪ `clinical:read` | `emergency:read`. Transfer status column is read
/// chrome. Open IPD / billing / clearance / print remain without write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Transfers tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Transfer status column | read | ([transferColumn]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∪ |
/// | Row select → stay detail | read | ([detail]) |
/// | Next action Manage transfer | update | write ∪ ([nextActionManageTransfer]) |
/// | Next action Request transfer | create | write ∪ ([nextActionRequestTransfer]) |
/// | Detail complementary writes (vitals / alert / round / orders / end stay / …) | create / update | write ∪ |
/// | Detail Manage / Request transfer (when not row next-action) | create / update | write ∪ |
/// | Detail Open billing / Open IPD / clearance | navigate | [navigate] |
/// | Detail Print summary | export / read | read ∪ ([printSummary]) |
/// | Nested transfer / mutation dialogs | create / update | write ∪ |
/// | Deep link `?panel=transfer` | create / update | write ∪ ([panelDeepLink]) |
/// | Hard delete / void | delete | write ∪ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuTransfersAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement search = icuWorkspaceReadRequirement;
  static const AccessRequirement filters = icuWorkspaceReadRequirement;
  static const AccessRequirement settings = icuWorkspaceReadRequirement;
  static const AccessRequirement transferColumn = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionManageTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement nextActionRequestTransfer =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement manageTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement requestTransfer = icuWorkspaceWriteRequirement;
  static const AccessRequirement startStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement recordObservation =
      icuWorkspaceWriteRequirement;
  static const AccessRequirement recordVitals = icuWorkspaceWriteRequirement;
  static const AccessRequirement raiseAlert = icuWorkspaceWriteRequirement;
  static const AccessRequirement round = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderLab = icuWorkspaceWriteRequirement;
  static const AccessRequirement orderImaging = icuWorkspaceWriteRequirement;
  static const AccessRequirement prescribe = icuWorkspaceWriteRequirement;
  static const AccessRequirement assignBed = icuWorkspaceWriteRequirement;
  static const AccessRequirement markReadiness = icuWorkspaceWriteRequirement;
  static const AccessRequirement endStay = icuWorkspaceWriteRequirement;
  static const AccessRequirement printSummary = icuWorkspaceReadRequirement;
  static const AccessRequirement navigate = icuNavigationRequirement;
  static const AccessRequirement navigation = icuNavigationRequirement;
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement openBilling = icuNavigationRequirement;
  static const AccessRequirement openDischargeClearance =
      icuNavigationRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses ICU write ∪ / read ∪ only.
  static const AccessRequirement nestedWrite = icuWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = icuWorkspaceWriteRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Bed board tab atom → permission mapping (inventory + matrix).
///
/// ICU ward occupancy (`/icu?section=beds`). Read view over the shared bed
/// catalog; bed CRUD stays in Facility / Rooms & beds. Write keeps source ∪
/// `clinical:write` | `emergency:write` (matrix ∩ `clinical:write` alone).
/// Manage beds follows rooms-beds admin gates ([manageBeds] /
/// [icuBedBoardManageRequirement]) — strip primary on Bed board only (Refresh /
/// Start ICU stay stay removed). Nested general matrix rows _(n/a)_ reuse ICU
/// read/write; manage is the dedicated cross-module nested write.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Bed board tab / count badge | navigate | read ∪ ([tab]) |
/// | Ward ChoiceChip filters | read chrome | ([wardFilters]) |
/// | Available / occupied summary badges | read chrome | ([summaryChips]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Bed row (location / occupant / status) | read | ([rowSelect]) |
/// | Open IPD (occupied row) | navigate | [openIpd] (no write) |
/// | Manage beds → `/rooms-beds` | nested write / navigate | [manageBeds] |
/// | Create / update / delete stay mutations | create / update / delete | write ∪ — not on this tab |
/// | Success / validation (authorized mutations elsewhere) | visible feedback | write ∪ |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IcuBedBoardAtomPermissions {
  static const AccessRequirement tab = icuWorkspaceReadRequirement;
  static const AccessRequirement listChrome = icuWorkspaceReadRequirement;
  static const AccessRequirement wardFilters = icuWorkspaceReadRequirement;
  static const AccessRequirement summaryChips = icuWorkspaceReadRequirement;
  static const AccessRequirement empty = icuWorkspaceReadRequirement;
  static const AccessRequirement loading = icuWorkspaceReadRequirement;
  static const AccessRequirement retry = icuWorkspaceReadRequirement;
  static const AccessRequirement success = icuWorkspaceWriteRequirement;
  static const AccessRequirement validation = icuWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = icuWorkspaceReadRequirement;
  static const AccessRequirement detail = icuWorkspaceReadRequirement;
  static const AccessRequirement create = icuWorkspaceWriteRequirement;
  static const AccessRequirement update = icuWorkspaceWriteRequirement;
  static const AccessRequirement delete = icuWorkspaceDeleteRequirement;
  static const AccessRequirement write = icuWorkspaceWriteRequirement;
  /// Occupied-row Open IPD — inventory: no write gate.
  static const AccessRequirement openIpd = icuNavigationRequirement;
  static const AccessRequirement navigate = icuNavigationRequirement;
  /// Rooms & beds admin — prompt: manage follows rooms-beds gates.
  static const AccessRequirement manageBeds = icuBedBoardManageRequirement;
  /// Nested cross-module write for manage (IPD source admin ∪).
  static const AccessRequirement nestedWrite = icuBedBoardManageRequirement;
  /// Nested cross-module read — matrix _(n/a)_; board read ∪.
  static const AccessRequirement nestedRead = icuWorkspaceReadRequirement;
  static const AccessRequirement entry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = icuWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      icuWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.icuEntry;
}

/// Verifies AppRoutes ICU entry keys stay aligned with [routeEntry].
bool icuRouteEntryMatchesAppRoutes() {
  final Set<AppPermission> routeKeys = AppRoutes.icu.requiredAnyPermissions
      .toSet();
  final Set<AppPermission> atomKeys =
      IcuActiveIcuAtomPermissions.routeEntry.anyPermissions.toSet();
  return routeKeys.containsAll(atomKeys) && atomKeys.containsAll(routeKeys);
}
