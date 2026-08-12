import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
  ],
  List<String> roles = const <String>['LAB_TECH'],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        roles: roles,
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
  group('lab access requirements', () {
    test('read ∩ needs lab:read and lab-workflows', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.labRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.labWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.labRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(labWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(labWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(labWorkspaceReadRequirement.isAllowed(noModule), isFalse);
      expect(canReadLab(reader), isTrue);
      expect(canReadLab(writerOnly), isFalse);
    });

    test('write ∩ needs lab:write and lab-workflows (matrix all-of)', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.labRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.labWrite,
        },
      );
      final AppAccessPolicy writeWithoutModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.labWrite},
        modules: const <AppModuleEntitlement>[],
      );

      expect(labWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(labWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(labWorkspaceWriteRequirement.isAllowed(writeWithoutModule), isFalse);
      expect(canWriteLab(writer), isTrue);
      expect(canWriteLab(reader), isFalse);
      expect(canConfigureLab(reader), isFalse);
      expect(canConfigureLab(writer), isTrue);
    });

    test('export/print ∩ needs evidence:export', () {
      final AppAccessPolicy withoutExport = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.labWrite,
        },
      );
      final AppAccessPolicy withExport = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.evidenceExport,
        },
      );

      expect(canExportLabWorkspace(withoutExport), isFalse);
      expect(canPrintLabWorkspace(withoutExport), isFalse);
      expect(canExportLabWorkspace(withExport), isTrue);
      expect(canPrintLabWorkspace(withExport), isTrue);
      expect(
        identical(
          labWorkspacePrintRequirement,
          labWorkspaceExportRequirement,
        ),
        isTrue,
      );
    });

    test('create patient via lab ∩ needs patient:write', () {
      final AppAccessPolicy withoutWrite = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.labWrite,
          AppPermissions.patientRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: labWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      final AppAccessPolicy withWrite = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.labWrite,
          AppPermissions.patientWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: labWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(canCreatePatientViaLab(withoutWrite), isFalse);
      expect(canCreatePatientViaLab(withWrite), isTrue);
      expect(
        LabAllAtomPermissions.createPatient.isAllowed(withWrite),
        isTrue,
      );
      expect(
        LabAllAtomPermissions.createPatient.isAllowed(withoutWrite),
        isFalse,
      );
    });

    test(
      'route entry ∪ allows lab:read | clinical:read | clinical:write '
      '(matrix view ∩ remains lab:read)',
      () {
        final AppAccessPolicy labReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.labRead},
        );
        final AppAccessPolicy clinicalReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['DOCTOR'],
        );
        final AppAccessPolicy clinicalWriter = _policyFor(
          permissions: <AppPermission>{AppPermissions.clinicalWrite},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
          roles: const <String>['DOCTOR'],
        );
        final AppAccessPolicy neither = _policyFor(
          permissions: <AppPermission>{AppPermissions.patientRead},
        );

        expect(labWorkspaceRouteEntryRequirement.isAllowed(labReader), isTrue);
        expect(
          labWorkspaceRouteEntryRequirement.isAllowed(clinicalReader),
          isTrue,
        );
        expect(
          labWorkspaceRouteEntryRequirement.isAllowed(clinicalWriter),
          isTrue,
        );
        expect(labWorkspaceRouteEntryRequirement.isAllowed(neither), isFalse);
        expect(canEnterLabWorkspace(clinicalReader), isTrue);
        expect(canReadLab(clinicalReader), isFalse);
        expect(canWriteLab(clinicalReader), isFalse);
      },
    );

    test('catalog entry stays ∩ lab:read (RouteAccessCatalog)', () {
      expect(
        identical(
          labWorkspaceCatalogEntryRequirement,
          RouteAccessCatalog.labEntry,
        ),
        isTrue,
      );
    });

    test(
      'critical notify ∩ denial when clinical:read missing '
      '(lab:write alone insufficient)',
      () {
        final AppAccessPolicy labWriterOnly = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        );
        final AppAccessPolicy withClinicalRead = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
            AppPermissions.clinicalRead,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: labWorkflowsModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        expect(canNotifyLabCritical(labWriterOnly), isFalse);
        expect(canNotifyLabCritical(withClinicalRead), isTrue);
      },
    );

    test('request-from-clinical reuses clinicalLabOrderWriteRequirement ∪', () {
      expect(
        identical(
          labRequestFromClinicalWriteRequirement,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      final AppAccessPolicy clinicalWriter = _policyFor(
        permissions: <AppPermission>{AppPermissions.clinicalWrite},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
        roles: const <String>['DOCTOR'],
      );
      expect(canRequestLabFromClinical(clinicalWriter), isTrue);
      expect(canWriteLab(clinicalWriter), isFalse);
    });

    test('subscription strips write without lab-workflows module', () {
      final AppAccessPolicy writerNoModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.labRead,
          AppPermissions.labWrite,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(canWriteLab(writerNoModule), isFalse);
      expect(canReadLab(writerNoModule), isFalse);
      expect(canEnterLabWorkspace(writerNoModule), isFalse);
    });

    test('All atom map reuses feature *Requirement helpers', () {
      expect(
        identical(LabAllAtomPermissions.tab, labWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(LabAllAtomPermissions.create, labWorkspaceWriteRequirement),
        isTrue,
      );
      expect(
        identical(
          LabAllAtomPermissions.createPatient,
          labCreatePatientRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAllAtomPermissions.configure,
          labConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAllAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAllAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAllAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(LabAllAtomPermissions.previewReport, labReportPreviewRequirement),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.worklist),
          LabAllAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.worklist),
          LabAllAtomPermissions.create,
        ),
        isTrue,
      );
    });

    test('Awaiting results atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.tab,
          labWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.configure,
          labConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabAwaitingResultsAtomPermissions.workflowMutate,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.collection),
          LabAwaitingResultsAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.collection),
          LabAwaitingResultsAtomPermissions.create,
        ),
        isTrue,
      );
    });

    test('Critical atom map reuses feature *Requirement helpers', () {
      expect(
        identical(LabCriticalAtomPermissions.tab, labWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.configure,
          labConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.criticalNotify,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.acknowledge,
          labCriticalNotifyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabCriticalAtomPermissions.workflowMutate,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.critical),
          LabCriticalAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.critical),
          LabCriticalAtomPermissions.create,
        ),
        isTrue,
      );
    });

    test('Verified atom map reuses feature *Requirement helpers', () {
      expect(
        identical(LabVerifiedAtomPermissions.tab, labWorkspaceReadRequirement),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.create,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.configure,
          labConfigurationsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.previewReport,
          labReportPreviewRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.editVerifiedResult,
          labWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.routeEntry,
          labWorkspaceRouteEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          LabVerifiedAtomPermissions.requestFromClinical,
          clinicalLabOrderWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          labSectionTabRequirement(LabDeskSection.completed),
          LabVerifiedAtomPermissions.tab,
        ),
        isTrue,
      );
      expect(
        identical(
          labStripCreateRequirement(LabDeskSection.completed),
          LabVerifiedAtomPermissions.create,
        ),
        isTrue,
      );
    });

    test('All tab present for lab:read; clinical-only keeps worklist sections', () {
      final AppAccessPolicy labReader = _policyFor(
        permissions: <AppPermission>{AppPermissions.labRead},
      );
      final AppAccessPolicy clinicalReader = _policyFor(
        permissions: <AppPermission>{AppPermissions.clinicalRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: labWorkflowsModule,
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
        roles: const <String>['DOCTOR'],
      );

      expect(canViewLabAllTab(labReader), isTrue);
      expect(canViewLabAwaitingResultsTab(labReader), isTrue);
      expect(canViewLabCriticalTab(labReader), isTrue);
      expect(canViewLabVerifiedTab(labReader), isTrue);
      expect(canViewLabAllTab(clinicalReader), isFalse);
      expect(canViewLabAwaitingResultsTab(clinicalReader), isFalse);
      expect(canViewLabCriticalTab(clinicalReader), isFalse);
      expect(canViewLabVerifiedTab(clinicalReader), isFalse);
      expect(
        labAllowedSections(labReader),
        <LabDeskSection>[
          LabDeskSection.collection,
          LabDeskSection.critical,
          LabDeskSection.completed,
          LabDeskSection.followUps,
          LabDeskSection.worklist,
        ],
      );
      expect(
        labAllowedSections(clinicalReader),
        contains(LabDeskSection.worklist),
      );
      expect(
        labAllowedSections(clinicalReader),
        contains(LabDeskSection.collection),
      );
      expect(
        labAllowedSections(clinicalReader),
        contains(LabDeskSection.critical),
      );
      expect(
        labAllowedSections(clinicalReader),
        contains(LabDeskSection.completed),
      );
      expect(
        labAllowedSections(clinicalReader),
        isNot(contains(LabDeskSection.followUps)),
      );
      expect(labFallbackSection(labReader), LabDeskSection.collection);
      expect(
        labAllowedSections(labReader).last,
        LabDeskSection.worklist,
      );
    });
  });
}
