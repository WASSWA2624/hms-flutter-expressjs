import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';

void main() {
  group('CatalogConfigureScopeVisibility', () {
    test('elevated platform admin selects tenant and facility', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
        ),
      );

      final CatalogConfigureScopeVisibility visibility =
          CatalogConfigureScopeVisibility.fromPolicy(policy);

      expect(visibility.showTenantSelector, isTrue);
      expect(visibility.showFacilitySelector, isTrue);
      expect(visibility.skipPicker, isFalse);
    });

    test('tenant admin without facility selects facility only', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'TEN0000001',
            roles: <String>['TENANT_ADMIN'],
          ),
          permissions: const <AppPermission>[AppPermissions.tenantAdmin],
        ),
      );

      final CatalogConfigureScopeVisibility visibility =
          CatalogConfigureScopeVisibility.fromPolicy(policy);

      expect(visibility.showTenantSelector, isFalse);
      expect(visibility.showFacilitySelector, isTrue);
      expect(visibility.skipPicker, isFalse);
    });

    test('facility-scoped actor skips the picker', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'TEN0000001',
            facilityId: 'FAC0000001',
            roles: <String>['FACILITY_ADMIN'],
          ),
        ),
      );

      final CatalogConfigureScopeVisibility visibility =
          CatalogConfigureScopeVisibility.fromPolicy(policy);

      expect(visibility.showTenantSelector, isFalse);
      expect(visibility.showFacilitySelector, isFalse);
      expect(visibility.skipPicker, isTrue);
    });
  });
}
