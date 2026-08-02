import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_display.dart';

void main() {
  group('clinicalNotesForDisplay', () {
    test('drops prescribe action-label notes and duplicates', () {
      final List<ClinicalRelatedRecord> notes = clinicalNotesForDisplay(
        <ClinicalRelatedRecord>[
          const ClinicalRelatedRecord(
            id: 'n1',
            kind: 'clinical_note',
            title: 'Prescribe',
          ),
          const ClinicalRelatedRecord(
            id: 'n2',
            kind: 'clinical_note',
            title: 'Patient reports productive cough for 3 days.',
          ),
          const ClinicalRelatedRecord(
            id: 'n2',
            kind: 'clinical_note',
            title: 'Patient reports productive cough for 3 days.',
          ),
        ],
      );

      expect(notes, hasLength(1));
      expect(notes.single.title, contains('productive cough'));
    });
  });

  group('deduplicateClinicalRelatedRecords diagnoses', () {
    test('collapses same code and type', () {
      final List<ClinicalRelatedRecord> diagnoses =
          deduplicateClinicalRelatedRecords(
            <ClinicalRelatedRecord>[
              const ClinicalRelatedRecord(
                id: 'd1',
                kind: 'diagnosis',
                title: 'Pneumonia - Primary | J18.9',
                code: 'J18.9',
                diagnosisType: 'PRIMARY',
              ),
              const ClinicalRelatedRecord(
                id: 'd2',
                kind: 'diagnosis',
                title: 'Pneumonia - Primary | J18.9',
                code: 'J18.9',
                diagnosisType: 'PRIMARY',
              ),
            ],
            diagnoses: true,
          );

      expect(diagnoses, hasLength(1));
    });
  });

  group('clinicalPrescriptionItemPaperLine', () {
    test('formats layman-readable dosing', () {
      const ClinicalPharmacyOrderItem item = ClinicalPharmacyOrderItem(
        id: 'i1',
        drugDisplayName: 'Amoxicillin 500 mg',
        doseAmount: '500',
        doseUnit: 'mg',
        route: 'ORAL',
        frequency: 'BID',
        durationValue: '7',
        durationUnit: 'days',
        quantity: '14',
        quantityUnit: 'tablets',
      );

      final String line = clinicalPrescriptionItemPaperLine(item);
      expect(line, contains('Amoxicillin 500 mg'));
      expect(line.toLowerCase(), contains('twice daily'));
      expect(line, contains('7 days'));
      expect(line, contains('Qty 14 tablets'));
    });
  });
}
