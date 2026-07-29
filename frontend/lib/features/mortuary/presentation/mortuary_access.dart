import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
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
/// mounts on Custody today; keep for helpers / future chrome.
const AccessRequirement mortuaryAuditRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.mortuaryAudit],
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

/// Per-panel tab strip gate. Overview / Intake / Custody use their atom maps;
/// other panels share ∩ `mortuary:read` until their tab scans land.
AccessRequirement mortuaryPanelTabRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.tab,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.tab,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.tab,
    _ => mortuaryWorkspaceReadRequirement,
  };
}

/// Detail Print documents gate for the active panel (source ∪ export|reports).
AccessRequirement mortuaryPanelPrintRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.printDocuments,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.printDocuments,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.printDocuments,
    _ => mortuaryExportRequirement,
  };
}

/// Detail Billing events panel gate for the active panel
/// (∩ `mortuary:billing_event` + `billing:read`).
AccessRequirement mortuaryPanelBillingRequirement(String panel) {
  return switch (panel) {
    mortuaryPanelOverview => MortuaryOverviewAtomPermissions.billingPanel,
    mortuaryPanelIntake => MortuaryIntakeAtomPermissions.billingPanel,
    mortuaryPanelCustody => MortuaryCustodyAtomPermissions.billingPanel,
    _ => mortuaryBillingPanelRequirement,
  };
}

bool canViewMortuaryPanel(AppAccessPolicy policy, String panel) {
  return mortuaryPanelTabRequirement(panel).isAllowed(policy);
}

/// Panels the user may open.
///
/// Matrix tab read is ∩ `mortuary:read`. Route-only entrants (approve / release /
/// audit / write without `mortuary:read`) may still open `/mortuary` via
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
/// Inventory: `screens/mortuary.md` → Intake tab (cases worklist; receive-case
/// create ∩ `mortuary:write` — no-op chrome removed). Read-only detail; Print
/// documents when export ∪. Nested cross-module write matrix is n/a for this
/// tab. Billing events use ∩ `mortuary:billing_event` + `billing:read`.
/// Route entry ∪ is [routeEntry].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Intake strip tab / count | navigate | read ∩ `mortuary:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → detail | read / navigate | read ∩ |
/// | Next action (guidance text only) | read | read ∩ |
/// | Detail Identity / Storage / Custody / Viewing / Post-mortem / Release / Documents | read | read ∩ |
/// | Detail Billing events | read | billing ∩ ([billingPanel]) |
/// | Detail Print documents | export | export ∪ ([printDocuments]) |
/// | Receive case | create | write ∩ ([create]) — not mounted |
/// | Assign storage | update | manage_storage ∩ — not mounted |
/// | Post-mortem request / approve / release | create / approve / update | fine-grained ∩ — not mounted |
/// | Audit panel | read | audit ∩ — not mounted |
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
/// Inventory: `screens/mortuary.md` → Custody tab (custody-events worklist;
/// read-only detail; Print documents when export ∪). Nested write ∪ is
/// documented via [nestedWrite] — no write chrome mounts today. Export keeps
/// source ∪ `mortuary:export` | `reports:read`. Billing events use ∩
/// `mortuary:billing_event` + `billing:read`. Route entry ∪ is [routeEntry].
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
