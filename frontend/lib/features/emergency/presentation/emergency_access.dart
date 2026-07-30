import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';

/// Module entitlement for the emergency workspace route and board tabs.
const String emergencySchedulingQueueModule = 'scheduling-queue';

/// View / read UI (matrix ∩ `emergency:read`).
const AccessRequirement emergencyWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.emergencyRead],
  activeModules: <String>[emergencySchedulingQueueModule],
  requiresTenantContext: true,
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement emergencyReadRequirement =
    emergencyWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.emergency]
/// (∪ `emergency:read` | `emergency:write` | `operations:read` + module).
const AccessRequirement emergencyWorkspaceEntryRequirement =
    RouteAccessCatalog.emergencyEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement emergencyWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.emergencyEntry;

/// Create / update mutations (matrix ∩ `emergency:write`).
const AccessRequirement emergencyWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.emergencyWrite],
  activeModules: <String>[emergencySchedulingQueueModule],
  requiresTenantContext: true,
);

/// Alias matching historical `_writeRequirement` / panel write gate.
const AccessRequirement emergencyWriteRequirement =
    emergencyWorkspaceWriteRequirement;

/// Hard delete / void (matrix ∩ `emergency:delete`). No board delete atom
/// mounts today; keep the gate so write-only staff never see delete chrome.
const AccessRequirement emergencyWorkspaceDeleteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.emergencyDelete],
  activeModules: <String>[emergencySchedulingQueueModule],
  requiresTenantContext: true,
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement emergencyDeleteRequirement =
    emergencyWorkspaceDeleteRequirement;

/// Handoff mutations — source inventory (`screens/emergency.md`) documents ∪
/// emergency / patient / clinical / operations write. Matrix create/update is
/// ∩ `emergency:write`; keep source for handoff chrome.
const AccessRequirement emergencyHandoffWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.emergencyWrite,
    AppPermissions.patientWrite,
    AppPermissions.clinicalWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[emergencySchedulingQueueModule],
  requiresTenantContext: true,
);

/// Vehicle / fleet context on Active/Critical detail (emergency read ∩).
///
/// Ambulance strip uses [emergencyAmbulanceTabRequirement] ∪ so
/// `operations:read` alone can open dispatch/trip worklists.
const AccessRequirement emergencyAmbulanceContextReadRequirement =
    emergencyWorkspaceReadRequirement;

/// Ambulance tab / asset-context board (matrix ∪):
/// `emergency:read` | `operations:read`.
const AccessRequirement emergencyAmbulanceTabRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.emergencyRead,
    AppPermissions.operationsRead,
  ],
  activeModules: <String>[emergencySchedulingQueueModule],
  requiresTenantContext: true,
);

