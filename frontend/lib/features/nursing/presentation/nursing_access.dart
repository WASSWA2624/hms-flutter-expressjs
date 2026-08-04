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
/// handover / transfer / discharge pending stage write atoms when tighter
/// than source ∪; [nursingWriteRequirement] remains the historical shared
/// gate for complementary detail writes and All / Assigned ward / Urgent
/// non-stage chrome.
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

/// Matrix medication-due View ∩: `clinical:read` + `pharmacy:read` + module.
///
/// Tab strip keeps source workspace ∪ ([nursingWorkspaceReadRequirement]);
/// this intersection gates med-due data chrome when both keys are required.
const AccessRequirement nursingMedicationDueReadIntersectionRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.pharmacyRead,
      ],
      activeModules: <String>[nursingInpatientBedModule],
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

/// Stable tab-strip order for nursing workspace chrome.
const List<NursingQueueScope> nursingTabStripOrder = <NursingQueueScope>[
  NursingQueueScope.all,
  NursingQueueScope.assignedWard,
  NursingQueueScope.urgent,
  NursingQueueScope.medicationDue,
  NursingQueueScope.handoverPending,
  NursingQueueScope.transferPending,
  NursingQueueScope.dischargePending,
];

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

/// Per-tab strip gate. Prefer tab `*AtomPermissions.tab` when present.
AccessRequirement nursingBoardTabRequirement(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => NursingAllAtomPermissions.tab,
    NursingQueueScope.assignedWard => NursingAssignedWardAtomPermissions.tab,
    NursingQueueScope.urgent => NursingUrgentAtomPermissions.tab,
    NursingQueueScope.medicationDue => NursingMedicationDueAtomPermissions.tab,
    NursingQueueScope.handoverPending =>
      NursingHandoverPendingAtomPermissions.tab,
    NursingQueueScope.transferPending =>
      NursingTransferPendingAtomPermissions.tab,
    NursingQueueScope.dischargePending =>
      NursingDischargePendingAtomPermissions.tab,
  };
}

bool canViewNursingTab(AppAccessPolicy policy, NursingQueueScope scope) {
  return nursingBoardTabRequirement(scope).isAllowed(policy);
}

bool canViewNursingAssignedWard(AppAccessPolicy policy) {
  return NursingAssignedWardAtomPermissions.tab.isAllowed(policy);
}

bool canViewNursingUrgent(AppAccessPolicy policy) {
  return NursingUrgentAtomPermissions.tab.isAllowed(policy);
}

bool canViewNursingMedicationDue(AppAccessPolicy policy) {
  return NursingMedicationDueAtomPermissions.tab.isAllowed(policy);
}

bool canViewNursingHandoverPending(AppAccessPolicy policy) {
  return NursingHandoverPendingAtomPermissions.tab.isAllowed(policy);
}

bool canViewNursingTransferPending(AppAccessPolicy policy) {
  return NursingTransferPendingAtomPermissions.tab.isAllowed(policy);
}

bool canViewNursingDischargePending(AppAccessPolicy policy) {
  return NursingDischargePendingAtomPermissions.tab.isAllowed(policy);
}

List<NursingQueueScope> nursingAllowedScopes(AppAccessPolicy policy) {
  return nursingTabStripOrder
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
    NursingQueueScope.all => NursingAllAtomPermissions.write,
    NursingQueueScope.assignedWard => NursingAssignedWardAtomPermissions.write,
    NursingQueueScope.urgent => NursingUrgentAtomPermissions.write,
    NursingQueueScope.medicationDue =>
      NursingMedicationDueAtomPermissions.write,
    NursingQueueScope.handoverPending =>
      NursingHandoverPendingAtomPermissions.write,
    NursingQueueScope.transferPending =>
      NursingTransferPendingAtomPermissions.write,
    NursingQueueScope.dischargePending =>
      NursingDischargePendingAtomPermissions.write,
  };
}

