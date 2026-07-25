import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

void main() {
  group('checkRadiologyCatalogDuplicates', () {
    const List<RadiologyCatalogTest> existing = <RadiologyCatalogTest>[
      RadiologyCatalogTest(
        id: 'rad-1',
        name: 'Chest X-Ray',
        code: 'CXR-001',
        modality: 'XRAY',
      ),
      RadiologyCatalogTest(
        id: 'rad-2',
        name: 'Brain MRI',
        code: 'MRI-001',
        modality: 'MRI',
      ),
    ];

    test('detects exact name and code conflicts', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Ray',
            code: 'CXR-001',
            existing: existing,
          );

      expect(result.exactNameConflict, isTrue);
      expect(result.exactCodeConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
    });

    test('detects similar names above threshold', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Rayy',
            code: 'NEW-001',
            existing: existing,
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.score,
        greaterThanOrEqualTo(radiologyCatalogSimilarityThreshold),
      );
    });

    test('ignores excluded test when editing', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Ray',
            code: 'CXR-001',
            existing: existing,
            excludeTestId: 'rad-1',
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('ignores empty code when checking code conflicts', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Unique Procedure',
            code: '',
            existing: existing,
          );

      expect(result.exactCodeConflict, isFalse);
      expect(result.hasExactConflict, isFalse);
    });
  });
}
