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

/// Entitlements tab read — same ∪ as workspace entry (no stricter panel gate).
const AccessRequirement accessAdminEntitlementsReadRequirement =
    accessAdminWorkspaceReadRequirement;

/// Entitlements has no create/update/delete UI today; reserved for nested
/// mutations and ∩ denial tests (matrix ∩ `tenant:admin`).
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

bool canReadAccessAdminDemo(AppAccessPolicy policy) {
  return canReadAccessAdmin(policy);
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
      canWriteAccessAdmin(policy, workspaceCanWrite: workspaceCanWrite);
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

/// Registrations tab: elevated (super-admin) only — source inventory.
bool canAccessAccessAdminRegistrations(AppAccessPolicy policy) {
  return policy.isElevated;
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
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Directory tab | navigate | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → user detail | read | read ∪ |
/// | Create user | create | write ∩ + canWrite |
/// | Activate / Deactivate | update | write ∩ + canWrite |
/// | Open HR profile | navigate | linked profile (nested n/a) |
/// | Detail Close | progressive-disclosure | read ∪ |
abstract final class AccessAdminDirectoryAtomPermissions {
  static const AccessRequirement tab = accessAdminDirectoryReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminDirectoryReadRequirement;
  static const AccessRequirement detail = accessAdminDirectoryReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement delete = accessAdminDeleteRequirement;
}

/// Demo tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Demo tab | navigate | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → detail | read | read ∪ |
/// | Create user | create | write ∩ + canWrite |
/// | Activate / Deactivate | update | write ∩ + canWrite |
/// | Reset demo password | update | write ∩ + canResetDemoPasswords |
/// | Open HR profile | navigate | linked profile (nested n/a) |
/// | Detail Close | progressive-disclosure | read ∪ |
abstract final class AccessAdminDemoAtomPermissions {
  static const AccessRequirement tab = accessAdminDemoReadRequirement;
  static const AccessRequirement listChrome = accessAdminDemoReadRequirement;
  static const AccessRequirement detail = accessAdminDemoReadRequirement;
  static const AccessRequirement create = accessAdminCreateRequirement;
  static const AccessRequirement update = accessAdminUpdateRequirement;
  static const AccessRequirement write = accessAdminWriteRequirement;
}

/// Entitlements tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Entitlements tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → read-only detail | read | read ∪ |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Create / update / delete / next-action | write | _(absent)_ ; write ∩ if added |
abstract final class AccessAdminEntitlementsAtomPermissions {
  static const AccessRequirement tab = accessAdminEntitlementsReadRequirement;
  static const AccessRequirement listChrome =
      accessAdminEntitlementsReadRequirement;
  static const AccessRequirement detail = accessAdminEntitlementsReadRequirement;
  static const AccessRequirement write =
      accessAdminEntitlementsWriteRequirement;
}

/// Permissions tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Permissions tab | navigate / progressive-disclosure | read ∪ |
/// | Search / filters / columns / pagination | read chrome | read ∪ |
/// | Empty / error / retry | read chrome | read ∪ |
/// | Row select → read-only catalog detail | read | read ∪ |
/// | Detail Close | progressive-disclosure | read ∪ |
/// | Create / update / delete / next-action | write | _(absent)_ ; write ∩ if added |
/// | Nested cross-module | n/a | _(n/a)_ |
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
