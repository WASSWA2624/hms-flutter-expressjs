import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/plan_permission_caps.dart';
import 'package:hosspi_hms/core/permissions/version_disabled_permissions.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

void main() {
  group('VersionDisabledPermissions', () {
    tearDown(() {
      // flutter_test_config disables enforce for feature suites; restore here
      // after unit assertions that toggle it.
      VersionDisabledPermissions.enforce = false;
    });

    test('lists deferred shell domains', () {
      expect(
        VersionDisabledPermissions.domains,
        containsAll(<String>[
          'emergency',
          'rooms_beds',
          'physiotherapy',
          'operations',
          'housekeeping',
          'biomed',
          'mortuary',
          'communications',
          'integration',
        ]),
      );
    });

    test('omits deferred domains from every plan permission cap', () {
      VersionDisabledPermissions.enforce = true;
      for (final Set<String> names in PlanPermissionCaps.byTier.values) {
        for (final String name in names) {
          expect(
            VersionDisabledPermissions.isDisabled(name),
            isFalse,
            reason: '$name must not appear in plan caps',
          );
        }
      }
    });

    test('strips deferred grants from AppAccessPolicy for all actors', () {
      VersionDisabledPermissions.enforce = true;
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            roles: <String>['TENANT_ADMIN'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.emergencyRead,
            AppPermissions.roomsBedsRead,
            AppPermissions.physiotherapyRead,
            AppPermissions.operationsRead,
            AppPermissions.housekeepingRead,
            AppPermissions.biomedRead,
            AppPermissions.mortuaryRead,
            AppPermissions.communicationsRead,
            AppPermissions.integrationRead,
            AppPermissions.theaterRead,
          },
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(
              code: 'inpatient-bed-management',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(code: 'physiotherapy', planTierCode: 'PRO'),
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(
              code: 'biomedical-engineering-suite',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(code: 'mortuary', planTierCode: 'PRO'),
            AppModuleEntitlement(
              code: 'notifications-communications',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(
              code: 'integrations-core',
              planTierCode: 'PRO',
            ),
            AppModuleEntitlement(
              code: 'theatre-anesthesia',
              planTierCode: 'PRO',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(policy.grants(AppPermissions.clinicalRead), isTrue);
      expect(policy.grants(AppPermissions.theaterRead), isTrue);
      expect(policy.grants(AppPermissions.emergencyRead), isFalse);
      expect(policy.grants(AppPermissions.roomsBedsRead), isFalse);
      expect(policy.grants(AppPermissions.physiotherapyRead), isFalse);
      expect(policy.grants(AppPermissions.operationsRead), isFalse);
      expect(policy.grants(AppPermissions.housekeepingRead), isFalse);
      expect(policy.grants(AppPermissions.biomedRead), isFalse);
      expect(policy.grants(AppPermissions.mortuaryRead), isFalse);
      expect(policy.grants(AppPermissions.communicationsRead), isFalse);
      expect(policy.grants(AppPermissions.integrationRead), isFalse);
    });
  });
}
