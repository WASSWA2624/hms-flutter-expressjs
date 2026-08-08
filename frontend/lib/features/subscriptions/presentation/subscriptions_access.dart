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

/// Catalog shell entry — platform admins only ([RouteAccessCatalog.subscriptions]).
const AccessRequirement subscriptionsWorkspaceCatalogEntryRequirement =
    RouteAccessCatalog.subscriptionsEntry;

/// [AppRoutes.subscriptions] route entry — same platform-admin gate as catalog.
const AccessRequirement subscriptionsWorkspaceRouteEntryRequirement =
    RouteAccessCatalog.subscriptionsEntry;

/// Alias matching historical / prompt "route entry" naming when AppRoutes ∪
/// is intended (not the workspace `subscriptions:read` content atoms).
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
  return subscriptionsWorkspaceRouteEntryRequirement.isAllowed(policy);
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
    SubscriptionPanel.overview => SubscriptionsOverviewAtomPermissions.tab,
    SubscriptionPanel.catalog => SubscriptionsPlansAtomPermissions.tab,
    SubscriptionPanel.modules => SubscriptionsPlansAtomPermissions.tab,
    SubscriptionPanel.billing => SubscriptionsInvoicesAtomPermissions.tab,
    SubscriptionPanel.governance => SubscriptionsLicensesAtomPermissions.tab,
    SubscriptionPanel.operations => SubscriptionsAtomPermissions.tab,
    SubscriptionPanel.denied => SubscriptionsAtomPermissions.tab,
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

/// Overview tab (`panel=overview`) atom → permission mapping (inventory +
/// matrix). Summary KPIs only; no create primary on the tab strip.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Overview strip tab | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Queue chips (shared chrome) | navigate / read | read ∩ ([queueChip]) |
/// | KPI cohort cards (Active / Not subscribed / Closed) | read | read ∩ ([kpi] / [listChrome]) |
/// | Usage limits panel | read | read ∩ ([usageLimits]) |
/// | Recommendations list | read | read ∩ ([recommendations]) |
/// | Cohort dialog (accounts list) | read / progressive disclosure | read ∩ ([cohortDialog] / [detail]) |
/// | Cohort New subscription | create | write ∩ ([create] / [nestedWrite]) |
/// | Cohort Edit subscription | update | write ∩ ([update] / [nestedWrite]) |
/// | Tab-strip primary create | create | _(none on Overview)_ |
/// | Destructive delete / void | delete | delete ∩ — **not mounted** |
/// | Nested cross-module read / write | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Empty / loading / error / retry / success / validation | read chrome | read ∩ |
/// | Route entry (deep link) | navigate | ∪ `system:admin` ([routeEntry]) |
/// | Catalog shell entry | navigate | ∩ read + module ([catalogEntry]) |
///
/// Matrix view ∪ and nested cross-module rows are _(n/a)_. Route entry ∪ is
/// [subscriptionsWorkspaceRouteEntryRequirement]; atom gates still use
/// `subscriptions:*` ∩ module so elevated-but-scoped sessions cannot
/// over-grant. Create / update share write ∩ (`subscriptions:write`).
abstract final class SubscriptionsOverviewAtomPermissions {
  static const AccessRequirement tab = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement listChrome =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement kpi = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement usageLimits =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement recommendations =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement queueChip =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement cohortDialog =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement detail = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement empty = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement loading =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement retryChrome =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement read = subscriptionsWorkspaceReadRequirement;

  /// Matrix ∩ `subscriptions:write` — cohort New subscription.
  static const AccessRequirement create =
      subscriptionsWorkspaceCreateRequirement;

