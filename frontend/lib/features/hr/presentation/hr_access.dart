import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';

/// Module entitlement for the HR workspace route and sections.
const String hrRostersModule = 'hr-rosters';

/// Alias used by Access tab / manage-users prompts.
const String hrAccessActiveModule = hrRostersModule;

/// Billing module required for [AppPermissions.financialApprove] plan checks.
const String hrBillingPaymentsModule = 'billing-payments';

/// View / read UI (matrix ∩ `hr:read`).
const AccessRequirement hrReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrRead],
  activeModules: <String>[hrRostersModule],
);

/// Alias — workspace / leave / staff directory read ∩.
const AccessRequirement hrWorkspaceReadRequirement = hrReadRequirement;

/// Create / update / delete mutations (matrix ∩ `hr:write`).
const AccessRequirement hrWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  activeModules: <String>[hrRostersModule],
);

/// Alias — workspace write ∩ (leave approve / request / reject).
const AccessRequirement hrWorkspaceWriteRequirement = hrWriteRequirement;

/// Roster / shift create & update (source ∪ `hr:write` | `roster:write`).
///
/// screens/hr.md and staff-detail roster actions keep this union.
const AccessRequirement hrRosterWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterWrite,
  ],
  activeModules: <String>[hrRostersModule],
);

/// Swap approve/reject (source ∪ `hr:write` | `roster:approve`).
const AccessRequirement hrRosterApproveRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterApprove,
  ],
  activeModules: <String>[hrRostersModule],
);

/// Roster publish (source ∪ `hr:write` | `roster:publish`).
const AccessRequirement hrRosterPublishRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrWrite,
    AppPermissions.rosterPublish,
  ],
  activeModules: <String>[hrRostersModule],
);

/// Nested cross-module write ∪ (`roster:publish` | `roster:approve`).
const AccessRequirement hrRosterNestedWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.rosterPublish,
    AppPermissions.rosterApprove,
  ],
  activeModules: <String>[hrRostersModule],
);

/// Payroll process / approve (source inventory): ∩ `hr:write` + ∪
/// `financial:approve`. Matrix nested ∪ alone is weaker — keep source.
const AccessRequirement hrPayrollRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.hrWrite],
  anyPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>[hrRostersModule],
);

/// Payroll preview (backend preview is `hr:read`).
const AccessRequirement hrPayrollPreviewRequirement = hrReadRequirement;

/// Matrix nested cross-module write row (∪) — documentation / union fixtures.
const AccessRequirement hrPayrollNestedWriteMatrixRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.financialApprove,
        AppPermissions.hrWrite,
      ],
      activeModules: <String>[hrRostersModule],
    );

/// Route entry — keep [RouteAccessCatalog.hrEntry] (∩ `hr:read` + facility +
/// module). Prompt ∪ `hr:read` | `hr:write` is noted in leave-tab tests.
const AccessRequirement hrWorkspaceEntryRequirement = RouteAccessCatalog.hrEntry;

// ---------------------------------------------------------------------------
// Access tab (Manage users and roles) — embeds admin-access rules
// ---------------------------------------------------------------------------

/// Admin union for Access tab read (matrix ∪).
const List<AppPermission> hrAccessAdminReadPermissions = <AppPermission>[
  AppPermissions.tenantAdmin,
  AppPermissions.facilityAdmin,
  AppPermissions.systemAdmin,
];

/// Access tab view — matrix ∩ `hr:read` **or** ∪ admin keys (either path).
const AccessRequirement hrAccessReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.hrRead,
    ...hrAccessAdminReadPermissions,
  ],
  activeModules: <String>[hrRostersModule],
);

/// Create (matrix ∩): `tenant:admin` + module.
///
/// Source inventory (`screens/hr.md`) maps Access write chrome to
/// [canWriteHrAccess] (`hr:write`). Prefer [canCreateHrAccess], which
/// intersects this requirement with source `hr:write`.
const AccessRequirement hrAccessCreateRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.tenantAdmin],
  activeModules: <String>[hrRostersModule],
);

/// Update (matrix ∩): same as create ∩ `tenant:admin`.
const AccessRequirement hrAccessUpdateRequirement = hrAccessCreateRequirement;

