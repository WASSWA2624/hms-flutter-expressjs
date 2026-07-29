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

/// Per-section tab strip gate. Sections share workspace read ∩ until a tab
/// prompt documents a narrower requirement.
AccessRequirement operationsSectionTabRequirement(
  OperationsDeskSection section,
) {
  return switch (section) {
    OperationsDeskSection.allRequests =>
      OperationsAllRequestsAtomPermissions.tab,
    OperationsDeskSection.open => OperationsOpenAtomPermissions.tab,
    OperationsDeskSection.inProgress =>
      OperationsInProgressAtomPermissions.tab,
    OperationsDeskSection.completed => OperationsCompletedAtomPermissions.tab,
    OperationsDeskSection.assets => OperationsAssetsAtomPermissions.tab,
  };
}

/// Tab-strip Create request primary — matrix create ∩ via section atom map.
AccessRequirement operationsSectionCreateRequirement(
  OperationsDeskSection section,
) {
  return switch (section) {
    OperationsDeskSection.allRequests =>
      OperationsAllRequestsAtomPermissions.createRequest,
    OperationsDeskSection.open => OperationsOpenAtomPermissions.createRequest,
    OperationsDeskSection.inProgress =>
      OperationsInProgressAtomPermissions.createRequest,
    OperationsDeskSection.completed =>
      OperationsCompletedAtomPermissions.createRequest,
    OperationsDeskSection.assets =>
      OperationsAssetsAtomPermissions.createRequest,
  };
}

