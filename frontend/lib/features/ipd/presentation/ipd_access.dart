import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

/// Module entitlement for the IPD workspace route and board tabs.
const String ipdInpatientBedManagementModule = 'inpatient-bed-management';

const List<AppRole> _ipdAdminActionRoles = <AppRole>[
  AppRole.superAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

/// View / read UI (matrix ∪): `clinical:read` | `operations:read` + module.
///
/// Billing-only route entry does **not** satisfy Active Patients chrome.
const AccessRequirement ipdWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.operationsRead,
  ],
  activeModules: <String>[ipdInpatientBedManagementModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement ipdReadRequirement = ipdWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.ipd]
/// (∪ `clinical:read` | `operations:read` | `billing:read` + module).
///
/// Matches [AppRoutes.ipd] `requiredAnyPermissions`. Matrix view chrome still
/// uses [ipdWorkspaceReadRequirement] (no `billing:read` alone for Active).
const AccessRequirement ipdWorkspaceEntryRequirement =
    RouteAccessCatalog.ipdEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement ipdWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.ipdEntry;

/// Alias for historical call sites.
const AccessRequirement ipdWorkspaceRouteEntryRequirement =
    ipdWorkspaceEntryRequirement;

/// Operational create / update (approve, assign bed, transfer, start admission).
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/ipd.md`)
/// documents [ipdOperationalWriteRequirement] as ∪ `clinical:write` |
/// `operations:write` + roles + module — keep source.
const AccessRequirement ipdOperationalWriteRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._ipdAdminActionRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.operations,
    AppRole.icuManager,
  ],
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[ipdInpatientBedManagementModule],
);

/// Clinical create / update (nursing note, discharge, orders, rounds).
///
/// Aligns with matrix ∩ `clinical:write` (+ source roles + module).
const AccessRequirement ipdClinicalWriteRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._ipdAdminActionRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.icuManager,
  ],
  anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  activeModules: <String>[ipdInpatientBedManagementModule],
);

/// Delete / reject — source uses operational write ∪ (matrix ∩ `clinical:write`
/// alone — keep source).
const AccessRequirement ipdWorkspaceDeleteRequirement =
    ipdOperationalWriteRequirement;

/// Alias matching matrix create/update/delete when clinical ∩ is intended.
const AccessRequirement ipdWriteRequirement = ipdClinicalWriteRequirement;

/// Navigation chrome (Open ICU / Theater / Nursing) — no write.
const AccessRequirement ipdNavigationRequirement = AccessRequirement();

/// Nested billing / insurance panels inside admission detail.
///
/// Prompt note: billing panels need `billing:read` (matrix nested rows _(n/a)_
/// for other cross-module UI; this is the documented billing gate).
const AccessRequirement ipdBillingReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>['billing-payments'],
);

/// Manage beds → `/rooms-beds` (facility/tenant/system admin + module).
///
/// Prompt also lists `unit:manage`; source inventory keeps rooms-beds admin
/// gates only (no `unit:manage`) so HR unit packs do not unlock manage — keep
/// source.
const AccessRequirement ipdBedManageRequirement = AccessRequirement(
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
  activeModules: <String>[ipdInpatientBedManagementModule],
);

/// Per-section tab strip gate (Active Patients matrix ∪ read).
AccessRequirement ipdBoardTabRequirement(IpdWorkspaceSection section) {
  return switch (section) {
    IpdWorkspaceSection.activePatients => IpdActivePatientsAtomPermissions.tab,
    // Other tabs share the same board read ∪ until their scans refine gates.
    IpdWorkspaceSection.admissionQueue ||
    IpdWorkspaceSection.transferPending ||
    IpdWorkspaceSection.dischargePlanned ||
    IpdWorkspaceSection.bedBoard ||
    IpdWorkspaceSection.followUps => ipdWorkspaceReadRequirement,
  };
}

bool canViewIpdTab(AppAccessPolicy policy, IpdWorkspaceSection section) {
  return ipdBoardTabRequirement(section).isAllowed(policy);
}

bool canViewIpdActivePatients(AppAccessPolicy policy) {
  return IpdActivePatientsAtomPermissions.tab.isAllowed(policy);
}

bool canReadIpd(AppAccessPolicy policy) {
  return ipdWorkspaceReadRequirement.isAllowed(policy);
}

bool canOperateIpd(AppAccessPolicy policy) {
  return ipdOperationalWriteRequirement.isAllowed(policy);
}

bool canWriteIpdClinical(AppAccessPolicy policy) {
  return ipdClinicalWriteRequirement.isAllowed(policy);
}

bool canManageIpdBeds(AppAccessPolicy policy) {
  return ipdBedManageRequirement.isAllowed(policy);
}

bool canReadIpdBilling(AppAccessPolicy policy) {
  return ipdBillingReadRequirement.isAllowed(policy);
}

bool canEnterIpdWorkspace(AppAccessPolicy policy) {
  return ipdWorkspaceEntryRequirement.isAllowed(policy);
}

/// Tabs the user may open; empty when no board read passes.
List<IpdWorkspaceSection> ipdAllowedSections(AppAccessPolicy policy) {
  return IpdWorkspaceSection.values
      .where((IpdWorkspaceSection section) => canViewIpdTab(policy, section))
      .toList(growable: false);
}

IpdWorkspaceSection? ipdFallbackSection(AppAccessPolicy policy) {
  final List<IpdWorkspaceSection> allowed = ipdAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(IpdWorkspaceSection.activePatients)) {
    return IpdWorkspaceSection.activePatients;
  }
  return allowed.first;
}

/// Whether the Next action column mounts for [section].
///
/// Queue tabs keep the column so navigate / continue-care labels remain for
/// readers; write buttons hide via [AppAccessActionGate].
bool ipdBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  IpdWorkspaceSection section,
) {
  if (section.isBedBoard || section.isFollowUps) {
    return false;
  }
  return canViewIpdTab(policy, section);
}

/// Requirement for a deep-linked `panel=` / `action=` mutation.
AccessRequirement? ipdFocusedMutationRequirement({
  IpdDetailPanel? panel,
  String? action,
}) {
  final String normalizedAction = (action ?? '').trim().toLowerCase();
  if (normalizedAction == 'approve') {
    return ipdOperationalWriteRequirement;
  }
  return switch (panel) {
    IpdDetailPanel.beds ||
    IpdDetailPanel.transfer => ipdOperationalWriteRequirement,
    IpdDetailPanel.discharge ||
    IpdDetailPanel.nursing => ipdClinicalWriteRequirement,
    IpdDetailPanel.medication ||
    IpdDetailPanel.rounds ||
    null => null,
  };
}

/// Active Patients tab atom → permission mapping (inventory + matrix).
///
/// Current inpatients (`/ipd?section=active`). Nested cross-module matrix rows
/// are _(n/a)_ except billing panels ([billingRead]). Operational writes keep
/// source ∪ `clinical:write` | `operations:write` rather than matrix ∩
/// `clinical:write` alone. Clinical writes / orders use [clinicalWrite]. Route
/// entry ∪ is [routeEntry]. Start admission uses [operationalWrite]. Manage
/// beds is bed-board chrome ([manageBeds]) — not mounted on Active.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active Patients tab / count badge | navigate | read ∪ ([tab]) |
/// | Start admission (toolbar) | create | operational write ∪ ([startAdmission]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → admission detail | read | ([detail]) |
/// | Next action approve / assign bed / transfer | create / update | operational ∪ |
/// | Next action nursing note / discharge | create / update | clinical write |
/// | Next action theatre handover | navigate | ([navigation]) |
/// | Next action continue care (label) | progressive disclosure | read ∪ |
/// | Detail complementary writes | create / update / delete | operational / clinical |
/// | Detail insurance / billing panel | nested read | ([billingRead]) |
/// | Nested mutation dialogs / `panel=` deep link | create / update | matching write |
/// | Route entry (deep link) | navigate | clinical \| operations \| billing:read |
abstract final class IpdActivePatientsAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement empty = ipdWorkspaceReadRequirement;
  static const AccessRequirement loading = ipdWorkspaceReadRequirement;
  static const AccessRequirement retry = ipdWorkspaceReadRequirement;
  static const AccessRequirement success = ipdClinicalWriteRequirement;
  static const AccessRequirement validation = ipdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = ipdWorkspaceReadRequirement;
  static const AccessRequirement detail = ipdWorkspaceReadRequirement;
  static const AccessRequirement create = ipdClinicalWriteRequirement;
  static const AccessRequirement update = ipdClinicalWriteRequirement;
  static const AccessRequirement delete = ipdWorkspaceDeleteRequirement;
  static const AccessRequirement write = ipdClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = ipdClinicalWriteRequirement;
  static const AccessRequirement operationalWrite =
      ipdOperationalWriteRequirement;
  static const AccessRequirement startAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextActionApprove =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextActionAssignBed =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextActionManageTransfer =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextActionRequestTransfer =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextActionNursingNote =
      ipdClinicalWriteRequirement;
  static const AccessRequirement nextActionDischarge =
      ipdClinicalWriteRequirement;
  static const AccessRequirement nextActionTheatreHandover =
      ipdNavigationRequirement;
  static const AccessRequirement nextActionContinueCare =
      ipdWorkspaceReadRequirement;
  static const AccessRequirement approveAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement assignBed = ipdOperationalWriteRequirement;
  static const AccessRequirement requestTransfer =
      ipdOperationalWriteRequirement;
  static const AccessRequirement manageTransfer =
      ipdOperationalWriteRequirement;
  static const AccessRequirement releaseBed = ipdOperationalWriteRequirement;
  static const AccessRequirement rejectAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement recordNursingNote =
      ipdClinicalWriteRequirement;
  static const AccessRequirement planDischarge = ipdClinicalWriteRequirement;
  static const AccessRequirement wardRound = ipdClinicalWriteRequirement;
  static const AccessRequirement medication = ipdClinicalWriteRequirement;
  static const AccessRequirement orderLab = ipdClinicalWriteRequirement;
  static const AccessRequirement orderRadiology = ipdClinicalWriteRequirement;
  static const AccessRequirement orderPrescription =
      ipdClinicalWriteRequirement;
  static const AccessRequirement requestTherapy = ipdClinicalWriteRequirement;
  static const AccessRequirement startIcuStay = ipdClinicalWriteRequirement;
  static const AccessRequirement openIcu = ipdNavigationRequirement;
  static const AccessRequirement openTheater = ipdNavigationRequirement;
  static const AccessRequirement openNursing = ipdNavigationRequirement;
  static const AccessRequirement openPhysiotherapy = ipdNavigationRequirement;
  static const AccessRequirement navigation = ipdNavigationRequirement;
  static const AccessRequirement billingRead = ipdBillingReadRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses clinical write ∩.
  static const AccessRequirement nestedWrite = ipdClinicalWriteRequirement;
  /// Nested cross-module read — billing panel uses [billingRead]; other nested
  /// read reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = ipdOperationalWriteRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}

bool ipdRouteEntryMatchesAppRoutes() {
  final Set<AppPermission> routeKeys = AppRoutes.ipd.requiredAnyPermissions
      .toSet();
  final Set<AppPermission> atomKeys =
      IpdActivePatientsAtomPermissions.routeEntry.anyPermissions.toSet();
  return routeKeys.containsAll(atomKeys) && atomKeys.containsAll(routeKeys);
}
