import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/communications/domain/entities/communications_entities.dart';
import 'package:hosspi_hms/features/communications/presentation/communications_access.dart';

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(
      code: 'notifications-communications',
      licenseStatus: 'ACTIVE',
    ),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
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
  group('communications access requirements', () {
    test('read requirement needs communications:read ∩ module', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      final AppAccessPolicy writerOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(communicationsWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(
        communicationsWorkspaceReadRequirement.isAllowed(writerOnly),
        isFalse,
      );
      expect(communicationsWorkspaceReadRequirement.isAllowed(noModule), isFalse);
      expect(canReadCommunications(reader), isTrue);
      expect(canReadCommunications(writerOnly), isFalse);
    });

    test('write requirement needs communications:write ∩ module', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
        },
      );

      expect(communicationsWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(communicationsWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(canWriteCommunications(writer), isTrue);
      expect(canWriteCommunications(reader), isFalse);
    });

    test(
      'delete requirement needs communications:delete ∩ (intersection denial)',
      () {
        final AppAccessPolicy writer = _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsWrite,
          },
        );
        final AppAccessPolicy deleter = _policy(
          permissions: <AppPermission>{
            AppPermissions.communicationsRead,
            AppPermissions.communicationsDelete,
          },
        );

        expect(
          communicationsWorkspaceDeleteRequirement.isAllowed(writer),
          isFalse,
        );
        expect(
          communicationsWorkspaceDeleteRequirement.isAllowed(deleter),
          isTrue,
        );
        expect(canDeleteCommunications(deleter), isTrue);
        expect(canDeleteCommunications(writer), isFalse);
      },
    );

    test(
      'route entry ∪ allows communications:write alone without communications:read',
      () {
        final AppAccessPolicy writeOnly = _policy(
          permissions: <AppPermission>{AppPermissions.communicationsWrite},
        );
        final AppAccessPolicy readOnly = _policy(
          permissions: <AppPermission>{AppPermissions.communicationsRead},
        );

        expect(
          communicationsWorkspaceEntryRequirement.isAllowed(writeOnly),
          isTrue,
        );
        expect(
          communicationsWorkspaceEntryRequirement.isAllowed(readOnly),
          isTrue,
        );
        expect(canEnterCommunications(writeOnly), isTrue);
        expect(
          CommunicationsMessagesAtomPermissions.tab.isAllowed(writeOnly),
          isFalse,
        );
      },
    );

    test('subscription strip: missing module denies all communications gates', () {
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
        modules: const <AppModuleEntitlement>[],
      );

      expect(canReadCommunications(noModule), isFalse);
      expect(canWriteCommunications(noModule), isFalse);
      expect(canDeleteCommunications(noModule), isFalse);
      expect(canEnterCommunications(noModule), isFalse);
    });

    test('plan BASIC strips communications:delete even when role grants it', () {
      final AppAccessPolicy basicWithDeleteGrant = _policy(
        permissions: <AppPermission>{
          AppPermissions.communicationsRead,
          AppPermissions.communicationsWrite,
          AppPermissions.communicationsDelete,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'notifications-communications',
            licenseStatus: 'ACTIVE',
            planTierCode: 'BASIC',
          ),
        ],
      );

      expect(canReadCommunications(basicWithDeleteGrant), isTrue);
      expect(canWriteCommunications(basicWithDeleteGrant), isTrue);
      expect(canDeleteCommunications(basicWithDeleteGrant), isFalse);
    });

    test('Messages atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.newMessage,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.delete,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      // Nested cross-module matrix rows are _(n/a)_ — nested gates stay in-module.
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.nestedRead,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsMessagesAtomPermissions.nestedWrite,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    });

    test('Notifications atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.tab,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.markRead,
          communicationsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.archive,
          communicationsWorkspaceDeleteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.routeEntry,
          communicationsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          CommunicationsNotificationsAtomPermissions.nestedRead,
          communicationsWorkspaceReadRequirement,
        ),
        isTrue,
      );
    });

    test('allowed panels collapse when read is missing', () {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsWrite},
      );
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.communicationsRead},
      );

      expect(communicationsAllowedPanels(writeOnly), isEmpty);
      expect(communicationsFallbackPanel(writeOnly), isNull);
      expect(
        communicationsAllowedPanels(reader),
        CommunicationsPanel.values,
      );
      expect(
        canViewCommunicationsPanel(reader, CommunicationsPanel.inbox),
        isTrue,
      );
    });
  });
}
