import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_permission_assignment_picker.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('AppPermissionAssignmentPicker', () {
    const List<AppPermissionAssignmentOption> permissions =
        <AppPermissionAssignmentOption>[
          AppPermissionAssignmentOption(
            id: 'perm-patient-read',
            code: 'patient:read',
            label: 'Patient — Read',
          ),
          AppPermissionAssignmentOption(
            id: 'perm-patient-write',
            code: 'patient:write',
            label: 'Patient — Write',
          ),
          AppPermissionAssignmentOption(
            id: 'perm-clinical-read',
            code: 'clinical:read',
            label: 'Clinical — Read',
          ),
        ];

    testWidgets('renders grouped checkboxes and bulk actions', (tester) async {
      final Set<String> selected = <String>{'perm-patient-read'};

      await tester.pumpWidget(
        _wrap(
          AppPermissionAssignmentPicker(
            permissions: permissions,
            selectedPermissionIds: selected,
            onSelectionChanged: (Set<String> next) {
              selected
                ..clear()
                ..addAll(next);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search permissions'), findsOneWidget);
      expect(find.text('Select all permissions'), findsOneWidget);
      expect(find.text('Clear permissions'), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);
    });

    testWidgets('select all adds every permission', (tester) async {
      final Set<String> selected = <String>{};

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPermissionAssignmentPicker(
                permissions: permissions,
                selectedPermissionIds: selected,
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

      await tester.tap(find.text('Select all permissions'));
      await tester.pumpAndSettle();

      expect(selected.length, permissions.length);
    });

    testWidgets('group checkbox selects and deselects a module group', (
      tester,
    ) async {
      final Set<String> selected = <String>{};

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPermissionAssignmentPicker(
                permissions: permissions,
                selectedPermissionIds: selected,
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

      await tester.tap(find.byKey(const ValueKey<String>('group-patient')));
      await tester.pumpAndSettle();

      expect(selected, contains('perm-patient-read'));
      expect(selected, contains('perm-patient-write'));
      expect(selected, isNot(contains('perm-clinical-read')));

      await tester.tap(find.byKey(const ValueKey<String>('group-patient')));
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
    });

    testWidgets('single permission checkbox toggles independently', (
      tester,
    ) async {
      final Set<String> selected = <String>{};
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPermissionAssignmentPicker(
                permissions: permissions,
                selectedPermissionIds: selected,
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

      final Finder permissionTile = find.byKey(
        const ValueKey<String>('permission-perm-patient-read'),
      );
      await tester.ensureVisible(permissionTile);
      await tester.tap(permissionTile);
      await tester.pumpAndSettle();

      expect(selected, equals(<String>{'perm-patient-read'}));

      await tester.ensureVisible(permissionTile);
      await tester.tap(permissionTile);
      await tester.pumpAndSettle();

      expect(selected, isEmpty);
    });

    testWidgets('select all matching respects the search filter', (tester) async {
      final Set<String> selected = <String>{};

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppPermissionAssignmentPicker(
                permissions: permissions,
                selectedPermissionIds: selected,
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

      await tester.enterText(find.byType(TextField), 'clinical');
      await tester.pump();

      await tester.tap(find.text('Select all matching permissions'));
      await tester.pumpAndSettle();

      expect(selected, equals(<String>{'perm-clinical-read'}));
    });

    testWidgets('renders nothing when catalog is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppPermissionAssignmentPicker(
            permissions: const <AppPermissionAssignmentOption>[],
            selectedPermissionIds: const <String>{},
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search permissions'), findsNothing);
      expect(find.text('0 of 0 selected'), findsNothing);
    });

    testWidgets('filters permissions by search query', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppPermissionAssignmentPicker(
            permissions: permissions,
            selectedPermissionIds: const <String>{},
            onSelectionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'clinical');
      await tester.pump();

      expect(find.text('Clinical'), findsOneWidget);
      expect(find.text('Patient'), findsNothing);
    });
  });
}
