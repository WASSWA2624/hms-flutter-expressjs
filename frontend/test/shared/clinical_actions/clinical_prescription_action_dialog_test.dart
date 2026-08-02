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

    testWidgets('shows paper-style prescription lines with inline editors', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await _addMedicinesFromCatalog(tester, <String>[
        'Amoxicillin',
        'Ibuprofen',
      ]);

      expect(find.text('Amoxicillin 500 mg'), findsWidgets);
      expect(find.text('Ibuprofen 200 mg'), findsWidgets);
      expect(
        find.textContaining('Take by mouth twice daily'),
        findsWidgets,
      );
      expect(find.textContaining('Qty 1'), findsWidgets);
      expect(find.text('Prescription details'), findsWidgets);
      expect(find.text('Dose amount'), findsWidgets);
      expect(find.text('Medication route'), findsWidgets);
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

    testWidgets('blocks prescribe when dose details are incomplete', (
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
      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submitted, isFalse);
      expect(find.text('CHOOSE MEDICINES'), findsNothing);
      expect(find.textContaining('Amoxicillin'), findsWidgets);
    });

    testWidgets('inline dose edit allows prescribe submit', (
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
      await _editDoseInline(
        tester,
        doseAmount: '500',
        doseUnit: 'mg',
      );

      expect(
        find.textContaining('Take 500 mg by mouth twice daily'),
        findsWidgets,
      );

      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submittedItems, isNotNull);
      expect(submittedItems!.single['drug_id'], 'DRG-AMOX');
      expect(submittedItems!.single['dose_amount'], 500);
      expect(submittedItems!.single['dose_unit'], 'mg');
    });

    testWidgets('edit details dialog remains available for full form', (
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
      await _editDetailsDialog(
        tester,
        doseAmount: '250',
        doseUnit: 'mg',
      );

      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submittedItems, isNotNull);
      expect(submittedItems!.single['dose_amount'], 250);
      expect(submittedItems!.single['dose_unit'], 'mg');
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

Future<void> _editDoseInline(
  WidgetTester tester, {
  required String doseAmount,
  required String doseUnit,
}) async {
  final Finder doseAmountField = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Dose amount',
  );
  expect(doseAmountField, findsWidgets);
  await tester.ensureVisible(doseAmountField.first);
  await tester.enterText(doseAmountField.first, doseAmount);
  await tester.pumpAndSettle();

  final Finder doseUnitField = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == 'Dose unit',
  );
  await tester.ensureVisible(doseUnitField.first);
  await tester.tap(
    find.descendant(
      of: doseUnitField.first,
      matching: find.byType(EditableText),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(doseUnit).last);
  await tester.pumpAndSettle();
}

Future<void> _editDetailsDialog(
  WidgetTester tester, {
  required String doseAmount,
  required String doseUnit,
}) async {
  final Finder editAction = find.byTooltip('Edit details');
  expect(editAction, findsWidgets);
  await tester.tap(editAction.first);
  await tester.pumpAndSettle();

  expect(find.text('EDIT MEDICINE'), findsOneWidget);

  final Finder doseAmountField = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Dose amount',
  );
  await tester.ensureVisible(doseAmountField.last);
  await tester.enterText(doseAmountField.last, doseAmount);
  await tester.pumpAndSettle();

  final Finder doseUnitField = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == 'Dose unit',
  );
  await tester.ensureVisible(doseUnitField.last);
  await tester.tap(
    find.descendant(
      of: doseUnitField.last,
      matching: find.byType(EditableText),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(doseUnit).last);
  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(AppButton, 'Done'));
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
