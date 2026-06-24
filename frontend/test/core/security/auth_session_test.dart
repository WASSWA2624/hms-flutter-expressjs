import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

void main() {
  group('AuthSession', () {
    test('enrichFromUserProfile updates subject and user', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
      );
      const profile = AuthUserProfile(
        id: 'user-1',
        email: 'doctor@example.com',
        firstName: 'Jane',
        lastName: 'Doe',
        tenantId: 'tenant-1',
      );

      final enriched = session.enrichFromUserProfile(profile);

      expect(enriched.subject, 'doctor@example.com');
      expect(enriched.user?.fullName, 'Jane Doe');
      expect(enriched.user?.tenantId, 'tenant-1');
    });

    test('copyWith preserves unchanged fields', () {
      const permission = AppPermission('patient.read');
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        permissions: <AppPermission>{permission},
      );

      final copied = session.copyWith(
        user: const AuthUserProfile(email: 'nurse@example.com'),
      );

      expect(copied.user?.email, 'nurse@example.com');
      expect(copied.permissions, contains(permission));
      expect(copied.tokens.accessToken, 'access-token');
    });
  });
}
