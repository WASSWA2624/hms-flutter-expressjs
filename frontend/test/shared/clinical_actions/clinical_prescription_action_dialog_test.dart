import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  group('ClinicalPrescriptionActionDialog', () {
    testWidgets('hides help copy and payment mode controls', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      expect(
        find.text(
          'Review selection, add catalog items, then confirm billing.',
        ),
        findsNothing,
      );
      expect(find.text('Bill on dispense'), findsNothing);
      expect(find.text('Pay at prescribe'), findsNothing);
      expect(find.text('Build prescription'), findsNothing);
      expect(find.text('No medicines added yet'), findsOneWidget);
    });

    testWidgets('shows table search actions for prescribe workflow', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget.runtimeType.toString().startsWith('AppListTable'),
        ),
        findsOneWidget,
      );
      expect(find.text('Filters'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Add medicine'), findsWidgets);
      expect(find.text('Review billing'), findsWidgets);
      expect(find.text('Remove selected'), findsWidgets);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Prescribe'), findsWidgets);
    });

    testWidgets('review billing is disabled when no medicines are listed', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      final Finder reviewBilling = find.text('Review billing');
      expect(reviewBilling, findsWidgets);
      await tester.tap(reviewBilling.first);
      await tester.pumpAndSettle();

      expect(find.text('Request billing'), findsNothing);
    });

    testWidgets('add medicine opens catalog table picker', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await tester.tap(find.text('Add medicine').first);
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE MEDICINES'), findsOneWidget);
      expect(find.text('Available drug'), findsNothing);
      expect(find.text('Amoxicillin'), findsWidgets);
      expect(find.text('Ibuprofen'), findsWidgets);
      expect(find.text('Add selected medicines'), findsOneWidget);
    });

    testWidgets('cancel on catalog picker adds nothing', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await tester.tap(find.text('Add medicine').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amoxicillin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Cancel').last);
      await tester.pumpAndSettle();

      expect(find.text('No medicines added yet'), findsOneWidget);
      expect(find.textContaining('Amoxicillin'), findsNothing);
    });

    testWidgets('adds collapsed collapsible cards with prescription summary', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await _addMedicinesFromCatalog(tester, <String>[
        'Amoxicillin',
        'Ibuprofen',
      ]);

      expect(find.byType(AppCollapsibleSection), findsNWidgets(2));
      expect(find.textContaining('Amoxicillin 500 mg'), findsWidgets);
      expect(find.textContaining('Ibuprofen 200 mg'), findsWidgets);
      // Default 7-day course × BID → qty 14 / 14
      expect(find.textContaining('Oral · BID · Qty 14'), findsWidgets);
      expect(find.text('Prescription details'), findsNothing);
      expect(find.text('Edit details'), findsNothing);
      expect(_fieldWithLabel('Dose amount'), findsNothing);
      expect(find.text('Remove item'), findsWidgets);
    });

    testWidgets('expanding a card reveals dosing fields without section title', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);
      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);

      await _expandFirstMedicineCard(tester);

      expect(find.text('Prescription details'), findsNothing);
      expect(_fieldWithLabel('Dose amount'), findsWidgets);
      expect(_selectWithLabel('Medication route'), findsWidgets);
      expect(_fieldWithLabel('Duration'), findsWidgets);
      expect(_fieldWithLabel('Instructions'), findsWidgets);
    });

    testWidgets('seeds dose amount and unit from catalog strength', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);
      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);
      await _expandFirstMedicineCard(tester);

      final Finder doseAmountField = _fieldWithLabel('Dose amount');
      final AppTextField field = tester.widget<AppTextField>(
        doseAmountField.first,
      );
      expect(field.controller?.text, '500');
      expect(find.text('mg'), findsWidgets);
    });

    testWidgets('adds selected medicines from catalog and removes them', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await _addMedicinesFromCatalog(tester, <String>[
        'Amoxicillin',
        'Ibuprofen',
      ]);

      expect(find.textContaining('Amoxicillin'), findsWidgets);
      expect(find.textContaining('Ibuprofen'), findsWidgets);

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove selected').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('REMOVE'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ibuprofen'), findsNothing);
      expect(find.textContaining('Amoxicillin'), findsWidgets);
    });

    testWidgets('does not add a duplicate medicine already on the list', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);
      expect(find.textContaining('Amoxicillin'), findsWidgets);

      await tester.tap(find.text('Add medicine').first);
      await tester.pumpAndSettle();

      expect(find.text('CHOOSE MEDICINES'), findsOneWidget);
      expect(find.text('Amoxicillin'), findsNothing);
      expect(find.text('Ibuprofen'), findsWidgets);

      await tester.tap(find.widgetWithText(AppButton, 'Cancel').last);
      await tester.pumpAndSettle();
    });

    testWidgets('blocks prescribe when duration is cleared', (
      WidgetTester tester,
    ) async {
      var submitted = false;
      await _pumpPrescribeDialog(
        tester,
        onSubmit:
            ({
              required List<Map<String, Object?>> items,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              submitted = true;
              return null;
            },
      );

      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);
      await _expandFirstMedicineCard(tester);
      await _setDurationInline(tester, duration: '');

      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text('CHOOSE MEDICINES'), findsNothing);
      expect(find.textContaining('Amoxicillin'), findsWidgets);
      expect(_fieldWithLabel('Dose amount'), findsWidgets);
      expect(find.text('Check the highlighted details.'), findsOneWidget);
      expect(find.text('This field is required.'), findsWidgets);
      final AppTextField durationField = tester.widget<AppTextField>(
        _fieldWithLabel('Duration').first,
      );
      expect(durationField.errorText, 'This field is required.');
    });

    testWidgets('seeds duration and derived quantity so prescribe succeeds', (
      WidgetTester tester,
    ) async {
      List<Map<String, Object?>>? submittedItems;

      await _pumpPrescribeDialog(
        tester,
        onSubmit:
            ({
              required List<Map<String, Object?>> items,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              submittedItems = items;
              return null;
            },
      );

      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);
      expect(find.textContaining('Qty 14'), findsWidgets);

      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submittedItems, isNotNull);
      expect(submittedItems!.single['drug_id'], 'DRG-AMOX');
      expect(submittedItems!.single['dose_amount'], 500);
      expect(submittedItems!.single['dose_unit'], 'mg');
      expect(submittedItems!.single['quantity'], 14);
      expect(submittedItems!.single['duration_value'], 7);
      expect(submittedItems!.single['quantity_unit'], 'capsule');
    });

    testWidgets('duration edit updates quantity and allows prescribe', (
      WidgetTester tester,
    ) async {
      List<Map<String, Object?>>? submittedItems;

      await _pumpPrescribeDialog(
        tester,
        onSubmit:
            ({
              required List<Map<String, Object?>> items,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              submittedItems = items;
              return null;
            },
      );

      await _addMedicinesFromCatalog(tester, <String>['Amoxicillin']);
      await _expandFirstMedicineCard(tester);
      await _setDurationInline(tester, duration: '5');

      expect(find.textContaining('Qty 10'), findsWidgets);

      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submittedItems, isNotNull);
      expect(submittedItems!.single['drug_id'], 'DRG-AMOX');
      expect(submittedItems!.single['dose_amount'], 500);
      expect(submittedItems!.single['dose_unit'], 'mg');
      expect(submittedItems!.single['quantity'], 10);
      expect(submittedItems!.single['duration_value'], 5);
    });
  });
}