bool canReadEmergency(AppAccessPolicy policy) {
  return emergencyWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteEmergency(AppAccessPolicy policy) {
  return emergencyWorkspaceWriteRequirement.isAllowed(policy);
}

bool canDeleteEmergency(AppAccessPolicy policy) {
  return emergencyWorkspaceDeleteRequirement.isAllowed(policy);
}

bool canHandoffEmergency(AppAccessPolicy policy) {
  return emergencyHandoffWriteRequirement.isAllowed(policy);
}

/// Alias used by Ambulance / shared handoff call sites.
bool canWriteEmergencyHandoff(AppAccessPolicy policy) {
  return canHandoffEmergency(policy);
}

bool canEnterEmergencyWorkspace(AppAccessPolicy policy) {
  return emergencyWorkspaceEntryRequirement.isAllowed(policy);
}

/// Per-tab strip gate. Most tabs share ∩ `emergency:read`; Ambulance uses ∪
/// with `operations:read` for vehicle context.
AccessRequirement emergencyBoardTabRequirement(EmergencyBoardTab tab) {
  return switch (tab) {
    EmergencyBoardTab.ambulance => EmergencyAmbulanceAtomPermissions.tab,
    EmergencyBoardTab.active => EmergencyActiveCasesAtomPermissions.tab,
    EmergencyBoardTab.all => EmergencyAllAtomPermissions.tab,
    EmergencyBoardTab.closed => EmergencyClosedAtomPermissions.tab,
    EmergencyBoardTab.critical => EmergencyCriticalAtomPermissions.tab,
    EmergencyBoardTab.handoff => EmergencyHandoffAtomPermissions.tab,
  };
}

bool canViewEmergencyTab(AppAccessPolicy policy, EmergencyBoardTab tab) {
  return emergencyBoardTabRequirement(tab).isAllowed(policy);
}

bool canViewEmergencyHandoff(AppAccessPolicy policy) {
  return EmergencyHandoffAtomPermissions.tab.isAllowed(policy);
}

bool canViewEmergencyAmbulance(AppAccessPolicy policy) {
  return EmergencyAmbulanceAtomPermissions.tab.isAllowed(policy);
}

/// Case detail / print / Open-in-module chrome for the active board tab.
///
/// Ambulance uses ∪ `emergency:read` | `operations:read`; other tabs use ∩
/// `emergency:read`.
AccessRequirement emergencyDetailReadRequirement(EmergencyBoardTab tab) {
  return switch (tab) {
    EmergencyBoardTab.ambulance => EmergencyAmbulanceAtomPermissions.detail,
    EmergencyBoardTab.active => EmergencyActiveCasesAtomPermissions.detail,
    EmergencyBoardTab.all => EmergencyAllAtomPermissions.detail,
    EmergencyBoardTab.closed => EmergencyClosedAtomPermissions.detail,
    EmergencyBoardTab.critical => EmergencyCriticalAtomPermissions.detail,
    EmergencyBoardTab.handoff => EmergencyHandoffAtomPermissions.detail,
  };
}

/// Create / update write ∩ for the active board tab (`*AtomPermissions.write`).
AccessRequirement emergencyWriteRequirementForTab(EmergencyBoardTab tab) {
  return switch (tab) {
    EmergencyBoardTab.ambulance => EmergencyAmbulanceAtomPermissions.write,
    EmergencyBoardTab.active => EmergencyActiveCasesAtomPermissions.write,
    EmergencyBoardTab.all => EmergencyAllAtomPermissions.write,
    EmergencyBoardTab.closed => EmergencyClosedAtomPermissions.write,
    EmergencyBoardTab.critical => EmergencyCriticalAtomPermissions.write,
    EmergencyBoardTab.handoff => EmergencyHandoffAtomPermissions.write,
  };
}

/// Whether the user may open case detail (any visible board tab / Ambulance ∪).
bool canOpenEmergencyCaseDetail(AppAccessPolicy policy) {
  return emergencyAllowedBoardTabs(policy).isNotEmpty;
}

/// Whether any workflow next-action column may mount (write ∩ or handoff ∪).
bool canShowEmergencyNextAction(AppAccessPolicy policy) {
  return canWriteEmergency(policy) || canHandoffEmergency(policy);
}

/// Whether the Next action column mounts for [tab].
bool emergencyBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  EmergencyBoardTab tab,
) {
  if (tab == EmergencyBoardTab.closed) {
    return false;
  }
  return canShowEmergencyNextAction(policy);
}

/// Tabs the user may open; empty when no board read (incl. ambulance ∪) passes.
List<EmergencyBoardTab> emergencyAllowedBoardTabs(AppAccessPolicy policy) {
  return EmergencyBoardTab.values
      .where((EmergencyBoardTab tab) => canViewEmergencyTab(policy, tab))
      .toList(growable: false);
}

