import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

void main() {
  const DrugPackFieldParser parser = DrugPackFieldParser();

  group('DrugPackFieldParser', () {
    test('maps barcode + OCR fixture into field candidates', () {
      const String ocr = '''
Amoxil
Amoxicillin
Capsule 500mg
Batch: LOT-7788
MFG: 01/2025
EXP: 12/2027
NDC: AMX-500
8901234567890
''';

      final DrugPackFieldCandidates result = parser.parse(
        barcode: '8901234567890',
        ocrText: ocr,
      );

      expect(result.barcode, '8901234567890');
      expect(result.code, isNotNull);
      expect(result.form, 'Capsule');
      expect(result.strength?.toLowerCase(), contains('500'));
      expect(result.batchNumber, 'LOT-7788');
      expect(result.manufacturedAt, isNotNull);
      expect(result.expiryDate, isNotNull);
      expect(result.hasAnyIdentityField, isTrue);
    });

    test('extracts form abbreviations and strength without barcode', () {
      final DrugPackFieldCandidates result = parser.parse(
        ocrText: 'Paracetamol tabs 500 mg\nLot No. AB12\nExp: Mar 2028',
      );

      expect(result.form, 'Tablet');
      expect(result.strength?.toLowerCase(), contains('500'));
      expect(result.batchNumber, 'AB12');
      expect(result.expiryDate?.year, 2028);
      expect(result.expiryDate?.month, 3);
    });
  });

  group('AppSuggestedFieldSet', () {
    test('accept and accept-all clear highlight state', () {
      final AppSuggestedFieldSet suggestions = AppSuggestedFieldSet(<String>[
        PharmacyDrugSuggestedFields.genericName,
        PharmacyDrugSuggestedFields.brandName,
        PharmacyDrugSuggestedFields.code,
      ]);

      expect(suggestions.hasPending, isTrue);
      expect(
        suggestions.isSuggested(PharmacyDrugSuggestedFields.genericName),
        isTrue,
      );

      suggestions.accept(PharmacyDrugSuggestedFields.genericName);
      expect(
        suggestions.isSuggested(PharmacyDrugSuggestedFields.genericName),
        isFalse,
      );
      expect(suggestions.pendingCount, 2);

      suggestions.acceptAll();
      expect(suggestions.hasPending, isFalse);
      expect(suggestions.pendingCount, 0);
    });

    test('edit clears suggested state for a field', () {
      final AppSuggestedFieldSet suggestions = AppSuggestedFieldSet(<String>[
        PharmacyDrugSuggestedFields.form,
      ]);
      suggestions.edit(PharmacyDrugSuggestedFields.form);
      expect(suggestions.isSuggested(PharmacyDrugSuggestedFields.form), isFalse);
    });
  });
}
