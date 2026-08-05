import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_access.dart';
import 'package:hosspi_hms/features/reports/presentation/pages/reports_workspace_page.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: pharmacyDispensingModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['PHARMACIST'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('pharmacy reports deep link access', () {
    test('requires pharmacy read (reports is platform infrastructure)', () {
      final AppAccessPolicy denied = _policyFor(
        permissions: <AppPermission>{AppPermissions.reportsRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(canOpenPharmacyReportsAnalytics(denied), isFalse);

      final AppAccessPolicy allowed = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: pharmacyDispensingModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(canOpenPharmacyReportsAnalytics(allowed), isTrue);
    });
  });

  group('ReportsWorkspacePageQuery', () {
    test('parses dataset query from uri', () {
      final ReportsWorkspacePageQuery query = ReportsWorkspacePageQuery.fromUri(
        Uri.parse('/reports?dataset=pharmacy_drug_consumption'),
      );
      expect(query.dataset, 'pharmacy_drug_consumption');
    });

    test('returns null dataset when absent', () {
      final ReportsWorkspacePageQuery query = ReportsWorkspacePageQuery.fromUri(
        Uri.parse('/reports'),
      );
      expect(query.dataset, isNull);
    });
  });
}
