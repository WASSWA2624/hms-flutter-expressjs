import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';

/// Module entitlement for the nursing workspace route and board tabs.
const String nursingInpatientBedManagementModule = 'inpatient-bed-management';

/// Pharmacy module for medication panels / administer actions.
const String nursingPharmacyDispensingModule = 'pharmacy-dispensing';

/// HR rosters module for shift-context chrome.
const String nursingHrRostersModule = 'hr-rosters';

const List<AppRole> _nursingWriteRoles = <AppRole>[
  AppRole.nurse,
  AppRole.wardManager,
  AppRole.icuManager,
  AppRole.theatreManager,
  AppRole.facilityAdmin,
  AppRole.tenantAdmin,
  AppRole.superAdmin,
];

/// View / read UI (matrix ∪): `clinical:read` | `patient:read` + module.
///
/// Route entry may also allow `last_office:read` | `operations:read` (see
/// [nursingWorkspaceEntryRequirement]); those alone do **not** satisfy All-tab
/// chrome — `last_office:read` must not unlock write or clinical list UI.
const AccessRequirement nursingWorkspaceReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalRead,
    AppPermissions.patientRead,
  ],
  activeModules: <String>[nursingInpatientBedManagementModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement nursingReadRequirement = nursingWorkspaceReadRequirement;

/// Route entry — unique atom from [RouteAccessCatalog.nursing] / [AppRoutes.nursing]
/// (∪ `clinical:read` | `patient:read` | `last_office:read` | `operations:read`
/// + nursing workspace roles + module).
const AccessRequirement nursingWorkspaceEntryRequirement =
    RouteAccessCatalog.nursingEntry;

/// Prompt / AppRoutes route-entry ∪ alias (same as catalog entry).
const AccessRequirement nursingWorkspaceRouteUnionRequirement =
    RouteAccessCatalog.nursingEntry;

/// Alias for historical call sites.
const AccessRequirement nursingWorkspaceRouteEntryRequirement =
    nursingWorkspaceEntryRequirement;

/// Create / update / delete mutations on the nursing worklist and detail.
///
/// Matrix lists ∩ `clinical:write` alone; source inventory (`screens/nursing.md`)
/// documents [nursingWriteRequirement] as ∪ `clinical:write` | `patient:write` |
/// `last_office:write` + nurse/manager/admin roles + `inpatient-bed-management`
/// — keep source. `last_office:read` alone never satisfies this gate.
const AccessRequirement nursingWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.patientWrite,
    AppPermissions.lastOfficeWrite,
  ],
  anyRoles: _nursingWriteRoles,
  activeModules: <String>[nursingInpatientBedManagementModule],
);

/// Alias matching matrix create/update/delete when clinical ∩ is intended.
///
/// Prefer [nursingWriteRequirement] at call sites (source). This alias keeps
/// matrix ∩ `clinical:write` available for tests / documentation mapping.
const AccessRequirement nursingClinicalWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.clinicalWrite],
  anyRoles: _nursingWriteRoles,
  activeModules: <String>[nursingInpatientBedManagementModule],
);

/// Delete — same as source write ∪ (matrix ∩ `clinical:write` alone — keep source).
const AccessRequirement nursingDeleteRequirement = nursingWriteRequirement;

/// Medication panel / data-only meds list (prompt nested note): ∩ `pharmacy:read`.
const AccessRequirement nursingMedicationReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
);

/// Administer medication / medication next-action.
///
/// Prompt: pharmacy:read to view meds and clinical:write (or pharmacy:write
/// where dispense is involved) — ∩ when both apply →
/// `pharmacy:read` ∩ (`clinical:write` | `pharmacy:write`) + source roles +
/// inpatient module.
const AccessRequirement nursingMedicationWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
  anyPermissions: <AppPermission>[
    AppPermissions.clinicalWrite,
    AppPermissions.pharmacyWrite,
  ],
  anyRoles: _nursingWriteRoles,
  activeModules: <String>[nursingInpatientBedManagementModule],
);

/// Shift context toolbar (progressive disclosure) — matches controller
/// `_canReadOperationsContext`: `hr-rosters` + ∪ roster/hr/operations/unit read.
///
/// Prompt: "Shift context is read via roster:read when present."
const AccessRequirement nursingShiftContextRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.rosterRead,
    AppPermissions.hrRead,
    AppPermissions.operationsRead,
    AppPermissions.unitRead,
  ],
  activeModules: <String>[nursingHrRostersModule],
);

/// Navigation chrome (Open ICU) — no write.
const AccessRequirement nursingNavigationRequirement = AccessRequirement();

