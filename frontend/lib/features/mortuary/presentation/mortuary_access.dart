import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/mortuary/domain/entities/mortuary_entities.dart';

/// Module entitlement for the mortuary workspace route and panels.
const String mortuaryActiveModule = 'mortuary';

/// Route entry — source inventory / [AppRoutes.mortuary] ∪:
/// `mortuary:read` | `write` | `approve` | `release` | `audit` + module +
/// facility ([RouteAccessCatalog.mortuaryEntry]).
const AccessRequirement mortuaryWorkspaceRouteEntryRequirement =
    RouteAccessCatalog.mortuaryEntry;

/// Alias used by atom maps for deep-link / shell entry.
const AccessRequirement mortuaryWorkspaceEntryRequirement =
    mortuaryWorkspaceRouteEntryRequirement;

/// View / read UI (matrix ∩ `mortuary:read`).
const AccessRequirement mortuaryWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryRead],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement mortuaryReadRequirement =
    mortuaryWorkspaceReadRequirement;

/// Create / update / delete mutations (matrix ∩ `mortuary:write`).
///
/// Source inventory (`screens/mortuary.md`) removed no-op mutation chrome;
/// keep the gate so write-only helpers and future controls stay aligned.
const AccessRequirement mortuaryWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryWrite],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement mortuaryWriteRequirement =
    mortuaryWorkspaceWriteRequirement;

/// Storage assignment mutations (fine-grained ∩ `mortuary:manage_storage`).
const AccessRequirement mortuaryManageStorageRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryManageStorage],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Post-mortem request create (fine-grained ∩ `mortuary:post_mortem_request`).
const AccessRequirement mortuaryPostMortemRequestRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.mortuaryPostMortemRequest],
      activeModules: <String>[mortuaryActiveModule],
      requiresFacilityContext: true,
    );

/// Approvals (fine-grained ∩ `mortuary:approve`).
const AccessRequirement mortuaryApproveRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryApprove],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Release authorisations (fine-grained ∩ `mortuary:release`).
const AccessRequirement mortuaryReleaseRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryRelease],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Nested custody / post-mortem workflow write (matrix ∪):
/// `mortuary:post_mortem_request` | `mortuary:approve` | `mortuary:write`.
///
/// No nested write chrome mounts today (inventory removed no-ops); keep the
/// gate for helpers / tests and future entry points from Custody detail.
const AccessRequirement mortuaryNestedWorkflowWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.mortuaryPostMortemRequest,
        AppPermissions.mortuaryApprove,
        AppPermissions.mortuaryWrite,
      ],
      activeModules: <String>[mortuaryActiveModule],
      requiresFacilityContext: true,
    );

/// Billing events panel (fine-grained ∩):
/// `mortuary:billing_event` ∩ `billing:read` where billable events are shown.
const AccessRequirement mortuaryBillingPanelRequirement = AccessRequirement(
  allPermissions: <AppPermission>[
    AppPermissions.mortuaryBillingEvent,
    AppPermissions.billingRead,
  ],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Print / export (source inventory ∪):
/// `mortuary:export` | `reports:read` + facility context.
const AccessRequirement mortuaryExportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.mortuaryExport,
    AppPermissions.reportsRead,
  ],
  requiresFacilityContext: true,
);

/// Audit panels (fine-grained ∩ `mortuary:audit`). No dedicated audit panel
/// mounts on Reports today; keep for helpers / future chrome.
const AccessRequirement mortuaryAuditRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryAudit],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Reports tab view / read UI (matrix ∪):
/// `mortuary:read` | `mortuary:audit` | `mortuary:export` + module + facility.
///
/// Lets audit- or export-only entrants open the Reports strip without
/// ∩ `mortuary:read`. Standard ∩ read remains [mortuaryWorkspaceReadRequirement].
const AccessRequirement mortuaryReportsTabReadRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.mortuaryRead,
    AppPermissions.mortuaryAudit,
    AppPermissions.mortuaryExport,
  ],
  activeModules: <String>[mortuaryActiveModule],
  requiresFacilityContext: true,
);

/// Reports nested cross-module write (matrix ∪ `mortuary:export` only).
///
/// Print documents keep source inventory ∪ `mortuary:export` | `reports:read`
/// via [mortuaryExportRequirement]; this gate documents the matrix nested-write
/// row and future export-only entry points.
const AccessRequirement mortuaryReportsNestedExportWriteRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.mortuaryExport],
      activeModules: <String>[mortuaryActiveModule],
      requiresFacilityContext: true,
    );

