import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';

void main() {
  group('tenantFacilityUsesScopedTenantPanel', () {
    test('platform creator uses full tenant list', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(roles: <String>['SUPER_ADMIN']),
        ),
      );

      expect(policy.canCreateTenant(), isTrue);
      expect(policy.canManageTenant(), isTrue);
      expect(
        tenantFacilityUsesScopedTenantPanel(
          canManageTenant: policy.canManageTenant(),
          canCreateTenant: policy.canCreateTenant(),
        ),
        isFalse,
      );
    });

    test('tenant admin uses scoped own-tenant panel', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['TENANT_ADMIN'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
        ),
      );

      expect(policy.canCreateTenant(), isFalse);
      expect(policy.canManageTenant(), isTrue);
      expect(
        tenantFacilityUsesScopedTenantPanel(
          canManageTenant: policy.canManageTenant(),
          canCreateTenant: policy.canCreateTenant(),
        ),
        isTrue,
      );
    });

    test('facility admin without tenant admin does not get tenants panel mode', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['FACILITY_ADMIN'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
        ),
      );

      expect(policy.canManageTenant(), isFalse);
      expect(
        tenantFacilityUsesScopedTenantPanel(
          canManageTenant: policy.canManageTenant(),
          canCreateTenant: policy.canCreateTenant(),
        ),
        isFalse,
      );
    });
  });

  group('ManageTenantsPanel scoped wiring', () {
    late String managementDialogsSource;
    late String setupPageSource;

    setUpAll(() {
      managementDialogsSource = File(
        'lib/features/tenant_facility/presentation/widgets/'
        'tenant_facility_management_dialogs.dart',
      ).readAsStringSync();
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/'
        'tenant_facility_setup_page.dart',
      ).readAsStringSync();
    });

    test('setup page passes session tenant into ManageTenantsPanel', () {
      expect(setupPageSource.contains('sessionTenant: snapshot.tenant'), isTrue);
    });

    test('scoped managers skip listTenants and render own-tenant details', () {
      expect(
        managementDialogsSource.contains('tenantFacilityUsesScopedTenantPanel'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('_buildScopedBody'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('_reloadScopedTenant'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('tenantFacilityEditTenantAction'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains(
          'if (_isScopedTenantManager) {\n      return;',
        ),
        isTrue,
        reason: 'scoped mode must not attach platform tenant list realtime sync',
      );
    });

    test('platform create/delete chrome stays create-gated', () {
      expect(
        managementDialogsSource.contains('bool get _canDelete => _canCreate;'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains(
          'trailingActions: widget.showCreateAction && _canCreate',
        ),
        isTrue,
      );
    });

    test('tenant edits upsert from lastSavedTenant for instant UI sync', () {
      expect(
        managementDialogsSource.contains('_upsertTenantLocally'),
        isTrue,
      );
      expect(
        managementDialogsSource.contains('lastSavedTenant'),
        isTrue,
      );
      expect(
        File(
          'lib/features/tenant_facility/presentation/pages/'
          'tenant_facility_setup_page.dart',
        ).readAsStringSync().contains('widget.tenant?.mutationId'),
        isTrue,
      );
    });
  });
}
