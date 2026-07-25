import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/facility_catalog/clinical_catalog_admin_dialogs.dart';

void main() {
  group('LabCatalogItemMutationDialog', () {
    testWidgets('create test shows ordered comprehensive fields', (
      WidgetTester tester,
    ) async {
      await _pumpMutationDialog(tester);

      expect(find.text('CREATE LAB TEST'), findsOneWidget);
      expect(find.text('Test name'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Specimen type'), findsOneWidget);
      expect(find.text('Result kind'), findsOneWidget);
      expect(find.text('Default unit'), findsOneWidget);
      expect(find.text('Unit options'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Reference range override'), findsOneWidget);
      expect(find.text('Adult'), findsOneWidget);
      expect(find.text('Add reference range'), findsOneWidget);
    });

    testWidgets('qualitative kind shows result options and hides unit options', (
      WidgetTester tester,
    ) async {
      await _pumpMutationDialog(tester);

      await tester.tap(find.text('Numeric'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qualitative').last);
      await tester.pumpAndSettle();

      expect(find.text('Qualitative result options'), findsOneWidget);
      expect(find.text('Unit options'), findsNothing);
      expect(find.text('Default unit'), findsOneWidget);
    });

    testWidgets('save submits full test payload', (WidgetTester tester) async {
      Map<String, Object?>? submitted;
      await _pumpMutationDialog(
        tester,
        onSubmit: (Map<String, Object?> payload) async {
          submitted = payload;
          return null;
        },
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'Glucose');
      await tester.enterText(find.byType(TextFormField).at(1), 'GLU');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!['name'], 'Glucose');
      expect(submitted!['code'], 'GLU');
      expect(submitted!['tenant_id'], 'tenant-1');
      expect(submitted!['result_kind'], 'NUMERIC');
      expect(submitted!['specimen_type'], isA<String>());
      expect(submitted!['unit_options'], isA<List<Object?>>());
      expect(submitted!['result_options'], isA<List<Object?>>());
      expect(submitted!['reference_ranges'], isA<List<Object?>>());
    });
  });
}

Future<void> _pumpMutationDialog(
  WidgetTester tester, {
  Future<AppFailure?> Function(Map<String, Object?> payload)? onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open',
              onPressed: () {
                showAppDialog<bool>(
                  context: context,
                  builder: (_) => LabCatalogItemMutationDialog(
                    kind: LabCatalogItemType.test,
                    tenantId: 'tenant-1',
                    catalogItems: const <LabCatalogItem>[
                      LabCatalogItem(
                        id: 'LBT1',
                        type: LabCatalogItemType.test,
                        name: 'Hemoglobin',
                        code: 'HB',
                        category: 'Hematology',
                        specimenType: 'Whole blood',
                        unit: 'g/dL',
                      ),
                    ],
                    onSubmit: onSubmit ?? (_) async => null,
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
