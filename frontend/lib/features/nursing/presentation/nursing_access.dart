import 'package:hosspi_hms/app/router/app_routes.dart';
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

/// Route entry — [RouteAccessCatalog.nursingEntry] (∩ `nursing:read` + module).
///
/// Prompt / [AppRoutes.nursing] list ∪ `clinical:read` | `patient:read` |
/// `last_office:read` | `operations:read`; live shell prefers the catalog atom.
const AccessRequirement nursingWorkspaceEntryRequirement =
    RouteAccessCatalog.nursingEntry;

/// Prompt / AppRoutes route-entry ∪ (broader than catalog ∩ `nursing:read`).
const AccessRequirement nursingWorkspaceRouteUnionRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.patientRead,
        AppPermissions.lastOfficeRead,
        AppPermissions.operationsRead,
      ],
      anyRoles: AppRoutes.nursingWorkspaceRoles,
      activeModules: <String>[nursingInpatientBedModule],
    );

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

/// Administer medication — ∩ `clinical:write` + `pharmacy:read` when both apply
/// (source roles + nursing module).
const AccessRequirement nursingMedicationAdministerRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[
        AppPermissions.clinicalWrite,
        AppPermissions.pharmacyRead,
      ],
      anyRoles: nursingWriteRoles,
      activeModules: <String>[nursingInpatientBedModule],
    );

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
  return nursingWorkspaceEntryRequirement.isAllowed(policy) ||
      nursingWorkspaceRouteUnionRequirement.isAllowed(policy);
}

bool canViewNursingShiftContext(AppAccessPolicy policy) {
  return nursingShiftContextRequirement.isAllowed(policy);
}

bool canViewNursingMedicationsPanel(AppAccessPolicy policy) {
  return nursingMedicationsPanelRequirement.isAllowed(policy);
}

bool canAdministerNursingMedication(AppAccessPolicy policy) {
  return nursingMedicationAdministerRequirement.isAllowed(policy);
}

bool canViewNursingBillingClearance(AppAccessPolicy policy) {
  return nursingBillingClearanceReadRequirement.isAllowed(policy);
}

/// Per-tab strip gate. Discharge pending uses
/// [NursingDischargePendingAtomPermissions.tab]; other scopes share workspace
/// read ∪ until their tab scans land.
AccessRequirement nursingBoardTabRequirement(NursingQueueScope scope) {
  return switch (scope) {
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
AccessRequirement nursingFocusedPanelRequirement(NursingDetailPanel panel) {
  return switch (panel) {
    NursingDetailPanel.medication => nursingMedicationAdministerRequirement,
    NursingDetailPanel.discharge =>
      NursingDischargePendingAtomPermissions.write,
    NursingDetailPanel.checklist => nursingWorkspaceReadRequirement,
    _ => nursingWriteRequirement,
  };
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
