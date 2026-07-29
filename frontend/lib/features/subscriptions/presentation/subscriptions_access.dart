import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/subscriptions/domain/entities/subscription_entities.dart';

/// Module entitlement for the subscriptions workspace (`platform subscriptions`).
const String subscriptionsControlsModule = 'subscription-controls';

/// Alias used by tab atom maps / prompts.
const String subscriptionsActiveModule = subscriptionsControlsModule;

/// View / read UI (matrix ∩ `subscriptions:read`) + `subscription-controls`.
const AccessRequirement subscriptionsWorkspaceReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.subscriptionsRead],
      activeModules: <String>[subscriptionsControlsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement subscriptionsReadRequirement =
    subscriptionsWorkspaceReadRequirement;

/// Catalog shell entry — unique atom from [RouteAccessCatalog.subscriptions]
/// (∩ `subscriptions:read` + module).
const AccessRequirement subscriptionsWorkspaceCatalogEntryRequirement =
    RouteAccessCatalog.subscriptionsEntry;

/// Prompt / [AppRoutes.subscriptions] route-entry ∪: `system:admin`
/// (SUPER_ADMIN). Catalog entry stays
/// [subscriptionsWorkspaceCatalogEntryRequirement].
const AccessRequirement subscriptionsWorkspaceRouteEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.systemAdmin],
      anyRoles: <AppRole>[AppRole.superAdmin],
    );

/// Alias matching historical / prompt "route entry" naming when AppRoutes ∪
/// is intended (not the catalog `subscriptions:read` atom).
const AccessRequirement subscriptionsWorkspaceAppRouteRequirement =
    subscriptionsWorkspaceRouteEntryRequirement;

/// Create / update mutations (matrix ∩ `subscriptions:write`) + module.
const AccessRequirement subscriptionsWorkspaceWriteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.subscriptionsWrite],
      activeModules: <String>[subscriptionsControlsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement subscriptionsWriteRequirement =
    subscriptionsWorkspaceWriteRequirement;

const AccessRequirement subscriptionsWorkspaceCreateRequirement =
    subscriptionsWorkspaceWriteRequirement;
const AccessRequirement subscriptionsWorkspaceUpdateRequirement =
    subscriptionsWorkspaceWriteRequirement;

/// Soft/hard delete / void (matrix ∩ `subscriptions:delete`) + module.
const AccessRequirement subscriptionsWorkspaceDeleteRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.subscriptionsDelete],
      activeModules: <String>[subscriptionsControlsModule],
    );

/// Alias used by tab atom maps / prompts.
const AccessRequirement subscriptionsDeleteRequirement =
    subscriptionsWorkspaceDeleteRequirement;

/// Effective capabilities for subscriptions chrome.
final class SubscriptionsCapabilities {
  const SubscriptionsCapabilities({
    required this.canRead,
    required this.canWrite,
    required this.canDelete,
  });

  final bool canRead;
  final bool canWrite;
  final bool canDelete;

  factory SubscriptionsCapabilities.fromPolicy(AppAccessPolicy policy) {
    return SubscriptionsCapabilities(
      canRead: canReadSubscriptions(policy),
      canWrite: canWriteSubscriptions(policy),
      canDelete: canDeleteSubscriptions(policy),
    );
  }
}

bool canEnterSubscriptionsWorkspace(AppAccessPolicy policy) {
  return subscriptionsWorkspaceCatalogEntryRequirement.isAllowed(policy) ||
      subscriptionsWorkspaceRouteEntryRequirement.isAllowed(policy);
}

