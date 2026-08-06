import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// Temporary ship gate: permission domains withheld from every user and every
/// subscription package until a later release re-enables them.
///
/// Catalog keys and role packs may still list these domains; effective access
/// and plan caps must strip them. See `.cursor/access/version-disabled-screens.mdc`.
abstract final class VersionDisabledPermissions {
  static const Set<String> domains = <String>{
    'emergency',
    'rooms_beds',
    'physiotherapy',
    'operations',
    'housekeeping',
    'biomed',
    'mortuary',
    'communications',
    'integration',
  };

  /// When false, [apply] is a no-op. Feature tests for deferred screens may
  /// clear this in `setUp` / restore in `tearDown`.
  @visibleForTesting
  static bool enforce = true;

  static String domainOf(String permissionName) {
    final String normalized = permissionName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    final int separator = normalized.indexOf(':');
    return separator > 0 ? normalized.substring(0, separator) : normalized;
  }

  static bool isDisabled(String permissionName) {
    if (!enforce) {
      return false;
    }
    return domains.contains(domainOf(permissionName));
  }

  static Set<AppPermission> apply(Set<AppPermission> permissions) {
    if (!enforce) {
      return permissions;
    }
    return permissions
        .where((AppPermission permission) => !isDisabled(permission.value))
        .toSet();
  }

  static Set<String> applyNames(Set<String> permissionNames) {
    if (!enforce) {
      return permissionNames;
    }
    return permissionNames
        .where((String name) => !isDisabled(name))
        .toSet();
  }
}
