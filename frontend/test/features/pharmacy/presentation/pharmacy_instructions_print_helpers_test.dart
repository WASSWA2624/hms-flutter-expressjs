import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart';
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
    testWidgets('renders medicines table without duplicate metadata', (
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
      expect(html, contains('Artemether + Lumefantrine'));
      expect(html, contains('4 tablets'));
      expect(html, contains('twice daily'));
      expect(html, isNot(contains('print-template-kv')));
      expect(html, isNot(contains('<ul class="print-template-list">')));
      expect(html, isNot(contains('BID')));
    });

    testWidgets('includes pricing columns and grand total when priced', (
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
      expect(html, contains('Line total'));
      expect(html, contains('Grand total'));
      expect(html, contains('three times daily'));
      expect(html, isNot(contains('TID')));
    });
  });

  group('clinicalFrequencyReadable', () {
    test('maps common abbreviations', () {
      expect(clinicalFrequencyReadable('BID'), 'twice daily');
      expect(clinicalFrequencyReadable('TID'), 'three times daily');
      expect(clinicalFrequencyReadable('QID'), 'four times daily');
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
    quantityUnit: 'tablets',
    pharmacyUnitPrice: pharmacyUnitPrice,
    pharmacyCurrency: pharmacyCurrency,
  );
}