EmergencyBoardTab? emergencyFallbackTab(AppAccessPolicy policy) {
  final List<EmergencyBoardTab> allowed = emergencyAllowedBoardTabs(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(EmergencyBoardTab.active)) {
    return EmergencyBoardTab.active;
  }
  return allowed.first;
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement emergencyFocusedPanelRequirement(
  EmergencyDetailPanelFocus panel,
) {
  return switch (panel) {
    EmergencyDetailPanelFocus.handoff => emergencyHandoffWriteRequirement,
    EmergencyDetailPanelFocus.none => emergencyWorkspaceReadRequirement,
    _ => emergencyWorkspaceWriteRequirement,
  };
}

/// Active cases tab atom → permission mapping (inventory + matrix).
///
/// Live ED board (`/emergency?scope=active`); Quick arrival primary. Nested
/// cross-module matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse
/// emergency write/read only. Handoff keeps source ∪ write keys. Route entry ∪
/// is [routeEntry]. Delete ∩ is documented but no Active delete control mounts
/// — write-only staff must not see delete chrome.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active cases tab / count badge | navigate | read ∩ `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → detail | read | read ∩ ([detail]) |
/// | Quick arrival | create | write ∩ `emergency:write` ([quickArrival]) |
/// | Next action Triage / Response / Dispatch / Trip | create / update | write ∩ |
/// | Next action Handoff | update | handoff ∪ ([nextActionHandoff]) |
/// | Detail Priority / Triage / Response / Dispatch / Trip / Theater | create / update | write ∩ |
/// | Detail Handoff | update | handoff ∪ |
/// | Nested mutation dialogs | create / update | write ∩ / handoff ∪ |
/// | Deep link `panel=` | create / update | write ∩ / handoff ∪ ([panelDeepLink]) |
/// | Print summary | export / read | read ∩ ([printSummary]) |
/// | Open in {module} | navigate | read ∩ ([detail]) |
/// | Ambulance timeline panel | read | read ∩ ([ambulanceContext]) |
/// | Hard delete / void | delete | delete ∩ ([delete]) — not mounted |
/// | Route entry (deep link) | navigate | read \| write \| operations:read ([routeEntry]) |
abstract final class EmergencyActiveCasesAtomPermissions {
  static const AccessRequirement tab = emergencyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = emergencyWorkspaceReadRequirement;
  static const AccessRequirement search = emergencyWorkspaceReadRequirement;
  static const AccessRequirement filters = emergencyWorkspaceReadRequirement;
  static const AccessRequirement settings = emergencyWorkspaceReadRequirement;
  static const AccessRequirement empty = emergencyWorkspaceReadRequirement;
  static const AccessRequirement loading = emergencyWorkspaceReadRequirement;
  static const AccessRequirement retry = emergencyWorkspaceReadRequirement;
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement validation = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyWorkspaceReadRequirement;
  static const AccessRequirement detail = emergencyWorkspaceReadRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionDispatch =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionCompleteTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandoff =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement triage = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement recordTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement response = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement markResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement dispatch = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement trip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement startTrip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement completeTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement priority = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement updatePriority =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleTheater =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  static const AccessRequirement printSummary =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyWorkspaceReadRequirement;
  /// Navigate Billing workspace for deferred settlement (∩ `billing:read`).
  static const AccessRequirement openBilling = AccessRequirement(
    allPermissions: <AppPermission>[AppPermissions.billingRead],
    activeModules: <String>['billing-payments'],
    requiresTenantContext: true,
  );
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceContextReadRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses emergency write ∩ only.
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}

bool canViewEmergencyActive(AppAccessPolicy policy) {
  return EmergencyActiveCasesAtomPermissions.tab.isAllowed(policy);
}

bool canOpenEmergencyBilling(AppAccessPolicy policy) {
  return EmergencyActiveCasesAtomPermissions.openBilling.isAllowed(policy);
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Unfiltered board (`/emergency?scope=all`). Quick arrival / triage /
/// response / dispatch / trip / priority / Schedule in Theater need
/// ∩ `emergency:write`. Handoff keeps source ∪. Hard delete/void needs
/// ∩ `emergency:delete` (no All delete control yet). Matrix nested
/// cross-module rows are _(n/a)_. Route entry keeps catalog ∪
/// `emergency:read` | `emergency:write` | `operations:read` ([routeEntry]).
/// Tab chrome stays ∩ `emergency:read`. Ambulance vehicle context may also
/// need `operations:read` for fleet panels elsewhere; do not expose delete to
/// write-only staff.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab / count badge | navigate | read ∩ `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → case detail | read | read ∩ |
/// | Quick arrival | create | write ∩ |
/// | Next action triage / response / dispatch / trip | create / update | write ∩ |
/// | Next action handoff | update | handoff ∪ source |
/// | Detail Update priority / triage / response / ambulance | update | write ∩ |
/// | Detail Handoff | update | handoff ∪ source |
/// | Detail Schedule in Theater | navigate / update | write ∩ |
/// | Detail Print summary | export / read | read ∩ |
/// | Open in {module} (handoff outcome) | navigate | read ∩ |
/// | Ambulance timeline panel | read | read ∩ ([ambulanceContext]) |
/// | Hard delete / void | delete | delete ∩ (no UI atom yet) |
/// | Nested mutation dialogs | create / update | write ∩ / handoff ∪ |
/// | Panel deep link `?panel=` | create / update | write ∩ / handoff ∪ |
/// | Route entry (deep link) | navigate | catalog ∪ |
abstract final class EmergencyAllAtomPermissions {
  static const AccessRequirement tab = emergencyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = emergencyWorkspaceReadRequirement;
  static const AccessRequirement search = emergencyWorkspaceReadRequirement;
  static const AccessRequirement filters = emergencyWorkspaceReadRequirement;
  static const AccessRequirement settings = emergencyWorkspaceReadRequirement;
  static const AccessRequirement empty = emergencyWorkspaceReadRequirement;
  static const AccessRequirement loading = emergencyWorkspaceReadRequirement;
  static const AccessRequirement retry = emergencyWorkspaceReadRequirement;
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyWorkspaceReadRequirement;
  static const AccessRequirement detail = emergencyWorkspaceReadRequirement;
  static const AccessRequirement printSummary =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionDispatch =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionCompleteTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandoff =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement updatePriority =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement recordTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement triage = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement markResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement response = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement dispatch = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement startTrip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement completeTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement trip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement priority = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  static const AccessRequirement scheduleTheater =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceContextReadRequirement;
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}

bool canViewEmergencyAll(AppAccessPolicy policy) {
  return EmergencyAllAtomPermissions.tab.isAllowed(policy);
}

/// Critical tab atom → permission mapping (inventory + matrix).
///
/// Critical acuity filter (`?scope=critical`). Quick arrival / triage /
/// response / dispatch / trip / priority / Schedule in Theater need
/// ∩ `emergency:write`. Handoff keeps source ∪. Hard delete/void needs
/// ∩ `emergency:delete` (no Critical delete control yet). Matrix nested
/// cross-module rows are _(n/a)_. Route entry keeps catalog ∪
/// `emergency:read` | `emergency:write` | `operations:read` ([routeEntry]).
/// Tab chrome stays ∩ `emergency:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Critical tab / count badge | navigate | read ∩ `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Critical row highlight / priority chip | read | read ∩ ([criticalChip]) |
/// | Row select → case detail | read | read ∩ |
/// | Quick arrival | create | write ∩ |
/// | Next action triage / response / dispatch / trip | create / update | write ∩ |
/// | Next action handoff | update | handoff ∪ source |
/// | Detail complementary writes (priority / triage / …) | create / update | write ∩ |
/// | Detail Record handoff | update | handoff ∪ source |
/// | Detail Schedule in Theater | navigate / update | write ∩ |
/// | Detail Print summary | export / read | read ∩ |
/// | Open in {module} (handoff outcome) | navigate | read ∩ |
/// | Ambulance timeline panel | read | read ∩ ([ambulanceContext]) |
/// | Hard delete / void | delete | delete ∩ (no UI yet) |
/// | Nested mutation dialogs | create / update | write ∩ / handoff ∪ |
/// | Panel deep link `?panel=` | create / update | write ∩ / handoff ∪ |
/// | Route entry (deep link) | navigate | catalog ∪ |
abstract final class EmergencyCriticalAtomPermissions {
  static const AccessRequirement tab = emergencyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = emergencyWorkspaceReadRequirement;
  static const AccessRequirement search = emergencyWorkspaceReadRequirement;
  static const AccessRequirement filters = emergencyWorkspaceReadRequirement;
  static const AccessRequirement settings = emergencyWorkspaceReadRequirement;
  static const AccessRequirement empty = emergencyWorkspaceReadRequirement;
  static const AccessRequirement loading = emergencyWorkspaceReadRequirement;
  static const AccessRequirement retry = emergencyWorkspaceReadRequirement;
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyWorkspaceReadRequirement;
  static const AccessRequirement detail = emergencyWorkspaceReadRequirement;
  static const AccessRequirement criticalChip =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionDispatch =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionCompleteTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandoff =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement updatePriority =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement recordTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement triage = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement markResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement response = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement dispatch = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement startTrip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement completeTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement trip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement priority = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleTheater =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  static const AccessRequirement printSummary =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceContextReadRequirement;
  /// Nested cross-module — not used on this tab (matrix _(n/a)_).
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}

bool canViewEmergencyCritical(AppAccessPolicy policy) {
  return EmergencyCriticalAtomPermissions.tab.isAllowed(policy);
}

/// Ambulance tab atom → permission mapping (inventory + matrix).
///
/// Dispatch / trips worklist (`/emergency?scope=ambulance`). Matrix nested
/// cross-module rows are _(n/a)_. Tab read uses ∪ `emergency:read` |
/// `operations:read` for vehicle/asset context; create/update ∩
/// `emergency:write`; delete ∩ `emergency:delete` (no delete control mounted).
/// Handoff keeps source ∪. Print summary is read chrome under the tab gate.
/// Route entry keeps catalog ∪ ([routeEntry]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Ambulance tab / count badge | navigate | tab ∪ `emergency:read` \| `operations:read` |
/// | Search / Clear / Filters / Settings (columns) | read chrome | [listChrome] |
/// | Empty / loading / error / retry | read chrome | [listChrome] / page |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Quick arrival (strip primary) | create | write ∩ |
/// | Row select → case detail | read | [detail] |
/// | Next action Dispatch / Start trip / Complete trip / … | create / update | write ∩ |
/// | Next action Record handoff | update | handoff ∪ source |
/// | Detail complementary writes (priority / triage / …) | create / update | write ∩ |
/// | Detail Handoff | update | handoff ∪ source |
/// | Detail Schedule in Theater | navigate / update | write ∩ |
/// | Detail Print summary | export / read | [printSummary] |
/// | Nested mutation dialogs (dispatch / trip / …) | create / update | write ∩ |
/// | Hard delete / void | delete | delete ∩ (no UI on this tab) |
/// | Open in {module} (handoff outcome) | navigate | [detail] when handoff present |
/// | Ambulance timeline panel | read | [ambulanceContext] ∪ |
/// | Route entry (deep link) | navigate | entry ∪ |
///
/// Matrix view ∩ `emergency:read` alone remains [emergencyReadRequirement] for
/// other tabs; this strip uses [tab] ∪ so operations:read alone still shows it.
abstract final class EmergencyAmbulanceAtomPermissions {
  static const AccessRequirement tab = emergencyAmbulanceTabRequirement;
  static const AccessRequirement listChrome = emergencyAmbulanceTabRequirement;
  static const AccessRequirement search = emergencyAmbulanceTabRequirement;
  static const AccessRequirement filters = emergencyAmbulanceTabRequirement;
  static const AccessRequirement settings = emergencyAmbulanceTabRequirement;
  static const AccessRequirement empty = emergencyAmbulanceTabRequirement;
  static const AccessRequirement loading = emergencyAmbulanceTabRequirement;
  static const AccessRequirement retry = emergencyAmbulanceTabRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyAmbulanceTabRequirement;
  static const AccessRequirement detail = emergencyAmbulanceTabRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionDispatch =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionCompleteTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandoff =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement dispatch = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement startTrip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement completeTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement updatePriority =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement triage = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement response = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  static const AccessRequirement scheduleTheater =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement printSummary =
      emergencyAmbulanceTabRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyAmbulanceTabRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyAmbulanceTabRequirement;
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceTabRequirement;
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyAmbulanceTabRequirement;
  static const AccessRequirement panelDeepLink =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}

bool canViewEmergencyClosed(AppAccessPolicy policy) {
  return EmergencyClosedAtomPermissions.tab.isAllowed(policy);
}

/// Handoff ready tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=handoff` — cases ready for ward/OPD handoff. Quick arrival
/// / triage / response / dispatch / trip / priority / Schedule in Theater need
/// ∩ `emergency:write`. Record handoff keeps source ∪ (emergency \| patient \|
/// clinical \| operations write) so admit-capable clinical staff can hand off
/// without emergency:write. Hard delete/void needs ∩ `emergency:delete` (no
/// delete control mounted). Matrix nested cross-module rows _(n/a)_. Route
/// entry keeps catalog ∪ ([routeEntry]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Handoff ready tab / count badge | navigate | read ∩ `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → case detail | read | read ∩ |
/// | Quick arrival | create | write ∩ |
/// | Next action Record handoff (primary on this tab) | update | handoff ∪ source |
/// | Next action triage / response / dispatch / trip | create / update | write ∩ |
/// | Detail complementary writes (priority / triage / …) | create / update | write ∩ |
/// | Detail Record handoff | update | handoff ∪ source |
/// | Detail Schedule in Theater | navigate / update | write ∩ |
/// | Detail Print summary | export / read | read ∩ |
/// | Open in {module} (handoff outcome) | navigate | read ∩ |
/// | Ambulance timeline panel | read | read ∩ ([ambulanceContext]) |
/// | Hard delete / void | delete | delete ∩ (no UI yet) |
/// | Nested mutation dialogs | create / update | write ∩ / handoff ∪ |
/// | Panel deep link `?panel=handoff` | update | handoff ∪ |
/// | Route entry (deep link) | navigate | catalog ∪ |
abstract final class EmergencyHandoffAtomPermissions {
  static const AccessRequirement tab = emergencyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = emergencyWorkspaceReadRequirement;
  static const AccessRequirement search = emergencyWorkspaceReadRequirement;
  static const AccessRequirement filters = emergencyWorkspaceReadRequirement;
  static const AccessRequirement settings = emergencyWorkspaceReadRequirement;
  static const AccessRequirement empty = emergencyWorkspaceReadRequirement;
  static const AccessRequirement loading = emergencyWorkspaceReadRequirement;
  static const AccessRequirement retry = emergencyWorkspaceReadRequirement;
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyWorkspaceReadRequirement;
  static const AccessRequirement detail = emergencyWorkspaceReadRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionDispatch =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionStartTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionCompleteTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextActionHandoff =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement triage = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement recordTriage =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement response = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement markResponse =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement dispatch = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement trip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement startTrip = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement completeTrip =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement priority = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement updatePriority =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement scheduleTheater =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  static const AccessRequirement printSummary =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceContextReadRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses emergency write/read only.
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}

/// Closed tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=closed`. Closed cases; no Quick arrival; no next-action
/// column. Detail omits complementary writes (`isOpen` false). Panel deep
/// links fall back to read detail for closed cases. Hard delete / void maps
/// to [delete] but inventory has no delete control yet — gate kept so
/// write-only staff never gain delete. Matrix nested cross-module rows
/// _(n/a)_. Route entry keeps catalog ∪ ([routeEntry] / [routeEntryUnion]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Closed tab / count badge | navigate | read ∩ `emergency:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → detail | read | read ∩ |
/// | Quick arrival | create | write ∩ (absent on Closed) |
/// | Next action column / cells | update | write ∩ (absent on Closed) |
/// | Detail complementary writes | create / update | write ∩ (absent when closed) |
/// | Detail Print summary | export / read | read ∩ |
/// | Detail Open in {module} | navigate | read ∩ |
/// | Detail Ambulance / timeline panels | read | read ∩ |
/// | Hard delete / void | delete | delete ∩ `emergency:delete` (no UI yet) |
/// | Nested mutation / panel deep link | create / update | write ∩ (closed → detail) |
/// | Route entry (deep link) | navigate | catalog ∪ |
abstract final class EmergencyClosedAtomPermissions {
  static const AccessRequirement tab = emergencyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = emergencyWorkspaceReadRequirement;
  static const AccessRequirement search = emergencyWorkspaceReadRequirement;
  static const AccessRequirement filters = emergencyWorkspaceReadRequirement;
  static const AccessRequirement settings = emergencyWorkspaceReadRequirement;
  static const AccessRequirement empty = emergencyWorkspaceReadRequirement;
  static const AccessRequirement loading = emergencyWorkspaceReadRequirement;
  static const AccessRequirement retry = emergencyWorkspaceReadRequirement;
  static const AccessRequirement success = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = emergencyWorkspaceReadRequirement;
  static const AccessRequirement detail = emergencyWorkspaceReadRequirement;
  static const AccessRequirement printSummary =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openInReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement openReceivingModule =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement ambulancePanel =
      emergencyAmbulanceContextReadRequirement;
  static const AccessRequirement timelinePanel =
      emergencyWorkspaceReadRequirement;
  static const AccessRequirement ambulanceContext =
      emergencyAmbulanceContextReadRequirement;
  static const AccessRequirement quickArrival =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nextAction =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement create = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement update = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement write = emergencyWorkspaceWriteRequirement;
  static const AccessRequirement delete = emergencyWorkspaceDeleteRequirement;
  static const AccessRequirement handoffWrite =
      emergencyHandoffWriteRequirement;
  static const AccessRequirement handoff = emergencyHandoffWriteRequirement;
  /// Nested cross-module — not used on this tab (matrix _(n/a)_).
  static const AccessRequirement nestedWrite =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = emergencyWorkspaceReadRequirement;
  /// Panel deep-link write gate; closed cases still open read detail only.
  static const AccessRequirement panelDeepLink =
      emergencyWorkspaceWriteRequirement;
  static const AccessRequirement entry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = emergencyWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      emergencyWorkspaceRouteUnionRequirement;
}
