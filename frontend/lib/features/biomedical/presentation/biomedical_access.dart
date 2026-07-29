import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';

/// Module entitlement for the biomedical workspace route and panels.
const String biomedicalEngineeringSuiteModule = 'biomedical-engineering-suite';

/// Alias used by Analytics / newer call sites.
const String biomedicalActiveModule = biomedicalEngineeringSuiteModule;

/// View / read UI (matrix ∩ `biomed:read`).
const AccessRequirement biomedicalWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.biomedRead],
  activeModules: <String>[biomedicalEngineeringSuiteModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement biomedicalReadRequirement =
    biomedicalWorkspaceReadRequirement;

/// Route entry (∪): `biomed:read` | `biomed:write` — matches
/// [AppRoutes.biomedical] `requiredAnyPermissions`.
const AccessRequirement biomedicalWorkspaceEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.biomedRead,
    AppPermissions.biomedWrite,
  ],
  activeModules: <String>[biomedicalEngineeringSuiteModule],
);

/// Create / update / delete mutations.
///
/// Matrix lists ∩ `biomed:write` alone; source inventory (`screens/biomedical.md`)
/// documents `_writeRequirement` as ∪ `biomed:write` | `operations:write` plus
/// the biomedical module — keep source and note the mapping in tests.
const AccessRequirement biomedicalWorkspaceWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.biomedWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[biomedicalEngineeringSuiteModule],
);

/// Alias used by tab atom maps / prompts / `AppAccessActionGate`.
const AccessRequirement biomedicalWriteRequirement =
    biomedicalWorkspaceWriteRequirement;

/// Analytics tab + nested charts (matrix): view ∩ `biomed:read` and nested
/// cross-module ∪ `reports:read`.
const AccessRequirement biomedicalAnalyticsTabRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.biomedRead],
  anyPermissions: <AppPermission>[AppPermissions.reportsRead],
  activeModules: <String>[biomedicalEngineeringSuiteModule],
);

/// Nested cross-module read for Analytics charts / utilization UI.
const AccessRequirement biomedicalAnalyticsNestedReadRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.reportsRead],
      activeModules: <String>[biomedicalEngineeringSuiteModule],
    );

/// Print / export asset report (source `_printRequirement`).
///
/// Matrix notes exports may need `reports:read` or `evidence:export`; source
/// inventory requires ∩ `evidence:export` plus ∪ biomed/operations read|write.
const AccessRequirement biomedicalWorkspacePrintRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.evidenceExport],
  anyPermissions: <AppPermission>[
    AppPermissions.biomedRead,
    AppPermissions.biomedWrite,
    AppPermissions.operationsRead,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[biomedicalEngineeringSuiteModule],
);

/// Alias matching historical `_printRequirement` / export naming.
const AccessRequirement biomedicalPrintRequirement =
    biomedicalWorkspacePrintRequirement;

/// Alias used by Analytics atom map.
const AccessRequirement biomedicalExportRequirement =
    biomedicalWorkspacePrintRequirement;

/// Per-panel tab strip gate.
///
/// Most panels need biomed read. Analytics additionally requires reports:read.
AccessRequirement biomedicalPanelTabRequirement(String panel) {
  return biomedicalPanelReadRequirement(panel);
}

AccessRequirement biomedicalPanelReadRequirement(String panel) {
  return switch (panel) {
    BiomedicalPanels.analytics => biomedicalAnalyticsTabRequirement,
    _ => biomedicalWorkspaceReadRequirement,
  };
}

