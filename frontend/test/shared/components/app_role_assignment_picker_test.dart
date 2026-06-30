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
    const List<AppRoleAssignmentOption> roles = <AppRoleAssignmentOption>[
      AppRoleAssignmentOption(
        id: 'role-nurse',
        label: 'Nurse | ROL001',
        permissionCount: 12,
      ),
      AppRoleAssignmentOption(
        id: 'role-admin',
        label: 'Administrator | ROL002',
        permissionCount: 24,
        isSystemCritical: true,
      ),
    ];

    testWidgets('shows empty selected state without warning by default',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppRoleAssignmentPicker(
            roles: roles,
            selectedRoleIds: const <String>{},
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No roles assigned yet'), findsNothing);
      expect(find.text('No roles selected yet.'), findsOneWidget);
      expect(find.text('Search roles'), findsNothing);
      expect(find.text('Add role'), findsOneWidget);
    });

    testWidgets('shows custom empty warning when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppRoleAssignmentPicker(
            roles: roles,
            selectedRoleIds: const <String>{},
            onSelectionChanged: (_) {},
            emptyWarning: 'Assign at least one role.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign at least one role.'), findsOneWidget);
    });

    testWidgets('filters roles via consolidated searchable select',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppRoleAssignmentPicker(
            roles: roles,
            selectedRoleIds: const <String>{},
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownMenuFormField<String>));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'admin');
      await tester.pump();

      expect(find.text('admin'), findsOneWidget);
    });
  });
}
