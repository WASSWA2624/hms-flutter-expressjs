import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/operations/domain/entities/operations_entities.dart';

/// Module entitlement for the operations workspace route and sections.
const String operationsFacilitiesMaintenanceModule = 'facilities-maintenance';

/// Alias used by tests and newer call sites.
const String operationsFacilitiesModule =
    operationsFacilitiesMaintenanceModule;

/// Alias used by newer call sites / tests.
const String operationsActiveModule = operationsFacilitiesMaintenanceModule;

/// View / read UI (matrix ∩ `operations:read`).
///
/// Facility ABAC is enforced on route entry ([operationsWorkspaceEntryRequirement]);
/// in-page atoms reuse module + permission only (same pattern as housekeeping).
const AccessRequirement operationsWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.operationsRead],
  activeModules: <String>[operationsFacilitiesMaintenanceModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement operationsReadRequirement =
    operationsWorkspaceReadRequirement;

/// Create / update / delete mutations (matrix ∩ `operations:write`).
///
/// Source inventory `_mutationRequirement` — create request, assign, status,
/// service logs, notes. Asset mutations map to the same write ∩; Assets detail
/// has no write UI today (inventory).
const AccessRequirement operationsWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.operationsWrite],
  activeModules: <String>[operationsFacilitiesMaintenanceModule],
);

/// Alias matching historical `_mutationRequirement` / canMutate naming.
const AccessRequirement operationsMutationRequirement =
    operationsWorkspaceWriteRequirement;

/// Alias matching matrix create / update / delete ∩.
const AccessRequirement operationsWriteRequirement =
    operationsWorkspaceWriteRequirement;

/// Route entry — matches [AppRoutes.operations] ∪ `operations:read` |
/// `operations:write` plus `facilities-maintenance` and facility ABAC.
const AccessRequirement operationsWorkspaceEntryRequirement =
    RouteAccessCatalog.operationsEntry;

/// Report summary secondary (Assets matrix): ∩ `operations:read` only.
///
/// Source inventory says Report is always when workspace loads; Assets matrix
/// narrows to read ∩ — keep matrix for this tab and note mapping in tests.
const AccessRequirement operationsWorkspaceReportRequirement =
    operationsWorkspaceReadRequirement;

/// Alias used by tab atom maps.
const AccessRequirement operationsReportRequirement =
    operationsWorkspaceReportRequirement;

/// Effective capabilities for operations chrome.
///
/// - [canWrite] / [canMutate]: matrix create/update/delete ∩ `operations:write`
/// - [canReport]: matrix report ∩ `operations:read`
/// - [canRead]: matrix view ∩ `operations:read`
final class OperationsCapabilities {
  const OperationsCapabilities({
    required this.canWrite,
    required this.canReport,
    required this.canRead,
  });

  final bool canWrite;
  final bool canReport;
  final bool canRead;

  /// Historical alias for create / assign / status / notes mutations.
  bool get canMutate => canWrite;

  factory OperationsCapabilities.fromPolicy(AppAccessPolicy policy) {
    return OperationsCapabilities(
      canWrite: canWriteOperations(policy),
      canReport: canReportOperations(policy),
      canRead: canReadOperations(policy),
    );
  }
}

bool canEnterOperationsWorkspace(AppAccessPolicy policy) {
  return operationsWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadOperations(AppAccessPolicy policy) {
  return operationsWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteOperations(AppAccessPolicy policy) {
  return operationsWorkspaceWriteRequirement.isAllowed(policy);
}

bool canMutateOperations(AppAccessPolicy policy) {
  return canWriteOperations(policy);
}

bool canReportOperations(AppAccessPolicy policy) {
  return operationsWorkspaceReportRequirement.isAllowed(policy);
}

/// Per-section tab strip gate. Sections share workspace read until a tab
/// prompt documents a narrower requirement.
AccessRequirement operationsSectionTabRequirement(
  OperationsDeskSection section,
) {
  return switch (section) {
    OperationsDeskSection.assets => OperationsAssetsAtomPermissions.tab,
    OperationsDeskSection.allRequests ||
    OperationsDeskSection.open ||
    OperationsDeskSection.inProgress ||
    OperationsDeskSection.completed => operationsWorkspaceReadRequirement,
  };
}

bool canViewOperationsSection(
  AppAccessPolicy policy,
  OperationsDeskSection section,
) {
  return operationsSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the policy may show in the workspace tab strip.
List<OperationsDeskSection> operationsAllowedSections(AppAccessPolicy policy) {
  return <OperationsDeskSection>[
    for (final OperationsDeskSection section in OperationsDeskSection.values)
      if (canViewOperationsSection(policy, section)) section,
  ];
}

/// First authorized section (prefer all requests), or null when none are visible.
OperationsDeskSection? operationsFallbackSection(AppAccessPolicy policy) {
  final List<OperationsDeskSection> sections =
      operationsAllowedSections(policy);
  if (sections.isEmpty) {
    return null;
  }
  if (sections.contains(OperationsDeskSection.allRequests)) {
    return OperationsDeskSection.allRequests;
  }
  return sections.first;
}

/// Assets tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Assets tab | navigate | read ∩ `operations:read` |
/// | Create request (tab primary) | create | write ∩ `operations:write` |
/// | Report summary | read | report ∩ `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → asset detail | read | read ∩ |
/// | Asset detail identity tiles (no asset writes) | read | read ∩ |
/// | Nested create-request dialog | create | write ∩ |
/// | Asset create / update / delete UI | create / update / delete | write ∩ (no UI today) |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Matrix nested cross-module rows are _(n/a)_. Inventory documents asset
/// detail as progressive disclosure with **no write actions**; create/update/
/// delete still map to write ∩ for matrix completeness (request create on
/// this tab is the live create atom). Report uses Assets matrix read ∩
/// (source "Always" narrowed — note in tests). Facility ABAC is enforced on
/// route entry only; in-page atoms reuse module + permission.
abstract final class OperationsAssetsAtomPermissions {
  static const AccessRequirement tab = operationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement search = operationsWorkspaceReadRequirement;
  static const AccessRequirement filters = operationsWorkspaceReadRequirement;
  static const AccessRequirement settings = operationsWorkspaceReadRequirement;
  static const AccessRequirement empty = operationsWorkspaceReadRequirement;
  static const AccessRequirement loading = operationsWorkspaceReadRequirement;
  static const AccessRequirement retry = operationsWorkspaceReadRequirement;
  static const AccessRequirement success = operationsWorkspaceWriteRequirement;
  static const AccessRequirement validation =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = operationsWorkspaceReadRequirement;
  static const AccessRequirement detail = operationsWorkspaceReadRequirement;
  static const AccessRequirement create = operationsWorkspaceWriteRequirement;
  static const AccessRequirement update = operationsWorkspaceWriteRequirement;
  static const AccessRequirement delete = operationsWorkspaceWriteRequirement;
  static const AccessRequirement write = operationsWorkspaceWriteRequirement;
  static const AccessRequirement mutate = operationsWorkspaceWriteRequirement;
  static const AccessRequirement createRequest =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement createAsset =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement updateAsset =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement deleteAsset =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement report = operationsWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement entry = operationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      operationsWorkspaceEntryRequirement;
}
