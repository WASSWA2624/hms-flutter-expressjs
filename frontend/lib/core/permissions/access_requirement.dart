import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

final class AccessRequirement {
  const AccessRequirement({
    this.allPermissions = const <AppPermission>[],
    this.anyPermissions = const <AppPermission>[],
    this.anyRoles = const <AppRole>[],
    this.activeModules = const <String>[],
    this.requiresTenantContext = false,
    this.requiresFacilityContext = false,
  });

  final Iterable<AppPermission> allPermissions;
  final Iterable<AppPermission> anyPermissions;
  final Iterable<AppRole> anyRoles;
  final Iterable<String> activeModules;
  final bool requiresTenantContext;
  final bool requiresFacilityContext;

  bool get isEmpty {
    return allPermissions.isEmpty &&
        anyPermissions.isEmpty &&
        anyRoles.isEmpty &&
        activeModules.isEmpty &&
        !requiresTenantContext &&
        !requiresFacilityContext;
  }

  bool isAllowed(AppAccessPolicy policy) {
    final bool hasPermissionRequirements =
        allPermissions.isNotEmpty || anyPermissions.isNotEmpty;

    // Role packs authorize through their permissions. Canonical role names are
    // only required when a route is role-gated with no permission requirements.
    if (anyRoles.isNotEmpty && !policy.hasAnyRole(anyRoles)) {
      if (!hasPermissionRequirements) {
        return false;
      }
    }
    if (!policy.grantsAll(allPermissions)) {
      return false;
    }
    if (anyPermissions.isNotEmpty && !policy.grantsAny(anyPermissions)) {
      return false;
    }
    if (requiresTenantContext &&
        !policy.hasTenantContext &&
        !policy.isElevated) {
      return false;
    }
    if (requiresFacilityContext &&
        !policy.hasFacilityContext &&
        !policy.isElevated) {
      return false;
    }

    return policy.hasAllActiveModules(activeModules);
  }
}
