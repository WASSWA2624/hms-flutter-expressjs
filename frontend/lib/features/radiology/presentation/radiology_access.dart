import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

/// Module entitlement for the radiology workspace route and worklists.
const String radiologyWorkflowsModule = 'radiology-workflows';

/// Alias used by tests and newer call sites.
const String radiologyActiveModule = radiologyWorkflowsModule;

/// View / read UI (matrix ∩ `radiology:read`).
///
/// Facility ABAC for shell entry lives on [RouteAccessCatalog.radiologyEntry];
/// tab chrome uses module + permission ∩ like lab/pharmacy peers.
const AccessRequirement radiologyWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.radiologyRead],
  activeModules: <String>[radiologyWorkflowsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement radiologyReadRequirement =
    radiologyWorkspaceReadRequirement;

/// Create / update / delete / assign / study / report / release (matrix ∩
/// `radiology:write`).
///
/// Source inventory historically used `anyPermissions: [radiologyWrite]` for
/// `_workRequirement` — equivalent for a single key; prefer ∩ `allPermissions`
/// to match the matrix. Request imaging / configurations / reporting / release
/// need `radiology:write`.
const AccessRequirement radiologyWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.radiologyWrite],
  activeModules: <String>[radiologyWorkflowsModule],
);

/// Alias matching historical `_workRequirement` / `AppAccessActionGate`.
const AccessRequirement radiologyWriteRequirement =
    radiologyWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement radiologyMutationRequirement =
    radiologyWorkspaceWriteRequirement;

/// Catalog / configurations enablement (same ∩ `radiology:write` as mutations).
///
/// Readers with only `clinical:read` must not see config/create.
const AccessRequirement radiologyConfigurationsWriteRequirement =
    radiologyWorkspaceWriteRequirement;

/// Strip **Request imaging** create (matrix ∩ `radiology:write`).
///
/// Source `_requestRequirement` used ∪ `clinical:write` | `radiology:write`.
/// Matrix create is ∩ `radiology:write`; clinical ∪ remains
/// [radiologyRequestFromClinicalWriteRequirement] for nested clinical reuse.
const AccessRequirement radiologyRequestImagingRequirement =
    radiologyWorkspaceWriteRequirement;

/// Nested request-from-clinical create (source ∪) — reuse clinical helper.
const AccessRequirement radiologyRequestFromClinicalWriteRequirement =
    clinicalRadiologyOrderWriteRequirement;

/// Billing hold column / filter / payment field (prompt: billing holds need
/// `billing:read`). Reuses [billingReadRequirement]
/// (`billing:read` ∩ `billing-payments`).
const AccessRequirement radiologyBillingHoldReadRequirement =
    billingReadRequirement;

/// Print released / draft reports (inventory: not write-gated; ∩
/// `radiology:read`).
const AccessRequirement radiologyPrintReportRequirement =
    radiologyWorkspaceReadRequirement;

/// Navigation catalog entry — ∩ `radiology:read`
/// ([RouteAccessCatalog.radiologyEntry]).
const AccessRequirement radiologyWorkspaceCatalogEntryRequirement =
    RouteAccessCatalog.radiologyEntry;

/// Route entry matching [AppRoutes.radiology] ∪ `radiology:read` |
/// `radiology:write` | `clinical:read` | `clinical:write` | `billing:read`
/// plus `radiology-workflows`.
const AccessRequirement radiologyWorkspaceRouteEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.radiologyRead,
        AppPermissions.radiologyWrite,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.billingRead,
      ],
      activeModules: <String>[radiologyWorkflowsModule],
    );

/// Alias used by atom maps for deep-link / shell entry.
const AccessRequirement radiologyWorkspaceEntryRequirement =
    radiologyWorkspaceRouteEntryRequirement;

/// Follow-ups tab / panel read on radiology host (matrix ∩ `radiology:read`).
const AccessRequirement radiologyFollowUpsRequirement =
    radiologyWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — write ∩.
const AccessRequirement radiologyFollowUpsWriteRequirement =
    radiologyWorkspaceWriteRequirement;

/// Per-section tab strip gate.
///
/// Worklist / Reporting / Released / All orders share ∩ `radiology:read` +
/// `radiology-workflows`; Follow-ups uses [radiologyFollowUpsRequirement].
AccessRequirement radiologySectionTabRequirement(RadiologyDeskSection section) {
  return switch (section) {
    RadiologyDeskSection.allOrders => RadiologyAllOrdersAtomPermissions.tab,
    RadiologyDeskSection.followUps => RadiologyFollowUpsAtomPermissions.tab,
    RadiologyDeskSection.worklist ||
    RadiologyDeskSection.reporting ||
    RadiologyDeskSection.released => radiologyWorkspaceReadRequirement,
  };
}

