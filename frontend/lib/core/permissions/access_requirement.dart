import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';

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

  /// Plan modules required up front: explicit [activeModules] plus domains from
  /// [allPermissions]. [anyPermissions] are plan-checked per permission in
  /// [AppAccessPolicy.grants] so one entitled right can satisfy an any-of set.
  List<String> get effectiveModules {
    final Set<String> modules = <String>{
      for (final String code in activeModules)
        if (code.trim().isNotEmpty) code.trim(),
    };
    for (final AppPermission permission in allPermissions) {
      final String? module = PermissionModuleMap.moduleForPermission(
        permission,
      );
      if (module != null) {
        modules.add(module);
      }
    }
    return modules.toList(growable: false);
  }

  bool isAllowed(AppAccessPolicy policy) {
    // Authority order: Plan (modules) → Role → Rights (permissions) → scope.
    // Plan is the hard gate for module access; role/rights only apply afterward.
    if (!policy.hasAllActiveModules(effectiveModules)) {
      return false;
    }

    final bool hasPermissionRequirements =
        allPermissions.isNotEmpty || anyPermissions.isNotEmpty;

    // Role packs authorize through their permissions. Canonical role names are
    // only required when a route is role-gated with no permission requirements.
    // Patient portal and housekeeping must not permission-bypass into staff
    // clinical/patient-flow routes.
    if (anyRoles.isNotEmpty && !policy.hasAnyRole(anyRoles)) {
      if (policy.hasRole(AppRole.patient) ||
          policy.hasRole(AppRole.houseKeeper) ||
          !hasPermissionRequirements) {
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
        !policy.isPlatformElevated) {
      return false;
    }
    if (requiresFacilityContext &&
        !policy.hasFacilityContext &&
        !policy.isPlatformElevated) {
      return false;
    }

    return true;
  }
}