/// Delete (matrix ∩): `hr:write` — matches source [canWriteHrAccess].
const AccessRequirement hrAccessDeleteRequirement = hrWriteRequirement;

bool canReadHr(AppAccessPolicy policy) {
  return hrReadRequirement.isAllowed(policy);
}

bool canWriteHr(AppAccessPolicy policy) {
  return hrWriteRequirement.isAllowed(policy);
}

bool canProcessHrPayroll(AppAccessPolicy policy) {
  return hrPayrollRequirement.isAllowed(policy);
}

bool canPreviewHrPayroll(AppAccessPolicy policy) {
  return hrPayrollPreviewRequirement.isAllowed(policy);
}

bool canEnterHrWorkspace(AppAccessPolicy policy) {
  return hrWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadHrAccess(AppAccessPolicy policy) {
  return hrAccessReadRequirement.isAllowed(policy) || policy.isElevated;
}

/// Source inventory write gate: `hr:write` + `hr-rosters`.
bool canWriteHrAccessPolicy(AppAccessPolicy policy) {
  return hrWriteRequirement.isAllowed(policy) || policy.isElevated;
}

bool canWriteHrAccess(WidgetRef ref) {
  return canWriteHrAccessPolicy(ref.read(appAccessPolicyProvider));
}

/// Create atoms: source `hr:write` ∩ matrix `tenant:admin`.
bool canCreateHrAccess(AppAccessPolicy policy) {
  if (!canWriteHrAccessPolicy(policy)) {
    return false;
  }
  return hrAccessCreateRequirement.isAllowed(policy) || policy.isElevated;
}

/// Update atoms: same intersection as create.
bool canUpdateHrAccess(AppAccessPolicy policy) {
  return canCreateHrAccess(policy);
}

/// Delete atoms: matrix ∩ `hr:write` (source [canWriteHrAccess]).
bool canDeleteHrAccess(AppAccessPolicy policy) {
  return canWriteHrAccessPolicy(policy);
}

/// Per-section tab strip gate.
AccessRequirement hrSectionRequirement(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.access => HrManageUsersRolesAtomPermissions.tab,
    HrDeskSection.leaveRequests => HrLeaveRequestsAtomPermissions.tab,
    HrDeskSection.payroll => HrPayrollDraftsAtomPermissions.tab,
    HrDeskSection.shiftRoster => HrShiftsAtomPermissions.tab,
    HrDeskSection.staffDirectory => HrHumanResourcesAtomPermissions.tab,
  };
}

/// Alias used by payroll / desk helpers.
AccessRequirement hrDeskSectionTabRequirement(HrDeskSection section) {
  return hrSectionRequirement(section);
}

bool canViewHrSection(AppAccessPolicy policy, HrDeskSection section) {
  if (section == HrDeskSection.access) {
    return canReadHrAccess(policy);
  }
  return hrSectionRequirement(section).isAllowed(policy);
}

/// Alias — payroll / desk naming.
bool canViewHrDeskSection(AppAccessPolicy policy, HrDeskSection section) {
  return canViewHrSection(policy, section);
}

/// Sections the policy may show in the HR workspace tab strip.
List<HrDeskSection> hrAllowedSections(AppAccessPolicy policy) {
  return <HrDeskSection>[
    for (final HrDeskSection section in HrDeskSection.values)
      if (canViewHrSection(policy, section)) section,
  ];
}

/// Alias — payroll / desk naming.
List<HrDeskSection> hrAllowedDeskSections(AppAccessPolicy policy) {
  return hrAllowedSections(policy);
}

/// First authorized section (prefer staff directory), or null when none.
HrDeskSection? hrFallbackSection(AppAccessPolicy policy) {
  final List<HrDeskSection> sections = hrAllowedSections(policy);
  if (sections.isEmpty) {
    return null;
  }
  if (sections.contains(HrDeskSection.staffDirectory)) {
    return HrDeskSection.staffDirectory;
  }
  return sections.first;
}

/// Alias — payroll / desk naming.
HrDeskSection? hrFallbackDeskSection(AppAccessPolicy policy) {
  return hrFallbackSection(policy);
}

