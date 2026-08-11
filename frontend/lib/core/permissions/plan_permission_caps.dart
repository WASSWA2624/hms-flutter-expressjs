import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';
import 'package:hosspi_hms/core/permissions/version_disabled_permissions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

/// Mirrors backend `subscription-permission-caps.js`.
///
/// Runtime grants are intersected with these action caps after module
/// entitlement filtering so the shell cannot show Pro routes the API will 403.
abstract final class PlanPermissionCaps {
  static const Set<String> free = <String>{
    'patient:read',
    'patient:write',
    'patients:read',
    'reports:read',
  };

  static const Set<String> basic = <String>{
    ...free,
    'reception:read',
    'opd:read',
    'clinical:read',
    'clinical:write',
    // emergency:* and communications:* withheld — version-disabled-screens.
    'pharmacy:read',
    'pharmacy:write',
    'billing:read',
    'billing:write',
    'accounts:read',
    'accounts:write',
    'pricing:pharmacy_read',
    'pricing:pharmacy_write',
    'pricing:facility_read',
    'pricing:facility_write',
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
    'claims:read',
    'ipd:read',
    // rooms_beds:* and physiotherapy:* withheld — version-disabled-screens.
    'nursing:read',
    'icu:read',
    'discharge:read',
    'theater:read',
  };

  static const Set<String> pro = <String>{
    ...advanced,
    // operations:*, housekeeping:*, biomed:*, mortuary:*, integration:*
    // withheld — version-disabled-screens.
    'hr:read',
    'hr:write',
    'unit:read',
    'unit:manage',
    'roster:read',
    'roster:write',
    'roster:publish',
    'roster:approve',
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
    final List<String> explicit = VersionDisabledPermissions.applyNames(
      allowedPermissions
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet(),
    ).toList(growable: false);
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
    final Set<AppPermission> capped = cap == null
        ? permissions
        : permissions
              .where(
                (AppPermission permission) =>
                    !PermissionModuleMap.isModuleScoped(permission.value) ||
                    cap.contains(permission.value),
              )
              .toSet();
    return VersionDisabledPermissions.apply(capped);
  }
}
