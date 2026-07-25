import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

void main() {
  group('checkRadiologyCatalogDuplicates', () {
    const List<RadiologyCatalogProcedure> existing = <RadiologyCatalogProcedure>[
      RadiologyCatalogProcedure(
        id: 'rad-1',
        name: 'Chest X-Ray',
        code: 'CXR-001',
        modality: 'XRAY',
      ),
      RadiologyCatalogProcedure(
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
            modality: 'XRAY',
            existing: existing,
          );

      expect(result.exactNameConflict, isTrue);
      expect(result.exactCodeConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.score, 100);
      expect(result.similarMatches.first.reasons, contains('modality'));
    });

    test('lowers composite score when modality differs on exact name', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Ray',
            code: '',
            modality: 'MRI',
            existing: existing,
          );

      expect(result.exactNameConflict, isFalse);
      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(result.nonExactSimilarMatches.first.score, lessThan(100));
      expect(result.nonExactSimilarMatches.first.modalityScore, 0);
      expect(result.nonExactSimilarMatches.first.nameScore, 100);
    });

    test('detects punctuation-equivalent codes as exact conflicts', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Unique Procedure',
            code: 'CXR001',
            modality: 'XRAY',
            existing: existing,
          );

      expect(result.exactCodeConflict, isTrue);
    });

    test('detects similar names above threshold', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Rayy',
            code: 'NEW-001',
            modality: 'XRAY',
            existing: existing,
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.reasons,
        contains('name'),
      );
      expect(result.nonExactSimilarMatches.first.nameScore, isNotNull);
      expect(
        result.nonExactSimilarMatches.first.nameScore!,
        greaterThanOrEqualTo(radiologyCatalogSimilarityThreshold),
      );
    });

    test('composite score uses name, code, and modality weights', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Rayy',
            code: 'CXR-002',
            modality: 'XRAY',
            existing: existing,
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      final RadiologyCatalogSimilarityMatch match =
          result.nonExactSimilarMatches.first;
      expect(match.codeScore, isNotNull);
      expect(
        match.codeScore!,
        greaterThanOrEqualTo(radiologyCatalogSimilarityThreshold),
      );
      expect(match.modalityScore, 100);
      expect(match.nameScore, isNotNull);
      expect(
        match.score,
        radiologyCompositeSimilarityScore(
          nameScore: match.nameScore,
          codeScore: match.codeScore,
          modalityScore: match.modalityScore,
        ),
      );
      expect(
        match.score,
        lessThan(100),
      );
    });

    test('detects similar codes above threshold', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Totally Unique Procedure',
            code: 'CXR-002',
            modality: 'CT',
            existing: existing,
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.reasons,
        contains('code'),
      );
    });

    test('detects token-order and misspelling variants in names', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Xray Chest',
            code: 'UNIQUE-99',
            modality: 'XRAY',
            existing: existing,
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.nameScore!,
        greaterThanOrEqualTo(radiologyCatalogSimilarityThreshold),
      );
    });

    test('ignores excluded test when editing', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Ray',
            code: 'CXR-001',
            modality: 'XRAY',
            existing: existing,
            excludeProcedureId: 'rad-1',
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('ignores excluded procedure when exclude id matches displayId', () {
      const List<RadiologyCatalogProcedure> withDisplayIds =
          <RadiologyCatalogProcedure>[
            const RadiologyCatalogProcedure(
              id: 'uuid-1',
              displayId: 'RAD-CHEST-1',
              name: 'Chest X-Ray',
              code: 'CXR-001',
              modality: 'XRAY',
            ),
            const RadiologyCatalogProcedure(
              id: 'uuid-2',
              displayId: 'RAD-MRI-1',
              name: 'Brain MRI',
              code: 'MRI-001',
              modality: 'MRI',
            ),
          ];

      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Chest X-Ray',
            code: 'CXR-001',
            modality: 'XRAY',
            existing: withDisplayIds,
            excludeProcedureId: 'RAD-CHEST-1',
          );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('still flags exact conflicts against other procedures while editing', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Brain MRI',
            code: 'MRI-001',
            modality: 'MRI',
            existing: existing,
            excludeProcedureId: 'rad-1',
          );

      expect(result.exactNameConflict, isTrue);
      expect(result.exactCodeConflict, isTrue);
      expect(result.hasExactConflict, isTrue);
    });

    test('ignores empty code when checking code conflicts', () {
      final RadiologyCatalogDuplicateCheckResult result =
          checkRadiologyCatalogDuplicates(
            name: 'Unique Procedure',
            code: '',
            modality: 'CT',
            existing: existing,
          );

      expect(result.exactCodeConflict, isFalse);
      expect(result.hasExactConflict, isFalse);
    });
  });

  group('radiologyCompositeSimilarityScore', () {
    test('weights name, code, and modality', () {
      expect(
        radiologyCompositeSimilarityScore(
          nameScore: 100,
          codeScore: 0,
          modalityScore: 100,
        ),
        70,
      );
    });

    test('ignores missing parameters', () {
      expect(
        radiologyCompositeSimilarityScore(nameScore: 80, modalityScore: 100),
        86,
      );
    });
  });

  group('radiologyTextSimilarityScore', () {
    test('scores identical normalized text as 100', () {
      expect(radiologyTextSimilarityScore('chest xray', 'chest xray'), 100);
    });
  });
}