bool canEnterMortuaryWorkspace(AppAccessPolicy policy) {
  return mortuaryWorkspaceRouteEntryRequirement.isAllowed(policy);
}

bool canReadMortuary(AppAccessPolicy policy) {
  return mortuaryWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteMortuary(AppAccessPolicy policy) {
  return mortuaryWorkspaceWriteRequirement.isAllowed(policy);
}

bool canManageMortuaryStorage(AppAccessPolicy policy) {
  return mortuaryManageStorageRequirement.isAllowed(policy);
}

bool canRequestMortuaryPostMortem(AppAccessPolicy policy) {
  return mortuaryPostMortemRequestRequirement.isAllowed(policy);
}

bool canApproveMortuary(AppAccessPolicy policy) {
  return mortuaryApproveRequirement.isAllowed(policy);
}

bool canReleaseMortuary(AppAccessPolicy policy) {
  return mortuaryReleaseRequirement.isAllowed(policy);
}

bool canWriteMortuaryNestedWorkflow(AppAccessPolicy policy) {
  return mortuaryNestedWorkflowWriteRequirement.isAllowed(policy);
}

bool canViewMortuaryBillingPanel(AppAccessPolicy policy) {
  return mortuaryBillingPanelRequirement.isAllowed(policy);
}

bool canExportMortuary(AppAccessPolicy policy) {
  return mortuaryExportRequirement.isAllowed(policy);
}

bool canAuditMortuary(AppAccessPolicy policy) {
  return mortuaryAuditRequirement.isAllowed(policy);
}

bool canViewMortuaryReportsTab(AppAccessPolicy policy) {
  return mortuaryReportsTabReadRequirement.isAllowed(policy);
}

bool canWriteMortuaryReportsNestedExport(AppAccessPolicy policy) {
  return mortuaryReportsNestedExportWriteRequirement.isAllowed(policy);
}

/// Per-panel tab strip gate. Overview / Intake / Storage / Custody / Release /
/// Reports use their atom maps. Reports uses ∪ `read`|`audit`|`export`.
AccessRequirement mortuaryPanelTabRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.tab,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.tab,
    mortuaryPanelStorage => MortuaryStorageAtomPermissions.tab,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.tab,
    mortuaryPanelRelease => MortuaryReleaseAtomPermissions.tab,
    mortuaryPanelReporting => MortuaryReportsAtomPermissions.tab,
    _ => mortuaryWorkspaceReadRequirement,
  };
}

/// Detail Print documents gate for the active panel (source ∪ export|reports).
AccessRequirement mortuaryPanelPrintRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.printDocuments,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.printDocuments,
    mortuaryPanelStorage => MortuaryStorageAtomPermissions.printDocuments,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.printDocuments,
    mortuaryPanelRelease => MortuaryReleaseAtomPermissions.printDocuments,
    mortuaryPanelReporting => MortuaryReportsAtomPermissions.printDocuments,
    _ => mortuaryExportRequirement,
  };
}

/// Detail Billing events panel gate for the active panel
/// (∩ `mortuary:billing_event` + `billing:read`).
AccessRequirement mortuaryPanelBillingRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.billingPanel,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.billingPanel,
    mortuaryPanelStorage => MortuaryStorageAtomPermissions.billingPanel,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.billingPanel,
    mortuaryPanelRelease => MortuaryReleaseAtomPermissions.billingPanel,
    mortuaryPanelReporting => MortuaryReportsAtomPermissions.billingPanel,
    _ => mortuaryBillingPanelRequirement,
  };
}

/// Open Billing workspace (settle outstanding) — never a module cashier.
/// Returns null when the panel does not mount Open billing.
AccessRequirement? mortuaryPanelOpenBillingRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.openBilling,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.openBilling,
    mortuaryPanelStorage => MortuaryStorageAtomPermissions.openBilling,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.openBilling,
    mortuaryPanelRelease => MortuaryReleaseAtomPermissions.openBilling,
    mortuaryPanelReporting => MortuaryReportsAtomPermissions.openBilling,
    _ => null,
  };
}

/// True when [policy] may navigate to Billing from a mortuary panel.
bool canOpenMortuaryBilling(AppAccessPolicy policy, [String? panel]) {
  final AccessRequirement? requirement = panel == null
      ? billingReadRequirement
      : mortuaryPanelOpenBillingRequirement(panel);
  return requirement?.isAllowed(policy) ?? false;
}

