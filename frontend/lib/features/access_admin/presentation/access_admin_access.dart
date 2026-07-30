import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';

/// Product label from UI-permission prompts (`access administration`).
///
/// Admin keys (`tenant:admin` / `facility:admin` / `system:admin`) are
/// core/platform rights (not [PermissionModuleMap]-scoped). Subscription
/// stripping of commercial modules does not revoke these keys; the workspace
/// API lives under platform facility structure.
const String accessAdminModuleLabel = 'access administration';

/// Product module code (see `.cursor/access/modules.mdc`).
const String accessAdminActiveModule = 'access_admin';

/// Route / workspace read keys (matrix ∪).
const List<AppPermission> accessAdminReadPermissions = <AppPermission>[
  AppPermissions.tenantAdmin,
  AppPermissions.facilityAdmin,
  AppPermissions.systemAdmin,
];

/// View / read UI (matrix ∪): `tenant:admin` | `facility:admin` | `system:admin`.
///
/// Aligns with `AppRoutes.accessAdmin` and settings access-admin link.
const AccessRequirement accessAdminWorkspaceReadRequirement =
    AccessRequirement(
      anyPermissions: accessAdminReadPermissions,
      requiresTenantContext: true,
    );

/// Alias used by tab prompts / atom maps.
const AccessRequirement accessAdminReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Directory tab read — same union as workspace entry.
const AccessRequirement accessAdminDirectoryReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Roles tab read — same union as workspace entry.
const AccessRequirement accessAdminRolesReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Demo tab read — same union as Directory / workspace entry.
const AccessRequirement accessAdminDemoReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Create / update / delete (matrix ∩): `tenant:admin`.
///
/// Source inventory (`screens/admin-access.md`) maps write chrome to backend
/// `canWrite`. Prefer [canWriteAccessAdmin], which intersects this requirement
/// with the workspace `canWrite` flag.
const AccessRequirement accessAdminWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.tenantAdmin],
  requiresTenantContext: true,
);

/// Directory create / update / delete atoms share the write ∩ requirement.
const AccessRequirement accessAdminCreateRequirement =
    accessAdminWriteRequirement;
const AccessRequirement accessAdminUpdateRequirement =
    accessAdminWriteRequirement;
const AccessRequirement accessAdminDeleteRequirement =
    accessAdminWriteRequirement;

/// Roles create / update / delete (matrix ∩): same as workspace write ∩.
const AccessRequirement accessAdminRolesWriteRequirement =
    accessAdminWriteRequirement;

/// Entitlements tab read — same ∪ as workspace entry (no stricter panel gate).
const AccessRequirement accessAdminEntitlementsReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Entitlements has no create/update/delete UI today (read-only catalog);
/// reserved for nested mutations and ∩ denial tests (matrix ∩ `tenant:admin`).
/// Elevations still use [canWriteAccessAdmin] / [canMutateAccessAdminEntitlements].
const AccessRequirement accessAdminEntitlementsWriteRequirement =
    accessAdminWriteRequirement;

/// Permissions tab read — same ∪ as workspace entry (catalog is read-focused).
const AccessRequirement accessAdminPermissionsReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Permissions catalog has no create/update/delete UI on this tab (source:
/// read-only detail). Reserved for nested mutations and ∩ denial tests
/// (matrix ∩ `tenant:admin`). Elevations still use [canWriteAccessAdmin].
const AccessRequirement accessAdminPermissionsWriteRequirement =
    accessAdminWriteRequirement;

/// Registrations tab read (matrix ∩ `system:admin`).
///
/// Source inventory additionally requires elevated (`SUPER_ADMIN`). Prefer
/// [canReadAccessAdminRegistrations] / [canAccessAccessAdminRegistrations].
/// Workspace route entry still uses [accessAdminWorkspaceReadRequirement] (∪).
const AccessRequirement accessAdminRegistrationsReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.systemAdmin],
    );

/// Registrations create / update / delete (matrix ∩): `tenant:admin`.
/// Prefer [canMutateAccessAdminRegistrations] (intersects workspace `canWrite`).
const AccessRequirement accessAdminRegistrationsWriteRequirement =
    accessAdminWriteRequirement;
const AccessRequirement accessAdminRegistrationsCreateRequirement =
    accessAdminCreateRequirement;
const AccessRequirement accessAdminRegistrationsUpdateRequirement =
    accessAdminUpdateRequirement;
const AccessRequirement accessAdminRegistrationsDeleteRequirement =
    accessAdminDeleteRequirement;