/// Whether the Next action column mounts for [scope].
bool nursingBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  NursingQueueScope scope,
) {
  if (!canViewNursingTab(policy, scope)) {
    return false;
  }
  return switch (scope) {
    NursingQueueScope.medicationDue =>
      NursingMedicationDueAtomPermissions.nextActionMedication.isAllowed(
        policy,
      ),
    _ => nursingWriteRequirementForScope(scope).isAllowed(policy),
  };
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement? nursingFocusedPanelRequirement(NursingDetailPanel panel) {
  return switch (panel) {
    NursingDetailPanel.medication =>
      NursingMedicationDueAtomPermissions.panelDeepLink,
    NursingDetailPanel.handover =>
      NursingHandoverPendingAtomPermissions.panelDeepLink,
    NursingDetailPanel.discharge =>
      NursingDischargePendingAtomPermissions.panelDeepLink,
    NursingDetailPanel.checklist => null,
    NursingDetailPanel.vitals => nursingWriteRequirement,
  };
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Full nursing worklist (`/nursing` or `?scope=all`). Nested cross-module
/// matrix rows are _(n/a)_ except medication panels ([medicationsPanel] /
/// [administerMedication] — pharmacy ∩) and shift context ([shiftContext] —
/// roster/hr ∪ + `hr-rosters`). Write controls keep source
/// [nursingWriteRequirement] (∪ clinical|patient|last_office write + roles)
/// rather than matrix ∩ `clinical:write` alone — `last_office:read` alone
/// never unlocks write. Route entry ∪ is [routeEntry] (includes
/// `last_office:read` | `operations:read` for shell entry, not All-tab chrome).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context (search bar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Medication due count (column choices) | nested read | ([medicationsPanel]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action (task-type cascade) | create / update | write ∪ / medication ∩ |
/// | Detail complementary writes | create / update | write ∪ |
/// | Detail administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationsPanel]) |
/// | Detail billing clearance panel / Open billing | nested read | ([billingPanel] / [openBilling]) |
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
  static const AccessRequirement nextActionHandover =
      NursingHandoverPendingAtomPermissions.nextActionHandover;
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
  static const AccessRequirement acceptHandover =
      NursingHandoverPendingAtomPermissions.acceptHandover;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  /// Billing clearance panel + Open billing — `billing:read` ∩ `billing-payments`.
  static const AccessRequirement billingPanel =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement openBilling =
      nursingBillingClearanceReadRequirement;
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

/// Assigned ward tab atom → permission mapping (inventory + matrix).
///
/// ABAC ward/assignment-scoped worklist (`/nursing?scope=assigned-ward`).
/// Nested cross-module matrix rows are _(n/a)_ except medication panels
/// ([medicationsPanel] / [administerMedication] — pharmacy ∩) and shift
/// context ([shiftContext] — roster/hr ∪ + `hr-rosters`). Write controls keep
/// source [nursingWriteRequirement] (∪ clinical|patient|last_office write +
/// roles) rather than matrix ∩ `clinical:write` alone — `last_office:read`
/// alone never unlocks write. Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Assigned ward tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context (search bar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action (task-type cascade) | create / update | write ∪ / medication ∩ |
/// | Detail complementary writes | create / update | write ∪ |
/// | Detail administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationsPanel]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Detail billing clearance panel | nested read | ([billingPanel]) |
/// | Admission checklist write steps | create / update | write ∪ |
/// | Nested mutation dialogs / `panel=` deep link | create / update | matching write |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read |
abstract final class NursingAssignedWardAtomPermissions {
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
  static const AccessRequirement nextActionHandover =
      NursingHandoverPendingAtomPermissions.nextActionHandover;
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
  static const AccessRequirement acceptHandover =
      NursingHandoverPendingAtomPermissions.acceptHandover;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement billingPanel =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement openBilling =
      nursingBillingClearanceReadRequirement;
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

/// Urgent tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=urgent`. Urgent / critical nursing tasks. Nested
/// cross-module matrix rows are _(n/a)_ except medication panels
/// ([medicationsPanel] / [administerMedication] — pharmacy ∩) and shift
/// context ([shiftContext] — roster/hr ∪ + `hr-rosters`). Write controls keep
/// source [nursingWriteRequirement] (∪ clinical|patient|last_office write +
/// roles) rather than matrix ∩ `clinical:write` alone — `last_office:read`
/// alone never unlocks write. Critical rows force Escalate next-action;
/// non-critical urgent rows use the task-type cascade. Route entry ∪ is
/// [routeEntry] (includes `last_office:read` | `operations:read` for shell
/// entry, not Urgent-tab chrome).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Urgent tab / danger count badge | navigate | read ∪ ([tab]) |
/// | Shift context (search bar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Priority column / mobile priority meta | read | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action Escalate (critical) | create / update | write ∪ ([nextActionEscalate]) |
/// | Next action vitals / handover / … | create / update | write ∪ / medication ∩ |
/// | Detail complementary writes (note / vitals / …) | create / update | write ∪ |
/// | Detail Escalate (when not row next-action) | create / update | write ∪ |
/// | Detail Administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationsPanel]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Admission checklist write steps | create / update | write ∪ |
/// | Nested mutation dialogs / `panel=` deep link | create / update | matching write |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read |
abstract final class NursingUrgentAtomPermissions {
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
  static const AccessRequirement nextActionHandover =
      NursingHandoverPendingAtomPermissions.nextActionHandover;
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
  static const AccessRequirement acceptHandover =
      NursingHandoverPendingAtomPermissions.acceptHandover;
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

/// Medication due tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=medication-due`. Due meds; pharmacy:read ∩ clinical:write
/// (or pharmacy:write) for charting/admin. Nested cross-module matrix rows are
/// _(n/a)_. Source inventory (`screens/nursing.md`) lists Medication due as
/// always when workspace loads — tab keeps [nursingWorkspaceReadRequirement]
/// (∪ `clinical:read` | `patient:read`). Matrix View ∩ `clinical:read` +
/// `pharmacy:read` maps to [readIntersection] / [medicationsPanel] for med
/// data. Create/update/delete matrix ∩ `clinical:write` → [clinicalWrite];
/// stage Administer uses [nextActionMedication] /
/// [nursingMedicationAdministerRequirement]. Complementary detail writes keep
/// source [nursingWriteRequirement] ∪. `last_office:read` alone must not
/// unlock writes. Shift context uses roster/ops read ∩ `hr-rosters`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Medication due tab / count badge | navigate | read ∪ ([tab]; matrix ∩ → [readIntersection]) |
/// | Shift context | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Medication due count column | nested read | ([medicationsPanel] / [medicationDueCount]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | ([success] / [validation]) |
/// | Row select → detail | read | ([detail]) |
/// | Next action Administer medication | create / update | ([nextActionMedication]) |
/// | Detail complementary writes (note / vitals / …) | create / update | ([complementaryWrite]) |
/// | Detail Administer medication | create / update | ([administerMedication]) |
/// | Detail medications panel (data) | nested read | ([medicationsPanel]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Detail Print summary | export | ([printSummary]) |
/// | Admission checklist write steps | create / update | ([checklistWrite]) |
/// | Nested mutation dialog / `panel=medication` | create / update | ([panelDeepLink]) |
/// | Route entry (deep link) | navigate | ([routeEntry]) |
abstract final class NursingMedicationDueAtomPermissions {
  static const AccessRequirement tab = nursingWorkspaceReadRequirement;
  static const AccessRequirement readUnion = nursingWorkspaceReadRequirement;
  static const AccessRequirement readIntersection =
      nursingMedicationDueReadIntersectionRequirement;
  static const AccessRequirement listChrome = nursingWorkspaceReadRequirement;
  static const AccessRequirement search = nursingWorkspaceReadRequirement;
  static const AccessRequirement filters = nursingWorkspaceReadRequirement;
  static const AccessRequirement settings = nursingWorkspaceReadRequirement;
  static const AccessRequirement empty = nursingWorkspaceReadRequirement;
  static const AccessRequirement loading = nursingWorkspaceReadRequirement;
  static const AccessRequirement retry = nursingWorkspaceReadRequirement;
  static const AccessRequirement success = nursingMedicationAdministerRequirement;
  static const AccessRequirement validation =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement rowSelect = nursingWorkspaceReadRequirement;
  static const AccessRequirement detail = nursingWorkspaceReadRequirement;
  static const AccessRequirement nextActionMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement create = nursingClinicalWriteRequirement;
  static const AccessRequirement update = nursingClinicalWriteRequirement;
  static const AccessRequirement delete = nursingClinicalWriteRequirement;
  static const AccessRequirement write = nursingMedicationAdministerRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement complementaryWrite = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement medicationDueCount =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement panelDeepLink =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement navigation = AccessRequirement();
  /// Nested cross-module matrix rows _(n/a)_; medication uses [medicationsPanel].
  static const AccessRequirement nestedRead = nursingMedicationsPanelRequirement;
  static const AccessRequirement nestedWrite =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.nursingEntry;
}

/// Handover pending tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=handover-pending`. Shift handover complete needs ∩
/// `clinical:write` (+ nurse/manager/admin roles + `inpatient-bed-management`)
/// — [nursingClinicalWriteRequirement]. Source inventory
/// (`screens/nursing.md`) documents broader ∪ write keys for shared nursing
/// chrome; this tab's stage write atoms prefer the matrix ∩. Create/update/
/// delete matrix ∩ `clinical:write` → [create] / [update] / [delete] /
/// [write]. Complementary detail writes (note / vitals / prescribe / …) keep
/// source [nursingWriteRequirement] ∪ — mapping noted in tests.
/// `last_office:read` alone must not unlock writes. Nested cross-module
/// matrix rows are _(n/a)_ except medication panels ([medicationsPanel] /
/// [administerMedication]), billing clearance ([billingPanel] /
/// [openBilling] — `billing:read` ∩ `billing-payments`), and shift context
/// ([shiftContext]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Handover pending tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | ([success] / [validation]) |
/// | Row select → detail | read | ([detail]) |
/// | Next action Create handover | create / update | ([nextActionHandover]) |
/// | Detail complementary writes (note / vitals / …) | create / update | ([complementaryWrite]) |
/// | Detail Accept / Create handover | create / update | ([acceptHandover] / [createHandover]) |
/// | Detail Prescribe / lab / radiology | create | ([prescribe] / [orderLab] / [orderRadiology]) |
/// | Detail Administer medication | update | ([administerMedication]) |
/// | Detail medications panel | nested read | ([medicationsPanel]) |
/// | Detail billing clearance panel / Open billing | nested read | ([billingPanel] / [openBilling]) |
/// | Detail Discharge clearance | update | ([dischargeClearance]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Detail Print summary | export | ([printSummary]) |
/// | Checklist handover / write steps | create / update | ([checklistWrite]) |
/// | Deep link `panel=handover` | create / update | ([panelDeepLink]) |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read ([routeEntry]) |
abstract final class NursingHandoverPendingAtomPermissions {
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
  static const AccessRequirement nextAction = nursingClinicalWriteRequirement;
  static const AccessRequirement nextActionHandover =
      nursingClinicalWriteRequirement;
  static const AccessRequirement create = nursingClinicalWriteRequirement;
  static const AccessRequirement update = nursingClinicalWriteRequirement;
  static const AccessRequirement delete = nursingClinicalWriteRequirement;
  static const AccessRequirement write = nursingClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement createHandover = nursingClinicalWriteRequirement;
  static const AccessRequirement acceptHandover = nursingClinicalWriteRequirement;
  /// Source ∪ for shared detail complementary writes — matrix ∩ is [write].
  static const AccessRequirement complementaryWrite = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement prescribe = nursingWriteRequirement;
  static const AccessRequirement orderLab = nursingWriteRequirement;
  static const AccessRequirement orderRadiology = nursingWriteRequirement;
  static const AccessRequirement escalate = nursingWriteRequirement;
  static const AccessRequirement acknowledgeTransfer =
      NursingTransferPendingAtomPermissions.nextActionTransfer;
  static const AccessRequirement dischargeClearance =
      NursingDischargePendingAtomPermissions.write;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  /// Billing clearance panel + Open billing — `billing:read` ∩ `billing-payments`.
  static const AccessRequirement billingPanel =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement openBilling =
      nursingBillingClearanceReadRequirement;
  /// Nested cross-module matrix _(n/a)_; medication uses [medicationsPanel].
  static const AccessRequirement nestedRead =
      nursingNestedCrossModuleReadRequirement;
  static const AccessRequirement nestedWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement panelDeepLink = nursingClinicalWriteRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement navigation = AccessRequirement();
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
/// chrome; this tab's stage write atoms prefer the matrix ∩. Create/update/
/// delete matrix ∩ `clinical:write` → [create] / [update] / [delete] /
/// [write]. Complementary detail writes (note / vitals / …) keep source
/// [nursingWriteRequirement] ∪ — mapping noted in tests. `last_office:read`
/// alone must not unlock writes. Nested cross-module matrix rows are _(n/a)_
/// except medication panels ([medicationsPanel] / [administerMedication]) and
/// shift context ([shiftContext]). No `panel=transfer` deep link in inventory.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Transfer pending tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Transfer status column / filter | read | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | ([success] / [validation]) |
/// | Row select → detail | read | ([detail]) |
/// | Next action Acknowledge transfer | update | ([nextActionTransfer]) |
/// | Detail complementary writes (note / vitals / …) | create / update | ([complementaryWrite]) |
/// | Detail Acknowledge transfer | update | ([acknowledgeTransfer]) |
/// | Detail Administer medication | update | ([administerMedication]) |
/// | Detail medications panel | nested read | ([medicationsPanel]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Detail Print summary | export | ([printSummary]) |
/// | Admission checklist write steps | create / update | ([checklistWrite]) |
/// | Transfer dialog | update | ([write]) |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read ([routeEntry]) |
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
  static const AccessRequirement nextAction = nursingClinicalWriteRequirement;
  static const AccessRequirement nextActionTransfer =
      nursingClinicalWriteRequirement;
  static const AccessRequirement acknowledgeTransfer =
      nursingClinicalWriteRequirement;
  static const AccessRequirement create = nursingClinicalWriteRequirement;
  static const AccessRequirement update = nursingClinicalWriteRequirement;
  static const AccessRequirement delete = nursingClinicalWriteRequirement;
  static const AccessRequirement write = nursingClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  /// Source ∪ for shared detail complementary writes — matrix ∩ is [write].
  static const AccessRequirement complementaryWrite = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  /// Nested cross-module matrix _(n/a)_; medication uses [medicationsPanel].
  static const AccessRequirement nestedRead =
      nursingNestedCrossModuleReadRequirement;
  static const AccessRequirement nestedWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement navigation = AccessRequirement();
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.nursingEntry;
}

/// Discharge pending tab atom → permission mapping (inventory + matrix).
///
/// Worklist `?scope=discharge-pending`. Nursing discharge checks; billing
/// clearance nested panel needs `billing:read` ([billingPanel] /
/// [nestedBillingRead] — ∩ `billing-payments`). Discharge execute needs ∩
/// `clinical:write` (+ nurse/manager/admin roles + `inpatient-bed-management`)
/// — [nursingClinicalWriteRequirement]. Source inventory (`screens/nursing.md`)
/// documents broader ∪ write keys for shared nursing chrome; this tab's stage
/// write atoms prefer the matrix ∩. Create/update/delete matrix ∩
/// `clinical:write` → [create] / [update] / [delete] / [write]. Complementary
/// detail writes (note / vitals / …) keep source [nursingWriteRequirement] ∪ —
/// mapping noted in tests. `last_office:read` alone must not unlock writes.
/// Nested cross-module read ∪: `billing:read` | `last_office:read`
/// ([nestedRead]); nested write _(n/a)_ except stage discharge ([nestedWrite] /
/// [write]). Medication panels use [medicationsPanel] /
/// [administerMedication]. Shift context uses [shiftContext].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Discharge pending tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Discharge status column / filter | read | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | ([success] / [validation]) |
/// | Row select → detail | read | ([detail]) |
/// | Next action Discharge clearance | update | ([nextActionDischarge]) |
/// | Detail complementary writes (note / vitals / …) | create / update | ([complementaryWrite]) |
/// | Detail Discharge clearance (when not next-action) | update | ([write]) |
/// | Detail Administer medication | update | ([administerMedication]) |
/// | Detail medications panel | nested read | ([medicationsPanel]) |
/// | Detail Prescribe / Order lab / radiology | create | ([prescribe] / [orderLab] / [orderRadiology]) |
/// | Detail billing clearance panel | nested read | ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Detail Open ICU | navigate | ([openIcu]) |
/// | Detail Print summary | export | ([printSummary]) |
/// | Admission checklist write / clearance step | create / update | ([checklistWrite]) |
/// | Discharge dialog / `panel=discharge` | update | ([panelDeepLink] / [write]) |
/// | Route entry (deep link) | navigate | clinical \| patient \| last_office \| operations:read ([routeEntry]) |
///
/// Financial inventory: `nursing_discharge_pending_billing_inventory.dart`.
abstract final class NursingDischargePendingAtomPermissions {
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
  static const AccessRequirement nextAction = nursingClinicalWriteRequirement;
  static const AccessRequirement nextActionDischarge =
      nursingClinicalWriteRequirement;
  static const AccessRequirement create = nursingClinicalWriteRequirement;
  static const AccessRequirement update = nursingClinicalWriteRequirement;
  static const AccessRequirement delete = nursingClinicalWriteRequirement;
  static const AccessRequirement write = nursingClinicalWriteRequirement;
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  /// Source ∪ for shared detail complementary writes — matrix ∩ is [write].
  static const AccessRequirement complementaryWrite = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement prescribe = nursingWriteRequirement;
  static const AccessRequirement orderLab = nursingWriteRequirement;
  static const AccessRequirement orderRadiology = nursingWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement medicationsPanel =
      nursingMedicationsPanelRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationAdministerRequirement;
  static const AccessRequirement billingPanel =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement openBilling =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement nestedBillingRead =
      nursingBillingClearanceReadRequirement;
  static const AccessRequirement nestedLastOfficeRead =
      nursingLastOfficeNestedReadRequirement;
  static const AccessRequirement nestedRead =
      nursingNestedCrossModuleReadRequirement;
  static const AccessRequirement nestedWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement panelDeepLink = nursingClinicalWriteRequirement;
  static const AccessRequirement openIcu = AccessRequirement();
  static const AccessRequirement navigation = AccessRequirement();
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.nursingEntry;
}
