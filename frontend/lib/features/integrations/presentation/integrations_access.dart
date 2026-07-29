import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/integrations/domain/entities/integration_entities.dart';

/// Module entitlement for the integrations workspace route and sections.
const String integrationsCoreModule = 'integrations-core';

/// Alias used by tab atom maps / prompts.
const String integrationsActiveModule = integrationsCoreModule;

/// View / read UI (matrix ∩ `integration:read`).
const AccessRequirement integrationsWorkspaceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.integrationRead],
      activeModules: <String>[integrationsCoreModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement integrationsReadRequirement =
    integrationsWorkspaceReadRequirement;

/// Route entry (∪): `integration:read` | `integration:write` | tenant /
/// facility / system admin — matches [AppRoutes.integrations]
/// `requiredAnyPermissions`.
const AccessRequirement integrationsWorkspaceEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.integrationRead,
        AppPermissions.integrationWrite,
        AppPermissions.tenantAdmin,
        AppPermissions.facilityAdmin,
        AppPermissions.systemAdmin,
      ],
      activeModules: <String>[integrationsCoreModule],
    );

/// Create / update mutations (source inventory manage).
///
/// Matrix create/update is ∩ `integration:write`. Source
/// (`screens/integrations.md` / `_integrationsManageRequirement`) keeps ∪
/// write | tenant/facility/system admin + `integrations-core` — note mapping
/// in tests.
const AccessRequirement integrationsWorkspaceManageRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.integrationWrite,
        AppPermissions.tenantAdmin,
        AppPermissions.facilityAdmin,
        AppPermissions.systemAdmin,
      ],
      activeModules: <String>[integrationsCoreModule],
    );

/// Alias matching matrix create / update (via source manage ∪).
const AccessRequirement integrationsWorkspaceWriteRequirement =
    integrationsWorkspaceManageRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement integrationsWriteRequirement =
    integrationsWorkspaceManageRequirement;

/// Alias matching historical manage naming.
const AccessRequirement integrationsManageRequirement =
    integrationsWorkspaceManageRequirement;

