import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_format.dart';

void main() {
  group('formatLabReferenceRangeDisplay', () {
    test('puts unit after bounds without Unit prefix', () {
      expect(
        formatLabReferenceRangeDisplay(
          label: 'Adult male',
          unit: 'g/dL',
          gender: 'MALE',
          ageMinValue: 18,
          ageMinUnit: 'YEAR',
          normalMinValue: '13.5',
          normalMaxValue: '17.5',
        ),
        'Adult male | MALE | 18 years+ | 13.5 - 17.5 g/dL',
      );
    });

    test('rewrites legacy Unit fragments in summary fallbacks', () {
      expect(
        rewriteLegacyLabReferenceRangeUnitSummary(
          'Adult male | Unit g/dL | MALE | 18 years+ | 13.5 - 17.5',
        ),
        'Adult male | MALE | 18 years+ | 13.5 - 17.5 g/dL',
      );
    });
  });

  group('formatLabReferenceRangeFromMap', () {
    test('recovers unit from legacy summary when unit field is missing', () {
      expect(
        formatLabReferenceRangeFromMap(<String, Object?>{
          'label': 'Adult ISE',
          'summary': 'Adult ISE | Unit mg/dL | 3.6 - 5.2',
          'normal_min_value': '3.6000',
          'normal_max_value': '5.2000',
        }),
        'Adult ISE | 3.6000 - 5.2000 mg/dL',
      );
    });
  });

  group('resolveLabOrderItemDisplayReferenceRange', () {
    test('prefers gender-matched catalog range when available', () {
      const LabOrderItem item = LabOrderItem(
        id: 'item-1',
        referenceRanges: <LabReferenceRange>[
          LabReferenceRange(
            id: 'male',
            label: 'Adult male',
            unit: 'g/dL',
            gender: 'MALE',
            normalMinValue: '13.5',
            normalMaxValue: '17.5',
          ),
          LabReferenceRange(
            id: 'female',
            label: 'Adult female',
            unit: 'g/dL',
            gender: 'FEMALE',
            normalMinValue: '12.0',
            normalMaxValue: '15.0',
          ),
        ],
      );

      expect(
        resolveLabOrderItemDisplayReferenceRange(
          item,
          patientGender: 'male',
        ),
        'Adult male | MALE | 13.5 - 17.5 g/dL',
      );
    });
  });
}
