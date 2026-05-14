import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

void main() {
  group('AppAccessPolicy', () {
    test('merges direct permissions with permissions from multiple roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR', 'BILLING']),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.grants(AppPermissions.clinicalWrite), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isTrue);
      expect(policy.grants(AppPermissions.financialApprove), isTrue);
      expect(policy.grants(AppPermissions.systemAdmin), isFalse);
    });

    test('normalizes legacy role aliases to canonical backend roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          roles: <String>['charge_nurse', 'ambulance_driver'],
        ),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasRole(AppRole.wardManager), isTrue);
      expect(policy.hasRole(AppRole.ambulanceOperator), isTrue);
      expect(policy.grants(AppPermissions.rosterPublish), isTrue);
      expect(policy.grants(AppPermissions.emergencyWrite), isTrue);
    });

    test('uses active module entitlements when they are present', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR']),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'clinical-care', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing', isActive: false),
        ],
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasActiveModule('clinical_care'), isTrue);
      expect(policy.hasActiveModule('billing'), isFalse);
      expect(policy.hasAllActiveModules(<String>['clinical-care']), isTrue);
      expect(
        policy.hasAllActiveModules(<String>['clinical-care', 'billing']),
        isFalse,
      );
    });

    test('does not block modules before entitlements are loaded', () {
      final policy = AppAccessPolicy.fromSession(null);

      expect(policy.hasActiveModule('clinical-care'), isTrue);
    });
  });
}
