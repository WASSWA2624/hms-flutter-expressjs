import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/widgets/pharmacy_print_options_section.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

void main() {
  group('PharmacyPrintOptionsController', () {
    test('defaults select all medications and hide zero-quantity', () {
      final PharmacyPrintOptionsController controller =
          PharmacyPrintOptionsController(_workflow());

      expect(controller.selectedItemIds, <String>{'item-1', 'item-2'});
      expect(controller.hideZeroQuantity, isTrue);
      expect(controller.hidePartiallyDispensed, isFalse);
      expect(controller.includeHistory, isFalse);
      expect(controller.canPrint, isTrue);
      expect(controller.selectedHistoryItems, isEmpty);
    });

    test('disables print when no medications are selected', () {
      final PharmacyPrintOptionsController controller =
          PharmacyPrintOptionsController(_workflow());

      controller.setItemSelected('item-1', false);
      controller.setItemSelected('item-2', false);

      expect(controller.canPrint, isFalse);
      expect(controller.selectedItemIds, isEmpty);
    });

    test('includes selected history only when includeHistory is enabled', () {
      final PharmacyPrintOptionsController controller =
          PharmacyPrintOptionsController(_workflow());

      expect(controller.selectedHistoryItems, isEmpty);

      controller.setIncludeHistory(true);
      expect(
        controller.selectedHistoryItems.map((PharmacyTimelineItem e) => e.id),
        <String>['hist-1'],
      );

      controller.setHistorySelected('hist-1', false);
      expect(controller.selectedHistoryItems, isEmpty);
    });
  });

  testWidgets('Print options section orders filters above medicines', (
    WidgetTester tester,
  ) async {
    final PharmacyPrintOptionsController controller =
        PharmacyPrintOptionsController(_workflow());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PharmacyPrintOptionsSection(controller: controller),
          ),
        ),
      ),
    );

    expect(find.text('Print options'), findsOneWidget);
    expect(find.text('Hide zero-quantity items'), findsOneWidget);
    expect(find.text('Hide partially dispensed items'), findsOneWidget);
    expect(find.text('Include dispense history'), findsOneWidget);
    expect(find.text('Medications to include'), findsOneWidget);
    expect(find.textContaining('Med A'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byType(AppReportSectionTile), findsWidgets);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(RadioListTile<Object>), findsNothing);

    final double filterY = tester
        .getTopLeft(find.text('Hide zero-quantity items'))
        .dy;
    final double medicinesY = tester
        .getTopLeft(find.text('Medications to include'))
        .dy;
    expect(filterY, lessThan(medicinesY));

    await tester.tap(find.text('Include dispense history'));
    await tester.pump();
    expect(find.text('History records to include'), findsOneWidget);

    controller.dispose();
  });
}

PharmacyOrderWorkflow _workflow() {
  return const PharmacyOrderWorkflow(
    order: PharmacyOrder(
      id: 'order-1',
      displayId: 'PHA0000001',
      patientId: 'patient-1',
      encounterId: 'encounter-1',
      status: 'READY',
    ),
    items: <PharmacyOrderItem>[
      PharmacyOrderItem(
        id: 'item-1',
        drugDisplayName: 'Med A',
        quantityPrescribed: 10,
        quantityDispensed: 0,
        quantityRemaining: 10,
      ),
      PharmacyOrderItem(
        id: 'item-2',
        drugDisplayName: 'Med B',
        quantityPrescribed: 5,
        quantityDispensed: 2,
        quantityRemaining: 3,
      ),
    ],
    timeline: <PharmacyTimelineItem>[
      PharmacyTimelineItem(
        id: 'hist-1',
        type: 'DISPENSED',
        labelParams: <String, Object?>{},
      ),
    ],
  );
}