/// Human resources (staff) tab atom → permission mapping (inventory + matrix).
///
/// Nested roster / payroll actions reuse source ∪ / ∩ helpers — note mapping
/// in the Human resources tab permission scan.
abstract final class HrHumanResourcesAtomPermissions {
  static const AccessRequirement tab = hrReadRequirement;
  static const AccessRequirement listChrome = hrReadRequirement;
  static const AccessRequirement search = hrReadRequirement;
  static const AccessRequirement filters = hrReadRequirement;
  static const AccessRequirement settings = hrReadRequirement;
  static const AccessRequirement empty = hrReadRequirement;
  static const AccessRequirement loading = hrReadRequirement;
  static const AccessRequirement retry = hrReadRequirement;
  static const AccessRequirement activity = hrReadRequirement;
  static const AccessRequirement success = hrWriteRequirement;
  static const AccessRequirement validation = hrWriteRequirement;
  static const AccessRequirement rowSelect = hrReadRequirement;
  static const AccessRequirement detail = hrReadRequirement;
  static const AccessRequirement reviewProfile = hrReadRequirement;
  static const AccessRequirement nextActionAssign = hrWriteRequirement;
  static const AccessRequirement create = hrWriteRequirement;
  static const AccessRequirement update = hrWriteRequirement;
  static const AccessRequirement delete = hrWriteRequirement;
  static const AccessRequirement write = hrWriteRequirement;
  static const AccessRequirement addStaff = hrWriteRequirement;
  static const AccessRequirement editStaff = hrWriteRequirement;
  static const AccessRequirement assignDepartment = hrWriteRequirement;
  static const AccessRequirement assignPosition = hrWriteRequirement;
  static const AccessRequirement requestLeave = hrWriteRequirement;
  static const AccessRequirement compensation = hrWriteRequirement;
  static const AccessRequirement assignRole = hrWriteRequirement;
  static const AccessRequirement moduleAccess = hrWriteRequirement;
  static const AccessRequirement offboard = hrWriteRequirement;
  static const AccessRequirement revokeRole = hrWriteRequirement;
  static const AccessRequirement endAssignment = hrWriteRequirement;
  static const AccessRequirement recordAvailability = hrWriteRequirement;
  static const AccessRequirement assignShift = hrRosterWriteRequirement;
  static const AccessRequirement swapShift = hrRosterWriteRequirement;
  static const AccessRequirement runPayroll = hrPayrollRequirement;
  static const AccessRequirement nestedWrite = hrWriteRequirement;
  static const AccessRequirement nestedRosterWrite = hrRosterWriteRequirement;
  static const AccessRequirement nestedRead = hrReadRequirement;
  static const AccessRequirement entry = hrWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = hrWorkspaceEntryRequirement;
}

/// Leave requests tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Leave requests tab | navigate | read ∩ `hr:read` |
/// | Request leave (strip primary) | create | write ∩ `hr:write` |
/// | HR activity | progressive disclosure | read ∩ |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → leave detail | read | read ∩ |
/// | Next action Approve leave | approve | write ∩ |
/// | Detail Approve / Reject leave | update / delete | write ∩ |
/// | Nested request / approve / reject dialogs | create / update | write ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry | navigate | catalog ∩ `hr:read` (prompt ∪ noted) |
abstract final class HrLeaveRequestsAtomPermissions {
  static const AccessRequirement tab = hrWorkspaceReadRequirement;
  static const AccessRequirement listChrome = hrWorkspaceReadRequirement;
  static const AccessRequirement search = hrWorkspaceReadRequirement;
  static const AccessRequirement filters = hrWorkspaceReadRequirement;
  static const AccessRequirement settings = hrWorkspaceReadRequirement;
  static const AccessRequirement empty = hrWorkspaceReadRequirement;
  static const AccessRequirement loading = hrWorkspaceReadRequirement;
  static const AccessRequirement retry = hrWorkspaceReadRequirement;
  static const AccessRequirement activity = hrWorkspaceReadRequirement;
  static const AccessRequirement rowSelect = hrWorkspaceReadRequirement;
  static const AccessRequirement detail = hrWorkspaceReadRequirement;
  static const AccessRequirement nextAction = hrWorkspaceWriteRequirement;
  static const AccessRequirement requestLeave = hrWriteRequirement;
  static const AccessRequirement approveLeave = hrWorkspaceWriteRequirement;
  static const AccessRequirement rejectLeave = hrWriteRequirement;
  static const AccessRequirement approve = hrWorkspaceWriteRequirement;
  static const AccessRequirement write = hrWriteRequirement;
  static const AccessRequirement create = hrWriteRequirement;
  static const AccessRequirement update = hrWriteRequirement;
  static const AccessRequirement delete = hrWriteRequirement;
  static const AccessRequirement success = hrWriteRequirement;
  static const AccessRequirement validation = hrWriteRequirement;
  static const AccessRequirement nestedWrite = AccessRequirement();
  static const AccessRequirement nestedRead = AccessRequirement();
  static const AccessRequirement routeEntry = hrWorkspaceEntryRequirement;
  static const AccessRequirement entry = hrWorkspaceEntryRequirement;
}

