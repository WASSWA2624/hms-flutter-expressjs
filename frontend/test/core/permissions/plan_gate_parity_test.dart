import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/commercial_module_tiers.dart';
import 'package:hosspi_hms/core/permissions/permission_module_map.dart';
import 'package:hosspi_hms/core/permissions/plan_permission_caps.dart';
import 'package:hosspi_hms/core/permissions/version_disabled_permissions.dart';

/// Mirrors of the backend plan gates. Update together with:
///   backend/src/lib/subscriptions/subscription-permission-caps.js
///   backend/src/lib/subscriptions/plan-module-matrix.js
///   backend/src/lib/authorization/permission-module-map.js
///
/// Backend-side invariants live in
/// backend/src/tests/lib/subscriptions/subscription-permission-caps.test.js.
const Set<String> _backendFree = <String>{
  'patient:read',
  'patient:write',
  'patients:read',
  'reports:read',
};

const Set<String> _backendBasic = <String>{
  ..._backendFree,
  'patient:delete',
  'reception:read',
  'opd:read',
  'clinical:read',
  'clinical:write',
  'pharmacy:read',
  'pharmacy:write',
  'billing:read',
  'billing:write',
  'accounts:read',
  'accounts:write',
  'subscriptions:read',
  'subscriptions:write',
  'subscriptions:delete',
};

const Set<String> _backendAdvanced = <String>{
  ..._backendBasic,
  'lab:read',
  'lab:write',
  'radiology:read',
  'radiology:write',
  'reports:write',
  'reports:delete',
  'financial:approve',
  'claims:read',
  'ipd:read',
  'nursing:read',
  'discharge:read',
};

const Set<String> _backendPro = <String>{
  ..._backendAdvanced,
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

/// Commercial modules whose minimum tier is above FREE.
const Map<String, String> _backendModuleTiers = <String, String>{
  'scheduling-queue': 'BASIC',
  'encounters-vitals': 'BASIC',
  'pharmacy-dispensing': 'BASIC',
  'billing-payments': 'BASIC',
  'facility-accounts': 'BASIC',
  'notifications-communications': 'BASIC',
  'inpatient-bed-management': 'BASIC',
  'subscription-controls': 'BASIC',
  'lab-workflows': 'ADVANCED',
  'insurance-claims': 'ADVANCED',
  'radiology-workflows': 'ADVANCED',
  'physiotherapy': 'ADVANCED',
  'extra-storage': 'ADVANCED',
  'inventory-procurement': 'ADVANCED',
  'theatre-anesthesia': 'PRO',
  'facilities-maintenance': 'PRO',
  'icu-critical-care': 'PRO',
  'inventory-procurement-lite': 'PRO',
  'mortuary': 'PRO',
  'biomedical-engineering-suite': 'PRO',
  'hr-rosters': 'PRO',
  'integrations-core': 'PRO',
  'compliance-audit-core': 'CUSTOM',
  'advanced-analytics': 'CUSTOM',
  'sms-credits': 'CUSTOM',
  'developer-tools': 'DEVELOPER',
};

const List<String> _orderedTiers = <String>['FREE', 'BASIC', 'ADVANCED', 'PRO'];

void main() {
  group('plan permission caps parity', () {
    test('each tier matches the backend cap', () {
      expect(PlanPermissionCaps.free, _backendFree);
      expect(PlanPermissionCaps.basic, _backendBasic);
      expect(PlanPermissionCaps.advanced, _backendAdvanced);
      expect(PlanPermissionCaps.pro, _backendPro);
    });

    test('tiers are cumulative', () {
      for (int i = 1; i < _orderedTiers.length; i += 1) {
        final Set<String> lower =
            PlanPermissionCaps.byTier[_orderedTiers[i - 1]]!;
        final Set<String> higher = PlanPermissionCaps.byTier[_orderedTiers[i]]!;
        expect(
          lower.difference(higher),
          isEmpty,
          reason: '${_orderedTiers[i]} must contain ${_orderedTiers[i - 1]}',
        );
      }
    });

    test('every capped permission is module-scoped', () {
      for (final String tier in _orderedTiers) {
        for (final String permission in PlanPermissionCaps.byTier[tier]!) {
          expect(
            PermissionModuleMap.moduleForPermissionCode(permission),
            isNotNull,
            reason: '$tier: $permission is core — a cap entry for it is inert',
          );
        }
      }
    });

    test('no capped permission sits below its module minimum tier', () {
      for (final String tier in _orderedTiers) {
        final int tierRank = CommercialModuleTiers.rankOf(tier);
        for (final String permission in PlanPermissionCaps.byTier[tier]!) {
          final String slug = PermissionModuleMap.moduleForPermissionCode(
            permission,
          )!;
          final String? minimum = CommercialModuleTiers.minimumTierForModule(
            slug,
          );
          if (minimum == null) continue;

          final int minimumRank = CommercialModuleTiers.rankOf(minimum);
          // CUSTOM / DEVELOPER modules sit outside the cumulative ladder.
          if (minimumRank > CommercialModuleTiers.rankOf('PRO')) continue;

          expect(
            minimumRank <= tierRank,
            isTrue,
            reason: '$tier: $permission needs module $slug ($minimum)',
          );
        }
      }
    });

    test('no tier carries a version-disabled domain', () {
      final bool previous = VersionDisabledPermissions.enforce;
      VersionDisabledPermissions.enforce = true;
      try {
        for (final Set<String> cap in PlanPermissionCaps.byTier.values) {
          for (final String permission in cap) {
            expect(
              VersionDisabledPermissions.isDisabled(permission),
              isFalse,
              reason: '$permission is version-disabled',
            );
          }
        }
      } finally {
        VersionDisabledPermissions.enforce = previous;
      }
    });
  });

  group('commercial module tier parity', () {
    test('matches the backend plan-module matrix', () {
      expect(CommercialModuleTiers.minimumTierBySlug, _backendModuleTiers);
    });

    test('every module named by a permission domain has a known tier', () {
      // FREE modules are intentionally absent from minimumTierBySlug.
      const Set<String> freeModules = <String>{
        'patient-registry',
        'reporting-analytics',
      };
      for (final String slug in PermissionModuleMap.domainToModule.values) {
        expect(
          freeModules.contains(slug) ||
              CommercialModuleTiers.minimumTierBySlug.containsKey(slug),
          isTrue,
          reason: '$slug has no tier and is not a known FREE module',
        );
      }
    });
  });

  group('permission module map', () {
    test('core and cross-module permissions stay unmapped', () {
      for (final String permission in <String>[
        'profile:read',
        'setup:read',
        'access_admin:read',
        'break_glass:request',
        'evidence:export',
        'tenant:admin',
        // Cross-module: the Billing price book hosts pharmacy rows, so pricing
        // must not require pharmacy-dispensing.
        'pricing:pharmacy_write',
        'pricing:facility_write',
      ]) {
        expect(
          PermissionModuleMap.moduleForPermissionCode(permission),
          isNull,
          reason: '$permission must not be plan-gated',
        );
      }
    });
  });
}