bool canViewMortuaryPanel(AppAccessPolicy policy, String panel) {
  return mortuaryPanelTabRequirement(panel).isAllowed(policy);
}

/// Panels the user may open.
///
/// Most tabs use matrix ∩ `mortuary:read`. Reports uses ∪
/// `mortuary:read`|`audit`|`export` so audit-/export-only users see that strip
/// without other panels. Route-only entrants (approve / release / write without
/// read or Reports ∪) may still open `/mortuary` via
/// [mortuaryWorkspaceRouteEntryRequirement] and see panel chrome read-only —
/// they must not see write / export / nested workflow / billing-gated panels.
List<String> mortuaryAllowedPanels(AppAccessPolicy policy) {
  final List<String> byRead = mortuaryPanels
      .where((String panel) => canViewMortuaryPanel(policy, panel))
      .toList(growable: false);
  if (byRead.isNotEmpty) {
    return byRead;
  }
  if (!canEnterMortuaryWorkspace(policy)) {
    return const <String>[];
  }
  return List<String>.unmodifiable(mortuaryPanels);
}

String? mortuaryFallbackPanel(AppAccessPolicy policy) {
  final List<String> allowed = mortuaryAllowedPanels(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(mortuaryPanelOverview)) {
    return mortuaryPanelOverview;
  }
  return allowed.first;
}

/// Atom → requirement map for Mortuary Overview (`/mortuary` / `?panel=overview`).
///
/// Inventory: `screens/mortuary.md` → Overview tab (cases summary worklist;
/// read-only detail; Print documents when export ∪). Nested cross-module
/// read/write matrix rows are n/a for this tab. Billing events use ∩
/// `mortuary:billing_event` + `billing:read`. Mutation chrome (Receive case /
/// Assign storage / Record custody / Approve release / Post-mortem) was
/// removed from inventory — gates kept for helpers / future controls.
/// Route entry ∪ is [routeEntry]. Export keeps source ∪
/// `mortuary:export` | `reports:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Overview strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (guidance text only) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ∩ `billing-payments` ([openBilling]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Receive case | create | write ∩ ([create]) — not mounted |
/// | Assign storage | update | manage_storage ∩ — not mounted |
/// | Post-mortem request / approve / release | create / approve / update | fine-grained ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
/// | Nested cross-module read / write | — | n/a (matrix) |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
abstract final class MortuaryOverviewAtomPermissions {
  static const AccessRequirement tab = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement listChrome = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement search = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement filters = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement settings = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement pagination = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement empty = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement loading = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement retry = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement success = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement validation = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement detail = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement nextAction = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement create = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement update = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement receiveCase = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;

  /// Navigate to Billing workspace to settle — never a module cashier.
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedRead = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}

/// Atom → requirement map for Mortuary Intake (`/mortuary?panel=intake`).
///
/// Inventory: cases worklist; receive-case create/update/delete ∩
/// `mortuary:write` — no-op mutation chrome removed. Read-only detail; Print
/// documents when export ∪. Billing events use ∩ `mortuary:billing_event` +
/// `billing:read`. Open billing uses Billing read (`billing:read` ∩
/// `billing-payments`) — never a module cashier. Financial inventory:
/// `mortuary_intake_billing_inventory.dart`. Route entry ∪ is [routeEntry].
/// Export keeps source ∪ `mortuary:export` | `reports:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Intake strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (guidance; Clear billing → Open billing when allowed) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ∩ `billing-payments` ([openBilling]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Receive case | create | write ∩ ([create] / [receiveCase]) — not mounted |
/// | Update / delete mutations | update / delete | write ∩ — not mounted |
/// | Assign storage | update | manage_storage ∩ — not mounted |
/// | Post-mortem request / approve / release | create / approve / update | fine-grained ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
/// | Nested cross-module read / write | — | n/a (matrix) |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
abstract final class MortuaryIntakeAtomPermissions {
  static const AccessRequirement tab = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement listChrome = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement search = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement filters = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement settings = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement pagination = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement empty = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement loading = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement retry = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement success = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement validation = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement detail = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement nextAction = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement create = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement update = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement receiveCase = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;

  /// Navigate to Billing workspace to settle — never a module cashier.
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedRead = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}