/// Soft/hard delete / revoke (matrix ∩ `integration:delete`).
const AccessRequirement integrationsWorkspaceDeleteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.integrationDelete],
      activeModules: <String>[integrationsCoreModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement integrationsDeleteRequirement =
    integrationsWorkspaceDeleteRequirement;

/// Catalog entry atom (facility ABAC). Prefer
/// [integrationsWorkspaceEntryRequirement] for AppRoutes ∪ parity in tests.
const AccessRequirement integrationsCatalogEntryRequirement =
    RouteAccessCatalog.integrationsEntry;

/// Effective capabilities for integrations chrome.
final class IntegrationsCapabilities {
  const IntegrationsCapabilities({
    required this.canRead,
    required this.canManage,
    required this.canDelete,
  });

  final bool canRead;
  final bool canManage;
  final bool canDelete;

  bool get canWrite => canManage;

  factory IntegrationsCapabilities.fromPolicy(AppAccessPolicy policy) {
    return IntegrationsCapabilities(
      canRead: canReadIntegrations(policy),
      canManage: canManageIntegrations(policy),
      canDelete: canDeleteIntegrations(policy),
    );
  }
}

bool canEnterIntegrationsWorkspace(AppAccessPolicy policy) {
  return integrationsWorkspaceEntryRequirement.isAllowed(policy);
}

bool canReadIntegrations(AppAccessPolicy policy) {
  return integrationsWorkspaceReadRequirement.isAllowed(policy);
}

bool canManageIntegrations(AppAccessPolicy policy) {
  return integrationsWorkspaceManageRequirement.isAllowed(policy);
}

bool canWriteIntegrations(AppAccessPolicy policy) {
  return canManageIntegrations(policy);
}

bool canDeleteIntegrations(AppAccessPolicy policy) {
  return integrationsWorkspaceDeleteRequirement.isAllowed(policy);
}

/// Per-section tab strip gate. Sections share workspace read until a tab
/// prompt documents a narrower requirement.
AccessRequirement integrationsSectionTabRequirement(
  IntegrationDeskSection section,
) {
  return switch (section) {
    IntegrationDeskSection.integrations =>
      IntegrationsIntegrationsAtomPermissions.tab,
    IntegrationDeskSection.apiKeys => IntegrationsApiKeysAtomPermissions.tab,
    IntegrationDeskSection.webhooks => IntegrationsWebhooksAtomPermissions.tab,
    IntegrationDeskSection.logs => IntegrationsLogsAtomPermissions.tab,
    IntegrationDeskSection.interop => IntegrationsInteropAtomPermissions.tab,
  };
}

bool canViewIntegrationsSection(
  AppAccessPolicy policy,
  IntegrationDeskSection section,
) {
  return integrationsSectionTabRequirement(section).isAllowed(policy);
}

/// Sections the policy may show in the workspace tab strip.
List<IntegrationDeskSection> integrationsAllowedSections(
  AppAccessPolicy policy,
) {
  return <IntegrationDeskSection>[
    for (final IntegrationDeskSection section in IntegrationDeskSection.values)
      if (canViewIntegrationsSection(policy, section)) section,
  ];
}

/// First authorized section (prefer integrations), or null when none visible.
IntegrationDeskSection? integrationsFallbackSection(AppAccessPolicy policy) {
  final List<IntegrationDeskSection> sections =
      integrationsAllowedSections(policy);
  if (sections.isEmpty) {
    return null;
  }
  if (sections.contains(IntegrationDeskSection.integrations)) {
    return IntegrationDeskSection.integrations;
  }
  return sections.first;
}

/// Whether a row next-action mutates (write-gated) vs opens detail (view).
bool integrationNextActionRequiresWrite(String nextAction) {
  return switch (nextAction) {
    'enable' ||
    'enable_webhook' ||
    'review_failure' ||
    'monitor' ||
    'review_key' ||
    'replay_or_escalate' => true,
    _ => false,
  };
}

/// Integrations tab atom → permission mapping (inventory + matrix).
///
/// Shared workspace helpers until the Integrations tab prompt deep-scans.
abstract final class IntegrationsIntegrationsAtomPermissions {
  static const AccessRequirement tab = integrationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement create = integrationsWorkspaceManageRequirement;
  static const AccessRequirement update = integrationsWorkspaceManageRequirement;
  static const AccessRequirement delete = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = integrationsWorkspaceManageRequirement;
  static const AccessRequirement entry = integrationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      integrationsWorkspaceEntryRequirement;
}

/// API keys tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | API keys tab | navigate | [tab] read ∩ `integration:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | [listChrome] |
/// | Empty / loading / error / retry | read chrome | [empty] / [loading] / [retry] |
/// | Row select → detail | read | [rowSelect] / [detail] |
/// | Next action Review key (warning) | update | [managePermissions] / [update] manage ∪ |
/// | Next action Rotate or monitor (healthy) | read / navigate | [viewNextAction] / [nextAction] |
/// | Create API key (+ secret reveal) | create | [create] manage ∪ (secret write-only) |
/// | Detail Manage permissions | update | [managePermissions] |
/// | Detail Enable / Disable | update | [enableDisable] / [update] |
/// | Detail Revoke key | delete | [revoke] / [delete] ∩ `integration:delete` |
/// | Detail remove permission grant | update | [removePermission] / [update] |
/// | Detail masked secret / rotation gap / grants list | read | [detail] |
/// | Nested cross-module read / write | — | _(n/a)_ |
/// | Route entry (deep link) | navigate | [routeEntry] read ∪ write ∪ admin |
///
/// Matrix create/update ∩ write maps to source manage ∪ (write \| admin).
/// Nested cross-module matrix rows are _(n/a)_.
abstract final class IntegrationsApiKeysAtomPermissions {
  static const AccessRequirement tab = integrationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement search = integrationsWorkspaceReadRequirement;
  static const AccessRequirement filters = integrationsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement empty = integrationsWorkspaceReadRequirement;
  static const AccessRequirement loading = integrationsWorkspaceReadRequirement;
  static const AccessRequirement retry = integrationsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement detail = integrationsWorkspaceReadRequirement;
  static const AccessRequirement nextAction =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement viewNextAction =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement create = integrationsWorkspaceManageRequirement;
  static const AccessRequirement update = integrationsWorkspaceManageRequirement;
  static const AccessRequirement delete = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = integrationsWorkspaceManageRequirement;
  static const AccessRequirement managePermissions =
      integrationsWorkspaceManageRequirement;
  static const AccessRequirement enableDisable =
      integrationsWorkspaceManageRequirement;
  static const AccessRequirement removePermission =
      integrationsWorkspaceManageRequirement;
  static const AccessRequirement revoke = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement secretReveal =
      integrationsWorkspaceManageRequirement;
  static const AccessRequirement nestedWrite =
      integrationsWorkspaceManageRequirement;
  static const AccessRequirement nestedRead =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement entry = integrationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      integrationsWorkspaceEntryRequirement;
  static const AccessRequirement read = integrationsReadRequirement;
}

/// Webhooks tab atom → permission mapping (shared helpers until tab scan).
abstract final class IntegrationsWebhooksAtomPermissions {
  static const AccessRequirement tab = integrationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement create = integrationsWorkspaceManageRequirement;
  static const AccessRequirement update = integrationsWorkspaceManageRequirement;
  static const AccessRequirement delete = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = integrationsWorkspaceManageRequirement;
  static const AccessRequirement entry = integrationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      integrationsWorkspaceEntryRequirement;
}

/// Logs tab atom → permission mapping (shared helpers until tab scan).
abstract final class IntegrationsLogsAtomPermissions {
  static const AccessRequirement tab = integrationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement create = integrationsWorkspaceManageRequirement;
  static const AccessRequirement update = integrationsWorkspaceManageRequirement;
  static const AccessRequirement delete = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = integrationsWorkspaceManageRequirement;
  static const AccessRequirement entry = integrationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      integrationsWorkspaceEntryRequirement;
}

/// Interop tab atom → permission mapping (shared helpers until tab scan).
abstract final class IntegrationsInteropAtomPermissions {
  static const AccessRequirement tab = integrationsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      integrationsWorkspaceReadRequirement;
  static const AccessRequirement create = integrationsWorkspaceManageRequirement;
  static const AccessRequirement update = integrationsWorkspaceManageRequirement;
  static const AccessRequirement delete = integrationsWorkspaceDeleteRequirement;
  static const AccessRequirement write = integrationsWorkspaceManageRequirement;
  static const AccessRequirement entry = integrationsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry =
      integrationsWorkspaceEntryRequirement;
}