/// Shifts tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Shifts tab | navigate | read ∩ `hr:read` |
/// | Schedule templates (strip primary) | create entry | write ∩ `roster:write` |
/// | HR activity | progressive disclosure | read ∩ |
/// | Queue switcher / search / filters / columns | read chrome | read ∩ |
/// | Row select → work-item detail | read | read ∩ |
/// | Next action Publish roster | approve | publish ∩ `roster:publish` |
/// | Next action Override shift | update | write ∩ `roster:write` |
/// | Next action Approve/Reject swap | approve | approve ∩ `roster:approve` |
/// | Detail Preview / Generate roster | update / create | write ∩ |
/// | Detail Publish roster | approve | publish ∩ |
/// | Detail Override shift | update | write ∩ |
/// | Detail Approve / Reject swap | approve | approve ∩ |
/// | Template Create / Edit | create / update | write ∩ |
/// | Template Delete | delete | hr write ∩ `hr:write` |
/// | Nested publish / approve | nested write ∪ | publish \| approve |
abstract final class HrShiftsAtomPermissions {
  static const AccessRequirement tab = hrReadRequirement;
  static const AccessRequirement listChrome = hrReadRequirement;
  static const AccessRequirement search = hrReadRequirement;
  static const AccessRequirement filters = hrReadRequirement;
  static const AccessRequirement settings = hrReadRequirement;
  static const AccessRequirement empty = hrReadRequirement;
  static const AccessRequirement loading = hrReadRequirement;
  static const AccessRequirement retry = hrReadRequirement;
  static const AccessRequirement activity = hrReadRequirement;
  static const AccessRequirement rowSelect = hrReadRequirement;
  static const AccessRequirement detail = hrReadRequirement;
  static const AccessRequirement nextActionChrome = hrReadRequirement;
  static const AccessRequirement create = hrRosterWriteRequirement;
  static const AccessRequirement update = hrRosterWriteRequirement;
  static const AccessRequirement delete = hrWriteRequirement;
  static const AccessRequirement write = hrRosterWriteRequirement;
  static const AccessRequirement scheduleTemplates = hrRosterWriteRequirement;
  static const AccessRequirement previewRoster = hrRosterWriteRequirement;
  static const AccessRequirement generateRoster = hrRosterWriteRequirement;
  static const AccessRequirement overrideShift = hrRosterWriteRequirement;
  static const AccessRequirement publishRoster = hrRosterPublishRequirement;
  static const AccessRequirement approveSwap = hrRosterApproveRequirement;
  static const AccessRequirement rejectSwap = hrRosterApproveRequirement;
  static const AccessRequirement nestedWrite = hrRosterNestedWriteRequirement;
  static const AccessRequirement success = hrRosterWriteRequirement;
  static const AccessRequirement validation = hrRosterWriteRequirement;
  static const AccessRequirement entry = hrWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = hrWorkspaceEntryRequirement;
}