/// Atom → requirement map for Mortuary Storage (`/mortuary?panel=storage`).
///
/// Storage-assignments worklist; assign-storage create/update ∩
/// `mortuary:manage_storage`; delete ∩ `mortuary:write` — mutation chrome not
/// mounted. Read-only detail; Print documents when export ∪. Billing events
/// use ∩ `mortuary:billing_event` + `billing:read`. Open billing uses Billing
/// read (`billing:read` ∩ `billing-payments`) — never a module cashier.
/// Financial inventory: `mortuary_storage_billing_inventory.dart`.
/// Route entry ∪ is [routeEntry]. Export keeps source ∪
/// `mortuary:export` | `reports:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Storage strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized storage) | visible feedback | manage_storage ∩ ([success]) |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (guidance text only) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Assign storage (create / update assignment) | create / update | manage_storage ∩ ([create] / [update]) — not mounted |
/// | Delete / void assignment | delete | write ∩ ([delete]) — not mounted |
/// | Post-mortem request / approve / release | create / approve / update | fine-grained ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
/// | Nested cross-module read / write | — | n/a (matrix) |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
abstract final class MortuaryStorageAtomPermissions {
  static const AccessRequirement tab = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement listChrome = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement search = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement filters = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement settings = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement pagination = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement empty = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement loading = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement retry = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement success = mortuaryManageStorageRequirement;
  static const AccessRequirement validation = mortuaryManageStorageRequirement;
  static const AccessRequirement rowSelect = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement detail = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement nextAction = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement create = mortuaryManageStorageRequirement;
  static const AccessRequirement update = mortuaryManageStorageRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement assignStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;

  /// Navigate to Billing workspace to settle — never a module cashier.
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedRead = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}

/// Atom → requirement map for Mortuary Custody (`/mortuary?panel=custody`).
///
/// Custody-events worklist; read-only detail; Print documents when export ∪.
/// Nested write ∪ is documented via [nestedWrite] — no write chrome mounts
/// today. Export keeps source ∪ `mortuary:export` | `reports:read`. Billing
/// events use ∩ `mortuary:billing_event` + `billing:read`. Open billing uses
/// Billing read (`billing:read` ∩ `billing-payments`) — never a module cashier.
/// Financial inventory: `mortuary_custody_billing_inventory.dart`.
/// Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Custody strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (guidance text only) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Nested post-mortem request / approve / record custody | create / update / approve | nested write ∪ ([nestedWrite]) — not mounted |
/// | Assign storage | update | manage_storage ∩ — not mounted |
/// | Release / approve release | approve / update | release / approve ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
abstract final class MortuaryCustodyAtomPermissions {
  static const AccessRequirement tab = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement listChrome = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement search = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement filters = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement settings = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement pagination = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement empty = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement loading = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement retry = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement success = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement validation = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement detail = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement nextAction = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement create = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement update = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedWrite =
      mortuaryNestedWorkflowWriteRequirement;
  static const AccessRequirement nestedRead = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}

/// Atom → requirement map for Mortuary Release (`/mortuary?panel=release`).
///
/// Release-authorisations worklist; body release update ∩ `mortuary:release`;
/// approve ∩ `mortuary:approve` — no-op mutation chrome removed. Read-only
/// detail; Print documents when export ∪. Billing events use ∩
/// `mortuary:billing_event` + `billing:read`. Open billing uses Billing read
/// (`billing:read` ∩ `billing-payments`) — never a module cashier.
/// Financial inventory: `mortuary_release_billing_inventory.dart`.
/// Route entry ∪ is [routeEntry]. Export keeps source ∪
/// `mortuary:export` | `reports:read`. Matrix create/delete stay ∩ write;
/// matrix update is ∩ `mortuary:release` ([update] / [release]).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Release strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized release) | visible feedback | release ∩ ([success]) |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (Clear billing / release guidance) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ([openBilling]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Create release authorisation / receive-adjacent create | create | write ∩ ([create]) — not mounted |
/// | Record / approve body release | update / approve | release ∩ / approve ∩ — not mounted |
/// | Delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Assign storage | update | manage_storage ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
/// | Nested cross-module read / write | — | n/a (matrix) |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
abstract final class MortuaryReleaseAtomPermissions {
  static const AccessRequirement tab = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement listChrome = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement search = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement filters = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement settings = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement pagination = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement empty = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement loading = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement retry = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement success = mortuaryReleaseRequirement;
  static const AccessRequirement validation = mortuaryReleaseRequirement;
  static const AccessRequirement rowSelect = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement detail = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement nextAction = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement create = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement update = mortuaryReleaseRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedRead = mortuaryWorkspaceReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}