Future<void> _addMedicinesFromCatalog(
  WidgetTester tester,
  List<String> medicineNames,
) async {
  await tester.tap(find.text('Add medicine').first);
  await tester.pumpAndSettle();

  expect(find.text('CHOOSE MEDICINES'), findsOneWidget);

  for (final String name in medicineNames) {
    await tester.ensureVisible(find.text(name).last);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  final Finder confirm = find.widgetWithText(
    AppButton,
    'Add selected medicines',
  );
  expect(confirm, findsOneWidget);
  await tester.tap(confirm);
  await tester.pumpAndSettle();

  expect(find.text('CHOOSE MEDICINES'), findsNothing);
}

Future<void> _expandFirstMedicineCard(WidgetTester tester) async {
  final Finder section = find.byType(AppCollapsibleSection).first;
  await tester.ensureVisible(section);
  await tester.tap(section);
  await tester.pumpAndSettle();
}

Finder _fieldWithLabel(String label) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is AppTextField && widget.labelText == label,
  );
}

Finder _selectWithLabel(String label) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == label,
  );
}

Future<void> _setDurationInline(
  WidgetTester tester, {
  required String duration,
}) async {
  final Finder durationField = _fieldWithLabel('Duration');
  expect(durationField, findsWidgets);
  await tester.ensureVisible(durationField.first);
  await tester.enterText(durationField.first, duration);
  await tester.pumpAndSettle();
}

Future<void> _pumpPrescribeDialog(
  WidgetTester tester, {
  Future<AppFailure?> Function({
    required List<Map<String, Object?>> items,
    ClinicalRequestBillingSubmit? billing,
  })?
  onSubmit,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: ClinicalPrescriptionActionDialog(
            referenceData: const ClinicalActionReferenceData(
              drugs: <ClinicalActionCatalogOption>[
                ClinicalActionCatalogOption(
                  id: 'amox',
                  publicId: 'DRG-AMOX',
                  name: 'Amoxicillin',
                  code: 'AMOX',
                  unitPrice: 12,
                  currency: 'USD',
                  metadata: <String, Object?>{
                    'generic_name': 'Amoxicillin',
                    'strength': '500 mg',
                    'form': 'Capsule',
                  },
                ),
                ClinicalActionCatalogOption(
                  id: 'ibu',
                  publicId: 'DRG-IBU',
                  name: 'Ibuprofen',
                  code: 'IBU',
                  unitPrice: 8,
                  currency: 'USD',
                  metadata: <String, Object?>{
                    'generic_name': 'Ibuprofen',
                    'strength': '200 mg',
                    'form': 'Tablet',
                  },
                ),
              ],
            ),
            onSubmit:
                onSubmit ??
                ({
                  required List<Map<String, Object?>> items,
                  ClinicalRequestBillingSubmit? billing,
                }) async {
                  return null;
                },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
