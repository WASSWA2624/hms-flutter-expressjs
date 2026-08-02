import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_prescription_dosing.dart';

void main() {
  group('clinicalParseDrugStrength', () {
    test('parses amount and unit', () {
      final ClinicalParsedStrength? parsed = clinicalParseDrugStrength('500 mg');
      expect(parsed?.amount, 500);
      expect(parsed?.unit, 'mg');
    });

    test('parses compact strength', () {
      final ClinicalParsedStrength? parsed = clinicalParseDrugStrength('400mg');
      expect(parsed?.amount, 400);
      expect(parsed?.unit, 'mg');
    });

    test('returns null for unparsable strength', () {
      expect(clinicalParseDrugStrength('variable'), isNull);
      expect(clinicalParseDrugStrength(''), isNull);
    });
  });

  group('clinicalPrescriptionDosesPerDay', () {
    test('maps common frequencies', () {
      expect(clinicalPrescriptionDosesPerDay('BID'), 2);
      expect(clinicalPrescriptionDosesPerDay('TID'), 3);
      expect(clinicalPrescriptionDosesPerDay('OD'), 1);
      expect(clinicalPrescriptionDosesPerDay('PRN'), isNull);
    });
  });

  group('clinicalDerivePrescriptionQuantity', () {
    test('derives quantity from dose frequency duration and strength', () {
      // quantity ≈ 2 × 7 × (500 / 500) = 14
      expect(
        clinicalDerivePrescriptionQuantity(
          doseAmount: 500,
          doseUnit: 'mg',
          frequency: 'BID',
          durationValue: 7,
          durationUnit: 'days',
          strengthAmount: 500,
          strengthUnit: 'mg',
        ),
        14,
      );
    });

    test('ceilings fractional tablet counts', () {
      // 2 × 7 × (750 / 500) = 21
      expect(
        clinicalDerivePrescriptionQuantity(
          doseAmount: 750,
          doseUnit: 'mg',
          frequency: 'BID',
          durationValue: 7,
          durationUnit: 'days',
          strengthAmount: 500,
          strengthUnit: 'mg',
        ),
        21,
      );
    });
  });

  group('clinicalSyncPrescriptionDosing', () {
    test('updates quantity when duration changes and qty is auto', () {
      final ClinicalPrescriptionDosingSyncResult result =
          clinicalSyncPrescriptionDosing(
            lastEdited: ClinicalPrescriptionDosingField.durationValue,
            doseAmount: 500,
            doseUnit: 'mg',
            frequency: 'BID',
            durationValue: 7,
            durationUnit: 'days',
            quantity: 1,
            strengthAmount: 500,
            strengthUnit: 'mg',
            quantityWasAutoDerived: true,
          );
      expect(result.quantity, 14);
      expect(result.isConsistent, isTrue);
    });

    test('derives duration when quantity is edited', () {
      final ClinicalPrescriptionDosingSyncResult result =
          clinicalSyncPrescriptionDosing(
            lastEdited: ClinicalPrescriptionDosingField.quantity,
            doseAmount: 500,
            doseUnit: 'mg',
            frequency: 'BID',
            durationValue: 7,
            durationUnit: 'days',
            quantity: 14,
            strengthAmount: 500,
            strengthUnit: 'mg',
            quantityWasAutoDerived: false,
          );
      expect(result.durationValue, 7);
      expect(result.durationUnit, 'days');
      expect(result.isConsistent, isTrue);
    });

    test('flags unit mismatch', () {
      final ClinicalPrescriptionDosingSyncResult result =
          clinicalSyncPrescriptionDosing(
            lastEdited: ClinicalPrescriptionDosingField.doseUnit,
            doseAmount: 500,
            doseUnit: 'mL',
            frequency: 'BID',
            durationValue: 7,
            durationUnit: 'days',
            quantity: 14,
            strengthAmount: 500,
            strengthUnit: 'mg',
            quantityWasAutoDerived: true,
          );
      expect(
        result.inconsistency,
        ClinicalPrescriptionDosingInconsistency.unitMismatch,
      );
    });
  });
}
