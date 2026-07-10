import 'package:hosspi_hms/core/permissions/app_permission.dart';

/// Maps permission domain prefixes to subscription module slugs.
///
/// Authority order: **Plan** (module) → **Role** (scope) → **Rights** (permission).
/// Permissions without a module mapping are treated as core/platform rights and
/// are not plan-gated at the permission layer.
abstract final class PermissionModuleMap {
  static const Map<String, String> domainToModule = <String, String>{
    'billing': 'billing-payments',
    'financial': 'billing-payments',
    'patient': 'patient-registry',
    'clinical': 'encounters-vitals',
    'emergency': 'scheduling-queue',
    'lab': 'lab-workflows',
    'radiology': 'radiology-workflows',
    'pharmacy': 'pharmacy-dispensing',
    'operations': 'facilities-maintenance',
    'hr': 'hr-rosters',
    'unit': 'hr-rosters',
    'roster': 'hr-rosters',
    'biomed': 'biomedical-engineering-suite',
    'mortuary': 'mortuary',
    'communications': 'notifications-communications',
    'integration': 'integrations-core',
    'reports': 'reporting-analytics',
    'subscriptions': 'subscription-controls',
  };

  /// Returns the subscription module slug for [permission], or null if core/platform.
  static String? moduleForPermission(AppPermission permission) {
    return moduleForPermissionCode(permission.value);
  }

  /// Returns the subscription module slug for a permission code, or null if core.
  static String? moduleForPermissionCode(String permissionCode) {
    final String normalized = permissionCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    final int separator = normalized.indexOf(':');
    final String domain = separator > 0
        ? normalized.substring(0, separator)
        : normalized;
    return domainToModule[domain];
  }

  /// Whether [permissionCode] is gated by a paid/product module.
  static bool isModuleScoped(String permissionCode) {
    return moduleForPermissionCode(permissionCode) != null;
  }
}