/// Payroll drafts tab atom → permission mapping (inventory + matrix).
abstract final class HrPayrollDraftsAtomPermissions {
  static const AccessRequirement tab = hrReadRequirement;
  static const AccessRequirement listChrome = hrReadRequirement;
  static const AccessRequirement search = hrReadRequirement;
  static const AccessRequirement filters = hrReadRequirement;
  static const AccessRequirement settings = hrReadRequirement;
  static const AccessRequirement empty = hrReadRequirement;
  static const AccessRequirement loading = hrReadRequirement;
  static const AccessRequirement retry = hrReadRequirement;
  static const AccessRequirement success = hrPayrollRequirement;
  static const AccessRequirement validation = hrPayrollRequirement;
  static const AccessRequirement rowSelect = hrReadRequirement;
  static const AccessRequirement detail = hrReadRequirement;
  static const AccessRequirement activity = hrReadRequirement;
  static const AccessRequirement preview = hrPayrollPreviewRequirement;
  static const AccessRequirement process = hrPayrollRequirement;
  static const AccessRequirement approve = hrPayrollRequirement;
  static const AccessRequirement nextAction = hrPayrollRequirement;
  static const AccessRequirement create = hrWriteRequirement;
  static const AccessRequirement update = hrWriteRequirement;
  static const AccessRequirement delete = hrWriteRequirement;
  static const AccessRequirement write = hrWriteRequirement;
  static const AccessRequirement nestedWrite = hrPayrollRequirement;
  static const AccessRequirement nestedWriteMatrix =
      hrPayrollNestedWriteMatrixRequirement;
  static const AccessRequirement nestedRead = hrReadRequirement;
  static const AccessRequirement routeEntry = hrWorkspaceEntryRequirement;
  static const AccessRequirement entry = hrWorkspaceEntryRequirement;
}

/// Manage users and roles tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Manage users and roles tab | navigate | read ∩ `hr:read` + ∪ admin |
/// | Panel toggle (Staff / Roles / Permissions) | progressive-disclosure | read |
/// | Search / filters / columns / pagination | read chrome | read |
/// | Empty / error / retry / tenant-required | read chrome | read |
/// | Refresh | read chrome | read |
/// | Row select → user / role / permission detail | read | read |
/// | Create staff / role / permission | create | create ∩ + source `hr:write` |
/// | Edit user / role / permission; assign; add role/permission | update | update ∩ + source `hr:write` |
/// | Remove role / remove direct permission | delete | delete ∩ `hr:write` |
/// | Open staff profile | navigate | read (linked profile) |
/// | Detail Close | progressive-disclosure | read |
/// | Nested cross-module | n/a | _(n/a)_ |
/// | HR activity (workspace secondary) | progressive-disclosure | workspace read |
///
/// Source inventory maps Access write chrome to [canWriteHrAccess] (`hr:write`).
/// Matrix create/update ∩ `tenant:admin` is applied via [canCreateHrAccess] /
/// [canUpdateHrAccess]. Delete matches source `hr:write`.
abstract final class HrAccessAtomPermissions {
  static const AccessRequirement tab = hrAccessReadRequirement;
  static const AccessRequirement listChrome = hrAccessReadRequirement;
  static const AccessRequirement search = hrAccessReadRequirement;
  static const AccessRequirement filters = hrAccessReadRequirement;
  static const AccessRequirement settings = hrAccessReadRequirement;
  static const AccessRequirement empty = hrAccessReadRequirement;
  static const AccessRequirement loading = hrAccessReadRequirement;
  static const AccessRequirement retry = hrAccessReadRequirement;
  static const AccessRequirement success = hrAccessUpdateRequirement;
  static const AccessRequirement validation = hrAccessUpdateRequirement;
  static const AccessRequirement rowSelect = hrAccessReadRequirement;
  static const AccessRequirement detail = hrAccessReadRequirement;
  static const AccessRequirement create = hrAccessCreateRequirement;
  static const AccessRequirement update = hrAccessUpdateRequirement;
  static const AccessRequirement delete = hrAccessDeleteRequirement;
  static const AccessRequirement write = hrWriteRequirement;
  static const AccessRequirement nestedRead = AccessRequirement();
  static const AccessRequirement nestedWrite = AccessRequirement();
  static const AccessRequirement entry = hrAccessReadRequirement;
  static const AccessRequirement routeEntry = hrWorkspaceEntryRequirement;
  static const AccessRequirement activity = hrWorkspaceReadRequirement;
}

/// Alias used by `screens/hr.md` / tab prompts.
typedef HrManageUsersRolesAtomPermissions = HrAccessAtomPermissions;