/// Strip **Request imaging** gate for the active worklist section.
AccessRequirement radiologyStripCreateRequirement(RadiologyDeskSection section) {
  return switch (section) {
    RadiologyDeskSection.allOrders => RadiologyAllOrdersAtomPermissions.create,
    RadiologyDeskSection.followUps => RadiologyFollowUpsAtomPermissions.write,
    RadiologyDeskSection.worklist ||
    RadiologyDeskSection.reporting ||
    RadiologyDeskSection.released => radiologyRequestImagingRequirement,
  };
}

/// Strip **Configurations** gate for the active worklist section.
AccessRequirement radiologyStripConfigureRequirement(
  RadiologyDeskSection section,
) {
  return switch (section) {
    RadiologyDeskSection.allOrders =>
      RadiologyAllOrdersAtomPermissions.configure,
    // Follow-ups mounts no Configurations chrome; keep write ∩ if ever reused.
    RadiologyDeskSection.followUps => RadiologyFollowUpsAtomPermissions.write,
    RadiologyDeskSection.worklist ||
    RadiologyDeskSection.reporting ||
    RadiologyDeskSection.released => radiologyConfigurationsWriteRequirement,
  };
}

bool canEnterRadiologyWorkspace(AppAccessPolicy policy) {
  return radiologyWorkspaceRouteEntryRequirement.isAllowed(policy);
}