  /// Matrix ∩ `subscriptions:write` — cohort Edit subscription.
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

/// Plans tab (`panel=catalog` / `resource=subscription-plans`) and Modules
/// primary tab (`panel=modules`) atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Plans strip tab (catalog) | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Modules strip tab (`panel=modules`) | navigate | read ∩ ([tab] / [nestedResourceTabs]) |
/// | Modules catalog list / detail | read | read ∩ ([listChrome] / [detail]) — **no write primary** |
/// | Search / filters / columns / pagination | read chrome | read ∩ ([listChrome] / [search] / [filters] / [columns] / [pagination]) |
/// | Empty / loading / error / retry / success / validation | read chrome | read ∩ ([empty] / [loading] / [retryChrome]) |
/// | Row select → plan detail | read | read ∩ ([rowSelect] / [detail]) |
/// | Detail metrics / included modules / tenant accounts | read | read ∩ ([detail]) |
/// | Create plan (tab primary + form) | create | write ∩ ([create]) |
/// | Edit plan (detail dialog action + form) | update | write ∩ ([edit] / [update]) |
/// | Manage modules / module pack (detail + dialog) | update | write ∩ ([manageModules] / [update]) |
/// | Destructive delete / void | delete | delete ∩ — **not mounted** ([delete]) |
/// | Nested cross-module read / write | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Overview KPI active plans (shared chrome) | read | read ∩ ([overviewKpi]) |
/// | Route entry (deep link) | navigate | ∪ `system:admin` ([routeEntry]) |
/// | Catalog shell entry | navigate | ∩ read + module ([catalogEntry]) |
///
/// Matrix view ∪ and nested cross-module rows are _(n/a)_. Route entry ∪ is
/// [subscriptionsWorkspaceRouteEntryRequirement]; atom gates still use
/// `subscriptions:*` ∩ module so elevated-but-scoped sessions cannot
/// over-grant. Create / edit / manage-modules (module packs) share write ∩
/// (`subscriptions:write`). Modules nested resource is a read-only catalog;
/// pack membership is edited via [manageModules] on a plan.
abstract final class SubscriptionsPlansAtomPermissions {
  static const AccessRequirement tab = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement nestedResourceTabs =
      subscriptionsWorkspaceReadRequirement;
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
  static const AccessRequirement overviewKpi =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement read = subscriptionsWorkspaceReadRequirement;

  /// Matrix ∩ `subscriptions:write` — Create plan primary.
  static const AccessRequirement create =
      subscriptionsWorkspaceCreateRequirement;

  /// Matrix ∩ `subscriptions:write` — Edit plan.
  static const AccessRequirement edit =
      subscriptionsWorkspaceUpdateRequirement;

  /// Matrix ∩ `subscriptions:write` — Manage included modules.
  static const AccessRequirement manageModules =
      subscriptionsWorkspaceUpdateRequirement;

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

/// Invoices tab (`panel=billing` / subscription invoices) atom → permission
/// mapping (inventory + matrix). Issue / adjust map to Collect / Retry (write ∩).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Invoices strip tab | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Past due invoices queue chip | navigate / read | read ∩ ([pastDueChip]) |
/// | Search / filters / columns / pagination | read chrome | read ∩ ([listChrome] / [search] / [filters] / [columns] / [pagination]) |
/// | Empty / loading / error / retry / success / validation | read chrome | read ∩ ([empty] / [loading] / [retryChrome]) |
/// | Row select → detail | read | read ∩ ([rowSelect] / [detail]) |
/// | Detail fields / timeline | read | read ∩ ([detail]) |
/// | Collect invoice (detail + dialog) — issue/adjust | update | write ∩ ([collect] / [update]) |
/// | Retry invoice (detail + dialog) — issue/adjust | update | write ∩ ([retry] / [update]) |
/// | Tab primary create | create | write ∩ — **not mounted** on invoices ([create]) |
/// | Destructive delete / void | delete | delete ∩ — **not mounted** ([delete]) |
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

/// Licenses tab (`panel=governance` / `resource=licenses`) atom → permission
/// mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Licenses strip tab | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Expiring licenses queue chip | navigate / read | read ∩ ([expiringLicensesChip]) |
/// | Search / filters / columns / pagination | read chrome | read ∩ ([listChrome] / [search] / [filters] / [columns] / [pagination]) |
/// | Empty / loading / error / retry / success / validation | read chrome | read ∩ ([empty] / [loading] / [retryChrome]) |
/// | Row select → detail | read | read ∩ ([rowSelect] / [detail]) |
/// | Detail fields / timeline | read | read ∩ ([detail]) |
/// | Add license (toolbar primary + form dialog) | create | write ∩ ([create] / [addLicense]) |
/// | Update license (detail action + form dialog) | update | write ∩ ([update] / [updateLicense]) |
/// | Status→CANCELLED in update form | update | write ∩ ([update]) — soft revoke |
/// | Revoke license (detail + confirm dialog) | delete | delete ∩ ([delete] / [revoke]) |
/// | Nested cross-module read / write | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Overview KPI expiring licenses (shared chrome) | read | read ∩ ([expiringLicensesChip]) |
/// | Route entry (deep link) | navigate | ∪ `system:admin` ([routeEntry]) |
/// | Catalog shell entry | navigate | ∩ read + module ([catalogEntry]) |
///
/// Matrix view ∪ and nested cross-module rows are _(n/a)_. Route entry ∪ is
/// [subscriptionsWorkspaceRouteEntryRequirement]; atom gates still use
/// `subscriptions:*` ∩ module so elevated-but-scoped sessions cannot
/// over-grant. Status→CANCELLED in the update form remains write ∩ (soft
/// revoke via update); destructive [revoke] uses HTTP delete ∩. Dialog
/// entry points re-check [create] / [update] / [delete] before mounting.
abstract final class SubscriptionsLicensesAtomPermissions {
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
  static const AccessRequirement expiringLicensesChip =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement read = subscriptionsWorkspaceReadRequirement;

