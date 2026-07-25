import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/lab_catalog/lab_reference_range_list_field.dart';

void main() {
  group('labReferenceRangesHaveDuplicateApplicability', () {
    test('detects duplicate label/gender/age band', () {
      final EditableLabReferenceRange first = EditableLabReferenceRange();
      final EditableLabReferenceRange second = EditableLabReferenceRange();
      first.labelController.text = 'Adult';
      second.labelController.text = 'Adult';

      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          first,
          second,
        ]),
        isTrue,
      );

      first.dispose();
      second.dispose();
    });

    test('allows same label with different non-overlapping age bands', () {
      final EditableLabReferenceRange adult = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setAllAges(value: false)
        ..setSpecificGender('MALE')
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';
      final EditableLabReferenceRange pediatric = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setAllAges(value: false)
        ..setSpecificGender('MALE')
        ..ageMinController.text = '0'
        ..ageMaxController.text = '17';

      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          adult,
          pediatric,
        ]),
        isFalse,
      );

      adult.dispose();
      pediatric.dispose();
    });

    test('All genders overlaps a specific gender on the same age band', () {
      final EditableLabReferenceRange allGenders = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setAllGenders()
        ..setAllAges(value: false)
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';
      final EditableLabReferenceRange male = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setSpecificGender('MALE')
        ..setAllAges(value: false)
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';

      expect(labReferenceRangesOverlap(allGenders, male), isTrue);
      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          allGenders,
          male,
        ]),
        isTrue,
      );

      allGenders.dispose();
      male.dispose();
    });

    test('All ages overlaps a specific age band on the same gender', () {
      final EditableLabReferenceRange allAges = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setSpecificGender('FEMALE')
        ..setAllAges(value: true);
      final EditableLabReferenceRange band = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setSpecificGender('FEMALE')
        ..setAllAges(value: false)
        ..ageMinController.text = '18'
        ..ageMaxController.text = '45';

      expect(labReferenceRangesOverlap(allAges, band), isTrue);
      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          allAges,
          band,
        ]),
        isTrue,
      );

      allAges.dispose();
      band.dispose();
    });

    test('allows same label with different genders and same age band', () {
      final EditableLabReferenceRange male = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setSpecificGender('MALE')
        ..setAllAges(value: false)
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';
      final EditableLabReferenceRange female = EditableLabReferenceRange()
        ..labelController.text = 'Adult'
        ..setSpecificGender('FEMALE')
        ..setAllAges(value: false)
        ..ageMinController.text = '18'
        ..ageMaxController.text = '65';

      expect(labReferenceRangesOverlap(male, female), isFalse);
      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          male,
          female,
        ]),
        isFalse,
      );

      male.dispose();
      female.dispose();
    });

    test('ignores fully empty optional rows', () {
      final EditableLabReferenceRange filled = EditableLabReferenceRange();
      final EditableLabReferenceRange empty = EditableLabReferenceRange();
      filled.labelController.text = 'Adult';

      expect(
        labReferenceRangesHaveDuplicateApplicability(<EditableLabReferenceRange>[
          filled,
          empty,
        ]),
        isFalse,
      );

      filled.dispose();
      empty.dispose();
    });
  });

  group('EditableLabReferenceRange.isValid', () {
    test('passes empty optional numeric bounds', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      expect(range.isValid(), isTrue);
      range.dispose();
    });

    test('allows open-ended numeric bounds', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange()
        ..setAllAges(value: false)
        ..normalMinController.text = '10';
      expect(range.isValid(), isTrue);
      range.dispose();
    });

    test('rejects non-numeric filled bounds', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      range.normalMinController.text = 'abc';
      expect(range.isValid(), isFalse);
      expect(range.hasNonNumericBound(), isTrue);
      range.dispose();
    });

    test('rejects inverted normal bounds', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      range.normalMinController.text = '10';
      range.normalMaxController.text = '5';
      expect(range.isValid(), isFalse);
      range.dispose();
    });

    test('allows equal age min and max', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange()
        ..setAllAges(value: false)
        ..ageMinController.text = '0'
        ..ageMaxController.text = '0'
        ..normalMinController.text = '10'
        ..normalMaxController.text = '15';
      expect(range.isValid(), isTrue);
      range.dispose();
    });

    test('rejects critical min above normal min', () {
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      range.normalMinController.text = '10';
      range.criticalMinController.text = '12';
      expect(range.isValid(), isFalse);
      expect(range.contradictsCriticalVsNormal(), isTrue);
      range.dispose();
    });
  });
}
