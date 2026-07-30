import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

/// Module entitlement for the lab workspace route and worklists.
const String labWorkflowsModule = 'lab-workflows';

/// Alias used by tests and newer call sites.
const String labActiveModule = labWorkflowsModule;

/// View / read UI (matrix ∩ `lab:read`).
const AccessRequirement labWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.labRead],
  activeModules: <String>[labWorkflowsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement labReadRequirement = labWorkspaceReadRequirement;

/// Create / update / delete / result / save mutations (matrix ∩ `lab:write`).
///
/// Source inventory (`screens/lab.md`) `_mutationRequirement` / `canMutate` used
/// `anyPermissions: [labWrite]` + `lab-workflows` — equivalent for a single key;
/// prefer ∩ `allPermissions` to match the matrix.
const AccessRequirement labWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.labWrite],
  activeModules: <String>[labWorkflowsModule],
);

/// Alias matching historical `_mutationRequirement` / `AppAccessActionGate`.
const AccessRequirement labWriteRequirement = labWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement labMutationRequirement = labWorkspaceWriteRequirement;

/// Catalog / configurations enablement (same ∩ `lab:write` as mutations).
///
/// Readers with only `clinical:read` must not see config/create.
const AccessRequirement labConfigurationsWriteRequirement =
    labWorkspaceWriteRequirement;

/// Preview / print released reports (source: `lab:read` ∪ `lab:write`).
const AccessRequirement labReportPreviewRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.labRead,
    AppPermissions.labWrite,
  ],
  activeModules: <String>[labWorkflowsModule],
);

/// Critical release clinician notify (prompt narrative ∩):
/// `lab:write` + `clinical:read`.
const AccessRequirement labCriticalNotifyRequirement = AccessRequirement(
  allPermissions: <AppPermission>[
    AppPermissions.labWrite,
    AppPermissions.clinicalRead,
  ],
  activeModules: <String>[labWorkflowsModule],
);

/// Request-from-clinical create order (prompt narrative ∪) — reuse clinical.
const AccessRequirement labRequestFromClinicalWriteRequirement =
    clinicalLabOrderWriteRequirement;

/// Navigation catalog entry — ∩ `lab:read` ([RouteAccessCatalog.labEntry]).
const AccessRequirement labWorkspaceCatalogEntryRequirement =
    RouteAccessCatalog.labEntry;

/// Route entry matching [AppRoutes.lab] ∪ `lab:read` | `clinical:read` |
/// `clinical:write` plus `lab-workflows`.
const AccessRequirement labWorkspaceRouteEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.labRead,
    AppPermissions.clinicalRead,
    AppPermissions.clinicalWrite,
  ],
  activeModules: <String>[labWorkflowsModule],
);

/// Alias used by atom maps for deep-link / shell entry.
const AccessRequirement labWorkspaceEntryRequirement =
    labWorkspaceRouteEntryRequirement;

/// Follow-ups tab / panel read on lab host (matrix ∩ `lab:read`).
const AccessRequirement labFollowUpsRequirement = labWorkspaceReadRequirement;

/// Follow-ups complete / reschedule — write ∩.
const AccessRequirement labFollowUpsWriteRequirement =
    labWorkspaceWriteRequirement;

/// Open billing navigation from unpaid lab gates — Billing owns settle.
const AccessRequirement labOpenBillingRequirement =
    billingWorkspaceReadRequirement;

/// Per-section tab strip gate.
///
/// Worklist tabs (All / Pending / Critical / Completed today) share ∩ `lab:read`
/// + `lab-workflows`; Follow-ups uses [labFollowUpsRequirement].
AccessRequirement labSectionTabRequirement(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.followUps => LabFollowUpsAtomPermissions.tab,
    LabDeskSection.worklist => LabAllAtomPermissions.tab,
    LabDeskSection.collection => LabAwaitingResultsAtomPermissions.tab,
    LabDeskSection.critical => LabCriticalAtomPermissions.tab,
    LabDeskSection.completed => LabVerifiedAtomPermissions.tab,
  };
}