/// Atom → requirement map for Mortuary Reports (`/mortuary?panel=reporting`).
///
/// Inventory: `screens/mortuary.md` → Reports tab (post-mortem / reporting
/// worklist; exports & audit). Matrix view ∪ is [tab] /
/// `mortuary:read`|`audit`|`export`. Matrix ∩ read stays [read] for helpers.
/// Nested cross-module write ∪ is [nestedWrite] `mortuary:export` only; Print
/// documents keep source ∪ `mortuary:export`|`reports:read` ([printDocuments]).
/// Nested cross-module read is n/a. Billing events use ∩
/// `mortuary:billing_event` + `billing:read`. Mutation chrome removed from
/// inventory — gates kept for helpers / future controls. Route entry ∪ is
/// [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Reports strip tab / count | navigate | read ∪ read\|audit\|export ([tab]) |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∪ ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | read ∪ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → detail | read / navigate | read ∪ |
/// | Next action (guidance text only) | read | read ∪ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∪ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Open billing | navigate | billing:read ∩ `billing-payments` ([openBilling]) |
/// | Detail Print documents | export | source export ∪ ([printDocuments]) |
/// | Nested export write entry | export | matrix export ∪ ([nestedWrite]) — not mounted beyond print |
/// | Create / update / delete mutations | create / update / delete | write ∩ — not mounted |
/// | Assign storage / approve / release / post-mortem | update / approve | fine-grained ∩ — not mounted |
/// | Audit panel | read | audit ∩ ([audit]) — not mounted |
/// | Nested cross-module read | — | n/a (matrix) |
/// | Route entry (deep link) | navigate | ∪ read\|write\|approve\|release\|audit ([routeEntry]) |
///
/// Financial inventory: `mortuary_reports_billing_inventory.dart`. Open billing
/// uses Billing read — never a module cashier.
abstract final class MortuaryReportsAtomPermissions {
  static const AccessRequirement tab = mortuaryReportsTabReadRequirement;
  static const AccessRequirement listChrome = mortuaryReportsTabReadRequirement;
  static const AccessRequirement search = mortuaryReportsTabReadRequirement;
  static const AccessRequirement filters = mortuaryReportsTabReadRequirement;
  static const AccessRequirement settings = mortuaryReportsTabReadRequirement;
  static const AccessRequirement pagination = mortuaryReportsTabReadRequirement;
  static const AccessRequirement empty = mortuaryReportsTabReadRequirement;
  static const AccessRequirement loading = mortuaryReportsTabReadRequirement;
  static const AccessRequirement retry = mortuaryReportsTabReadRequirement;
  static const AccessRequirement success = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement validation = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = mortuaryReportsTabReadRequirement;
  static const AccessRequirement detail = mortuaryReportsTabReadRequirement;
  static const AccessRequirement nextAction = mortuaryReportsTabReadRequirement;
  static const AccessRequirement create = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement update = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement delete = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement write = mortuaryWorkspaceWriteRequirement;
  static const AccessRequirement manageStorage = mortuaryManageStorageRequirement;
  static const AccessRequirement postMortemRequest =
      mortuaryPostMortemRequestRequirement;
  static const AccessRequirement approve = mortuaryApproveRequirement;
  static const AccessRequirement release = mortuaryReleaseRequirement;
  static const AccessRequirement billingPanel = mortuaryBillingPanelRequirement;
  static const AccessRequirement openBilling = billingReadRequirement;
  static const AccessRequirement printDocuments = mortuaryExportRequirement;
  static const AccessRequirement export = mortuaryExportRequirement;
  static const AccessRequirement nestedWrite =
      mortuaryReportsNestedExportWriteRequirement;
  static const AccessRequirement audit = mortuaryAuditRequirement;
  static const AccessRequirement nestedRead = mortuaryReportsTabReadRequirement;
  static const AccessRequirement entry = mortuaryWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      mortuaryWorkspaceRouteEntryRequirement;
  static const AccessRequirement read = mortuaryWorkspaceReadRequirement;
}
