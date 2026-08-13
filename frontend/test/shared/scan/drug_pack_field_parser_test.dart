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
      expect(result.genericName?.toLowerCase(), contains('paracetamol'));
      expect(result.strength?.toLowerCase(), contains('500'));
      expect(result.batchNumber, 'AB12');
      expect(result.expiryDate?.year, 2028);
      expect(result.expiryDate?.month, 3);
    });

    test('maps Paracetamol pack brand + generic from OCR-like lines', () {
      final DrugPackFieldCandidates result = parser.parse(
        ocrText: '''
AGOMO
Paracetamol Tablets B.P. 500mg
''',
        ocrLines: const <String>[
          'AGOMO',
          'Paracetamol Tablets B.P. 500mg',
        ],
      );

      expect(result.brandName, 'AGOMO');
      expect(result.genericName, 'Paracetamol');
      expect(result.form, 'Tablet');
      expect(result.strength?.toLowerCase(), contains('500'));
    });

    test('maps AI JSON output into candidates', () {
      final DrugPackFieldCandidates result = DrugPackFieldCandidates.fromAiOutput(
        <String, Object?>{
          'generic_name': 'Paracetamol',
          'brand_name': 'AGOMO',
          'form': 'Tablet',
          'strength': '500 mg',
          'batch_number': 'LOT-9',
          'expiry_date': '2027-12-01',
          'barcode': '8901234567890',
          'raw_text': 'AGOMO Paracetamol Tablets 500 mg',
        },
      );

      expect(result.genericName, 'Paracetamol');
      expect(result.brandName, 'AGOMO');
      expect(result.form, 'Tablet');
      expect(result.strength, '500 mg');
      expect(result.batchNumber, 'LOT-9');
      expect(result.expiryDate, DateTime(2027, 12, 1));
      expect(result.barcode, '8901234567890');
      expect(result.hasAnyIdentityField, isTrue);
    });

    test('rejects OCR garbage as brand or generic names', () {
      final DrugPackFieldCandidates result = parser.parse(
        ocrText: ''': S137189VL0LX0\nbw 005 '4'g s191ge] joweiadesel\nTablet\n500 mg''',
      );

      expect(result.form, 'Tablet');
      expect(result.strength?.toLowerCase(), contains('500'));
      expect(result.brandName, isNull);
      expect(result.genericName, isNull);
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
