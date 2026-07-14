import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

/// Mirrors backend `subscription-permission-caps.js`.
///
/// Runtime grants are intersected with these action caps after module
/// entitlement filtering so the shell cannot show Pro routes the API will 403.
abstract final class PlanPermissionCaps {
  static const Set<String> free = <String>{
    'patient:read',
    'patient:write',
    'reports:read',
  };

  static const Set<String> basic = <String>{
    ...free,
    'clinical:read',
    'clinical:write',
    'emergency:read',
    'emergency:write',
    'pharmacy:read',
    'pharmacy:write',
    'billing:read',
    'billing:write',
    'communications:read',
    'communications:write',
    'subscriptions:read',
    'subscriptions:write',
  };

  static const Set<String> advanced = <String>{
    ...basic,
    'lab:read',
    'lab:write',
    'radiology:read',
    'radiology:write',
    'reports:write',
    'financial:approve',
  };

  static const Set<String> pro = <String>{
    ...advanced,
    'operations:read',
    'operations:write',
    'hr:read',
    'hr:write',
    'unit:read',
    'unit:manage',
    'roster:read',
    'roster:write',
    'roster:publish',
    'roster:approve',
    'biomed:read',
    'biomed:write',
    'mortuary:read',
    'mortuary:write',
    'mortuary:release',
    'mortuary:manage_storage',
    'mortuary:post_mortem_request',
    'mortuary:approve',
    'mortuary:billing_event',
    'mortuary:export',
    'mortuary:audit',
    'integration:read',
    'integration:write',
    'integration:delete',
  };

  static const Map<String, Set<String>> byTier = <String, Set<String>>{
    'FREE': free,
    'BASIC': basic,
    'ADVANCED': advanced,
    'PRO': pro,
    'CUSTOM': pro,
    'DEVELOPER': pro,
  };

  /// Returns the allowed module-scoped permission codes, or `null` when
  /// unrestricted (no tier / non-production Developer semantics on the client).
  static Set<String>? resolve({
    String? planTierCode,
    Iterable<String> allowedPermissions = const <String>[],
  }) {
    final List<String> explicit = allowedPermissions
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (explicit.isNotEmpty) {
      return Set<String>.unmodifiable(explicit);
    }

    final String tier = (planTierCode ?? '').trim().toUpperCase();
    if (tier.isEmpty) {
      return null;
    }
    // Client never treats DEVELOPER as unrestricted; mirror production ceiling.
    if (tier == 'DEVELOPER') {
      return Set<String>.unmodifiable(free);
    }
    return byTier[tier];
  }

  static Set<String>? resolveFromSession(AuthSession? session) {
    if (session == null) {
      return null;
    }

    final Iterable<AppModuleEntitlement> entitlements =
        session.moduleEntitlements.values;
    String? tierFromEntitlements;
    for (final AppModuleEntitlement entry in entitlements) {
      final String? tier = entry.planTierCode?.trim();
      if (tier != null && tier.isNotEmpty) {
        tierFromEntitlements = tier;
        break;
      }
    }
    final List<String> allowed = entitlements
        .expand((AppModuleEntitlement entry) => entry.allowedPermissions)
        .toList(growable: false);

    return resolve(
      planTierCode:
          tierFromEntitlements ?? session.subscriptionSummary?.tierCode,
      allowedPermissions: allowed,
    );
  }

  static Set<AppPermission> apply(
    Set<AppPermission> permissions,
    Set<String>? cap,
  ) {
    if (cap == null) {
      return permissions;
    }
    return permissions
        .where(
          (AppPermission permission) =>
              !PermissionModuleMap.isModuleScoped(permission.value) ||
              cap.contains(permission.value),
        )
        .toSet();
  }
}
