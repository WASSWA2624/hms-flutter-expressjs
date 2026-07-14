import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_user_access_panel.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('AppUserAccessPanel', () {
    testWidgets('groups role permissions without delete affordance', (
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
      expect(find.textContaining('2 permissions'), findsOneWidget);
      expect(
        find.textContaining('cannot be removed individually'),
        findsOneWidget,
      );
      expect(find.text('Remove role'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
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
      await tester.tap(find.text('Remove permission'));
      await tester.pumpAndSettle();
      expect(removedId, 'perm-1');
    });

    testWidgets('shows add actions when writable', (tester) async {
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
    });
  });
}
