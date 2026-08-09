import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_user_access_panel.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('AppUserAccessPanel', () {
    testWidgets('collapses role permissions until expanded', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
                permissions: <String>['clinical:read', 'clinical:write'],
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[],
            canWrite: true,
            onRemoveRole: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NURSE'), findsOneWidget);
      expect(find.textContaining('2 permissions'), findsWidgets);
      expect(find.byIcon(Icons.expand_more), findsWidgets);
      expect(
        find.textContaining('cannot be removed individually'),
        findsNothing,
      );
      expect(find.text('Remove role'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);

      await tester.tap(find.textContaining('2 permissions').first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsWidgets);
      expect(
        find.textContaining('cannot be removed individually'),
        findsOneWidget,
      );
      expect(find.byType(Chip), findsWidgets);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('allows removing direct permissions only', (tester) async {
      var removedId = '';
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'profile:read'),
            ],
            canWrite: true,
            onRemoveDirectPermission: (AppUserAccessDirectPermission value) {
              removedId = value.id;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove permission'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      expect(
        find.textContaining('Prefer assigning a role'),
        findsNothing,
      );
      await tester.tap(find.text('Remove permission'));
      await tester.pumpAndSettle();
      expect(removedId, 'perm-1');
    });

    testWidgets('shows add actions when writable and prefers roles when empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[],
            directPermissions: const <AppUserAccessDirectPermission>[],
            canWrite: true,
            onAddRole: () {},
            onAddDirectPermission: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add role'), findsOneWidget);
      expect(find.text('Add permission'), findsOneWidget);
      expect(find.text('Remove all roles'), findsNothing);
      expect(find.text('Remove all permissions'), findsNothing);
      expect(find.text('Roles: 0'), findsOneWidget);
      expect(find.text('Direct: 0'), findsOneWidget);
      expect(
        find.textContaining('Prefer assigning a role'),
        findsOneWidget,
      );
      expect(
        find.text('Roles set the baseline permissions for this user.'),
        findsNothing,
      );
      expect(
        find.text('Direct permissions can be removed one at a time.'),
        findsNothing,
      );
      expect(
        find.text('Effective access from roles plus direct grants.'),
        findsNothing,
      );
    });

    testWidgets('places labeled counts and actions in section headers', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'profile:read'),
            ],
            canWrite: true,
            onAddRole: () {},
            onRemoveAllRoles: () {},
            onAddDirectPermission: () {},
            onRemoveAllDirectPermissions: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roles: 1'), findsOneWidget);
      expect(find.text('Direct: 1'), findsOneWidget);
      expect(find.text('Effective: 1'), findsOneWidget);
      expect(find.text('Remove all roles'), findsOneWidget);
      expect(find.text('Add role'), findsOneWidget);
      expect(find.text('Add permission'), findsOneWidget);
    });

    testWidgets('header actions become icon-only on narrow screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[],
            canWrite: true,
            onAddRole: () {},
            onRemoveAllRoles: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Roles: 1'), findsNothing);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Add role'), findsNothing);
      expect(find.text('Remove all roles'), findsNothing);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
      expect(find.byTooltip('Add role'), findsOneWidget);
      expect(find.byTooltip('Remove all roles'), findsOneWidget);
    });

    testWidgets('collapses assigned roles and direct permissions sections', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
                permissions: <String>['clinical:read'],
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'profile:read'),
            ],
            canWrite: true,
            onRemoveRole: (_) {},
            onRemoveAllRoles: () {},
            onRemoveDirectPermission: (_) {},
            onRemoveAllDirectPermissions: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NURSE'), findsOneWidget);
      expect(find.text('Remove permission'), findsOneWidget);

      await tester.tap(find.text('Assigned roles'));
      await tester.pumpAndSettle();
      expect(find.text('NURSE'), findsNothing);

      await tester.tap(find.text('Direct permissions'));
      await tester.pumpAndSettle();
      expect(find.text('Remove permission'), findsNothing);
    });

    testWidgets('exposes remove-all actions when assignments exist', (
      tester,
    ) async {
      var removedAllRoles = false;
      var removedAllPermissions = false;
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'profile:read'),
            ],
            canWrite: true,
            onRemoveAllRoles: () => removedAllRoles = true,
            onRemoveAllDirectPermissions: () => removedAllPermissions = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Remove all roles'), findsOneWidget);
      expect(find.text('Remove all permissions'), findsOneWidget);

      await tester.tap(find.text('Remove all roles'));
      await tester.pumpAndSettle();
      expect(removedAllRoles, isTrue);

      await tester.tap(find.text('Remove all permissions'));
      await tester.pumpAndSettle();
      expect(removedAllPermissions, isTrue);
    });

    testWidgets('shows grouped effective permissions from roles and directs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
                permissions: <String>['clinical:read', 'patient:read'],
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'billing:read'),
            ],
            canWrite: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Effective permissions'), findsOneWidget);
      expect(find.textContaining('3'), findsWidgets);
      expect(find.textContaining('cannot be removed individually'), findsNothing);
      // Module group cards from AppPermissionGroupedView.
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
    });

    testWidgets('prefers authoritative effectivePermissions when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
                permissions: <String>['clinical:read'],
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[],
            effectivePermissions: const <String>[
              'lab:read',
              'lab:write',
              'pharmacy:read',
            ],
            canWrite: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Effective permissions'), findsOneWidget);
      expect(
        find.textContaining('No permissions are currently effective'),
        findsNothing,
      );
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
    });

    testWidgets('hides write actions when read-only', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppUserAccessPanel(
            roleGroups: const <AppUserAccessRoleGroup>[
              AppUserAccessRoleGroup(
                roleId: 'role-nurse',
                roleName: 'NURSE',
                userRoleId: 'ur-1',
                permissions: <String>['clinical:read'],
              ),
            ],
            directPermissions: const <AppUserAccessDirectPermission>[
              AppUserAccessDirectPermission(id: 'perm-1', name: 'profile:read'),
            ],
            canWrite: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add role'), findsNothing);
      expect(find.text('Add permission'), findsNothing);
      expect(find.text('Remove role'), findsNothing);
      expect(find.text('Remove permission'), findsNothing);
      expect(find.text('Remove all roles'), findsNothing);
      expect(find.text('Remove all permissions'), findsNothing);
    });
  });
}
