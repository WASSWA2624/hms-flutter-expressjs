import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';
import 'package:hosspi_hms/core/permissions/permission_read_dependency.dart';
import 'package:hosspi_hms/core/permissions/version_disabled_permissions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';

/// Mirrors backend `subscription-permission-caps.js`.
///
/// Runtime grants are intersected with these action caps after module
/// entitlement filtering so the shell cannot show Pro routes the API will 403.
///
/// Two invariants keep this in step with the rest of access control:
///
/// 1. Caps only bite on module-scoped permissions ([PermissionModuleMap]).
///    Listing a core/platform key here is inert — do not add one.
/// 2. A key's tier must be >= its module's minimum tier in
///    [CommercialModuleTiers], otherwise the cap admits a permission whose
///    module the plan does not entitle and the workspace stays unreachable.
abstract final class PlanPermissionCaps {
  static const Set<String> free = <String>{
    'patient:read',
    'patient:write',
    // patient:delete is deliberately withheld here: FREE (and DEVELOPER, which
    // the client always resolves to FREE) must not admit destructive patient
    // actions. It enters at BASIC, the first tier with tenant/facility admins.
    'patients:read',
    'reports:read',
  };

  static const Set<String> basic = <String>{
    ...free,
    'patient:delete',
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
    // pricing:* is intentionally absent — it is a cross-module rights-layer
    // permission with no module mapping, so a cap entry for it would be inert.
    'subscriptions:read',
    'subscriptions:write',
    'subscriptions:delete',
  };

  static const Set<String> advanced = <String>{
    ...basic,
    'lab:read',
    'lab:write',
    'radiology:read',
    'radiology:write',
    'reports:write',
    'reports:delete',
    'financial:approve',
    'claims:read',
    // inpatient-bed-management is entitled from BASIC, but the IPD / nursing /
    // discharge workspaces open at ADVANCED — the cap is the binding gate.
    'ipd:read',
    // rooms_beds:* and physiotherapy:* withheld — version-disabled-screens.
    'nursing:read',
    'discharge:read',
  };

  static const Set<String> pro = <String>{
    ...advanced,
    // operations:*, housekeeping:*, biomed:*, mortuary:*, integration:*
    // withheld — version-disabled-screens.
    // icu-critical-care and theatre-anesthesia are PRO modules in
    // CommercialModuleTiers; their entry keys must not sit in a lower cap.
    'icu:read',
    'theater:read',
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
    // Custom without an explicit allowedPermissions list falls back to Pro.
    'CUSTOM': pro,
    // Developer never reaches this table: [resolve] short-circuits it to [free]
    // (the client never treats Developer as unrestricted). The entry mirrors
    // that ceiling so a direct table read cannot over-report.
    'DEVELOPER': free,
  };

  /// Returns the allowed module-scoped permission codes, or `null` when
  /// unrestricted (no tier / non-production Developer semantics on the client).
  static Set<String>? resolve({
    String? planTierCode,
    Iterable<String> allowedPermissions = const <String>[],
  }) {
    final Set<String> explicit = VersionDisabledPermissions.applyNames(
      allowedPermissions
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toSet(),
    );
    if (explicit.isNotEmpty) {
      // Match backend resolveSubscriptionPermissionCap, which expands required
      // reads on the explicit Custom-plan list. Without this a Custom plan
      // computes a narrower cap on the client than the API enforces.
      return Set<String>.unmodifiable(
        expandPermissionCodesWithRequiredReads(explicit),
      );
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