bool canReadSubscriptions(AppAccessPolicy policy) {
  return subscriptionsWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteSubscriptions(AppAccessPolicy policy) {
  return subscriptionsWorkspaceWriteRequirement.isAllowed(policy);
}

bool canDeleteSubscriptions(AppAccessPolicy policy) {
  return subscriptionsWorkspaceDeleteRequirement.isAllowed(policy);
}

/// Per-panel tab strip gate. Panels share workspace read until a tab prompt
/// documents a narrower requirement.
AccessRequirement subscriptionsPanelTabRequirement(SubscriptionPanel panel) {
  return switch (panel) {
    SubscriptionPanel.billing => SubscriptionsInvoicesAtomPermissions.tab,
    SubscriptionPanel.overview ||
    SubscriptionPanel.catalog ||
    SubscriptionPanel.operations ||
    SubscriptionPanel.governance => subscriptionsWorkspaceReadRequirement,
  };
}

bool canViewSubscriptionsPanel(
  AppAccessPolicy policy,
  SubscriptionPanel panel,
) {
  return subscriptionsPanelTabRequirement(panel).isAllowed(policy);
}

/// Panels the policy may show in the workspace tab strip.
List<SubscriptionPanel> subscriptionsAllowedPanels(AppAccessPolicy policy) {
  return <SubscriptionPanel>[
    for (final SubscriptionPanel panel in SubscriptionPanel.values)
      if (canViewSubscriptionsPanel(policy, panel)) panel,
  ];
}

/// First authorized panel (prefer catalog), or null when none are visible.
SubscriptionPanel? subscriptionsFallbackPanel(AppAccessPolicy policy) {
  final List<SubscriptionPanel> panels = subscriptionsAllowedPanels(policy);
  if (panels.isEmpty) {
    return null;
  }
  if (panels.contains(SubscriptionPanel.catalog)) {
    return SubscriptionPanel.catalog;
  }
  return panels.first;
}

/// Whether a summary queue chip may mount (target panel must be readable).
bool canViewSubscriptionsQueueChip(
  AppAccessPolicy policy,
  SubscriptionQueueSummary queue,
) {
  return canViewSubscriptionsPanel(policy, queue.panel);
}

/// Invoices tab (`panel=billing` / subscription invoices) atom → permission
/// mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Invoices strip tab | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Past due invoices queue chip | navigate / read | read ∩ ([pastDueChip]) |
/// | Search / filters / columns / pagination | read chrome | read ∩ ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ ([rowSelect] / [detail]) |
/// | Detail fields / timeline | read | read ∩ ([detail]) |
/// | Collect invoice (detail + dialog) | update | write ∩ ([collect] / [update]) |
/// | Retry invoice (detail + dialog) | update | write ∩ ([retry] / [update]) |
/// | Tab primary create | create | write ∩ — **not mounted** on invoices |
/// | Destructive delete / void | delete | delete ∩ — **not mounted** |
/// | Nested cross-module read / write | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Overview KPI past-due (shared chrome) | read | read ∩ ([pastDueChip]) |
/// | Route entry (deep link) | navigate | ∪ `system:admin` ([routeEntry]) |
/// | Catalog shell entry | navigate | ∩ read + module ([catalogEntry]) |
///
/// Matrix view ∪ and nested cross-module rows are _(n/a)_. Route entry ∪ is
/// [subscriptionsWorkspaceRouteEntryRequirement]; atom gates still use
/// `subscriptions:*` ∩ module so elevated-but-scoped sessions cannot
/// over-grant. Collect / retry share write ∩ (`subscriptions:write`).
abstract final class SubscriptionsInvoicesAtomPermissions {
  static const AccessRequirement tab = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement search = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement filters =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement columns =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement pagination =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement empty = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement retryChrome =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement rowSelect =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement detail = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement pastDueChip =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement read = subscriptionsWorkspaceReadRequirement;

  /// Matrix ∩ `subscriptions:write` — Collect invoice.
  static const AccessRequirement collect =
      subscriptionsWorkspaceWriteRequirement;

  /// Matrix ∩ `subscriptions:write` — Retry invoice.
  static const AccessRequirement retry = subscriptionsWorkspaceWriteRequirement;

  /// Matrix create ∩ — no invoices primary create control mounted.
  static const AccessRequirement create =
      subscriptionsWorkspaceCreateRequirement;

  static const AccessRequirement update =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement write = subscriptionsWorkspaceWriteRequirement;

  /// Matrix ∩ `subscriptions:delete` — no void/delete control mounted.
  static const AccessRequirement delete =
      subscriptionsWorkspaceDeleteRequirement;

  /// Nested cross-module — matrix _(n/a)_; reuses workspace read / write ∩.
  static const AccessRequirement nestedRead =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement nestedWrite =
      subscriptionsWorkspaceWriteRequirement;

  static const AccessRequirement routeEntry =
      subscriptionsWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      subscriptionsWorkspaceCatalogEntryRequirement;
  static const AccessRequirement entry =
      subscriptionsWorkspaceCatalogEntryRequirement;
}
