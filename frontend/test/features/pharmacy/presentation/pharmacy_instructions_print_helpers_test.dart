import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';

void main() {
  group('pharmacyOrderItemReadableInstructions', () {
    test('maps clinical frequency codes to patient-readable text', () {
      final PharmacyOrderItem item = _sampleItem(frequency: 'BID');

      final String instructions = pharmacyOrderItemReadableInstructions(item);

      expect(instructions, contains('twice daily'));
      expect(instructions, contains('Oral'));
      expect(instructions, isNot(contains('BID')));
      expect(instructions, isNot(contains('ORAL')));
    });
  });

  group('pharmacyInstructionsHtml', () {
    testWidgets('renders numbered medicines table without duplicate metadata', (
      tester,
    ) async {
      late String html;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyInstructionsHtml(
                context,
                PharmacyOrderWorkflow(
                  order: _sampleOrder(),
                  items: <PharmacyOrderItem>[_sampleItem(frequency: 'BID')],
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('print-template-table'));
      expect(html, contains('<td>1</td>'));
      expect(html, contains('Artemether + Lumefantrine'));
      expect(html, contains('4 tablets'));
      expect(html, contains('twice daily'));
      expect(html, contains('Unit price'));
      expect(html, contains('Amount'));
      expect(html, contains(pharmacyPrintPriceUnavailable));
      expect(html, contains('Total amount sold'));
      expect(html, contains('print-template-table-footer'));
      expect(html, isNot(contains('print-template-kv')));
      expect(html, isNot(contains('<ul class="print-template-list">')));
      expect(html, isNot(contains('BID')));
      expect(html, isNot(contains('Grand total')));
    });

    testWidgets('includes priced amount and total amount sold row', (
      tester,
    ) async {
      late String html;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyInstructionsHtml(
                context,
                PharmacyOrderWorkflow(
                  order: _sampleOrder(),
                  items: <PharmacyOrderItem>[
                    _sampleItem(
                      frequency: 'TID',
                      pharmacyUnitPrice: 2500,
                      pharmacyCurrency: 'UGX',
                    ),
                  ],
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('Unit price'));
      expect(html, contains('Amount'));
      expect(html, contains('Total amount sold'));
      expect(html, contains('UGX'));
      expect(html, contains('three times daily'));
      expect(html, isNot(contains('TID')));
      expect(html, isNot(contains('Grand total')));
    });

    testWidgets('shows dispense progress and bills dispensed qty on partial fills', (
      tester,
    ) async {
      late String html;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyInstructionsHtml(
                context,
                PharmacyOrderWorkflow(
                  order: _sampleOrder().copyWith(status: 'PARTIALLY_DISPENSED'),
                  items: <PharmacyOrderItem>[
                    _sampleItem(
                      frequency: 'TID',
                      pharmacyUnitPrice: 1000,
                      pharmacyCurrency: 'UGX',
                      quantityDispensed: 2,
                      quantityRemaining: 2,
                    ),
                  ],
                ),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('4 tablets (2 / 4)'));
      expect(html, contains('Total amount sold'));
      expect(html, contains('UGX'));
      // Amount column uses dispensed qty (2 × 1000), not full prescribed.
      expect(
        resolvePharmacyItemLineTotal(
          order: _sampleOrder().copyWith(status: 'PARTIALLY_DISPENSED'),
          item: _sampleItem(
            frequency: 'TID',
            pharmacyUnitPrice: 1000,
            pharmacyCurrency: 'UGX',
            quantityDispensed: 2,
            quantityRemaining: 2,
          ),
        ),
        2000,
      );
    });

    testWidgets('applies selected-item and zero-quantity filters', (
      tester,
    ) async {
      late String html;
      const PharmacyOrderItem kept = PharmacyOrderItem(
        id: 'kept',
        drugDisplayName: 'Kept Medicine',
        quantityPrescribed: 4,
        quantityUnit: 'tablets',
        quantityRemaining: 4,
        frequency: 'BID',
        route: 'ORAL',
      );
      const PharmacyOrderItem hiddenZero = PharmacyOrderItem(
        id: 'zero',
        drugDisplayName: 'Zero Remaining',
        quantityPrescribed: 4,
        quantityUnit: 'tablets',
        quantityRemaining: 0,
        frequency: 'BID',
        route: 'ORAL',
      );
      const PharmacyOrderItem unselected = PharmacyOrderItem(
        id: 'skip',
        drugDisplayName: 'Unselected Medicine',
        quantityPrescribed: 2,
        quantityUnit: 'tablets',
        quantityRemaining: 2,
        frequency: 'BID',
        route: 'ORAL',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyInstructionsHtml(
                context,
                const PharmacyOrderWorkflow(
                  order: PharmacyOrder(
                    id: 'order-1',
                    displayId: 'PHO-3E51507634',
                    patientId: 'PAT-03596352D8',
                    encounterId: 'ENC-3C95E3B11E',
                    patientDisplayName: 'Noah Demo-Echo',
                    status: 'DISPENSED',
                  ),
                  items: <PharmacyOrderItem>[kept, hiddenZero, unselected],
                ),
                selectedItemIds: <String>{'kept', 'zero'},
                hideZeroQuantity: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('Kept Medicine'));
      expect(html, isNot(contains('Zero Remaining')));
      expect(html, isNot(contains('Unselected Medicine')));
    });
  });

  group('resolvePharmacyDispenseBatchLines', () {
    test('matches lines by dispense batch ref', () {
      final PharmacyOrderItem item = PharmacyOrderItem(
        id: 'item-1',
        drugDisplayName: 'Artemether + Lumefantrine 20/120 mg Tablet',
        dosage: '20/120 mg',
        doseAmount: 2,
        doseUnit: 'tablets',
        route: 'ORAL',
        frequency: 'BID',
        quantityPrescribed: 4,
        quantityUnit: 'tablets',
        dispenseLogs: const <PharmacyDispenseLog>[
          PharmacyDispenseLog(
            id: 'log-1',
            dispenseBatchRef: 'DSPBATCH001',
            status: 'DISPENSED',
            quantityDispensed: 2,
          ),
          PharmacyDispenseLog(
            id: 'log-2',
            dispenseBatchRef: 'DSPBATCH002',
            status: 'DISPENSED',
            quantityDispensed: 1,
          ),
        ],
      );
      final PharmacyOrderWorkflow workflow = PharmacyOrderWorkflow(
        order: _sampleOrder(),
        items: <PharmacyOrderItem>[item],
      );

      final List<PharmacyDispenseBatchLine> lines =
          resolvePharmacyDispenseBatchLines(
            workflow: workflow,
            dispenseBatchRef: 'DSPBATCH001',
          );

      expect(lines, hasLength(1));
      expect(lines.single.quantityDispensed, 2);
      expect(lines.single.item.id, 'item-1');
    });

    test('matches a single log by id when batch is absent', () {
      final PharmacyOrderItem item = PharmacyOrderItem(
        id: 'item-1',
        drugDisplayName: 'Artemether + Lumefantrine 20/120 mg Tablet',
        quantityPrescribed: 4,
        quantityUnit: 'tablets',
        dispenseLogs: const <PharmacyDispenseLog>[
          PharmacyDispenseLog(
            id: 'log-orphan',
            status: 'DISPENSED',
            quantityDispensed: 3,
          ),
        ],
      );
      final PharmacyOrderWorkflow workflow = PharmacyOrderWorkflow(
        order: _sampleOrder(),
        items: <PharmacyOrderItem>[item],
      );

      final List<PharmacyDispenseBatchLine> lines =
          resolvePharmacyDispenseBatchLines(
            workflow: workflow,
            dispenseLogId: 'log-orphan',
          );

      expect(lines, hasLength(1));
      expect(lines.single.quantityDispensed, 3);
    });
  });

  group('pharmacyDispenseBatchHtml', () {
    testWidgets('renders dispensed quantities for the batch', (tester) async {
      late String html;
      final PharmacyOrderItem item = _sampleItem(frequency: 'BID');
      final PharmacyDispenseBatchLine line = PharmacyDispenseBatchLine(
        item: item,
        log: const PharmacyDispenseLog(
          id: 'log-1',
          dispenseBatchRef: 'DSPBATCH001',
          status: 'DISPENSED',
          quantityDispensed: 2,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              html = pharmacyDispenseBatchHtml(
                context,
                lines: <PharmacyDispenseBatchLine>[line],
                dispenseBatchRef: 'DSPBATCH001',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(html, contains('DSPBATCH001'));
      expect(html, contains('Artemether + Lumefantrine'));
      expect(html, contains('2 tablets'));
      expect(html, isNot(contains('Unit price')));
    });
  });
}

PharmacyOrder _sampleOrder() {
  return const PharmacyOrder(
    id: 'order-1',
    displayId: 'PHO-3E51507634',
    patientId: 'PAT-03596352D8',
    encounterId: 'ENC-3C95E3B11E',
    patientDisplayName: 'Noah Demo-Echo',
    status: 'DISPENSED',
  );
}

PharmacyOrderItem _sampleItem({
  required String frequency,
  num? pharmacyUnitPrice,
  String? pharmacyCurrency,
  num quantityDispensed = 0,
  num? quantityRemaining,
}) {
  return PharmacyOrderItem(
    id: 'item-1',
    drugDisplayName: 'Artemether + Lumefantrine 20/120 mg Tablet',
    dosage: '20/120 mg',
    doseAmount: 2,
    doseUnit: 'tablets',
    route: 'ORAL',
    frequency: frequency,
    durationValue: 3,
    durationUnit: 'days',
    instructions: 'Take with food.',
    quantityPrescribed: 4,
    quantityDispensed: quantityDispensed,
    quantityRemaining: quantityRemaining ?? 4,
    quantityUnit: 'tablets',
    pharmacyUnitPrice: pharmacyUnitPrice,
    pharmacyCurrency: pharmacyCurrency,
  );
}