bool canReadRadiology(AppAccessPolicy policy) {
  return radiologyWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteRadiology(AppAccessPolicy policy) {
  return radiologyWorkspaceWriteRequirement.isAllowed(policy);
}

bool canConfigureRadiology(AppAccessPolicy policy) {
  return radiologyConfigurationsWriteRequirement.isAllowed(policy);
}

bool canRequestRadiologyImaging(AppAccessPolicy policy) {
  return radiologyRequestImagingRequirement.isAllowed(policy);
}

bool canRequestRadiologyFromClinical(AppAccessPolicy policy) {
  return radiologyRequestFromClinicalWriteRequirement.isAllowed(policy);
}

bool canViewRadiologyBillingHold(AppAccessPolicy policy) {
  return radiologyBillingHoldReadRequirement.isAllowed(policy);
}

bool canPrintRadiologyReport(AppAccessPolicy policy) {
  return radiologyPrintReportRequirement.isAllowed(policy);
}

bool canViewRadiologyFollowUps(AppAccessPolicy policy) {
  return RadiologyFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadRadiologyFollowUps(AppAccessPolicy policy) {
  return radiologyFollowUpsRequirement.isAllowed(policy);
}

bool canWriteRadiologyFollowUps(AppAccessPolicy policy) {
  return radiologyFollowUpsWriteRequirement.isAllowed(policy);
}

bool canViewRadiologySection(
  AppAccessPolicy policy,
  RadiologyDeskSection section,
) {
  return radiologySectionTabRequirement(section).isAllowed(policy);
}

/// Sections the user may open.
///
/// Matrix tab read is ∩ `radiology:read`. Route-only clinical / billing readers
/// (`clinical:read` / `clinical:write` / `billing:read` without `radiology:read`)
/// may still open `/radiology` via [radiologyWorkspaceRouteEntryRequirement] and
/// see worklist chrome read-only — they must not see config/create
/// ([canWriteRadiology]).
List<RadiologyDeskSection> radiologyAllowedSections(AppAccessPolicy policy) {
  final List<RadiologyDeskSection> byRead = RadiologyDeskSection.values
      .where(
        (RadiologyDeskSection section) =>
            canViewRadiologySection(policy, section),
      )
      .toList(growable: false);
  if (byRead.isNotEmpty) {
    return byRead;
  }
  if (!canEnterRadiologyWorkspace(policy)) {
    return const <RadiologyDeskSection>[];
  }
  // Route ∪ without radiology:read: keep worklist tabs; Follow-ups stays
  // read-gated.
  return RadiologyDeskSection.values
      .where((RadiologyDeskSection section) => !section.isFollowUps)
      .toList(growable: false);
}

RadiologyDeskSection? radiologyFallbackSection(AppAccessPolicy policy) {
  final List<RadiologyDeskSection> allowed = radiologyAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(RadiologyDeskSection.worklist)) {
    return RadiologyDeskSection.worklist;
  }
  if (allowed.contains(RadiologyDeskSection.allOrders)) {
    return RadiologyDeskSection.allOrders;
  }
  return allowed.first;
}

/// Atom → requirement map for Radiology All orders
/// (`/radiology?section=all|all_orders|all-orders`).
///
/// Inventory: unfiltered orders board (`RadiologyDeskSection.allOrders`). Nested
/// cross-module matrix rows are _(n/a)_ for strip chrome; request-from-clinical
/// ∪ is documented via [requestFromClinical] for reuse. Billing holds use
/// [billingHold] (`billing:read`). Clinical:read alone may view shared results
/// chrome via [entry] but not config/create.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All orders strip tab / count | navigate | read ∩ `radiology:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Billing gate filter | read chrome | billing hold ∩ `billing:read` |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Orders view / Patients view toggle | navigate | read ∩ |
/// | Request imaging (primary) | create | write ∩ `radiology:write` |
/// | Configurations (secondary) | update | write ∩ |
/// | Row select / Next action → detail | read / navigate | read ∩ |
/// | Optional billing column | data read | billing hold ∩ |
/// | Detail payment field | data read | billing hold ∩ |
/// | Detail Assign / Start / Perform study / Edit request | update | write ∩ |
/// | Detail Draft / Release / Request+attest / Addendum / Cancel | update / delete | write ∩ |
/// | Detail Print report | export / read | print ∩ `radiology:read` |
/// | Nested configurations catalog enable | update | write ∩ |
/// | Request-from-clinical (cross-module; not strip) | create | clinical radiology ∪ |
/// | Route entry (deep link) | navigate | ∪ radiology\|clinical\|billing |
abstract final class RadiologyAllOrdersAtomPermissions {
  static const AccessRequirement tab = radiologyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = radiologyWorkspaceReadRequirement;
  static const AccessRequirement search = radiologyWorkspaceReadRequirement;
  static const AccessRequirement filters = radiologyWorkspaceReadRequirement;
  static const AccessRequirement billingFilter =
      radiologyBillingHoldReadRequirement;
  static const AccessRequirement settings = radiologyWorkspaceReadRequirement;
  static const AccessRequirement pagination = radiologyWorkspaceReadRequirement;
  static const AccessRequirement empty = radiologyWorkspaceReadRequirement;
  static const AccessRequirement loading = radiologyWorkspaceReadRequirement;
  static const AccessRequirement retry = radiologyWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = radiologyWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = radiologyWorkspaceReadRequirement;
  static const AccessRequirement detail = radiologyWorkspaceReadRequirement;
  static const AccessRequirement nextAction = radiologyWorkspaceReadRequirement;
  static const AccessRequirement viewToggle = radiologyWorkspaceReadRequirement;
  static const AccessRequirement create = radiologyRequestImagingRequirement;
  static const AccessRequirement update = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement delete = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement write = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement configure =
      radiologyConfigurationsWriteRequirement;
  static const AccessRequirement assign = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement startImaging =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement performStudy =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement editRequest =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement draftReport =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement releaseReport =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement requestFinalization =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement attestFinalization =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement addendum = radiologyWorkspaceWriteRequirement;
  static const AccessRequirement cancelOrder =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement printReport = radiologyPrintReportRequirement;
  static const AccessRequirement billingHold =
      radiologyBillingHoldReadRequirement;
  static const AccessRequirement billingColumn =
      radiologyBillingHoldReadRequirement;
  static const AccessRequirement paymentField =
      radiologyBillingHoldReadRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on All; reuse clinical ∪.
  static const AccessRequirement requestFromClinical =
      radiologyRequestFromClinicalWriteRequirement;
  static const AccessRequirement nestedWrite =
      radiologyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = radiologyWorkspaceReadRequirement;
  static const AccessRequirement entry = radiologyWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry =
      radiologyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      radiologyWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = radiologyWorkspaceReadRequirement;
}

bool canViewRadiologyAllOrdersTab(AppAccessPolicy policy) {
  return RadiologyAllOrdersAtomPermissions.tab.isAllowed(policy);
}

/// Follow-ups tab atom map on the radiology host (shared panel).
abstract final class RadiologyFollowUpsAtomPermissions {
  static const AccessRequirement tab = radiologyFollowUpsRequirement;
  static const AccessRequirement write = radiologyFollowUpsWriteRequirement;
  static const AccessRequirement read = radiologyFollowUpsRequirement;
}
