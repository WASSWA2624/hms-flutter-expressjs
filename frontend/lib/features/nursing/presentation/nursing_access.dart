import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';

/// Module entitlement for the nursing workspace route and ward tabs.
const String nursingInpatientBedModule = 'inpatient-bed-management';

/// Roles allowed for nursing clinical mutations (source inventory gate).
const List<AppRole> nursingWriteRoles = <AppRole>[
  AppRole.nurse,
  AppRole.wardManager,
  AppRole.icuManager,
  AppRole.theatreManager,
  AppRole.facilityAdmin,
  AppRole.tenantAdmin,
  AppRole.superAdmin,
];

/// View / read UI (matrix ∪): `clinical:read` | `patient:read` +
/// `inpatient-bed-management`.
const AccessRequirement nursingWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
  ],
  activeModules: <String>[nursingInpatientBedModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement nursingReadRequirement = nursingWorkspaceReadRequirement;

/// Route entry — [RouteAccessCatalog.nursingEntry] matches [AppRoutes.nursing]
/// ∪ `clinical:read` | `patient:read` | `last_office:read` | `operations:read`
/// + module. Matrix All-tab chrome still uses [nursingWorkspaceReadRequirement]
/// (`clinical:read` | `patient:read` only).
const AccessRequirement nursingWorkspaceEntryRequirement =
    RouteAccessCatalog.nursingEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement nursingWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.nursingEntry;

/// Create / update / delete nursing mutations.
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/nursing.md`)
/// documents [nursingWriteRequirement] as ∪ `clinical:write` | `patient:write` |
/// `last_office:write` + nurse/manager/admin roles + `inpatient-bed-management`
/// — keep source. `last_office:read` alone must not unlock write controls.
const AccessRequirement nursingWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
    AppPermissions.lastOfficeWrite,
  ],
  anyRoles: nursingWriteRoles,
  activeModules: <String>[nursingInpatientBedModule],
);

/// Matrix-aligned ∩ `clinical:write` (+ source roles + module). Prefer for
/// discharge / handover / transfer pending write atoms when tighter than source
/// ∪; [nursingWriteRequirement] remains the historical shared gate.
const AccessRequirement nursingClinicalWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  anyRoles: nursingWriteRoles,
  activeModules: <String>[nursingInpatientBedModule],
);

/// Shift context progressive disclosure — roster/ops read ∩ `hr-rosters`
/// (matches controller `_canReadOperationsContext`).
const AccessRequirement nursingShiftContextRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.rosterRead,
    AppPermissions.hrRead,
    AppPermissions.operationsRead,
    AppPermissions.unitRead,
  ],
  activeModules: <String>['hr-rosters'],
);

/// Medications detail panel / med due counts (∩ `pharmacy:read`).
const AccessRequirement nursingMedicationsPanelRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
);

/// Administer medication — `pharmacy:read` ∩ (`clinical:write` | `pharmacy:write`)
/// when both apply (source roles + nursing module).
const AccessRequirement nursingMedicationAdministerRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.pharmacyWrite,
      ],
      anyRoles: nursingWriteRoles,
      activeModules: <String>[nursingInpatientBedModule],
    );

/// Alias used by [nursingNextActionRequirement] / medication-due scans.
const AccessRequirement nursingMedicationWriteRequirement =
    nursingMedicationAdministerRequirement;

/// Nested cross-module read (matrix ∪): `billing:read` | `last_office:read`.
const AccessRequirement nursingNestedCrossModuleReadRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.lastOfficeRead,
      ],
    );

/// Billing clearance nested panel — reuses [billingReadRequirement]
/// (`billing:read` ∩ `billing-payments`).
const AccessRequirement nursingBillingClearanceReadRequirement =
    billingReadRequirement;

/// Last-office nested read (∩ `last_office:read`) within the nested ∪ row.
const AccessRequirement nursingLastOfficeNestedReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.lastOfficeRead],
    );

bool canReadNursing(AppAccessPolicy policy) {
  return nursingWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteNursing(AppAccessPolicy policy) {
  return nursingWriteRequirement.isAllowed(policy);
}

bool canEnterNursingWorkspace(AppAccessPolicy policy) {
  return nursingWorkspaceEntryRequirement.isAllowed(policy);
}

bool canViewNursingShiftContext(AppAccessPolicy policy) {
  return nursingShiftContextRequirement.isAllowed(policy);
}

/// Alias matching workspace page call sites.
bool canReadNursingShiftContext(AppAccessPolicy policy) {
  return canViewNursingShiftContext(policy);
}

bool canViewNursingMedicationsPanel(AppAccessPolicy policy) {
  return nursingMedicationsPanelRequirement.isAllowed(policy);
}

/// Alias used by detail panel call sites.
bool canReadNursingMedications(AppAccessPolicy policy) {
  return canViewNursingMedicationsPanel(policy);
}

bool canAdministerNursingMedication(AppAccessPolicy policy) {
  return nursingMedicationAdministerRequirement.isAllowed(policy);
}

bool canViewNursingBillingClearance(AppAccessPolicy policy) {
  return nursingBillingClearanceReadRequirement.isAllowed(policy);
}

/// Per-tab strip gate. Transfer / discharge pending use their atom maps; All
/// uses [NursingAllAtomPermissions.tab]; other scopes share workspace read ∪
/// until their tab scans land.
AccessRequirement nursingBoardTabRequirement(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => NursingAllAtomPermissions.tab,
    NursingQueueScope.transferPending =>
      NursingTransferPendingAtomPermissions.tab,
    NursingQueueScope.dischargePending =>
      NursingDischargePendingAtomPermissions.tab,
    _ => nursingWorkspaceReadRequirement,
  };
}

bool canViewNursingTab(AppAccessPolicy policy, NursingQueueScope scope) {
  return nursingBoardTabRequirement(scope).isAllowed(policy);
}

List<NursingQueueScope> nursingAllowedScopes(AppAccessPolicy policy) {
  return NursingQueueScope.values
      .where((NursingQueueScope scope) => canViewNursingTab(policy, scope))
      .toList(growable: false);
}

NursingQueueScope? nursingFallbackScope(AppAccessPolicy policy) {
  final List<NursingQueueScope> allowed = nursingAllowedScopes(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(NursingQueueScope.all)) {
    return NursingQueueScope.all;
  }
  return allowed.first;
}

/// Write gate for the active queue scope.
AccessRequirement nursingWriteRequirementForScope(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.handoverPending =>
      NursingHandoverPendingAtomPermissions.write,
    NursingQueueScope.transferPending =>
      NursingTransferPendingAtomPermissions.write,
    NursingQueueScope.dischargePending =>
      NursingDischargePendingAtomPermissions.write,
    _ => nursingWriteRequirement,
  };
}

/// Whether the Next action column mounts for [scope].
bool nursingBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  NursingQueueScope scope,
) {
  return nursingWriteRequirementForScope(scope).isAllowed(policy);
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement? nursingFocusedPanelRequirement(NursingDetailPanel panel) {
  return switch (panel) {
    NursingDetailPanel.medication => nursingMedicationAdministerRequirement,
    NursingDetailPanel.discharge =>
      NursingDischargePendingAtomPermissions.write,
    NursingDetailPanel.checklist => null,
    NursingDetailPanel.vitals ||
    NursingDetailPanel.handover => nursingWriteRequirement,
  };
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Full nursing worklist (`/nursing` or `?scope=all`). Nested cross-module
/// matrix rows are _(n/a)_ except medication panels ([medicationsPanel] /
/// [administerMedication] — pharmacy ∩) and shift context ([shiftContext] —
/// roster/hr ∪ + `hr-rosters`). Write controls keep source
/// [nursingWriteRequirement] (∪ clinical|patient|last_office write + roles)
/// rather than matrix ∩ `clinical:write` alone. Route entry ∪ is [routeEntry]
/// (includes `last_office:read` | `operations:read` for shell entry, not
/// All-tab chrome). `last_office:read` alone must not unlock writes.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context (toolbar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action vitals / handover / escalate | create / update | write ∪ ([nextAction]) |
/// | Next action administer medication | create / update | medication write ∩ |
/// | Next action transfer / discharge | create / update | transfer/discharge atom write |
/// | Detail complementary writes (note / vitals / orders / …) | create / update | write ∪ |
/// | Detail administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationsPanel]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Admission checklist write steps | create / update | write ∪ |
/// | Nested mutation dialogs / `panel=` deep link | create / update | matching write |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read |
abstract final class NursingAllAtomPermissions {
  static const AccessRequirement tab = nursingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = nursingWorkspaceReadRequirement;
  static const AccessRequirement search = nursingWorkspaceReadRequirement;
  static const AccessRequirement filters = nursingWorkspaceReadRequirement;
  static const AccessRequirement settings = nursingWorkspaceReadRequirement;
  static const AccessRequirement empty = nursingWorkspaceReadRequirement;
  static const AccessRequirement loading = nursingWorkspaceReadRequirement;
  static const AccessRequirement retry = nursingWorkspaceReadRequirement;
  static const AccessRequirement success = nursingWriteRequirement;
  static const AccessRequirement validation = nursingWriteRequirement;
  static const AccessRequirement rowSelect = nursingWorkspaceReadRequirement;
  static const AccessRequirement detail = nursingWorkspaceReadRequirement;
  static const AccessRequirement create = nursingWriteRequirement;
  static const AccessRequirement update = nursingWriteRequirement;
  static const AccessRequirement delete = nursingWriteRequirement;
  static const AccessRequirement write = nursingWriteRequirement;
  /// Matrix ∩ `clinical:write` mapping note — prefer [write] (source ∪) at call sites.
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement nextAction = nursingWriteRequirement;
  static const AccessRequirement nextActionMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement nextActionVitals = nursingWriteRequirement;
  static const AccessRequirement nextActionHandover = nursingWriteRequirement;
  static const AccessRequirement nextActionTransfer =
      NursingTransferPendingAtomPermissions.nextActionTransfer;
  static const AccessRequirement nextActionDischarge =
      NursingDischargePendingAtomPermissions.nextActionDischarge;
  static const AccessRequirement nextActionEscalate = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement prescribe = nursingWriteRequirement;
  static const AccessRequirement orderLab = nursingWriteRequirement;
  static const AccessRequirement orderRadiology = nursingWriteRequirement;
  static const AccessRequirement escalate = nursingWriteRequirement;
  static const AccessRequirement acknowledgeTransfer =
      NursingTransferPendingAtomPermissions.nextActionTransfer;
  static const AccessRequirement dischargeClearance =
      NursingDischargePendingAtomPermissions.write;
  static const AccessRequirement acceptHandover = nursingWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement navigation = AccessRequirement();
  /// Nested cross-module write — matrix _(n/a)_; medication uses [administerMedication].
  static const AccessRequirement nestedWrite = nursingWriteRequirement;
  /// Nested cross-module read — medication panel uses [medicationsPanel].
  static const AccessRequirement nestedRead = nursingWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = nursingWriteRequirement;
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.nursingEntry;
}

/// Transfer pending tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=transfer-pending`. Transfer execute needs ∩ `clinical:write`
/// (+ nurse/manager/admin roles + `inpatient-bed-management`) —
/// [nursingClinicalWriteRequirement]. Source inventory
/// (`screens/nursing.md`) documents broader ∪ write keys for shared nursing
/// chrome; this tab's stage write atoms prefer the matrix ∩. `last_office:read`
/// alone must not unlock writes. Nested cross-module matrix rows are _(n/a)_.
/// Medication panel uses ∩ `pharmacy:read`; administer uses ∩ `clinical:write`
/// + `pharmacy:read`. Shift context uses roster/ops read ∩ `hr-rosters`.
/// Complementary detail writes (note / vitals / …) keep source
/// [nursingWriteRequirement] ∪.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Transfer pending tab / count badge | navigate | read ∪ `clinical:read` \| `patient:read` |
/// | Shift context | progressive disclosure | shift ∩ roster/ops + `hr-rosters` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∪ |
/// | Transfer status column / filter | read | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / validation (authorized) | visible feedback | clinical:write ∩ |
/// | Row select → detail | read | read ∪ |
/// | Next action Acknowledge transfer | update | clinical:write ∩ |
/// | Detail complementary writes (note / vitals / …) | create / update | write source ∪ |
/// | Detail Acknowledge transfer | update | clinical:write ∩ |
/// | Detail Administer medication | update | clinical:write ∩ pharmacy:read |
/// | Detail medications panel | nested read | pharmacy:read ∩ |
/// | Detail Open ICU | navigate | always when ICU active |
/// | Detail Print summary | export | write source ∪ |
/// | Transfer dialog | update | clinical:write ∩ |
/// | Route entry (deep link) | navigate | catalog ∩ `nursing:read` ([routeEntry]) |
abstract final class NursingTransferPendingAtomPermissions {
  static const AccessRequirement tab = nursingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = nursingWorkspaceReadRequirement;
  static const AccessRequirement search = nursingWorkspaceReadRequirement;
  static const AccessRequirement filters = nursingWorkspaceReadRequirement;
  static const AccessRequirement settings = nursingWorkspaceReadRequirement;
  static const AccessRequirement empty = nursingWorkspaceReadRequirement;
  static const AccessRequirement loading = nursingWorkspaceReadRequirement;
  static const AccessRequirement retry = nursingWorkspaceReadRequirement;
  static const AccessRequirement success = nursingClinicalWriteRequirement;
  static const AccessRequirement validation = nursingClinicalWriteRequirement;
  static const AccessRequirement rowSelect = nursingWorkspaceReadRequirement;
  static const AccessRequirement detail = nursingWorkspaceReadRequirement;
  static const AccessRequirement nextActionTransfer =
      nursingClinicalWriteRequirement;
  static const AccessRequirement create = nursingClinicalWriteRequirement;
  static const AccessRequirement update = nursingClinicalWriteRequirement;
  static const AccessRequirement delete = nursingClinicalWriteRequirement;
  static const AccessRequirement write = nursingClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement complementaryWrite = nursingWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement nestedRead =
      nursingNestedCrossModuleReadRequirement;
  static const AccessRequirement nestedWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
}

/// Discharge pending tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=discharge-pending`. Nursing discharge checks; billing
/// clearance needs `billing:read`. Matrix nested cross-module write rows are
/// _(n/a)_. Write keeps source [nursingWriteRequirement] (∪ write keys + roles
/// + module) rather than matrix ∩ `clinical:write` alone — `last_office:read`
/// alone must not unlock writes. Medication panel uses ∩ `pharmacy:read`;
/// administer uses ∩ `clinical:write` + `pharmacy:read`. Shift context uses
/// roster/ops read ∩ `hr-rosters`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Discharge pending tab / count badge | navigate | read ∪ `clinical:read` \| `patient:read` |
/// | Shift context | progressive disclosure | shift ∩ roster/ops + `hr-rosters` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∪ |
/// | Empty / error / retry / loading | read chrome | read ∪ |
/// | Success snackbar / validation (authorized) | visible feedback | write source ∪ |
/// | Row select → detail | read | read ∪ |
/// | Next action Discharge clearance | update | write source ∪ |
/// | Detail complementary writes (note / vitals / …) | create / update | write source ∪ |
/// | Detail Administer medication | update | clinical:write ∩ pharmacy:read |
/// | Detail medications panel | nested read | pharmacy:read ∩ |
/// | Detail billing clearance panel | nested read | billing:read ∩ |
/// | Nested cross-module chrome | nested read | billing:read \| last_office:read |
/// | Detail Open ICU | navigate | always when ICU active |
/// | Detail Print summary | export | write source ∪ |
/// | Discharge clearance dialog / checklist action | update | write source ∪ |
/// | Deep link `panel=discharge` | update | write source ∪ |
/// | Route entry (deep link) | navigate | catalog ∩ `nursing:read` ([routeEntry]) |
abstract final class NursingDischargePendingAtomPermissions {
  static const AccessRequirement tab = nursingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = nursingWorkspaceReadRequirement;
  static const AccessRequirement search = nursingWorkspaceReadRequirement;
  static const AccessRequirement filters = nursingWorkspaceReadRequirement;
  static const AccessRequirement settings = nursingWorkspaceReadRequirement;
  static const AccessRequirement empty = nursingWorkspaceReadRequirement;
  static const AccessRequirement loading = nursingWorkspaceReadRequirement;
  static const AccessRequirement retry = nursingWorkspaceReadRequirement;
  static const AccessRequirement success = nursingWriteRequirement;
  static const AccessRequirement validation = nursingWriteRequirement;
  static const AccessRequirement rowSelect = nursingWorkspaceReadRequirement;
  static const AccessRequirement detail = nursingWorkspaceReadRequirement;
  static const AccessRequirement nextActionDischarge = nursingWriteRequirement;
  static const AccessRequirement create = nursingWriteRequirement;
  static const AccessRequirement update = nursingWriteRequirement;
  static const AccessRequirement delete = nursingWriteRequirement;
  static const AccessRequirement write = nursingWriteRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement billingPanel =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement nestedBillingRead =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement nestedLastOfficeRead =
      nursingLastOfficeNestedReadRequirement;
  static const AccessRequirement nestedRead =
      nursingNestedCrossModuleReadRequirement;
  static const AccessRequirement nestedWrite = nursingWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement panelDeepLink = nursingWriteRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
}