  /// Matrix ∩ `subscriptions:write` — Add license.
  static const AccessRequirement create =
      subscriptionsWorkspaceCreateRequirement;
  static const AccessRequirement addLicense =
      subscriptionsWorkspaceCreateRequirement;

  /// Matrix ∩ `subscriptions:write` — Update license (incl. status→CANCELLED).
  static const AccessRequirement update =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement updateLicense =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement write = subscriptionsWorkspaceWriteRequirement;

  /// Matrix ∩ `subscriptions:delete` — Revoke / delete license.
  static const AccessRequirement delete =
      subscriptionsWorkspaceDeleteRequirement;
  static const AccessRequirement revoke =
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

/// Subscriptions tab (`panel=operations` / `resource=subscriptions`, nested
/// Module subscriptions) atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Subscriptions strip tab (operations) | navigate | read ∩ `subscriptions:read` ([tab]) |
/// | Nested Subscriptions / Module subscriptions | navigate | read ∩ ([nestedResourceTabs]) |
/// | Pending changes queue chip | navigate / read | read ∩ ([pendingChangesChip]) |
/// | Search / filters / columns / pagination | read chrome | read ∩ ([listChrome]) |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ ([rowSelect] / [detail]) |
/// | Detail fields / timeline | read | read ∩ ([detail]) |
/// | New subscription (tab primary) | create | write ∩ ([create] / [newSubscription]) |
/// | Assign module (subscription detail) | create | write ∩ ([assignModule] / [create]) |
/// | Edit / Renew / Change plan / Activate | update | write ∩ ([update] / [edit] / …) |
/// | Cancel subscription (status→CANCELLED via PUT) | update | write ∩ ([cancel] / [update]) |
/// | Enable / Disable module | update | write ∩ ([toggleModule] / [update]) |
/// | Destructive HTTP delete / void | delete | delete ∩ — **not mounted** |
/// | Nested cross-module read / write | nested | _(n/a)_ ([nestedRead] / [nestedWrite]) |
/// | Route entry (deep link) | navigate | ∪ `system:admin` ([routeEntry]) |
/// | Catalog shell entry | navigate | ∩ read + module ([catalogEntry]) |
///
/// Matrix view ∪ and nested cross-module rows are _(n/a)_. Route entry ∪ is
/// [subscriptionsWorkspaceRouteEntryRequirement]; atom gates still use
/// `subscriptions:*` ∩ module so elevated-but-scoped sessions cannot
/// over-grant. Create / update / cancel / activate / renew / change-plan /
/// assign-module / toggle-module share write ∩ (`subscriptions:write`). Soft
/// cancel via PUT remains write ∩ (same pattern as license status→CANCELLED);
/// hard delete uses HTTP delete ∩ and is not mounted on this tab.
abstract final class SubscriptionsAtomPermissions {
  static const AccessRequirement tab = subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement nestedResourceTabs =
      subscriptionsWorkspaceReadRequirement;
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
  static const AccessRequirement pendingChangesChip =
      subscriptionsWorkspaceReadRequirement;
  static const AccessRequirement read = subscriptionsWorkspaceReadRequirement;

  /// Matrix ∩ `subscriptions:write` — New subscription primary.
  static const AccessRequirement create =
      subscriptionsWorkspaceCreateRequirement;
  static const AccessRequirement newSubscription =
      subscriptionsWorkspaceCreateRequirement;

  /// Matrix ∩ `subscriptions:write` — Assign module (nested resource).
  static const AccessRequirement assignModule =
      subscriptionsWorkspaceCreateRequirement;

  /// Matrix ∩ `subscriptions:write` — Edit / renew / change plan / activate.
  static const AccessRequirement update =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement edit =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement renew =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement changePlan =
      subscriptionsWorkspaceUpdateRequirement;
  static const AccessRequirement activate =
      subscriptionsWorkspaceUpdateRequirement;

  /// Matrix ∩ `subscriptions:write` — Cancel (status→CANCELLED via PUT).
  static const AccessRequirement cancel =
      subscriptionsWorkspaceUpdateRequirement;

  /// Matrix ∩ `subscriptions:write` — Enable / disable module subscription.
  static const AccessRequirement toggleModule =
      subscriptionsWorkspaceUpdateRequirement;

  static const AccessRequirement write = subscriptionsWorkspaceWriteRequirement;

  /// Matrix ∩ `subscriptions:delete` — no HTTP delete control mounted.
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
