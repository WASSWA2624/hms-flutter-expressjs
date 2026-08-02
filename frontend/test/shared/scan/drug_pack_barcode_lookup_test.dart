import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/scan/scan.dart';

void main() {
  group('CompositeDrugPackBarcodeLookup', () {
    test('returns first provider hit and soft-fails empty providers', () async {
      final DrugPackBarcodeLookup lookup = CompositeDrugPackBarcodeLookup(
        <DrugPackBarcodeLookup>[
          const DrugPackNoOpBarcodeLookup(),
          _FixedLookup(
            const DrugPackFieldCandidates(
              brandName: 'Amoxil',
              genericName: 'Amoxicillin',
              form: 'Capsule',
            ),
          ),
        ],
      );

      final DrugPackFieldCandidates? hit = await lookup.lookup('8901234567890');
      expect(hit, isNotNull);
      expect(hit!.brandName, 'Amoxil');
      expect(hit.barcode, '8901234567890');

      final DrugPackFieldCandidates? miss =
          await const CompositeDrugPackBarcodeLookup(
            <DrugPackBarcodeLookup>[DrugPackNoOpBarcodeLookup()],
          ).lookup('000');
      expect(miss, isNull);
    });

    test('swallows provider errors and continues', () async {
      final DrugPackBarcodeLookup lookup = CompositeDrugPackBarcodeLookup(
        <DrugPackBarcodeLookup>[
          const _ThrowingLookup(),
          _FixedLookup(
            const DrugPackFieldCandidates(genericName: 'Paracetamol'),
          ),
        ],
      );
      final DrugPackFieldCandidates? hit = await lookup.lookup('12345678');
      expect(hit?.genericName, 'Paracetamol');
    });
  });
}

final class _FixedLookup implements DrugPackBarcodeLookup {
  const _FixedLookup(this.candidates);

  final DrugPackFieldCandidates candidates;

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async => candidates;
}

final class _ThrowingLookup implements DrugPackBarcodeLookup {
  const _ThrowingLookup();

  @override
  Future<DrugPackFieldCandidates?> lookup(String barcode) async {
    throw StateError('network');
  }
}
