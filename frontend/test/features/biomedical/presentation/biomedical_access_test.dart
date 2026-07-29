import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/biomedical/domain/entities/biomedical_entities.dart';
import 'package:hosspi_hms/features/biomedical/presentation/biomedical_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: biomedicalEngineeringSuiteModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['BIOMED_ENGINEER'],
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
  group('biomedical access requirements', () {
    test('read requirement needs biomed:read ∩ biomedical-engineering-suite', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(biomedicalWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(biomedicalWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(biomedicalWorkspaceReadRequirement.isAllowed(noModule), isFalse);
      expect(canReadBiomedical(reader), isTrue);
      expect(canReadBiomedical(writerOnly), isFalse);
    });

    test(
      'write requirement keeps source ∪ biomed:write | operations:write '
      '(matrix lists ∩ biomed:write alone)',
      () {
        final AppAccessPolicy reader = _policyFor(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        );
        final AppAccessPolicy biomedWriter = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.biomedWrite,
          },
        );
        final AppAccessPolicy operationsWriter = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.operationsWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: biomedicalEngineeringSuiteModule,
              licenseStatus: 'ACTIVE',
            ),
            // operations:write is plan-gated to facilities-maintenance.
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final AppAccessPolicy operationsWriteWithoutOpsModule = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.operationsWrite,
          },
        );

        expect(biomedicalWorkspaceWriteRequirement.isAllowed(reader), isFalse);
        expect(
          biomedicalWorkspaceWriteRequirement.isAllowed(biomedWriter),
          isTrue,
        );
        expect(
          biomedicalWorkspaceWriteRequirement.isAllowed(operationsWriter),
          isTrue,
        );
        // Subscription ∩: operations:write without facilities-maintenance is
        // stripped even though the write requirement lists it in ∪.
        expect(
          biomedicalWorkspaceWriteRequirement.isAllowed(
            operationsWriteWithoutOpsModule,
          ),
          isFalse,
        );
        expect(canWriteBiomedical(biomedWriter), isTrue);
        expect(canWriteBiomedical(operationsWriter), isTrue);
        expect(canWriteBiomedical(reader), isFalse);
      },
    );

    test(
      'print requires evidence:export ∩ (biomed|operations read|write)',
      () {
        final AppAccessPolicy readerNoExport = _policyFor(
          permissions: <AppPermission>{AppPermissions.biomedRead},
        );
        final AppAccessPolicy exportOnly = _policyFor(
          permissions: <AppPermission>{AppPermissions.evidenceExport},
        );
        final AppAccessPolicy both = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.biomedRead,
            AppPermissions.evidenceExport,
          },
        );

        expect(canPrintBiomedical(readerNoExport), isFalse);
        expect(canPrintBiomedical(exportOnly), isFalse);
        expect(canPrintBiomedical(both), isTrue);
      },
    );

    test('route entry ∪ allows biomed:read or biomed:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedWrite},
      );
      final AppAccessPolicy neither = _policyFor(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );

      expect(biomedicalWorkspaceEntryRequirement.isAllowed(reader), isTrue);
      expect(biomedicalWorkspaceEntryRequirement.isAllowed(writer), isTrue);
      expect(biomedicalWorkspaceEntryRequirement.isAllowed(neither), isFalse);
    });

    test('Overview panel tab shares read requirement', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(
        canViewBiomedicalPanel(reader, BiomedicalPanels.overview),
        isTrue,
      );
      expect(
        identical(
          biomedicalPanelTabRequirement(BiomedicalPanels.overview),
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
    });

    test('Overview atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.tab,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.listChrome,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.detail,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.create,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.update,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.delete,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.write,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.export,
          biomedicalWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.print,
          biomedicalWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.nestedWrite,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.nestedRead,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.entry,
          biomedicalWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalOverviewAtomPermissions.routeEntry,
          biomedicalWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('Compliance panel tab shares read requirement', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.biomedRead},
      );
      expect(
        canViewBiomedicalPanel(reader, BiomedicalPanels.compliance),
        isTrue,
      );
      expect(
        identical(
          biomedicalPanelTabRequirement(BiomedicalPanels.compliance),
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
    });

    test('Compliance atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.tab,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.listChrome,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.detail,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.create,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.update,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.delete,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.write,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.recordCalibration,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.closeDowntime,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.acknowledgeRecall,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.export,
          biomedicalWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.print,
          biomedicalWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.nestedWrite,
          biomedicalWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.nestedRead,
          biomedicalWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.entry,
          biomedicalWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BiomedicalComplianceAtomPermissions.routeEntry,
          biomedicalWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('subscription strip denies read when module missing', () {
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.biomedRead,
          AppPermissions.biomedWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(BiomedicalOverviewAtomPermissions.tab.isAllowed(noModule), isFalse);
      expect(
        BiomedicalOverviewAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
      expect(
        BiomedicalComplianceAtomPermissions.tab.isAllowed(noModule),
        isFalse,
      );
      expect(
        BiomedicalComplianceAtomPermissions.write.isAllowed(noModule),
        isFalse,
      );
    });
  });
}