bool canEnterBiomedicalWorkspace(AppAccessPolicy policy) {
  return biomedicalWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadBiomedical(AppAccessPolicy policy) {
  return biomedicalWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteBiomedical(AppAccessPolicy policy) {
  return biomedicalWorkspaceWriteRequirement.isAllowed(policy);
}

bool canPrintBiomedical(AppAccessPolicy policy) {
  return biomedicalWorkspacePrintRequirement.isAllowed(policy);
}

bool canExportBiomedical(AppAccessPolicy policy) {
  return canPrintBiomedical(policy);
}

bool canAccessBiomedicalAnalytics(AppAccessPolicy policy) {
  return biomedicalAnalyticsTabRequirement.isAllowed(policy);
}

bool canReadBiomedicalAnalyticsNested(AppAccessPolicy policy) {
  return biomedicalAnalyticsNestedReadRequirement.isAllowed(policy);
}

bool canViewBiomedicalPanel(AppAccessPolicy policy, String panel) {
  return biomedicalPanelTabRequirement(panel).isAllowed(policy);
}

bool canAccessBiomedicalPanel(AppAccessPolicy policy, String panel) {
  return canViewBiomedicalPanel(policy, panel);
}

/// Panels the user may open; empty when read (and Analytics nested) fails.
List<String> biomedicalAllowedPanels(AppAccessPolicy policy) {
  return BiomedicalPanels.values
      .where((String panel) => canViewBiomedicalPanel(policy, panel))
      .toList(growable: false);
}

String? biomedicalFallbackPanel(AppAccessPolicy policy) {
  final List<String> allowed = biomedicalAllowedPanels(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(BiomedicalPanels.registry)) {
    return BiomedicalPanels.registry;
  }
  return allowed.first;
}

/// Registry tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Registry tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Register asset (tab primary) | create | write ∪ source |
/// | Next action Review record | navigate / read | read ∩ |
/// | Next action write (rare on registry rows) | create / update | write ∪ source |
/// | Detail Edit asset | update | write ∪ source |
/// | Detail complementary writes (transfer, WO, …) | create / update / delete | write ∪ source |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalRegistryAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement registerAsset =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement editAsset = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Overview tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Overview tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Next action Review | navigate / read | read ∩ |
/// | Next action write (maintain / WO / …) | create / update | write ∪ source |
/// | Detail complementary writes | create / update / delete | write ∪ source |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Tab-strip primary | create | _(none on Overview)_ |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalOverviewAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Preventive tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Preventive tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Schedule maintenance (tab primary) | create | write ∪ source |
/// | Next action Review record | navigate / read | read ∩ |
/// | Next action Perform maintenance | create / update | write ∪ source |
/// | Detail complementary writes (transfer, WO, …) | create / update / delete | write ∪ source |
/// | Detail Schedule maintenance | create | write ∪ source (omitted when next-action) |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalPreventiveAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement scheduleMaintenance =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement performMaintenance =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Compliance tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Compliance tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Record calibration (tab primary) | create | write ∪ source |
/// | Next action Review record | navigate / read | read ∩ |
/// | Next action Review compliance (calibration / safety) | update | [recordCalibration] write ∪ source |
/// | Next action Return to service (downtime / DOWN) | update | [closeDowntime] / write ∪ source |
/// | Next action Review recall | update | [acknowledgeRecall] write ∪ source |
/// | Detail Record calibration / safety / Report downtime | create | [create] write ∪ source |
/// | Detail Close downtime / Acknowledge recall | update | [closeDowntime]/[acknowledgeRecall] |
/// | Detail complementary writes (transfer, WO, …) | create / update / delete | write ∪ source |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalComplianceAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement recordCalibration =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement closeDowntime =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement acknowledgeRecall =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Support tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Support tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Report fault (tab primary) | create | write ∪ source |
/// | Next action Review record | navigate / read | read ∩ |
/// | Next action write (rare on support rows) | create / update | write ∪ source |
/// | Detail Log incident / complementary writes | create / update / delete | write ∪ source |
/// | Nested fault-report dialog | create | write ∪ source |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalSupportAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement reportFault = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement logIncident = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Work orders tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Work orders tab | navigate | read ∩ `biomed:read` |
/// | Search / filters / columns / pagination | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Create work order (tab primary) | create | write ∪ source |
/// | Next action Review record | navigate / read | read ∩ |
/// | Next action Work order follow-up (start) | update | write ∪ source |
/// | Next action Return to service | update | write ∪ source |
/// | Detail Update work order | update | write ∪ source |
/// | Detail Start / Return WO (status-gated) | update | write ∪ source (omitted when next-action) |
/// | Detail complementary writes (transfer, PM, …) | create / update / delete | write ∪ source |
/// | Print report | export | print (evidence:export ∩ …) |
/// | Nested mutation dialogs | create / update / delete | write ∪ source |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
abstract final class BiomedicalWorkOrdersAtomPermissions {
  static const AccessRequirement tab = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement listChrome = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement detail = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement create = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement update = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement delete = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement write = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement createWorkOrder =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement startWorkOrder =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement updateWorkOrder =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement returnToService =
      biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement export = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement print = biomedicalWorkspacePrintRequirement;
  static const AccessRequirement nestedWrite = biomedicalWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = biomedicalWorkspaceReadRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
}

/// Analytics tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Analytics tab | navigate | [tab] biomed:read ∩ + reports:read ∪ |
/// | Search / filters / columns / pagination | read chrome | [listChrome] |
/// | Empty / error / retry | read chrome | [listChrome] / page |
/// | Row select → detail | read | [detail] |
/// | Next action Review | navigate | [detail] |
/// | Next action write | create / update | [write] (source ∪) |
/// | Detail complementary writes | create / update / delete | [write] |
/// | Nested mutation dialogs | create / update / delete | [nestedWrite] |
/// | Nested charts / utilization (cross-module) | read | [nestedRead] reports:read ∪ |
/// | Print report | export | [export]/[print] (source evidence:export) |
/// | Tab-strip primary | _(n/a on Analytics)_ | — |
/// | Route entry (deep link) | navigate | [routeEntry]/[entry] read ∪ write |
///
/// Matrix nested cross-module write rows are _(n/a)_. Write keeps source ∪
/// `biomed:write` | `operations:write` rather than matrix ∩ `biomed:write` alone.
/// Exports keep source ∩ `evidence:export` (matrix notes reports:read | evidence:export).
abstract final class BiomedicalAnalyticsAtomPermissions {
  static const AccessRequirement tab = biomedicalAnalyticsTabRequirement;
  static const AccessRequirement listChrome = biomedicalAnalyticsTabRequirement;
  static const AccessRequirement detail = biomedicalAnalyticsTabRequirement;
  static const AccessRequirement nestedRead =
      biomedicalAnalyticsNestedReadRequirement;
  static const AccessRequirement create = biomedicalWriteRequirement;
  static const AccessRequirement update = biomedicalWriteRequirement;
  static const AccessRequirement delete = biomedicalWriteRequirement;
  static const AccessRequirement write = biomedicalWriteRequirement;
  static const AccessRequirement nestedWrite = biomedicalWriteRequirement;
  static const AccessRequirement export = biomedicalExportRequirement;
  static const AccessRequirement print = biomedicalExportRequirement;
  static const AccessRequirement entry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = biomedicalWorkspaceEntryRequirement;
  static const AccessRequirement read = biomedicalReadRequirement;
}