/// Tab-strip Report secondary — matrix report ∩ via section atom map.
AccessRequirement operationsSectionReportRequirement(
  OperationsDeskSection section,
) {
  return switch (section) {
    OperationsDeskSection.allRequests =>
      OperationsAllRequestsAtomPermissions.report,
    OperationsDeskSection.open => OperationsOpenAtomPermissions.report,
    OperationsDeskSection.inProgress =>
      OperationsInProgressAtomPermissions.report,
    OperationsDeskSection.completed => OperationsCompletedAtomPermissions.report,
    OperationsDeskSection.assets => OperationsAssetsAtomPermissions.report,
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

/// All requests tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All requests tab | navigate | read ∩ `operations:read` |
/// | Create request (tab primary) | create | write ∩ `operations:write` |
/// | Report summary | read | report ∩ `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Status filter (All only) | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → request detail | read | read ∩ |
/// | Next-action column chrome | progressive disclosure | read ∩ |
/// | Write next-actions (Assign / …) | create / update | write ∩ ([mutate]) |
/// | Detail complementary writes | update | write ∩ |
/// | Nested create / assign / status / log / notes | create / update | write ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Report uses matrix read ∩ (source inventory "Always" narrowed — note in
/// tests). Facility ABAC is on route entry only; in-page atoms reuse module +
/// permission. Next-action **column** stays under read ∩; write controls still
/// require [mutate] / [canMutateOperations] before mount.
abstract final class OperationsAllRequestsAtomPermissions {
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
  static const AccessRequirement nextAction =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement create = operationsWorkspaceWriteRequirement;
  static const AccessRequirement update = operationsWorkspaceWriteRequirement;
  static const AccessRequirement delete = operationsWorkspaceWriteRequirement;
  static const AccessRequirement write = operationsWorkspaceWriteRequirement;
  static const AccessRequirement mutate = operationsMutationRequirement;
  static const AccessRequirement createRequest =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement assign = operationsWorkspaceWriteRequirement;
  static const AccessRequirement updateStatus =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement serviceLog =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement note = operationsWorkspaceWriteRequirement;
  static const AccessRequirement closeout = operationsWorkspaceWriteRequirement;
  static const AccessRequirement report = operationsWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement entry = operationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      operationsWorkspaceEntryRequirement;
}

/// Open tab atom → permission mapping (inventory + matrix).
///
/// Target: `/operations?section=open`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Open tab | navigate | read ∩ `operations:read` |
/// | Create request (tab primary) | create | write ∩ `operations:write` |
/// | Report summary | read | report ∩ `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Status filter | — | absent (tab owns status) |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → request detail | read | read ∩ |
/// | Next-action column chrome | progressive disclosure | read ∩ |
/// | Next action Assign | update | write ∩ ([assign] / [mutate]) |
/// | Detail complementary writes | update | write ∩ |
/// | Nested create / assign / status / log / notes | create / update | write ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Report uses matrix read ∩ (source inventory "Always" narrowed — note in
/// tests). Facility ABAC is on route entry only; in-page atoms reuse module +
/// permission. Matrix nested cross-module rows are _(n/a)_. Next-action
/// **column** stays under read ∩; Assign / other write controls still require
/// [assign] / [mutate] before mount.
abstract final class OperationsOpenAtomPermissions {
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
  /// Next-action **column** chrome (progressive disclosure) under read ∩;
  /// Assign / other write controls still require [assign] / [mutate].
  static const AccessRequirement nextAction =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement create = operationsWorkspaceWriteRequirement;
  static const AccessRequirement update = operationsWorkspaceWriteRequirement;
  static const AccessRequirement delete = operationsWorkspaceWriteRequirement;
  static const AccessRequirement write = operationsWorkspaceWriteRequirement;
  static const AccessRequirement mutate = operationsMutationRequirement;
  static const AccessRequirement createRequest =
      operationsWriteRequirement;
  static const AccessRequirement assign = operationsWorkspaceWriteRequirement;
  static const AccessRequirement updateStatus =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement serviceLog =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement note = operationsWorkspaceWriteRequirement;
  static const AccessRequirement closeout = operationsWorkspaceWriteRequirement;
  static const AccessRequirement report = operationsWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement entry = operationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      operationsWorkspaceEntryRequirement;
}

/// In progress tab atom → permission mapping (inventory + matrix).
///
/// Target: `/operations?section=in-progress`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | In progress tab | navigate | read ∩ `operations:read` |
/// | Create request (tab primary) | create | write ∩ `operations:write` |
/// | Report summary | read | report ∩ `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Status filter | — | absent (tab owns status) |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → request detail | read | read ∩ |
/// | Next action Update status (no asset) | update | write ∩ ([updateStatus]) |
/// | Next action Add service log (with asset) | update | write ∩ ([serviceLog]) |
/// | Detail complementary writes | update | write ∩ |
/// | Nested create / assign / status / log / notes | create / update | write ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Report uses matrix read ∩ (source inventory "Always" narrowed — note in
/// tests). Facility ABAC is on route entry only; in-page atoms reuse module +
/// permission. Matrix nested cross-module rows are _(n/a)_. [nextAction] maps
/// to write ∩ because this tab's next-actions are stage writes (Update status /
/// Add service log); unauthorized rows mount nothing ([canMutateOperations]).
abstract final class OperationsInProgressAtomPermissions {
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
  /// Stage-write next-actions (Update status / Add service log) under write ∩.
  static const AccessRequirement nextAction =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement create = operationsWorkspaceWriteRequirement;
  static const AccessRequirement update = operationsWorkspaceWriteRequirement;
  static const AccessRequirement delete = operationsWorkspaceWriteRequirement;
  static const AccessRequirement write = operationsWorkspaceWriteRequirement;
  static const AccessRequirement mutate = operationsMutationRequirement;
  static const AccessRequirement createRequest = operationsWriteRequirement;
  static const AccessRequirement assign = operationsWorkspaceWriteRequirement;
  static const AccessRequirement updateStatus =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement serviceLog =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement note = operationsWorkspaceWriteRequirement;
  static const AccessRequirement closeout = operationsWorkspaceWriteRequirement;
  static const AccessRequirement report = operationsWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement entry = operationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      operationsWorkspaceEntryRequirement;
}

/// Completed tab atom → permission mapping (inventory + matrix).
///
/// Target: `/operations?section=completed` (completed / cancelled).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed tab | navigate | read ∩ `operations:read` |
/// | Create request (tab primary) | create | write ∩ `operations:write` |
/// | Report summary | read | report ∩ `operations:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Status filter | — | absent (tab owns status) |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Success snackbar / form validation | feedback | write ∩ |
/// | Row select → request detail | read | read ∩ |
/// | Next-action column chrome | progressive disclosure | read ∩ |
/// | Next action Closeout (write control) | update | write ∩ ([closeout]) |
/// | Cancelled non-button copy | read chrome | read ∩ |
/// | Detail complementary writes | update | write ∩ |
/// | Nested create / assign / status / log / notes | create / update | write ∩ |
/// | Nested cross-module read/write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | entry ∪ read\|write |
///
/// Report uses matrix read ∩ (source "Always" narrowed — note in tests).
/// Facility ABAC is on route entry only; in-page atoms reuse module +
/// permission. Matrix nested cross-module rows are _(n/a)_. Next-action
/// **column** stays under read ∩; Closeout / other write controls still
/// require [closeout] / [mutate] before mount.
abstract final class OperationsCompletedAtomPermissions {
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
  /// Next-action **column** chrome (progressive disclosure) under read ∩;
  /// Closeout / other write controls still require [closeout] / [mutate].
  static const AccessRequirement nextAction =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement create = operationsWorkspaceWriteRequirement;
  static const AccessRequirement update = operationsWorkspaceWriteRequirement;
  static const AccessRequirement delete = operationsWorkspaceWriteRequirement;
  static const AccessRequirement write = operationsWorkspaceWriteRequirement;
  static const AccessRequirement mutate = operationsMutationRequirement;
  static const AccessRequirement createRequest =
      operationsWriteRequirement;
  static const AccessRequirement assign = operationsWorkspaceWriteRequirement;
  static const AccessRequirement updateStatus =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement serviceLog =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement note = operationsWorkspaceWriteRequirement;
  static const AccessRequirement closeout = operationsWorkspaceWriteRequirement;
  static const AccessRequirement report = operationsWorkspaceReportRequirement;
  static const AccessRequirement nestedWrite =
      operationsWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      operationsWorkspaceReadRequirement;
  static const AccessRequirement entry = operationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      operationsWorkspaceEntryRequirement;
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