/// **Create Lab Order** gate for the active worklist section (search-bar action).
AccessRequirement labStripCreateRequirement(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.worklist => LabAllAtomPermissions.create,
    LabDeskSection.collection => LabAwaitingResultsAtomPermissions.create,
    LabDeskSection.critical => LabCriticalAtomPermissions.create,
    LabDeskSection.completed => LabVerifiedAtomPermissions.create,
    LabDeskSection.followUps => LabFollowUpsAtomPermissions.create,
  };
}

bool canEnterLabWorkspace(AppAccessPolicy policy) {
  return labWorkspaceRouteEntryRequirement.isAllowed(policy);
}

bool canReadLab(AppAccessPolicy policy) {
  return labWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteLab(AppAccessPolicy policy) {
  return labWorkspaceWriteRequirement.isAllowed(policy);
}

bool canConfigureLab(AppAccessPolicy policy) {
  return labConfigurationsWriteRequirement.isAllowed(policy);
}

bool canPreviewLabReport(AppAccessPolicy policy) {
  return labReportPreviewRequirement.isAllowed(policy);
}

bool canNotifyLabCritical(AppAccessPolicy policy) {
  return labCriticalNotifyRequirement.isAllowed(policy);
}

bool canRequestLabFromClinical(AppAccessPolicy policy) {
  return labRequestFromClinicalWriteRequirement.isAllowed(policy);
}

bool canViewLabFollowUps(AppAccessPolicy policy) {
  return LabFollowUpsAtomPermissions.tab.isAllowed(policy);
}

bool canReadLabFollowUps(AppAccessPolicy policy) {
  return labFollowUpsRequirement.isAllowed(policy);
}

bool canWriteLabFollowUps(AppAccessPolicy policy) {
  return labFollowUpsWriteRequirement.isAllowed(policy);
}

bool canViewLabSection(AppAccessPolicy policy, LabDeskSection section) {
  return labSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the user may open.
///
/// Matrix tab read is ∩ `lab:read`. Route-only clinical readers
/// (`clinical:read` / `clinical:write` without `lab:read`) may still open
/// `/lab` via [labWorkspaceRouteEntryRequirement] and see worklist chrome
/// read-only — they must not see config/create ([canWriteLab]).
List<LabDeskSection> labAllowedSections(AppAccessPolicy policy) {
  final List<LabDeskSection> byRead = LabDeskSection.values
      .where(
        (LabDeskSection section) => canViewLabSection(policy, section),
      )
      .toList(growable: false);
  if (byRead.isNotEmpty) {
    return byRead;
  }
  if (!canEnterLabWorkspace(policy)) {
    return const <LabDeskSection>[];
  }
  // Route ∪ without lab:read: keep worklist tabs; Follow-ups stays read-gated.
  return LabDeskSection.values
      .where((LabDeskSection section) => !section.isFollowUps)
      .toList(growable: false);
}

LabDeskSection? labFallbackSection(AppAccessPolicy policy) {
  final List<LabDeskSection> allowed = labAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  // Default landing tab is Pending when available.
  if (allowed.contains(LabDeskSection.collection)) {
    return LabDeskSection.collection;
  }
  return allowed.first;
}

/// Atom → requirement map for Lab All (`/lab` / `?section=all|worklist`).
///
/// Inventory: `screens/lab.md` → All tab (full worklist; Create Lab Order
/// primary). Nested cross-module matrix rows are _(n/a)_; request-from-clinical
/// ∪ is documented via [requestFromClinical] for reuse, not as an All-tab
/// strip control. Critical notify ∩ is [criticalNotify] (no dedicated chrome
/// on All today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All strip tab / count | navigate | read ∩ `lab:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Orders view / Patients view toggle | navigate | read ∩ |
/// | Create Lab Order (primary) | create | write ∩ `lab:write` |
/// | Lab Configurations (secondary) | update | write ∩ |
/// | Row select / Next action → result entry | read / navigate | read ∩ |
/// | Detail Preview report | export / read | preview ∪ lab read\|write |
/// | Detail Create additional order | create | write ∩ |
/// | Detail Edit / Delete order | update / delete | write ∩ |
/// | Workflow Collect / Receive / Save results / Reverse | update | write ∩ |
/// | Bulk / item result save / reject / delete | create / update / delete | write ∩ |
/// | Nested configurations catalog enable | update | write ∩ |
/// | Request-from-clinical (cross-module; not strip) | create | clinical lab ∪ |
/// | Critical notify (narrative ∩) | approve / update | lab:write ∩ clinical:read |
/// | Route entry (deep link) | navigate | ∪ lab\|clinical read\|write |
abstract final class LabAllAtomPermissions {
  static const AccessRequirement tab = labWorkspaceReadRequirement;
  static const AccessRequirement listChrome = labWorkspaceReadRequirement;
  static const AccessRequirement search = labWorkspaceReadRequirement;
  static const AccessRequirement filters = labWorkspaceReadRequirement;
  static const AccessRequirement settings = labWorkspaceReadRequirement;
  static const AccessRequirement pagination = labWorkspaceReadRequirement;
  static const AccessRequirement empty = labWorkspaceReadRequirement;
  static const AccessRequirement loading = labWorkspaceReadRequirement;
  static const AccessRequirement retry = labWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = labWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = labWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = labWorkspaceReadRequirement;
  static const AccessRequirement detail = labWorkspaceReadRequirement;
  static const AccessRequirement nextAction = labWorkspaceReadRequirement;
  static const AccessRequirement viewToggle = labWorkspaceReadRequirement;
  static const AccessRequirement create = labWorkspaceWriteRequirement;
  static const AccessRequirement update = labWorkspaceWriteRequirement;
  static const AccessRequirement delete = labWorkspaceWriteRequirement;
  static const AccessRequirement write = labWorkspaceWriteRequirement;
  static const AccessRequirement configure = labConfigurationsWriteRequirement;
  static const AccessRequirement previewReport = labReportPreviewRequirement;
  static const AccessRequirement createAdditionalOrder =
      labWorkspaceWriteRequirement;
  static const AccessRequirement editOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement deleteOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement workflowMutate = labWorkspaceWriteRequirement;
  static const AccessRequirement resultEntry = labWorkspaceWriteRequirement;
  static const AccessRequirement criticalNotify = labCriticalNotifyRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on All; reuse clinical ∪.
  static const AccessRequirement requestFromClinical =
      labRequestFromClinicalWriteRequirement;
  /// Open Billing workspace when payment gate blocks progression.
  static const AccessRequirement openBilling = labOpenBillingRequirement;
  static const AccessRequirement nestedWrite = labWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = labWorkspaceReadRequirement;
  static const AccessRequirement entry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      labWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = labWorkspaceReadRequirement;
}

bool canViewLabAllTab(AppAccessPolicy policy) {
  return LabAllAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Lab Awaiting results
/// (`/lab?section=awaiting-results|collection`).
///
/// Inventory: `screens/lab.md` → Awaiting results tab (collection queue;
/// pending sample / result entry). Nested cross-module matrix rows are
/// _(n/a)_; request-from-clinical ∪ is documented via [requestFromClinical]
/// for reuse, not as an Awaiting-results strip control. Critical notify ∩ is
/// [criticalNotify] (no dedicated chrome on this tab today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Awaiting results strip tab / count | navigate | read ∩ `lab:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Orders view / Patients view toggle | navigate | read ∩ |
/// | Create Lab Order (primary) | create | write ∩ `lab:write` |
/// | Lab Configurations (secondary) | update | write ∩ |
/// | Row select / Next action → result entry | read / navigate | read ∩ |
/// | Detail Preview report | export / read | preview ∪ lab read\|write |
/// | Detail Create additional order | create | write ∩ |
/// | Detail Edit / Delete order | update / delete | write ∩ |
/// | Workflow Collect / Receive / Save results / Reverse | update | write ∩ |
/// | Bulk / item result save / reject / delete | create / update / delete | write ∩ |
/// | Nested configurations catalog enable | update | write ∩ |
/// | Request-from-clinical (cross-module; not strip) | create | clinical lab ∪ |
/// | Critical notify (narrative ∩) | approve / update | lab:write ∩ clinical:read |
/// | Route entry (deep link) | navigate | ∪ lab\|clinical read\|write |
abstract final class LabAwaitingResultsAtomPermissions {
  static const AccessRequirement tab = labWorkspaceReadRequirement;
  static const AccessRequirement listChrome = labWorkspaceReadRequirement;
  static const AccessRequirement search = labWorkspaceReadRequirement;
  static const AccessRequirement filters = labWorkspaceReadRequirement;
  static const AccessRequirement settings = labWorkspaceReadRequirement;
  static const AccessRequirement pagination = labWorkspaceReadRequirement;
  static const AccessRequirement empty = labWorkspaceReadRequirement;
  static const AccessRequirement loading = labWorkspaceReadRequirement;
  static const AccessRequirement retry = labWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = labWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = labWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = labWorkspaceReadRequirement;
  static const AccessRequirement detail = labWorkspaceReadRequirement;
  static const AccessRequirement nextAction = labWorkspaceReadRequirement;
  static const AccessRequirement viewToggle = labWorkspaceReadRequirement;
  static const AccessRequirement create = labWorkspaceWriteRequirement;
  static const AccessRequirement update = labWorkspaceWriteRequirement;
  static const AccessRequirement delete = labWorkspaceWriteRequirement;
  static const AccessRequirement write = labWorkspaceWriteRequirement;
  static const AccessRequirement configure = labConfigurationsWriteRequirement;
  static const AccessRequirement previewReport = labReportPreviewRequirement;
  static const AccessRequirement createAdditionalOrder =
      labWorkspaceWriteRequirement;
  static const AccessRequirement editOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement deleteOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement workflowMutate = labWorkspaceWriteRequirement;
  static const AccessRequirement resultEntry = labWorkspaceWriteRequirement;
  static const AccessRequirement criticalNotify = labCriticalNotifyRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Awaiting results; reuse
  /// clinical ∪.
  static const AccessRequirement requestFromClinical =
      labRequestFromClinicalWriteRequirement;
  static const AccessRequirement nestedWrite = labWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = labWorkspaceReadRequirement;
  static const AccessRequirement entry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      labWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = labWorkspaceReadRequirement;
}

bool canViewLabAwaitingResultsTab(AppAccessPolicy policy) {
  return LabAwaitingResultsAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Lab Critical (`/lab?section=critical`).
///
/// Inventory: Critical tab (abnormal / out-of-range results entered today).
/// Create Lab Order lives in the search bar (not the tab strip). Lab
/// Configurations and Orders↔Patients toggle are not mounted on Lab.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Critical strip tab / count | navigate | read ∩ `lab:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Create Lab Order (search trailing) | create | write ∩ `lab:write` |
/// | Row select / Next action → result entry | read / navigate | read ∩ |
/// | Critical notify / acknowledge chrome | approve / update | lab:write ∩ clinical:read |
/// | Route entry (deep link) | navigate | ∪ lab\|clinical read\|write |
abstract final class LabCriticalAtomPermissions {
  static const AccessRequirement tab = labWorkspaceReadRequirement;
  static const AccessRequirement listChrome = labWorkspaceReadRequirement;
  static const AccessRequirement search = labWorkspaceReadRequirement;
  static const AccessRequirement filters = labWorkspaceReadRequirement;
  static const AccessRequirement settings = labWorkspaceReadRequirement;
  static const AccessRequirement pagination = labWorkspaceReadRequirement;
  static const AccessRequirement empty = labWorkspaceReadRequirement;
  static const AccessRequirement loading = labWorkspaceReadRequirement;
  static const AccessRequirement retry = labWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = labWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = labWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = labWorkspaceReadRequirement;
  static const AccessRequirement detail = labWorkspaceReadRequirement;
  static const AccessRequirement nextAction = labWorkspaceReadRequirement;
  static const AccessRequirement viewToggle = labWorkspaceReadRequirement;
  static const AccessRequirement create = labWorkspaceWriteRequirement;
  static const AccessRequirement update = labWorkspaceWriteRequirement;
  static const AccessRequirement delete = labWorkspaceWriteRequirement;
  static const AccessRequirement write = labWorkspaceWriteRequirement;
  static const AccessRequirement configure = labConfigurationsWriteRequirement;
  static const AccessRequirement previewReport = labReportPreviewRequirement;
  static const AccessRequirement createAdditionalOrder =
      labWorkspaceWriteRequirement;
  static const AccessRequirement editOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement deleteOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement workflowMutate = labWorkspaceWriteRequirement;
  static const AccessRequirement resultEntry = labWorkspaceWriteRequirement;
  /// Clinician notify / acknowledge — ∩ `lab:write` + `clinical:read`.
  static const AccessRequirement criticalNotify = labCriticalNotifyRequirement;
  static const AccessRequirement acknowledge = labCriticalNotifyRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Critical; reuse clinical ∪.
  static const AccessRequirement requestFromClinical =
      labRequestFromClinicalWriteRequirement;
  static const AccessRequirement nestedWrite = labWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = labWorkspaceReadRequirement;
  static const AccessRequirement entry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      labWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = labWorkspaceReadRequirement;
}

bool canViewLabCriticalTab(AppAccessPolicy policy) {
  return LabCriticalAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Lab Completed
/// (`/lab?section=completed|verified`).
///
/// Inventory: `screens/lab.md` → Completed tab (saved / COMPLETED results;
/// prefer read — Preview report; Next action is text-only for terminal rows;
/// row select still opens result entry). Nested cross-module matrix rows are
/// _(n/a)_; request-from-clinical ∪ is [requestFromClinical] for reuse (not
/// strip chrome). Critical notify ∩ is [criticalNotify] (no dedicated chrome
/// on Completed today). Readers with only `clinical:read` must not see
/// config/create. Reopen / edit saved results need ∩ `lab:write`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed strip tab / count | navigate | read ∩ `lab:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Orders view / Patients view toggle | navigate | read ∩ |
/// | Create Lab Order (primary) | create | write ∩ `lab:write` |
/// | Lab Configurations (secondary) | update | write ∩ |
/// | Row select → result entry | read / navigate | read ∩ |
/// | Next action (Completed label, text-only) | progressive disclosure | read ∩ |
/// | Detail Preview report | export / read | preview ∪ lab read\|write |
/// | Detail Create additional order | create | write ∩ |
/// | Detail Edit / Delete order | update / delete | write ∩ |
/// | Edit / reopen saved result | update | write ∩ |
/// | Workflow Collect / Receive / Save results / Reverse | update | write ∩ |
/// | Bulk / item result save / reject / delete | create / update / delete | write ∩ |
/// | Open billing (payment gate CTA) | navigate | Billing read |
/// | Nested configurations catalog enable | update | write ∩ |
/// | Request-from-clinical (cross-module; not strip) | create | clinical lab ∪ |
/// | Critical notify (narrative ∩) | approve / update | lab:write ∩ clinical:read |
/// | Route entry (deep link) | navigate | ∪ lab\|clinical read\|write |
abstract final class LabVerifiedAtomPermissions {
  static const AccessRequirement tab = labWorkspaceReadRequirement;
  static const AccessRequirement listChrome = labWorkspaceReadRequirement;
  static const AccessRequirement search = labWorkspaceReadRequirement;
  static const AccessRequirement filters = labWorkspaceReadRequirement;
  static const AccessRequirement settings = labWorkspaceReadRequirement;
  static const AccessRequirement pagination = labWorkspaceReadRequirement;
  static const AccessRequirement empty = labWorkspaceReadRequirement;
  static const AccessRequirement loading = labWorkspaceReadRequirement;
  static const AccessRequirement retry = labWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = labWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = labWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = labWorkspaceReadRequirement;
  static const AccessRequirement detail = labWorkspaceReadRequirement;
  static const AccessRequirement nextAction = labWorkspaceReadRequirement;
  static const AccessRequirement viewToggle = labWorkspaceReadRequirement;
  static const AccessRequirement create = labWorkspaceWriteRequirement;
  static const AccessRequirement update = labWorkspaceWriteRequirement;
  static const AccessRequirement delete = labWorkspaceWriteRequirement;
  static const AccessRequirement write = labWorkspaceWriteRequirement;
  static const AccessRequirement configure = labConfigurationsWriteRequirement;
  static const AccessRequirement previewReport = labReportPreviewRequirement;
  static const AccessRequirement createAdditionalOrder =
      labWorkspaceWriteRequirement;
  static const AccessRequirement editOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement deleteOrder = labWorkspaceWriteRequirement;
  static const AccessRequirement editVerifiedResult =
      labWorkspaceWriteRequirement;
  static const AccessRequirement reopenVerifiedResult =
      labWorkspaceWriteRequirement;
  static const AccessRequirement workflowMutate = labWorkspaceWriteRequirement;
  static const AccessRequirement resultEntry = labWorkspaceWriteRequirement;
  static const AccessRequirement criticalNotify = labCriticalNotifyRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Completed; reuse clinical ∪.
  static const AccessRequirement requestFromClinical =
      labRequestFromClinicalWriteRequirement;
  /// Open Billing workspace when payment gate blocks progression.
  static const AccessRequirement openBilling = labOpenBillingRequirement;
  static const AccessRequirement nestedWrite = labWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = labWorkspaceReadRequirement;
  static const AccessRequirement entry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      labWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = labWorkspaceReadRequirement;
}

bool canViewLabVerifiedTab(AppAccessPolicy policy) {
  return LabVerifiedAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Lab Follow-ups (`/lab?section=follow-ups`).
///
/// Inventory: Follow-ups tab (`FollowUpWorklistPanel`) with Filters, Settings,
/// and Create Lab Order chrome parity with other lab tabs.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Follow-ups strip tab / count badge | navigate | read ∩ `lab:read` |
/// | Search / Clear / Filters / Settings / columns | read chrome | read ∩ ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | ([empty] / [loading] / [retry]) |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ / form |
/// | Row select → Follow-up details | read | ([detail]) |
/// | Detail Close (read-only footer) | progressive disclosure | ([close]) |
/// | Reschedule follow-up | update | write ∩ ([reschedule]) |
/// | Mark completed | update | write ∩ ([markCompleted]) |
/// | Save follow-up (nested reschedule dialog) | update | write ∩ ([saveFollowUp]) |
/// | Hard delete / void | delete | write ∩ ([delete]) — not mounted |
/// | Create Lab Order | create | write ∩ ([create]) |
/// | Request-from-clinical / critical notify | nested write | _(n/a)_ — not reachable |
/// | Route entry (deep link) | navigate | ∪ lab\|clinical read\|write ([routeEntry]) |
abstract final class LabFollowUpsAtomPermissions {
  static const AccessRequirement tab = labFollowUpsRequirement;
  static const AccessRequirement listChrome = labFollowUpsRequirement;
  static const AccessRequirement search = labFollowUpsRequirement;
  static const AccessRequirement filters = labFollowUpsRequirement;
  static const AccessRequirement settings = labFollowUpsRequirement;
  static const AccessRequirement empty = labFollowUpsRequirement;
  static const AccessRequirement loading = labFollowUpsRequirement;
  static const AccessRequirement retry = labFollowUpsRequirement;
  /// Authorized success path after complete / reschedule (write-gated entry).
  static const AccessRequirement success = labFollowUpsWriteRequirement;
  /// Authorized form validation feedback (nested reschedule dialog).
  static const AccessRequirement validation = labFollowUpsWriteRequirement;
  static const AccessRequirement rowSelect = labFollowUpsRequirement;
  static const AccessRequirement detail = labFollowUpsRequirement;
  static const AccessRequirement close = labFollowUpsRequirement;
  static const AccessRequirement create = labFollowUpsWriteRequirement;
  static const AccessRequirement update = labFollowUpsWriteRequirement;
  static const AccessRequirement delete = labFollowUpsWriteRequirement;
  static const AccessRequirement reschedule = labFollowUpsWriteRequirement;
  static const AccessRequirement markCompleted = labFollowUpsWriteRequirement;
  static const AccessRequirement saveFollowUp = labFollowUpsWriteRequirement;
  static const AccessRequirement write = labFollowUpsWriteRequirement;
  /// Nested cross-module — matrix _(n/a)_; documented for reuse only.
  static const AccessRequirement requestFromClinical =
      labRequestFromClinicalWriteRequirement;
  static const AccessRequirement criticalNotify = labCriticalNotifyRequirement;
  static const AccessRequirement nestedWrite = labFollowUpsWriteRequirement;
  static const AccessRequirement nestedRead = labFollowUpsRequirement;
  static const AccessRequirement entry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry = labWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      labWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = labFollowUpsRequirement;
}
