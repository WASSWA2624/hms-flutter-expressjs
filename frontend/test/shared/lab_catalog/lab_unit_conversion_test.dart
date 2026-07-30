import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_format.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_unit_conversion.dart';

void main() {
  group('convertLabQuantity', () {
    test('converts g/dL to g/L by ×10', () {
      expect(
        convertLabQuantity(13.5, fromUnit: 'g/dL', toUnit: 'g/L'),
        135,
      );
      expect(
        convertLabQuantity(17.5, fromUnit: 'g/dL', toUnit: 'g/L'),
        175,
      );
    });

    test('converts g/L to g/dL by ÷10', () {
      expect(
        convertLabQuantity(150, fromUnit: 'g/L', toUnit: 'g/dL'),
        15,
      );
    });

    test('returns null when units are not convertible', () {
      expect(
        convertLabQuantity(15, fromUnit: 'g/dL', toUnit: '%'),
        isNull,
      );
    });

    test('normalizes label | unit display strings', () {
      expect(normalizeLabUnitToken('Grams per liter | g/L'), 'g/l');
      expect(
        convertLabQuantity(
          13.5,
          fromUnit: 'g/dL',
          toUnit: 'Grams per liter | g/L',
        ),
        135,
      );
    });
  });

  group('formatLabReferenceRangeForResultUnit', () {
    const LabReferenceRange adultMale = LabReferenceRange(
      id: 'male',
      label: 'Adult male',
      unit: 'g/dL',
      gender: 'MALE',
      ageMinValue: 18,
      ageMinUnit: 'YEAR',
      normalMinValue: '13.5',
      normalMaxValue: '17.5',
    );

    test('rewrites bounds into selected result unit when convertible', () {
      expect(
        formatLabReferenceRangeForResultUnit(
          adultMale,
          resultUnit: 'g/L',
        ),
        'Adult male | MALE | 18 years+ | 135 - 175 g/L',
      );
    });

    test('keeps native range when conversion is impossible', () {
      expect(
        formatLabReferenceRangeForResultUnit(
          adultMale,
          resultUnit: '%',
        ),
        'Adult male | MALE | 18 years+ | 13.5 - 17.5 g/dL',
      );
    });
  });

  group('interpretLabNumericResultFlag', () {
    const LabReferenceRange adultMale = LabReferenceRange(
      id: 'male',
      label: 'Adult male',
      unit: 'g/dL',
      gender: 'MALE',
      normalMinValue: '13.5',
      normalMaxValue: '17.5',
    );

    test('15 is NORMAL in g/dL and LOW in g/L against 13.5-17.5 g/dL', () {
      expect(
        interpretLabNumericResultFlag(
          valueText: '15',
          range: adultMale,
          resultUnit: 'g/dL',
        ),
        'NORMAL',
      );
      expect(
        interpretLabNumericResultFlag(
          valueText: '15',
          range: adultMale,
          resultUnit: 'g/L',
        ),
        'LOW',
      );
    });

    test('distinguishes critical-low and critical-high', () {
      const LabReferenceRange withCritical = LabReferenceRange(
        id: 'male-crit',
        label: 'Adult male',
        unit: 'g/dL',
        gender: 'MALE',
        normalMinValue: '13.5',
        normalMaxValue: '17.5',
        criticalMinValue: '7',
        criticalMaxValue: '20',
      );

      expect(
        interpretLabNumericResultFlag(
          valueText: '5',
          range: withCritical,
          resultUnit: 'g/dL',
        ),
        'CRITICAL_LOW',
      );
      expect(
        interpretLabNumericResultFlag(
          valueText: '12',
          range: withCritical,
          resultUnit: 'g/dL',
        ),
        'LOW',
      );
      expect(
        interpretLabNumericResultFlag(
          valueText: '15',
          range: withCritical,
          resultUnit: 'g/dL',
        ),
        'NORMAL',
      );
      expect(
        interpretLabNumericResultFlag(
          valueText: '18',
          range: withCritical,
          resultUnit: 'g/dL',
        ),
        'HIGH',
      );
      expect(
        interpretLabNumericResultFlag(
          valueText: '21',
          range: withCritical,
          resultUnit: 'g/dL',
        ),
        'CRITICAL_HIGH',
      );
    });

    test('returns null when units cannot be converted', () {
      expect(
        interpretLabNumericResultFlag(
          valueText: '15',
          range: adultMale,
          resultUnit: '%',
        ),
        isNull,
      );
    });
  });

  group('resolveLabOrderItemDisplayReferenceRange with resultUnit', () {
    test('converts gender-matched catalog range into result unit', () {
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
        ],
      );

      expect(
        resolveLabOrderItemDisplayReferenceRange(
          item,
          patientGender: 'male',
          resultUnit: 'g/L',
        ),
        'Adult male | MALE | 135 - 175 g/L',
      );
    });
  });
}
