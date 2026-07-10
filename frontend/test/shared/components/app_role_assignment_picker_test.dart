import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_role_assignment_picker.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('AppRoleAssignmentPicker', () {
    testWidgets('lists roles with checkboxes and permission counts', (
      tester,
    ) async {
      final Set<String> selected = <String>{};

      await tester.pumpWidget(
        _wrap(
          AppRoleAssignmentPicker(
            roles: const <AppRoleAssignmentOption>[
              AppRoleAssignmentOption(
                id: 'role-nurse',
                label: 'NURSE',
                permissionCount: 4,
              ),
              AppRoleAssignmentOption(
                id: 'role-doctor',
                label: 'DOCTOR',
                permissionCount: 8,
              ),
            ],
            selectedRoleIds: selected,
            onSelectionChanged: (Set<String> next) {
              selected
                ..clear()
                ..addAll(next);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NURSE'), findsOneWidget);
      expect(find.text('DOCTOR'), findsOneWidget);
      expect(find.textContaining('4 permissions'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('toggles role selection via checkbox', (tester) async {
      final Set<String> selected = <String>{};

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppRoleAssignmentPicker(
                roles: const <AppRoleAssignmentOption>[
                  AppRoleAssignmentOption(
                    id: 'role-nurse',
                    label: 'NURSE',
                    permissionCount: 2,
                  ),
                ],
                selectedRoleIds: selected,
                onSelectionChanged: (Set<String> next) {
                  setState(() {
                    selected
                      ..clear()
                      ..addAll(next);
                  });
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(selected, <String>{'role-nurse'});
    });

    testWidgets('loads permissions when a role card is expanded', (
      tester,
    ) async {
      var loadedRoleId = '';

      await tester.pumpWidget(
        _wrap(
          AppRoleAssignmentPicker(
            roles: const <AppRoleAssignmentOption>[
              AppRoleAssignmentOption(
                id: 'role-nurse',
                label: 'NURSE',
                permissionCount: 1,
              ),
            ],
            selectedRoleIds: const <String>{},
            onSelectionChanged: (_) {},
            loadRolePermissions: (String roleId) async {
              loadedRoleId = roleId;
              return <String>{'clinical:read'};
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NURSE'));
      await tester.pumpAndSettle();

      expect(loadedRoleId, 'role-nurse');
      expect(find.textContaining('Clinical'), findsWidgets);
    });
  });
}
