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

    test('allows same label with different age bands', () {
      final EditableLabReferenceRange adult = EditableLabReferenceRange();
      final EditableLabReferenceRange pediatric = EditableLabReferenceRange();
      adult.labelController.text = 'Adult';
      adult.ageMinController.text = '18';
      pediatric.labelController.text = 'Adult';
      pediatric.ageMinController.text = '0';
      pediatric.ageMaxController.text = '17';

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
      final EditableLabReferenceRange range = EditableLabReferenceRange();
      range.normalMinController.text = '10';
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
