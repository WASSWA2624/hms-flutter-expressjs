import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';

void main() {
  group('isPharmacyRegistryReader', () {
    test('returns true for pharmacist without patient write', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
        ),
      );

      expect(isPharmacyRegistryReader(policy), isTrue);
    });

    test('returns false for pharmacist with patient write', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
          permissions: const <AppPermission>[AppPermissions.patientWrite],
        ),
      );

      expect(isPharmacyRegistryReader(policy), isFalse);
    });
  });
}
