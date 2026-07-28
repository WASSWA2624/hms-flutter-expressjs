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

    testWidgets('adds a medicine row and removes it via remove selected', (
      WidgetTester tester,
    ) async {
      await _pumpPrescribeDialog(tester);

      await _addAmoxicillinLine(tester);

      expect(find.text('Amoxicillin 500mg'), findsWidgets);
      expect(find.text('500 mg'), findsWidgets);
      expect(find.text('Oral · twice daily'), findsWidgets);

      // Select the row via its checkbox (row tap does not toggle selection).
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove selected').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('REMOVE'), findsOneWidget);
      await tester.tap(find.widgetWithText(AppButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Amoxicillin 500mg'), findsNothing);
      expect(find.text('No medicines added yet'), findsOneWidget);
    });

    testWidgets('submit sends items with null billing by default', (
      WidgetTester tester,
    ) async {
      List<Map<String, Object?>>? submittedItems;
      ClinicalRequestBillingSubmit? submittedBilling;

      await _pumpPrescribeDialog(
        tester,
        onSubmit:
            ({
              required List<Map<String, Object?>> items,
              ClinicalRequestBillingSubmit? billing,
            }) async {
              submittedItems = items;
              submittedBilling = billing;
              return null;
            },
      );

      await _addAmoxicillinLine(tester);
      await tester.tap(find.widgetWithIcon(AppButton, Icons.send_outlined));
      await tester.pumpAndSettle();

      expect(submittedItems, isNotNull);
      expect(submittedItems!.single['drug_id'], 'DRG-AMOX');
      expect(submittedBilling, isNull);
    });
  });
}

Future<void> _addAmoxicillinLine(WidgetTester tester) async {
  await tester.tap(find.text('Add medicine').first);
  await tester.pumpAndSettle();

  expect(find.text('ADD MEDICINE'), findsOneWidget);

  final Finder lineDialog = find.byType(AppDialog).last;
  final Finder drugField = find.descendant(
    of: lineDialog,
    matching: find.byType(EditableText),
  );

  await tester.ensureVisible(drugField.first);
  await tester.tap(drugField.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Amoxicillin 500mg').last);
  await tester.pumpAndSettle();

  final Finder doseAmount = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Dose amount',
  );
  await tester.ensureVisible(doseAmount);
  await tester.enterText(doseAmount, '500');
  await tester.pumpAndSettle();

  final Finder doseUnit = find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == 'Dose unit',
  );
  await tester.ensureVisible(doseUnit);
  await tester.tap(find.descendant(of: doseUnit, matching: find.byType(EditableText)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('mg').last);
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
            referenceData: ClinicalActionReferenceData(
              drugs: <ClinicalActionCatalogOption>[
                const ClinicalActionCatalogOption(
                  id: 'amox',
                  publicId: 'DRG-AMOX',
                  name: 'Amoxicillin 500mg',
                  unitPrice: 12,
                  currency: 'USD',
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
