import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/presentation/domain_reporting_catalogs.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_role_tailoring.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_domain_reporting_groups.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/reports_pharmacy_domain_groups.dart';

AppAccessPolicy _policy({
  required List<String> roles,
  required Set<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: roles,
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'reporting-analytics',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('reports owned domain packs', () {
    test('pharmacist owns pharmacy only', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['PHARMACIST'],
        permissions: <AppPermission>{
          AppPermissions.pharmacyRead,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.pharmacy},
      );
      expect(ReportsPharmacyDomainGroups.shouldShow(policy), isTrue);
      expect(ReportsDomainReportingGroups.shouldShow(policy), isFalse);
    });

    test('doctor owns clinical and not pharmacy despite pharmacy:read', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['DOCTOR'],
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.pharmacyRead,
          AppPermissions.labRead,
          AppPermissions.radiologyRead,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.clinical},
      );
      expect(ReportsPharmacyDomainGroups.shouldShow(policy), isFalse);
      expect(ReportsDomainReportingGroups.shouldShow(policy), isTrue);
      expect(
        reportsDomainCatalog(ReportsDomainPack.clinical).any(
          (category) => category.reports.any(
            (report) => report.datasetKey == 'patient_registrations',
          ),
        ),
        isTrue,
      );
    });

    test('billing owns finance catalog with collections dataset', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['BILLING'],
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.finance},
      );
      expect(
        reportsDomainCatalog(ReportsDomainPack.finance).any(
          (category) => category.reports.any(
            (report) =>
                report.datasetKey == 'billing_collections_open_balances',
          ),
        ),
        isTrue,
      );
    });

    test('reception owns reception pack', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['RECEPTIONIST'],
        permissions: <AppPermission>{
          AppPermissions.receptionRead,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.reception},
      );
    });

    test('patient portal does not mount staff domain Reporting chrome', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['PATIENT'],
        permissions: <AppPermission>{
          AppPermissions.profileRead,
          AppPermissions.patientRead,
        },
      );
      // Platform may inject reports:read; still no owned staff packs/chrome.
      expect(reportsDomainPacks(policy), isEmpty);
      expect(ReportsPharmacyDomainGroups.shouldShow(policy), isFalse);
      expect(ReportsDomainReportingGroups.shouldShow(policy), isFalse);
    });

    test('admin overlay owns admin pack', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['TENANT_ADMIN'],
        permissions: <AppPermission>{
          AppPermissions.tenantAdmin,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.admin},
      );
      expect(
        reportsDomainCatalog(ReportsDomainPack.admin).isNotEmpty,
        isTrue,
      );
    });

    test('ambulance owns emergency pack', () {
      final AppAccessPolicy policy = _policy(
        roles: const <String>['AMBULANCE_OPERATOR'],
        permissions: <AppPermission>{
          AppPermissions.emergencyRead,
          AppPermissions.reportsRead,
        },
      );
      expect(
        reportsDomainPacks(policy),
        <ReportsDomainPack>{ReportsDomainPack.emergency},
      );
    });
  });
}
