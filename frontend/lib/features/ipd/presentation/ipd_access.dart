import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

/// Module entitlement for the IPD workspace route and board tabs.
const String ipdInpatientBedManagementModule = 'inpatient-bed-management';

const List<AppRole> _ipdAdminActionRoles = <AppRole>[
  AppRole.platformAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

/// View / read UI (matrix ∪): `clinical:read` | `operations:read` + module.
///
/// Billing-only route entry does **not** satisfy board chrome — see [routeEntry].
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
/// (∪ `ipd:read` | `clinical:read` | `operations:read` | `billing:read` + module).
///
/// Matches [AppRoutes.ipd] `requiredAnyPermissions`. Matrix view chrome still
/// uses [ipdWorkspaceReadRequirement] (no `billing:read` / `ipd:read` alone for tabs).
const AccessRequirement ipdWorkspaceEntryRequirement =
    RouteAccessCatalog.ipdEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement ipdWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.ipdEntry;

/// Alias for historical call sites.
const AccessRequirement ipdWorkspaceRouteEntryRequirement =
    ipdWorkspaceEntryRequirement;

/// Operational create / update (approve, assign bed, transfer, start admission,
/// reject).
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

/// Alias for workspace write when clinical ∩ is the verb.
const AccessRequirement ipdWorkspaceWriteRequirement =
    ipdClinicalWriteRequirement;

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

/// Alias used by Admission Queue atom map.
const AccessRequirement ipdBillingPanelReadRequirement =
    ipdBillingReadRequirement;

/// Manage beds → `/rooms-beds` (facility/tenant/system admin + module).
///
/// Prompt also lists `unit:manage`; source inventory keeps rooms-beds admin
/// gates only (no `unit:manage`) so HR unit packs do not unlock manage — keep
/// source.
const AccessRequirement ipdBedManageRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    AppRole.platformAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
  ],
  anyPermissions: <AppPermission>[
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.platformAdmin,
  ],
  activeModules: <String>[ipdInpatientBedManagementModule],
);

/// Follow-ups tab / panel read (matrix ∪): `clinical:read` | `operations:read`.
///
/// Shared [FollowUpWorklistPanel] defaults to reception ∪; IPD overrides with
/// this requirement (see Follow-ups tab permission scan).
const AccessRequirement ipdFollowUpsRequirement = ipdWorkspaceReadRequirement;

/// Follow-ups complete / reschedule / delete — matrix ∩ `clinical:write`
/// (reuses [ipdClinicalWriteRequirement] roles + module).
const AccessRequirement ipdFollowUpsWriteRequirement =
    ipdClinicalWriteRequirement;

/// IPD board list Export / Print (worklist Excel + preview print).
///
/// Uses ∩ `evidence:export` (same atom as Reception / Patients / OPD export).
const AccessRequirement ipdWorkspaceExportRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.evidenceExport],
);

/// Alias — Print uses the same desk export gate.
const AccessRequirement ipdWorkspacePrintRequirement =
    ipdWorkspaceExportRequirement;

bool canExportIpdWorkspace(AppAccessPolicy policy) {
  return ipdWorkspaceExportRequirement.isAllowed(policy);
}

bool canPrintIpdWorkspace(AppAccessPolicy policy) {
  return ipdWorkspacePrintRequirement.isAllowed(policy);
}

/// Per-section tab strip gate.
AccessRequirement ipdBoardTabRequirement(IpdWorkspaceSection section) {
  return switch (section) {
    IpdWorkspaceSection.admissionQueue => IpdAdmissionQueueAtomPermissions.tab,
    IpdWorkspaceSection.activePatients => IpdActivePatientsAtomPermissions.tab,
    IpdWorkspaceSection.transferPending => IpdTransfersAtomPermissions.tab,
    IpdWorkspaceSection.dischargePlanned => IpdDischargeAtomPermissions.tab,
    IpdWorkspaceSection.bedBoard => IpdBedBoardAtomPermissions.tab,
    IpdWorkspaceSection.followUps => IpdFollowUpsAtomPermissions.tab,
  };
}

/// Alias used by Admission Queue / shared call sites.
AccessRequirement ipdSectionTabRequirement(IpdWorkspaceSection section) {
  return ipdBoardTabRequirement(section);
}

bool canViewIpdTab(AppAccessPolicy policy, IpdWorkspaceSection section) {
  return ipdBoardTabRequirement(section).isAllowed(policy);
}

