import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_catalog_similarity.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

void main() {
  group('checkLabCatalogDuplicates', () {
    const List<LabCatalogItem> existing = <LabCatalogItem>[
      LabCatalogItem(
        id: 'lab-1',
        type: LabCatalogItemType.test,
        name: 'Complete Blood Count',
        code: 'CBC-001',
        category: 'Hematology',
      ),
      LabCatalogItem(
        id: 'lab-2',
        type: LabCatalogItemType.test,
        name: 'Liver Function Panel',
        code: 'LFT-001',
        category: 'Liver',
      ),
    ];

    test('detects exact name and code conflicts', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'Complete Blood Count',
        code: 'CBC-001',
        category: 'Hematology',
        existing: existing,
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.exactCodeConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.score, 100);
      expect(result.similarMatches.first.reasons, contains('category'));
    });

    test('detects exact name conflict even when category differs', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'Complete Blood Count',
        code: '',
        category: 'Chemistry',
        existing: existing,
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.hasExactConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.similarMatches.first.isExact, isTrue);
      expect(result.similarMatches.first.categoryScore, 0);
      expect(result.similarMatches.first.nameScore, 100);
    });

    test('detects short exact names such as test', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'test',
        code: 'test',
        category: 'Admission',
        existing: const <LabCatalogItem>[
          LabCatalogItem(
            id: 'lab-3',
            type: LabCatalogItemType.test,
            name: 'test',
            code: 'OTHER',
            category: 'Chemistry',
          ),
        ],
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.hasExactConflict, isTrue);
    });

    test('detects punctuation-equivalent codes as exact conflicts', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'Unique Lab Test',
        code: 'CBC001',
        category: 'Hematology',
        existing: existing,
      );

      expect(result.exactCodeConflict, isTrue);
    });

    test('detects similar names above threshold', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'Complete Blood Countt',
        code: 'NEW-001',
        category: 'Hematology',
        existing: existing,
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(result.nonExactSimilarMatches.first.reasons, contains('name'));
      expect(result.nonExactSimilarMatches.first.nameScore, isNotNull);
      expect(
        result.nonExactSimilarMatches.first.nameScore!,
        greaterThanOrEqualTo(labCatalogSimilarityThreshold),
      );
    });

    test('excludes the current item by id', () {
      final LabCatalogDuplicateCheckResult result = checkLabCatalogDuplicates(
        name: 'Complete Blood Count',
        code: 'CBC-001',
        category: 'Hematology',
        existing: existing,
        excludeTestId: 'lab-1',
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('mergeLabCatalogDuplicateChecks combines exact conflicts', () {
      final LabCatalogDuplicateCheckResult merged =
          mergeLabCatalogDuplicateChecks(<LabCatalogDuplicateCheckResult>[
            checkLabCatalogDuplicates(
              name: 'Complete Blood Count',
              code: '',
              category: 'Hematology',
              existing: existing,
            ),
            checkLabCatalogDuplicates(
              name: 'Other',
              code: 'CBC-001',
              category: 'Hematology',
              existing: existing,
            ),
          ]);

      expect(merged.exactNameConflict, isTrue);
      expect(merged.exactCodeConflict, isTrue);
    });
  });
}