bool canReadNursing(AppAccessPolicy policy) {
  return nursingWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteNursing(AppAccessPolicy policy) {
  return nursingWriteRequirement.isAllowed(policy);
}

bool canEnterNursingWorkspace(AppAccessPolicy policy) {
  return nursingWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadNursingMedications(AppAccessPolicy policy) {
  return nursingMedicationReadRequirement.isAllowed(policy);
}

bool canWriteNursingMedications(AppAccessPolicy policy) {
  return nursingMedicationWriteRequirement.isAllowed(policy);
}

bool canReadNursingShiftContext(AppAccessPolicy policy) {
  return nursingShiftContextRequirement.isAllowed(policy);
}

/// Tab-strip order (matches [nursingTabItems] presentation).
const List<NursingQueueScope> nursingTabStripOrder = <NursingQueueScope>[
  NursingQueueScope.all,
  NursingQueueScope.assignedWard,
  NursingQueueScope.urgent,
  NursingQueueScope.medicationDue,
  NursingQueueScope.handoverPending,
  NursingQueueScope.transferPending,
  NursingQueueScope.dischargePending,
];

/// Per-scope tab strip gate. All / Assigned ward use their atom maps; other
/// scopes share matrix read ∪ until their tab prompts refine.
AccessRequirement nursingBoardTabRequirement(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => NursingAllAtomPermissions.tab,
    NursingQueueScope.assignedWard => NursingAssignedWardAtomPermissions.tab,
    NursingQueueScope.urgent ||
    NursingQueueScope.medicationDue ||
    NursingQueueScope.handoverPending ||
    NursingQueueScope.transferPending ||
    NursingQueueScope.dischargePending => nursingWorkspaceReadRequirement,
  };
}

bool canViewNursingTab(AppAccessPolicy policy, NursingQueueScope scope) {
  return nursingBoardTabRequirement(scope).isAllowed(policy);
}

/// Tabs the user may open; empty when no board read passes.
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

/// Whether the Next action column / mobile trailing mounts for [scope].
bool nursingBoardShowsNextActionColumn(
  AppAccessPolicy policy,
  NursingQueueScope scope,
) {
  if (!canViewNursingTab(policy, scope)) {
    return false;
  }
  return canWriteNursing(policy) || canWriteNursingMedications(policy);
}

/// Requirement for a deep-linked `panel=` mutation.
AccessRequirement? nursingFocusedPanelRequirement(NursingDetailPanel panel) {
  return switch (panel) {
    NursingDetailPanel.medication => nursingMedicationWriteRequirement,
    NursingDetailPanel.vitals ||
    NursingDetailPanel.handover ||
    NursingDetailPanel.discharge => nursingWriteRequirement,
    NursingDetailPanel.checklist => null,
  };
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Full nursing worklist (`/nursing` or `?scope=all`). Nested cross-module
/// matrix rows are _(n/a)_ except medication panels ([medicationRead] /
/// [medicationWrite] — pharmacy ∩) and shift context ([shiftContext] —
/// roster/hr ∪ + `hr-rosters`). Write controls keep source
/// [nursingWriteRequirement] (∪ clinical|patient|last_office write + roles)
/// rather than matrix ∩ `clinical:write` alone. Route entry ∪ is [routeEntry]
/// (includes `last_office:read` | `operations:read` for shell entry, not
/// All-tab chrome).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context (toolbar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action vitals / handover / transfer / discharge / escalate | create / update | write ∪ ([nextAction]) |
/// | Next action administer medication | create / update | medication write ∩ ([nextActionMedication]) |
/// | Detail complementary writes (note / vitals / orders / …) | create / update | write ∪ |
/// | Detail administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationRead]) |
/// | Detail Open ICU | navigate | ([navigation]) |
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
  static const AccessRequirement delete = nursingDeleteRequirement;
  static const AccessRequirement write = nursingWriteRequirement;
  /// Matrix ∩ `clinical:write` mapping note — prefer [write] (source ∪) at call sites.
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement nextAction = nursingWriteRequirement;
  static const AccessRequirement nextActionMedication =
      nursingMedicationWriteRequirement;
  static const AccessRequirement nextActionVitals = nursingWriteRequirement;
  static const AccessRequirement nextActionHandover = nursingWriteRequirement;
  static const AccessRequirement nextActionTransfer = nursingWriteRequirement;
  static const AccessRequirement nextActionDischarge = nursingWriteRequirement;
  static const AccessRequirement nextActionEscalate = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationWriteRequirement;
  static const AccessRequirement prescribe = nursingWriteRequirement;
  static const AccessRequirement orderLab = nursingWriteRequirement;
  static const AccessRequirement orderRadiology = nursingWriteRequirement;
  static const AccessRequirement escalate = nursingWriteRequirement;
  static const AccessRequirement acknowledgeTransfer = nursingWriteRequirement;
  static const AccessRequirement dischargeClearance = nursingWriteRequirement;
  static const AccessRequirement acceptHandover = nursingWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationReadRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement openIcu = nursingNavigationRequirement;
  static const AccessRequirement navigation = nursingNavigationRequirement;
  /// Nested cross-module write — matrix _(n/a)_; medication uses [medicationWrite].
  static const AccessRequirement nestedWrite = nursingWriteRequirement;
  /// Nested cross-module read — medication panel uses [medicationRead].
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
/// ([medicationRead] / [medicationWrite] — pharmacy ∩) and shift context
/// ([shiftContext] — roster/hr ∪ + `hr-rosters`). Write controls keep source
/// [nursingWriteRequirement] (∪ clinical|patient|last_office write + roles)
/// rather than matrix ∩ `clinical:write` alone — `last_office:read` alone
/// never unlocks write. Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Assigned ward tab / count badge | navigate | read ∪ ([tab]) |
/// | Shift context (toolbar) | progressive disclosure | ([shiftContext]) |
/// | Search / Clear / Filters / Settings / columns | read chrome | ([listChrome]) |
/// | Empty / error / retry / loading | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write / form |
/// | Row select → patient detail | read | ([detail]) |
/// | Next action (task-type cascade) | create / update | write ∪ / medication ∩ |
/// | Detail complementary writes | create / update | write ∪ |
/// | Detail administer medication | create / update | medication write ∩ |
/// | Detail medications panel (data) | nested read | ([medicationRead]) |
/// | Detail Open ICU | navigate | ([navigation]) |
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
  static const AccessRequirement delete = nursingDeleteRequirement;
  static const AccessRequirement write = nursingWriteRequirement;
  /// Matrix ∩ `clinical:write` mapping note — prefer [write] (source ∪) at call sites.
  static const AccessRequirement clinicalWrite = nursingClinicalWriteRequirement;
  static const AccessRequirement nextAction = nursingWriteRequirement;
  static const AccessRequirement nextActionMedication =
      nursingMedicationWriteRequirement;
  static const AccessRequirement nextActionVitals = nursingWriteRequirement;
  static const AccessRequirement nextActionHandover = nursingWriteRequirement;
  static const AccessRequirement nextActionTransfer = nursingWriteRequirement;
  static const AccessRequirement nextActionDischarge = nursingWriteRequirement;
  static const AccessRequirement nextActionEscalate = nursingWriteRequirement;
  static const AccessRequirement recordVitals = nursingWriteRequirement;
  static const AccessRequirement addNote = nursingWriteRequirement;
  static const AccessRequirement administerMedication =
      nursingMedicationWriteRequirement;
  static const AccessRequirement prescribe = nursingWriteRequirement;
  static const AccessRequirement orderLab = nursingWriteRequirement;
  static const AccessRequirement orderRadiology = nursingWriteRequirement;
  static const AccessRequirement escalate = nursingWriteRequirement;
  static const AccessRequirement acknowledgeTransfer = nursingWriteRequirement;
  static const AccessRequirement dischargeClearance = nursingWriteRequirement;
  static const AccessRequirement acceptHandover = nursingWriteRequirement;
  static const AccessRequirement printSummary = nursingWriteRequirement;
  static const AccessRequirement checklistWrite = nursingWriteRequirement;
  static const AccessRequirement medicationRead =
      nursingMedicationReadRequirement;
  static const AccessRequirement medicationWrite =
      nursingMedicationWriteRequirement;
  static const AccessRequirement shiftContext = nursingShiftContextRequirement;
  static const AccessRequirement openIcu = nursingNavigationRequirement;
  static const AccessRequirement navigation = nursingNavigationRequirement;
  /// Nested cross-module write — matrix _(n/a)_; medication uses [medicationWrite].
  static const AccessRequirement nestedWrite = nursingWriteRequirement;
  /// Nested cross-module read — medication panel uses [medicationRead].
  static const AccessRequirement nestedRead = nursingWorkspaceReadRequirement;
  static const AccessRequirement panelDeepLink = nursingWriteRequirement;
  static const AccessRequirement entry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = nursingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntryUnion =
      nursingWorkspaceRouteUnionRequirement;
  static const AccessRequirement catalogEntry = RouteAccessCatalog.nursingEntry;
}