bool canViewIpdAdmissionQueue(AppAccessPolicy policy) {
  return IpdAdmissionQueueAtomPermissions.tab.isAllowed(policy);
}

bool canViewIpdActivePatients(AppAccessPolicy policy) {
  return IpdActivePatientsAtomPermissions.tab.isAllowed(policy);
}

bool canViewIpdDischarge(AppAccessPolicy policy) {
  return IpdDischargeAtomPermissions.tab.isAllowed(policy);
}

bool canViewIpdTransfers(AppAccessPolicy policy) {
  return IpdTransfersAtomPermissions.tab.isAllowed(policy);
}

bool canViewIpdBedBoard(AppAccessPolicy policy) {
  return IpdBedBoardAtomPermissions.tab.isAllowed(policy);
}

bool canViewIpdFollowUps(AppAccessPolicy policy) {
  return IpdFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadIpdFollowUps(AppAccessPolicy policy) {
  return ipdFollowUpsRequirement.isAllowed(policy);
}

bool canWriteIpdFollowUps(AppAccessPolicy policy) {
  return ipdFollowUpsWriteRequirement.isAllowed(policy);
}

bool canReadIpd(AppAccessPolicy policy) {
  return ipdWorkspaceReadRequirement.isAllowed(policy);
}

bool canOperateIpd(AppAccessPolicy policy) {
  return ipdOperationalWriteRequirement.isAllowed(policy);
}

/// Alias matching Admission Queue call sites.
bool canWriteIpdOperational(AppAccessPolicy policy) {
  return canOperateIpd(policy);
}

bool canWriteIpdClinical(AppAccessPolicy policy) {
  return ipdClinicalWriteRequirement.isAllowed(policy);
}

bool canDeleteIpd(AppAccessPolicy policy) {
  return ipdWorkspaceDeleteRequirement.isAllowed(policy);
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
  if (allowed.contains(IpdWorkspaceSection.admissionQueue)) {
    return IpdWorkspaceSection.admissionQueue;
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

/// Admission Queue tab atom → permission mapping (inventory + matrix).
///
/// Pending admissions (`/ipd` or `?section=admission-queue`). Nested
/// cross-module matrix rows are _(n/a)_ except billing panels ([billingPanel] /
/// [billingRead] — ∩ `billing:read` + `billing-payments`). Start admission /
/// approve / assign bed / reject keep source operational write ∪
/// `clinical:write` | `operations:write` rather than matrix ∩ `clinical:write`
/// alone. Clinical detail writes / orders use [clinicalWrite]. Manage beds is
/// bed-board chrome ([manageBeds]) — not mounted as primary on this tab. Route
/// entry ∪ is [routeEntry] (includes `billing:read` alone for shell entry, not
/// tab chrome).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Admission Queue tab / count badge | navigate | read ∪ ([tab]) |
/// | Start admission (toolbar primary) | create | operational write ∪ ([startAdmission]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | operational write / form |
/// | Row select → admission detail | read | ([detail]) |
/// | Next action Approve admission | update / approve | operational ∪ ([nextActionApprove]) |
/// | Next action Assign bed | update | operational ∪ ([nextActionAssignBed]) |
/// | Next action Manage / Request transfer | create / update | operational ∪ |
/// | Next action nursing note / discharge | create / update | clinical write |
/// | Next action theatre handover | navigate | ([navigation]) |
/// | Next action Continue care (label) | progressive disclosure | read ∪ ([nextActionContinueCare]) |
/// | Detail complementary operational writes | create / update / delete | operational ∪ |
/// | Detail complementary clinical writes / orders | create / update | clinical write |
/// | Detail Open ICU / Theater / Nursing | navigate | ([navigation]) |
/// | Detail insurance / billing / ward-round billing | nested read | ([billingPanel]) |
/// | Nested mutation dialogs / `panel=` / `action=` deep link | create / update | ([panelDeepLink]) |
/// | Manage beds → `/rooms-beds` | navigate | ([manageBeds]) — not primary on this tab |
/// | Route entry (deep link) | navigate | clinical \| operations \| billing:read ([routeEntry]) |
abstract final class IpdAdmissionQueueAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
  static const AccessRequirement empty = ipdWorkspaceReadRequirement;
  static const AccessRequirement loading = ipdWorkspaceReadRequirement;
  static const AccessRequirement retry = ipdWorkspaceReadRequirement;
  static const AccessRequirement success = ipdOperationalWriteRequirement;
  static const AccessRequirement validation = ipdOperationalWriteRequirement;
  static const AccessRequirement rowSelect = ipdWorkspaceReadRequirement;
  static const AccessRequirement detail = ipdWorkspaceReadRequirement;
  /// Start admission / approve / assign keep source operational ∪ (matrix ∩ clinical:write).
  static const AccessRequirement create = ipdOperationalWriteRequirement;
  static const AccessRequirement update = ipdOperationalWriteRequirement;
  static const AccessRequirement delete = ipdWorkspaceDeleteRequirement;
  static const AccessRequirement write = ipdOperationalWriteRequirement;
  static const AccessRequirement clinicalWrite = ipdClinicalWriteRequirement;
  static const AccessRequirement operationalWrite =
      ipdOperationalWriteRequirement;
  static const AccessRequirement startAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextAction = ipdOperationalWriteRequirement;
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
  static const AccessRequirement planOrManageDischarge =
      ipdClinicalWriteRequirement;
  static const AccessRequirement planDischarge = ipdClinicalWriteRequirement;
  static const AccessRequirement wardRound = ipdClinicalWriteRequirement;
  static const AccessRequirement medication = ipdClinicalWriteRequirement;
  static const AccessRequirement clinicalOrders = ipdClinicalWriteRequirement;
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
  static const AccessRequirement billingPanel = ipdBillingPanelReadRequirement;
  static const AccessRequirement billingRead = ipdBillingReadRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses operational write ∪.
  static const AccessRequirement nestedWrite = ipdOperationalWriteRequirement;
  /// Nested cross-module read — billing panel uses [billingPanel]; other nested
  /// read reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = ipdOperationalWriteRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}

/// Active Patients tab atom → permission mapping (inventory + matrix).
///
/// Current inpatients (`/ipd?section=active`). Nested cross-module matrix rows
/// are _(n/a)_ except billing panels ([billingPanel] / [billingRead] —
/// ∩ `billing:read` + `billing-payments`). Start admission / transfer / reject
/// keep source operational write ∪ `clinical:write` | `operations:write`
/// rather than matrix ∩ `clinical:write` alone. Clinical writes / nursing /
/// orders / discharge planning use [clinicalWrite] (∩ `clinical:write` +
/// source roles + module). Manage beds is bed-board chrome ([manageBeds]) —
/// not mounted on Active. Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active Patients tab / count badge | navigate | read ∪ ([tab]) |
/// | Start admission (toolbar) | create | operational write ∪ ([startAdmission]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | clinical write / form |
/// | Row select → admission detail | read | ([detail]) |
/// | Next action approve / assign bed / transfer | create / update | operational ∪ |
/// | Next action nursing note / plan discharge | create / update | clinical write |
/// | Next action theatre handover | navigate | ([navigation]) |
/// | Next action continue care (label) | progressive disclosure | read ∪ |
/// | Detail complementary writes | create / update / delete | operational / clinical |
/// | Detail insurance / billing / ward-round billing | nested read | ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Nested mutation dialogs / `panel=` deep link | create / update | matching write |
/// | Manage beds | navigate | ([manageBeds]) — not mounted on this tab |
/// | Route entry (deep link) | navigate | clinical \| operations \| billing:read |
abstract final class IpdActivePatientsAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
  static const AccessRequirement empty = ipdWorkspaceReadRequirement;
  static const AccessRequirement loading = ipdWorkspaceReadRequirement;
  static const AccessRequirement retry = ipdWorkspaceReadRequirement;
  static const AccessRequirement success = ipdClinicalWriteRequirement;
  static const AccessRequirement validation = ipdClinicalWriteRequirement;
  static const AccessRequirement rowSelect = ipdWorkspaceReadRequirement;
  static const AccessRequirement detail = ipdWorkspaceReadRequirement;
  /// Matrix ∩ `clinical:write` for clinical creates; Start admission uses
  /// [startAdmission] (source operational ∪).
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
  static const AccessRequirement planOrManageDischarge =
      ipdClinicalWriteRequirement;
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
  static const AccessRequirement billingPanel = ipdBillingPanelReadRequirement;
  /// Navigate to Billing workspace for settle / adjust / refund (no inline cashier).
  static const AccessRequirement openBilling = ipdBillingReadRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses clinical write ∩.
  static const AccessRequirement nestedWrite = ipdClinicalWriteRequirement;
  /// Nested cross-module read — billing panel uses [billingPanel]; other nested
  /// read reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = ipdOperationalWriteRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}

/// Bed board tab atom → permission mapping (inventory + matrix).
///
/// Occupancy board (`/ipd?section=bed-board`). Read view ∪ `clinical:read` |
/// `operations:read` + module. Start admission keeps source operational write ∪
/// (matrix ∩ `clinical:write` alone — keep source). Bed status next-actions and
/// Manage beds use [manageBeds] / [ipdBedManageRequirement] — prompt nested
/// matrix lists `unit:manage` | facility/tenant admin; source inventory keeps
/// rooms-beds admin perms only (no `unit:manage`). Billing panels in admission
/// detail / ward-round dialogs need ∩ [billingPanel]. Route entry ∪ is
/// [routeEntry] (includes `billing:read` alone for shell entry, not tab chrome).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Bed board tab | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar (start admission) | visible feedback | operational write ([success]) |
/// | Validation (authorized forms) | visible feedback | operational / manage |
/// | Row select → admission detail (occupied) | read | ([rowSelect] / [detail]) |
/// | Next action bed status (Reserve / Block / …) | update | ([nextAction] / [bedStatusUpdate]) |
/// | Start admission | create | operational write ([startAdmission]) |
/// | Manage beds → `/rooms-beds` | nested write / navigate | ([manageBeds]) |
/// | Detail complementary writes | create / update / delete | operational / clinical write |
/// | Detail / ward-round billing panels | nested read | ([billingPanel]) |
/// | `panel=` / `action=` deep link from board | create / update | ([panelDeepLink]) |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IpdBedBoardAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
  static const AccessRequirement empty = ipdWorkspaceReadRequirement;
  static const AccessRequirement loading = ipdWorkspaceReadRequirement;
  static const AccessRequirement retry = ipdWorkspaceReadRequirement;
  static const AccessRequirement success = ipdOperationalWriteRequirement;
  static const AccessRequirement validation = ipdOperationalWriteRequirement;
  static const AccessRequirement rowSelect = ipdWorkspaceReadRequirement;
  static const AccessRequirement detail = ipdWorkspaceReadRequirement;
  /// Matrix ∩ `clinical:write` alone — start admission keeps source operational ∪.
  static const AccessRequirement create = ipdOperationalWriteRequirement;
  /// Bed status mutations keep source manage gate (not matrix clinical:write).
  static const AccessRequirement update = ipdBedManageRequirement;
  static const AccessRequirement delete = ipdWorkspaceDeleteRequirement;
  static const AccessRequirement write = ipdOperationalWriteRequirement;
  static const AccessRequirement clinicalWrite = ipdClinicalWriteRequirement;
  static const AccessRequirement operationalWrite =
      ipdOperationalWriteRequirement;
  static const AccessRequirement startAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement nextAction = ipdBedManageRequirement;
  static const AccessRequirement bedStatusUpdate = ipdBedManageRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  static const AccessRequirement billingPanel = ipdBillingPanelReadRequirement;
  static const AccessRequirement billingRead = ipdBillingReadRequirement;
  /// Nested cross-module write for Manage beds (source admin ∪, no unit:manage).
  static const AccessRequirement nestedWrite = ipdBedManageRequirement;
  /// Nested cross-module read — billing panels use [billingPanel]; other nested
  /// read (admission detail from occupied row) reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement navigation = AccessRequirement();
  static const AccessRequirement panelDeepLink = ipdOperationalWriteRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}

/// Discharge tab atom → permission mapping (inventory + matrix).
///
/// Discharge planning handoff (`/ipd?section=discharge`). Nested cross-module
/// matrix rows are _(n/a)_ except billing panels ([billingPanel] /
/// [billingRead] — ∩ `billing:read` + `billing-payments` for clearance).
/// Operational writes keep source ∪ `clinical:write` | `operations:write`.
/// Clinical writes / plan-manage discharge use [clinicalWrite] (∩
/// `clinical:write` + source roles + module). Route entry ∪ is [routeEntry].
/// Start admission uses [startAdmission]. Manage beds is bed-board chrome
/// ([manageBeds]) — not mounted on Discharge.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Discharge tab / count badge | navigate | read ∪ ([tab]) |
/// | Start admission (toolbar) | create | operational write ∪ ([startAdmission]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → admission detail | read | ([detail]) |
/// | Next action approve / assign bed / transfer | create / update | operational ∪ |
/// | Next action nursing note / plan-manage discharge | create / update | clinical write ([planOrManageDischarge]) |
/// | Next action theatre handover | navigate | ([navigation]) |
/// | Next action continue care (label) | progressive disclosure | read ∪ |
/// | Detail complementary writes / clinical orders | create / update / delete | operational / clinical |
/// | Detail release bed (discharge planned) | update | operational ∪ ([releaseBed]) |
/// | Detail insurance / billing panel | nested read | ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) — Billing workspace |
/// | Nested mutation dialogs / `panel=discharge` deep link | create / update | clinical write ([panelDeepLink]) |
/// | Manage beds | navigate | ([manageBeds]) — not mounted on this tab |
/// | Route entry (deep link) | navigate | clinical \| operations \| billing:read |
abstract final class IpdDischargeAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
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
  static const AccessRequirement planOrManageDischarge =
      ipdClinicalWriteRequirement;
  static const AccessRequirement planDischarge = ipdClinicalWriteRequirement;
  static const AccessRequirement manageDischarge = ipdClinicalWriteRequirement;
  static const AccessRequirement wardRound = ipdClinicalWriteRequirement;
  static const AccessRequirement medication = ipdClinicalWriteRequirement;
  static const AccessRequirement clinicalOrders = ipdClinicalWriteRequirement;
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
  static const AccessRequirement billingPanel = ipdBillingPanelReadRequirement;
  /// Navigate to Billing for final bill / refund / outstanding — never cashier.
  static const AccessRequirement openBilling = ipdBillingPanelReadRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses clinical write ∩.
  static const AccessRequirement nestedWrite = ipdClinicalWriteRequirement;
  /// Nested cross-module read — billing panel uses [billingPanel]; other nested
  /// read reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = ipdClinicalWriteRequirement;
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
      IpdDischargeAtomPermissions.routeEntry.anyPermissions.toSet();
  return routeKeys.containsAll(atomKeys) && atomKeys.containsAll(routeKeys);
}

/// Transfers tab atom → permission mapping (inventory + matrix).
///
/// Ward/bed transfers (`/ipd?section=transfers`). Nested cross-module matrix
/// rows are _(n/a)_ except billing panels ([billingPanel] / [billingRead] —
/// ∩ `billing:read` + `billing-payments`). Transfer mutations and Start
/// admission keep source operational write ∪ `clinical:write` |
/// `operations:write` rather than matrix ∩ `clinical:write` alone. Clinical
/// detail writes / orders use [clinicalWrite]. Manage beds is bed-board chrome
/// ([manageBeds]) — not mounted on Transfers. Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Transfers tab / count badge | navigate | read ∪ ([tab]) |
/// | Start admission (toolbar) | create | operational write ∪ ([startAdmission]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → admission detail | read | ([detail]) |
/// | Next action Manage transfer | update | operational ∪ ([nextActionManageTransfer]) |
/// | Next action Request transfer | create | operational ∪ ([nextActionRequestTransfer]) |
/// | Next action approve / assign bed | create / update | operational ∪ |
/// | Next action nursing note / discharge | create / update | clinical write |
/// | Next action theatre handover | navigate | ([navigation]) |
/// | Next action continue care (label) | progressive disclosure | read ∪ |
/// | Detail complementary writes | create / update / delete | operational / clinical |
/// | Detail insurance / billing panel | nested read | ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) — Billing workspace |
/// | Nested transfer dialogs / `panel=transfers` deep link | create / update | operational ∪ |
/// | Manage beds | navigate | ([manageBeds]) — not mounted on this tab |
/// | Route entry (deep link) | navigate | clinical \| operations \| billing:read |
abstract final class IpdTransfersAtomPermissions {
  static const AccessRequirement tab = ipdWorkspaceReadRequirement;
  static const AccessRequirement listChrome = ipdWorkspaceReadRequirement;
  static const AccessRequirement search = ipdWorkspaceReadRequirement;
  static const AccessRequirement filters = ipdWorkspaceReadRequirement;
  static const AccessRequirement settings = ipdWorkspaceReadRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
  static const AccessRequirement empty = ipdWorkspaceReadRequirement;
  static const AccessRequirement loading = ipdWorkspaceReadRequirement;
  static const AccessRequirement retry = ipdWorkspaceReadRequirement;
  static const AccessRequirement success = ipdOperationalWriteRequirement;
  static const AccessRequirement validation = ipdOperationalWriteRequirement;
  static const AccessRequirement rowSelect = ipdWorkspaceReadRequirement;
  static const AccessRequirement detail = ipdWorkspaceReadRequirement;
  /// Transfer create/update keep source operational ∪ (matrix ∩ clinical:write).
  static const AccessRequirement create = ipdOperationalWriteRequirement;
  static const AccessRequirement update = ipdOperationalWriteRequirement;
  static const AccessRequirement delete = ipdWorkspaceDeleteRequirement;
  static const AccessRequirement write = ipdOperationalWriteRequirement;
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
  static const AccessRequirement billingPanel = ipdBillingPanelReadRequirement;
  static const AccessRequirement openBilling = ipdBillingPanelReadRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  /// Nested cross-module write — matrix _(n/a)_; reuses operational write ∪.
  static const AccessRequirement nestedWrite = ipdOperationalWriteRequirement;
  /// Nested cross-module read — billing panel uses [billingPanel]; other nested
  /// read reuses board read ∪.
  static const AccessRequirement nestedRead = ipdWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = ipdOperationalWriteRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}

/// Follow-ups tab atom → permission mapping (inventory + matrix).
///
/// Shared follow-up worklist (`/ipd?section=follow-ups`). Hosted via
/// [FollowUpWorklistPanel] with IPD read/write overrides. Nested cross-module
/// matrix rows are _(n/a)_ — [nestedWrite] / [nestedRead] reuse clinical write ∩
/// / board read ∪ only (no admission billing panels / Start admission on this
/// tab). Create / update / delete use matrix ∩ `clinical:write` via
/// [ipdClinicalWriteRequirement]. Route entry ∪ is [routeEntry]. Tab chrome
/// stays ∪ `clinical:read` | `operations:read`. No row next-action / admission
/// detail on this tab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups tab / count badge | navigate | read ∪ ([tab]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Export / Print | export | ∩ `evidence:export` ([export] / [print]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Start admission / Manage beds | create / navigate | absent on this tab |
/// | Nested billing panel | nested read | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | AppRoutes ∪ ([routeEntry]) |
abstract final class IpdFollowUpsAtomPermissions {
  static const AccessRequirement tab = ipdFollowUpsRequirement;
  static const AccessRequirement listChrome = ipdFollowUpsRequirement;
  static const AccessRequirement search = ipdFollowUpsRequirement;
  static const AccessRequirement filters = ipdFollowUpsRequirement;
  static const AccessRequirement settings = ipdFollowUpsRequirement;
  static const AccessRequirement export = ipdWorkspaceExportRequirement;
  static const AccessRequirement print = ipdWorkspacePrintRequirement;
  static const AccessRequirement empty = ipdFollowUpsRequirement;
  static const AccessRequirement loading = ipdFollowUpsRequirement;
  static const AccessRequirement retry = ipdFollowUpsRequirement;
  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = ipdFollowUpsWriteRequirement;
  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation = ipdFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = ipdFollowUpsRequirement;
  static const AccessRequirement detail = ipdFollowUpsRequirement;
  static const AccessRequirement close = ipdFollowUpsRequirement;
  static const AccessRequirement create = ipdFollowUpsWriteRequirement;
  static const AccessRequirement update = ipdFollowUpsWriteRequirement;
  static const AccessRequirement delete = ipdFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = ipdFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted = ipdFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp = ipdFollowUpsWriteRequirement;
  static const AccessRequirement write = ipdFollowUpsWriteRequirement;
  static const AccessRequirement clinicalWrite = ipdClinicalWriteRequirement;
  static const AccessRequirement startAdmission =
      ipdOperationalWriteRequirement;
  static const AccessRequirement manageBeds = ipdBedManageRequirement;
  static const AccessRequirement billingRead = ipdBillingReadRequirement;
  /// Nested cross-module — matrix _(n/a)_; reuses clinical write ∩ / read ∪.
  static const AccessRequirement nestedWrite = ipdFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = ipdFollowUpsRequirement;
  static const AccessRequirement entry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = ipdWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      ipdWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.ipdEntry;
}
