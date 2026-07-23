import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';

void main() {
  group('Admin setup HR-only path removal', () {
    late String setupPageSource;
    late String helpersSource;
    late String accessPolicySource;

    setUpAll(() {
      setupPageSource = File(
        'lib/features/tenant_facility/presentation/pages/'
        'tenant_facility_setup_page.dart',
      ).readAsStringSync();
      helpersSource = File(
        'lib/features/tenant_facility/presentation/widgets/'
        'tenant_facility_setup_helpers.dart',
      ).readAsStringSync();
      accessPolicySource = File(
        'lib/core/permissions/access_policy.dart',
      ).readAsStringSync();
    });

    test('setup page does not render HR-only body or Manage modals', () {
      expect(setupPageSource.contains('_HrFacilitySetupBody'), isFalse);
      expect(setupPageSource.contains('_SetupDetailDialog'), isFalse);
      expect(setupPageSource.contains('_openDepartmentsModal'), isFalse);
      expect(setupPageSource.contains('_openUnitsModal'), isFalse);
      expect(setupPageSource.contains('isHrSetupOnly'), isFalse);
      expect(setupPageSource.contains('canManageHrSetup'), isFalse);
      expect(setupPageSource.contains('tenantFacilityHrSetupManageAction'), isFalse);
    });

    test('setup page keeps permission-driven desk sections', () {
      expect(
        setupPageSource.contains('tenantFacilityVisibleSetupDeskSections'),
        isTrue,
      );
      expect(
        setupPageSource.contains('canEditFacilitySetupStructure'),
        isTrue,
      );
      expect(setupPageSource.contains('AppTabStrip'), isTrue);
    });

    test('helpers no longer branch workspace title on HR-only', () {
      expect(helpersSource.contains('isHrSetupOnly'), isFalse);
      expect(helpersSource.contains('tenantFacilityHrSetupTitle'), isFalse);
    });

    test('access policy drops HR-role-only setup helpers', () {
      expect(accessPolicySource.contains('canManageHrFacilitySetup'), isFalse);
      expect(accessPolicySource.contains('isHrFacilitySetupOnlyUser'), isFalse);
      expect(
        accessPolicySource.contains('canEditFacilitySetupStructure'),
        isTrue,
      );
    });
  });

  group('canEditFacilitySetupStructure', () {
    test('facility admin can edit structure', () {
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

      expect(policy.canEditFacilitySetupStructure(), isTrue);
      expect(policy.canManageFacility(), isTrue);
      expect(
        tenantFacilityVisibleSetupDeskSections(
          canManageTenant: policy.canManageTenant(),
          canManageFacility: policy.canManageFacility(),
          canManageAccess: true,
        ),
        contains(TenantFacilitySetupDeskSection.departments),
      );
    });

    test('HR role alone cannot manage facility or see setup desk sections', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['HR'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
        ),
      );

      expect(policy.canManageFacility(), isFalse);
      expect(policy.canManageTenant(), isFalse);
      expect(policy.canEditFacilitySetupStructure(), isFalse);
      expect(
        tenantFacilityVisibleSetupDeskSections(
          canManageTenant: policy.canManageTenant(),
          canManageFacility: policy.canManageFacility(),
          canManageAccess: false,
        ),
        isEmpty,
      );
    });

    test('unitManage without facility admin cannot edit structure', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['TESTING'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
          permissions: <AppPermission>{AppPermissions.unitManage},
        ),
      );

      expect(policy.hasRole(AppRole.hr), isFalse);
      expect(policy.canEditFacilitySetupStructure(), isFalse);
    });
  });
}