bool canReadAccessAdmin(AppAccessPolicy policy) {
  return accessAdminWorkspaceReadRequirement.isAllowed(policy) ||
      policy.isElevated;
}

bool canReadAccessAdminWorkspace(AppAccessPolicy policy) {
  return canReadAccessAdmin(policy);
}

bool canReadAccessAdminDirectory(AppAccessPolicy policy) {
  return canReadAccessAdmin(policy);
}

/// Directory mutations: create user / activate / deactivate — write ∩ +
/// workspace `canWrite`. Prefer over bare [accessAdminWriteRequirement] so
/// callers intersect the source inventory `canWrite` flag.
bool canMutateAccessAdminDirectory(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

bool canReadAccessAdminRoles(AppAccessPolicy policy) {
  return accessAdminRolesReadRequirement.isAllowed(policy) ||
      policy.isElevated;
}

/// Roles mutations: create / edit / delete — write ∩ + workspace `canWrite`.
bool canMutateAccessAdminRoles(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

bool canReadAccessAdminDemo(AppAccessPolicy policy) {
  return canReadAccessAdmin(policy);
}

/// Demo mutations: create user / activate / deactivate — same write ∩ as
/// Directory + workspace `canWrite`. Prefer over bare [accessAdminWriteRequirement].
bool canMutateAccessAdminDemo(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

/// Effective write gate: matrix ∩ `tenant:admin` and workspace `canWrite`.
/// Elevated actors also qualify when the workspace reports `canWrite`.
bool canWriteAccessAdmin(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  if (!workspaceCanWrite) {
    return false;
  }
  return accessAdminWriteRequirement.isAllowed(policy) || policy.isElevated;
}

/// Demo password reset: same write ∩ gate plus workspace demo-reset flag.
bool canResetDemoPasswordAccessAdmin(
  AppAccessPolicy policy, {
  required bool workspaceCanWrite,
  required bool workspaceCanResetDemoPasswords,
}) {
  return workspaceCanResetDemoPasswords &&
      canMutateAccessAdminDemo(policy, workspaceCanWrite: workspaceCanWrite);
}

bool canReadAccessAdminEntitlements(AppAccessPolicy policy) {
  return accessAdminEntitlementsReadRequirement.isAllowed(policy) ||
      policy.isElevated;
}

/// Entitlements mutations (none mounted); still enforces ∩ + workspace write.
bool canMutateAccessAdminEntitlements(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

bool canReadAccessAdminPermissions(AppAccessPolicy policy) {
  return accessAdminPermissionsReadRequirement.isAllowed(policy) ||
      policy.isElevated;
}

/// Permissions mutations (none mounted on this tab); enforces ∩ + canWrite.
bool canMutateAccessAdminPermissions(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

/// Registrations tab read — matrix ∩ `system:admin` (see
/// [accessAdminRegistrationsReadRequirement]).
///
/// Source inventory (`screens/admin-access.md`) keeps the tab **elevated-only**
/// (`SUPER_ADMIN`). Prefer that gate so bare `system:admin` without elevation
/// does not unlock the panel. Elevated role packs include `system:admin`.
bool canReadAccessAdminRegistrations(AppAccessPolicy policy) {
  return policy.isElevated;
}

/// Registrations create / update / delete: elevated tab gate + write ∩ +
/// workspace `canWrite`. Bare `tenant:admin` writers do not unlock mutations
/// when they cannot open the Registrations panel (source: elevated-only).
bool canMutateAccessAdminRegistrations(
  AppAccessPolicy policy, {
  bool workspaceCanWrite = true,
}) {
  return canReadAccessAdminRegistrations(policy) &&
      canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
}

/// Registrations tab: elevated (super-admin) only — source inventory.
bool canAccessAccessAdminRegistrations(AppAccessPolicy policy) {
  return canReadAccessAdminRegistrations(policy);
}

/// Whether [panel] may appear in the tab strip for [policy].
///
/// Overview is never shown. Registrations requires elevated (super-admin).
/// All other panels (Directory / Roles / Permissions / Entitlements / Demo)
/// use the read ∪ gate.
bool canAccessAccessAdminPanel(
  AppAccessPolicy policy,
  AccessAdminPanel panel,
) {
  if (!canReadAccessAdmin(policy)) {
    return false;
  }
  if (panel == AccessAdminPanel.registrations) {
    return canAccessAccessAdminRegistrations(policy);
  }
  return panel != AccessAdminPanel.overview;
}

/// Panels the actor may open; empty when read ∪ fails.
List<AccessAdminPanel> accessAdminAllowedPanels(AppAccessPolicy policy) {
  return AccessAdminPanel.values
      .where(
        (AccessAdminPanel panel) => canAccessAccessAdminPanel(policy, panel),
      )
      .toList(growable: false);
}

AccessAdminPanel? accessAdminFallbackPanel(AppAccessPolicy policy) {
  final List<AccessAdminPanel> allowed = accessAdminAllowedPanels(policy);
  if (allowed.isEmpty) {
    return null;
  }
  return allowed.first;
}

/// Directory tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminDirectoryBillingInventory]
/// (`access_admin_directory_billing.dart`). All mounted atoms are
/// `NOT_REQUIRED` / `NOT_BILLED` / `NO_CHARGE`; no patient Billing posts.
/// Role/permission previews in read-only detail must not mutate historical
/// ledgers.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Directory tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → user detail | read | read ∪ |
/// | Create user (tab primary) | create | write ∩ + canWrite |
/// | Activate / Deactivate (next-action / mobile trailing) | update | write ∩ + canWrite |
/// | Delete | delete | write ∩ (matrix; no delete UI on Directory today) |
/// | Open HR profile | navigate | linked profile (nested n/a) |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Source inventory maps write chrome to workspace `canWrite`; matrix ∩
/// `tenant:admin` is applied via [canWriteAccessAdmin] /
/// [canMutateAccessAdminDirectory]. Assignable rights stay within actor
/// ceiling / subscription (backend authoritative).
abstract final class AccessAdminDirectoryAtomPermissions {
  static const AccessRequirement tab = accessAdminDirectoryReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminDirectoryReadRequirement;
  static const AccessRequirement detail = accessAdminDirectoryReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
  static const AccessRequirement write = accessAdminWriteRequirement;
}

/// Roles tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminRolesBillingInventory]
/// (`access_admin_roles_billing.dart`). All mounted atoms are `NOT_REQUIRED` /
/// `NOT_BILLED` / `NO_CHARGE`; no patient Billing posts. Permission sync/editor
/// and restore/purge are unmounted on this tab (ManageRolesPermissionsPanel).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Roles tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → role detail | read | read ∪ |
/// | Create role (tab primary) | create | write ∩ + canWrite |
/// | Edit role (next-action / mobile trailing) | update | write ∩ + canWrite; not system-critical |
/// | Delete role (detail footer + confirm) | delete | write ∩ + canWrite; not system-critical |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Source inventory maps write chrome to workspace `canWrite`; matrix ∩
/// `tenant:admin` is applied via [canWriteAccessAdmin] /
/// [canMutateAccessAdminRoles]. Assignable rights stay within actor ceiling /
/// subscription (backend authoritative).
abstract final class AccessAdminRolesAtomPermissions {
  static const AccessRequirement tab = accessAdminRolesReadRequirement;
  static const AccessRequirement listChrome = accessAdminRolesReadRequirement;
  static const AccessRequirement detail = accessAdminRolesReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
  static const AccessRequirement write = accessAdminRolesWriteRequirement;
}

/// Demo tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminDemoBillingInventory]
/// (`access_admin_demo_billing.dart`). All mounted atoms are `NOT_REQUIRED` /
/// `NOT_BILLED` (display-only grants); no patient Billing posts.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Demo tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → detail | read | read ∪ |
/// | Create user | create | write ∩ + canWrite |
/// | Activate / Deactivate (next-action / mobile trailing) | update | write ∩ + canWrite |
/// | Reset demo password | update | write ∩ + canResetDemoPasswords |
/// | Delete | delete | write ∩ (matrix; no delete UI on Demo today) |
/// | Open HR profile | navigate | linked profile (nested n/a) |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Source inventory maps write chrome to workspace `canWrite`; matrix ∩
/// `tenant:admin` is applied via [canWriteAccessAdmin] /
/// [canMutateAccessAdminDemo] / [canResetDemoPasswordAccessAdmin]. Same write
/// gate as Directory. Assignable rights stay within actor ceiling /
/// subscription (backend authoritative).
abstract final class AccessAdminDemoAtomPermissions {
  static const AccessRequirement tab = accessAdminDemoReadRequirement;
  static const AccessRequirement listChrome = accessAdminDemoReadRequirement;
  static const AccessRequirement detail = accessAdminDemoReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
  static const AccessRequirement write = accessAdminWriteRequirement;
}

/// Entitlements tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminEntitlementsBillingInventory]
/// (`access_admin_entitlements_billing.dart`). All mounted atoms are
/// `NOT_REQUIRED` / `NOT_BILLED` (display-only); no patient Billing posts.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Entitlements tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → read-only detail | read | read ∪ |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Create | create | _(absent)_ ; write ∩ if added |
/// | Update | update | _(absent)_ ; write ∩ if added |
/// | Delete | delete | _(absent)_ ; write ∩ if added |
/// | next-action / tab primary | write | _(absent on this resource)_ |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Source inventory (`screens/admin-access.md`): Entitlements detail is a
/// read-only module/subscription summary (no write next-actions). Workspace
/// forces write chrome off for the Entitlements panel. Matrix ∩ `tenant:admin`
/// is reserved via [canMutateAccessAdminEntitlements] / create|update|delete
/// aliases if mutations are mounted later.
abstract final class AccessAdminEntitlementsAtomPermissions {
  static const AccessRequirement tab = accessAdminEntitlementsReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminEntitlementsReadRequirement;
  static const AccessRequirement detail = accessAdminEntitlementsReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
  static const AccessRequirement write =
      accessAdminEntitlementsWriteRequirement;
}

/// Permissions tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminPermissionsBillingInventory]
/// (`access_admin_permissions_billing.dart`). All mounted atoms are
/// `NOT_REQUIRED` / `NOT_BILLED` / `NO_CHARGE`; no patient Billing posts.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Permissions tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → read-only catalog detail | read | read ∪ |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Create | create | _(absent)_ ; write ∩ if added |
/// | Update | update | _(absent)_ ; write ∩ if added |
/// | Delete | delete | _(absent)_ ; write ∩ if added |
/// | next-action / tab primary | write | _(absent on this resource)_ |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Source inventory (`screens/admin-access.md`): Permissions detail is a
/// read-only catalog summary (no write next-actions). Workspace forces panel
/// write chrome off. Matrix ∩ `tenant:admin` is reserved via
/// [canMutateAccessAdminPermissions] / create|update|delete aliases if
/// mutations are mounted later. Prompt "edits elevated only" maps to that
/// reserved write ∩ + elevated path in [canWriteAccessAdmin].
abstract final class AccessAdminPermissionsAtomPermissions {
  static const AccessRequirement tab = accessAdminPermissionsReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminPermissionsReadRequirement;
  static const AccessRequirement detail = accessAdminPermissionsReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
  static const AccessRequirement write =
      accessAdminPermissionsWriteRequirement;
}

/// Registrations tab atom → permission mapping (inventory + matrix).
///
/// Financial classifications: [AccessAdminRegistrationsBillingInventory]
/// (`access_admin_registrations_billing.dart`). All mounted atoms are
/// `NOT_REQUIRED` / `NOT_BILLED` / `NO_CHARGE`; no patient Billing posts.
/// Activate provisions a SaaS trial via subscriptions onboarding and must not
/// mutate historical patient ledgers.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Registrations tab | navigate / progressive-disclosure | elevated (source); matrix ∩ `system:admin` |
/// | Search / filters / columns / pagination | read chrome | elevated |
/// | Empty / error / retry | read chrome | elevated |
/// | Row select → registration detail | read | elevated |
/// | Activate registration (next-action) | update | elevated + write ∩ + canWrite |
/// | Reject registration (detail) | delete | elevated + write ∩ + canWrite |
/// | Create user / Create role primary | create | _(absent on this resource)_ ; create ∩ if added |
/// | Detail Close | progressive-disclosure | elevated |
/// | Nested cross-module | n/a | _(n/a)_ |
///
/// Workspace entry remains read ∪ (`tenant:admin` \| `facility:admin` \|
/// `system:admin`). This tab is stricter than that union. Source inventory
/// maps write chrome to workspace `canWrite`; matrix ∩ `tenant:admin` plus
/// elevated tab gate via [canMutateAccessAdminRegistrations].
abstract final class AccessAdminRegistrationsAtomPermissions {
  static const AccessRequirement tab = accessAdminRegistrationsReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminRegistrationsReadRequirement;
  static const AccessRequirement detail =
      accessAdminRegistrationsReadRequirement;
  static const AccessRequirement create =
      accessAdminRegistrationsCreateRequirement;
  static const AccessRequirement update =
      accessAdminRegistrationsUpdateRequirement;
  static const AccessRequirement delete =
      accessAdminRegistrationsDeleteRequirement;
  static const AccessRequirement write =
      accessAdminRegistrationsWriteRequirement;
}
