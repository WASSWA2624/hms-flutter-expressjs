import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/housekeeping_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<String> roles = const <String>['VIEWER'],
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: housekeepingFacilitiesModule,
      licenseStatus: 'ACTIVE',
    ),
  ],
  String? facilityId = 'facility-1',
  String? tenantId = 'tenant-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('housekeeping access requirements', () {
    test('read ∩ needs operations:read and facilities-maintenance', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(housekeepingWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(
        housekeepingWorkspaceReadRequirement.isAllowed(writerOnly),
        isFalse,
      );
      expect(housekeepingWorkspaceReadRequirement.isAllowed(noModule), isFalse);
      expect(canReadHousekeeping(reader), isTrue);
      expect(canReadHousekeeping(writerOnly), isFalse);
    });

    test(
      'write ∩ needs operations:write (source canManage role OR maps via '
      'role packs that include operations:write)',
      () {
        final AppAccessPolicy reader = _policyFor(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        );
        final AppAccessPolicy writer = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
        );
        final AppAccessPolicy managerPack = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.operationsRead,
            AppPermissions.operationsWrite,
          },
          roles: const <String>['HOUSEKEEPING_MANAGER'],
        );

        expect(housekeepingWorkspaceWriteRequirement.isAllowed(reader), isFalse);
        expect(housekeepingWorkspaceWriteRequirement.isAllowed(writer), isTrue);
        expect(
          housekeepingWorkspaceWriteRequirement.isAllowed(managerPack),
          isTrue,
        );
        expect(canWriteHousekeeping(writer), isTrue);
        expect(canWriteHousekeeping(reader), isFalse);
      },
    );

    test('route entry ∪ allows operations:read or operations:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );
      final AppAccessPolicy neither = _policyFor(
        permissions: <AppPermission>{AppPermissions.reportsRead},
      );
      final AppAccessPolicy noFacility = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsRead},
        facilityId: null,
      );

      expect(housekeepingWorkspaceEntryRequirement.isAllowed(reader), isTrue);
      expect(
        housekeepingWorkspaceEntryRequirement.isAllowed(writerOnly),
        isTrue,
      );
      expect(housekeepingWorkspaceEntryRequirement.isAllowed(neither), isFalse);
      expect(
        housekeepingWorkspaceEntryRequirement.isAllowed(noFacility),
        isFalse,
      );
      expect(canEnterHousekeepingWorkspace(reader), isTrue);
      expect(canEnterHousekeepingWorkspace(writerOnly), isTrue);
    });

    test(
      'report ∪ allows reports:read or operations:read (source inventory)',
      () {
        final AppAccessPolicy opsReader = _policyFor(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        );
        final AppAccessPolicy reportsOnly = _policyFor(
          permissions: <AppPermission>{AppPermissions.reportsRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: housekeepingFacilitiesModule,
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'reporting-analytics',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final AppAccessPolicy neither = _policyFor(
          permissions: <AppPermission>{AppPermissions.operationsWrite},
        );

        expect(housekeepingReportRequirement.isAllowed(opsReader), isTrue);
        expect(housekeepingReportRequirement.isAllowed(reportsOnly), isTrue);
        expect(housekeepingReportRequirement.isAllowed(neither), isFalse);
      },
    );

    test(
      'canUpdateHousekeepingTasks allows housekeeper role without write '
      '(source canUpdateTasks; schedules create still needs write ∩)',
      () {
        final AppAccessPolicy housekeeper = _policyFor(
          permissions: <AppPermission>{AppPermissions.operationsRead},
          roles: const <String>['HOUSE_KEEPER'],
        );
        final AppAccessPolicy reader = _policyFor(
          permissions: <AppPermission>{AppPermissions.operationsRead},
        );

        expect(canUpdateHousekeepingTasks(housekeeper), isTrue);
        expect(canWriteHousekeeping(housekeeper), isFalse);
        expect(canUpdateHousekeepingTasks(reader), isFalse);
      },
    );

    test('Schedules atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          HousekeepingSchedulesAtomPermissions.tab,
          housekeepingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingSchedulesAtomPermissions.createSchedule,
          housekeepingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingSchedulesAtomPermissions.routeEntry,
          housekeepingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingSchedulesAtomPermissions.report,
          housekeepingReportRequirement,
        ),
        isTrue,
      );
    });

    test('Tasks atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          HousekeepingTasksAtomPermissions.tab,
          housekeepingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingTasksAtomPermissions.createTask,
          housekeepingWorkspaceManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingTasksAtomPermissions.assign,
          housekeepingManageRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingTasksAtomPermissions.report,
          housekeepingReportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          HousekeepingTasksAtomPermissions.routeEntry,
          housekeepingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('all sections share read ∩; allowed list collapses without it', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.operationsWrite},
      );

      expect(housekeepingAllowedSections(reader), HousekeepingSection.values);
      expect(housekeepingAllowedSections(writerOnly), isEmpty);
      expect(
        housekeepingFallbackSection(reader),
        HousekeepingSection.tasks,
      );
      expect(housekeepingFallbackSection(writerOnly), isNull);
      expect(
        canViewHousekeepingSection(reader, HousekeepingSection.schedules),
        isTrue,
      );
      expect(
        canViewHousekeepingSection(writerOnly, HousekeepingSection.schedules),
        isFalse,
      );
    });

    test('HousekeepingCapabilities.fromPolicy maps matrix + source flags', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.operationsRead,
          AppPermissions.operationsWrite,
          AppPermissions.reportsRead,
        },
      );
      final HousekeepingCapabilities caps =
          HousekeepingCapabilities.fromPolicy(writer);

      expect(caps.canRead, isTrue);
      expect(caps.canManage, isTrue);
      expect(caps.canUpdateTasks, isTrue);
      expect(caps.canReport, isTrue);
    });
  });
}
