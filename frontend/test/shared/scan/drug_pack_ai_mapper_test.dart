import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

void main() {
  group('DrugPackLocalAiMapper', () {
    const DrugPackLocalAiMapper mapper = DrugPackLocalAiMapper();

    test('maps cleaned OCR lines into candidates', () async {
      final DrugPackAiMapResult result = await mapper.map(
        rawText: '''
Bw 00s "4*g siege; oweraseiey
AGOMO
Paracetamol
Tablet 500 mg
Batch: LOT-9
''',
        ocrLines: const <String>[
          'Bw 00s "4*g siege; oweraseiey',
          'AGOMO',
          'Paracetamol',
          'Tablet 500 mg',
          'Batch: LOT-9',
        ],
      );

      expect(result.unavailable, isFalse);
      expect(result.hasCandidates, isTrue);
      expect(result.candidates!.brandName, 'AGOMO');
      expect(result.candidates!.genericName, 'Paracetamol');
      expect(result.candidates!.form, 'Tablet');
      expect(result.candidates!.strength?.toLowerCase(), contains('500'));
      expect(result.candidates!.batchNumber, 'LOT-9');
    });
  });

  group('DrugPackUnavailableAiMapper', () {
    test('reports unavailable', () async {
      const DrugPackUnavailableAiMapper mapper = DrugPackUnavailableAiMapper(
        message: 'offline',
      );
      final DrugPackAiMapResult result = await mapper.map(rawText: 'Tablet');
      expect(result.unavailable, isTrue);
      expect(result.message, 'offline');
      expect(result.hasCandidates, isFalse);
    });
  });
}
