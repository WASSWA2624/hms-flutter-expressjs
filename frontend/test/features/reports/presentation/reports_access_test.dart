import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';

const List<AppModuleEntitlement> _reportsModule = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
];

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = _reportsModule,
  List<String> roles = const <String>['REPORTING'],
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
      moduleEntitlements: modules,
    ),
  );
}

void main() {
  group('reports access requirements', () {
    test('workspace read is union of reports:read and compliance:read', () {
      final AppAccessPolicy reportsOnly = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy complianceOnly = _policy(
        permissions: <AppPermission>{AppPermissions.complianceRead},
      );
      final AppAccessPolicy neither = _policy(
        permissions: <AppPermission>{AppPermissions.evidenceExport},
      );

      expect(reportsWorkspaceReadRequirement.isAllowed(reportsOnly), isTrue);
      expect(reportsWorkspaceReadRequirement.isAllowed(complianceOnly), isTrue);
      expect(reportsWorkspaceReadRequirement.isAllowed(neither), isFalse);
      expect(canReadReportsWorkspace(reportsOnly), isTrue);
      expect(canReadReportsWorkspace(complianceOnly), isTrue);
    });

    test('write requirement needs reports:write intersection (∩ denial)', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      );

      expect(reportsWriteRequirement.isAllowed(reader), isFalse);
      expect(canWriteReports(reader), isFalse);
      expect(reportsWriteRequirement.isAllowed(writer), isTrue);
      expect(canWriteReports(writer), isTrue);
    });

    test('delete requirement needs reports:delete intersection', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      );
      final AppAccessPolicy deleter = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsDelete,
        },
      );

      expect(reportsDeleteRequirement.isAllowed(writer), isFalse);
      expect(canDeleteReports(writer), isFalse);
      expect(reportsDeleteRequirement.isAllowed(deleter), isTrue);
      expect(canDeleteReports(deleter), isTrue);
    });

    test('export uses evidence:export (source inventory), not reports:write', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
      );
      final AppAccessPolicy exporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.evidenceExport,
        },
      );

      // Matrix prose mentions reports:write for exports; inventory + backend
      // download authorize evidence:export — keep source mapping.
      expect(reportsExportRequirement.isAllowed(writer), isFalse);
      expect(canExportEvidence(writer), isFalse);
      expect(reportsExportRequirement.isAllowed(exporter), isTrue);
      expect(canExportEvidence(exporter), isTrue);
    });

    test('compliance panels need compliance:read or review', () {
      final AppAccessPolicy catalogOnly = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy complianceReader = _policy(
        permissions: <AppPermission>{AppPermissions.complianceRead},
      );
      final AppAccessPolicy reviewer = _policy(
        permissions: <AppPermission>{AppPermissions.complianceReview},
      );

      expect(canReadReportsCompliance(catalogOnly), isFalse);
      expect(canReadReportsCompliance(complianceReader), isTrue);
      expect(canReadReportsCompliance(reviewer), isTrue);
      expect(
        canAccessReportsPanel(catalogOnly, ReportsWorkspacePanel.audit),
        isFalse,
      );
      expect(
        canAccessReportsPanel(complianceReader, ReportsWorkspacePanel.audit),
        isTrue,
      );
      expect(
        canAccessReportsPanel(catalogOnly, ReportsWorkspacePanel.catalog),
        isTrue,
      );
    });

    test('reports read/write work without reporting-analytics entitlement', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.reportsWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      // Reporting is platform infrastructure — not package-gated.
      expect(reportsWriteRequirement.isAllowed(noModule), isTrue);
      expect(canWriteReports(noModule), isTrue);
      expect(canReadReportsCatalog(noModule), isTrue);
    });

    test('allowed panels union catalog and compliance grants', () {
      final AppAccessPolicy both = _policy(
        permissions: <AppPermission>{
          AppPermissions.reportsRead,
          AppPermissions.complianceRead,
        },
      );
      final AppAccessPolicy catalogOnly = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy complianceOnly = _policy(
        permissions: <AppPermission>{AppPermissions.complianceRead},
      );

      expect(
        reportsAllowedPanels(both),
        containsAll(ReportsWorkspacePanel.values),
      );
      expect(
        reportsAllowedPanels(catalogOnly).any(
          (ReportsWorkspacePanel panel) => panel.isCompliance,
        ),
        isFalse,
      );
      expect(
        reportsAllowedPanels(complianceOnly).every(
          (ReportsWorkspacePanel panel) => panel.isCompliance,
        ),
        isTrue,
      );
      expect(
        reportsFallbackPanel(complianceOnly),
        ReportsWorkspacePanel.audit,
      );
    });

    test('route integration accepts reports or compliance read', () {
      final AppAccessPolicy reportsOnly = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy complianceOnly = _policy(
        permissions: <AppPermission>{AppPermissions.complianceRead},
      );

      expect(canAccessShellRoute(AppRoutes.reports, reportsOnly), isTrue);
      expect(canAccessShellRoute(AppRoutes.reports, complianceOnly), isTrue);
    });

    test('admin overlay matches screens/reports.md write and export gates', () {
      final AppAccessPolicy tenantAdmin = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
        roles: const <String>['TENANT_ADMIN'],
      );

      expect(canWriteReports(tenantAdmin), isTrue);
      expect(canExportEvidence(tenantAdmin), isTrue);
      expect(canDeleteReports(tenantAdmin), isTrue);
      expect(canReadReportsCatalog(tenantAdmin), isTrue);
      expect(canReadReportsCompliance(tenantAdmin), isTrue);
    });

    test('reports route opens without reporting-analytics entitlement', () {
      final AppAccessPolicy policy = _policy(
        permissions: <AppPermission>{AppPermissions.reportsRead},
        modules: const <AppModuleEntitlement>[],
        roles: const <String>['PATIENT'],
      );

      expect(canReadReportsWorkspace(policy), isTrue);
      expect(canAccessShellRoute(AppRoutes.reports, policy), isTrue);
      expect(AppRoutes.reports.accessRequirement.isAllowed(policy), isTrue);
    });

    test('patient and other roles can open reports with reports:read', () {
      for (final String role in <String>['PATIENT', 'OTHER', 'VISITOR_GUEST']) {
        final AppAccessPolicy policy = _policy(
          permissions: <AppPermission>{AppPermissions.reportsRead},
          modules: const <AppModuleEntitlement>[],
          roles: <String>[role],
        );
        expect(canAccessShellRoute(AppRoutes.reports, policy), isTrue);
      }
    });
  });
}
