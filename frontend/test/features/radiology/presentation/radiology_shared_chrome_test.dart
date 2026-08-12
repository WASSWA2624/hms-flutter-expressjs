import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/radiology/presentation/radiology_access.dart';
import 'package:hosspi_hms/features/radiology/presentation/widgets/radiology_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: radiologyWorkflowsModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['RADIOLOGIST'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

RadiologyWorkspaceState _state({
  RadiologyWorkspaceQuery query = const RadiologyWorkspaceQuery(),
  int actionablePatients = 10,
  int reportingPatients = 4,
  int releasedPatients = 7,
  int totalItemCount = 99,
}) {
  return RadiologyWorkspaceState(
    orders: AppPage<RadiologyOrder>(
      items: const <RadiologyOrder>[],
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: totalItemCount,
    ),
    summary: RadiologySummary(
      actionablePatients: actionablePatients,
      reportingPatients: reportingPatients,
      releasedPatients: releasedPatients,
      actionableOrders: actionablePatients,
      reportingOrders: reportingPatients,
      historyOrders: releasedPatients,
    ),
    references: const RadiologyReferenceData(),
    query: query,
  );
}

void main() {
  group('radiology shared chrome access', () {
    test('export/print desk gate requires evidence:export', () {
      final AppAccessPolicy withoutExport = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
        },
      );
      final AppAccessPolicy withExport = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.radiologyRead,
          AppPermissions.radiologyWrite,
          AppPermissions.evidenceExport,
        },
      );

      expect(canExportRadiologyWorkspace(withoutExport), isFalse);
      expect(canPrintRadiologyWorkspace(withoutExport), isFalse);
      expect(canExportRadiologyWorkspace(withExport), isTrue);
      expect(canPrintRadiologyWorkspace(withExport), isTrue);
    });

    test('unauthorized sections are omitted from allowed list', () {
      final AppAccessPolicy noRadiology = _policyFor(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: radiologyWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      final List<RadiologyDeskSection> allowed = radiologyAllowedSections(
        noRadiology,
      );
      expect(allowed, isNotEmpty);
      expect(allowed.contains(RadiologyDeskSection.followUps), isFalse);
    });
  });

  group('radiologySectionTabCount', () {
    test('siblings use dedicated unfiltered summary totals', () {
      final RadiologyWorkspaceState state = _state();
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.worklist,
          activeSection: RadiologyDeskSection.reporting,
        ),
        10,
      );
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.reporting,
          activeSection: RadiologyDeskSection.worklist,
        ),
        4,
      );
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.allOrders,
          activeSection: RadiologyDeskSection.worklist,
        ),
        7,
      );
    });

    test('active unfiltered tab prefers summary scope total', () {
      final RadiologyWorkspaceState state = _state(totalItemCount: 99);
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.worklist,
          activeSection: RadiologyDeskSection.worklist,
        ),
        10,
      );
    });

    test('active narrowed tab uses filtered orders.totalItemCount', () {
      final RadiologyWorkspaceState state = _state(
        query: const RadiologyWorkspaceQuery(search: 'chest'),
        totalItemCount: 3,
      );
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.worklist,
          activeSection: RadiologyDeskSection.worklist,
        ),
        3,
      );
      expect(
        radiologySectionTabCount(
          state,
          RadiologyDeskSection.reporting,
          activeSection: RadiologyDeskSection.worklist,
        ),
        4,
      );
    });
  });

  group('radiologySectionCountTone', () {
    test('attention queues warning; others info', () {
      expect(
        radiologySectionCountTone(RadiologyDeskSection.worklist),
        AppTabCountTone.warning,
      );
      expect(
        radiologySectionCountTone(RadiologyDeskSection.reporting),
        AppTabCountTone.warning,
      );
      expect(
        radiologySectionCountTone(RadiologyDeskSection.allOrders),
        AppTabCountTone.info,
      );
      expect(
        radiologySectionCountTone(RadiologyDeskSection.followUps),
        AppTabCountTone.info,
      );
    });
  });
}
