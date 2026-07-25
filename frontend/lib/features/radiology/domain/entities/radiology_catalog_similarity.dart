import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int radiologyCatalogSimilarityThreshold = 80;

final class RadiologyCatalogSimilarityMatch {
  const RadiologyCatalogSimilarityMatch({
    required this.test,
    required this.score,
    required this.reasons,
    required this.isExact,
  });

  final RadiologyCatalogTest test;
  final int score;
  final List<String> reasons;
  final bool isExact;
}

final class RadiologyCatalogDuplicateCheckResult {
  const RadiologyCatalogDuplicateCheckResult({
    this.exactNameConflict = false,
    this.exactCodeConflict = false,
    this.similarMatches = const <RadiologyCatalogSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final bool exactCodeConflict;
  final List<RadiologyCatalogSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict || exactCodeConflict;

  List<RadiologyCatalogSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((RadiologyCatalogSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }
}

String normalizeRadiologyCatalogName(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeRadiologyCatalogCode(String value) {
  return value.trim().toUpperCase();
}

RadiologyCatalogDuplicateCheckResult checkRadiologyCatalogDuplicates({
  required String name,
  String? code,
  required List<RadiologyCatalogTest> existing,
  String? excludeTestId,
}) {
  final String normalizedName = normalizeRadiologyCatalogName(name);
  final String normalizedCode = normalizeRadiologyCatalogCode(code ?? '');

  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<RadiologyCatalogSimilarityMatch> matches =
      <RadiologyCatalogSimilarityMatch>[];

  for (final RadiologyCatalogTest test in existing) {
    if (excludeTestId != null &&
        (test.id == excludeTestId || test.apiId == excludeTestId)) {
      continue;
    }

    final String testName = normalizeRadiologyCatalogName(test.name);
    final String testCode = normalizeRadiologyCatalogCode(test.code ?? '');
    final bool nameExact =
        normalizedName.isNotEmpty && testName == normalizedName;
    final bool codeExact =
        normalizedCode.isNotEmpty &&
        testCode.isNotEmpty &&
        testCode == normalizedCode;

    if (nameExact || codeExact) {
      if (nameExact) {
        exactNameConflict = true;
      }
      if (codeExact) {
        exactCodeConflict = true;
      }
      matches.add(
        RadiologyCatalogSimilarityMatch(
          test: test,
          score: 100,
          reasons: <String>[
            if (nameExact) 'name',
            if (codeExact) 'code',
          ],
          isExact: true,
        ),
      );
      continue;
    }

    if (normalizedName.isEmpty || testName.isEmpty) {
      continue;
    }

    final int score = nameSimilarityScore(normalizedName, testName);
    if (score >= radiologyCatalogSimilarityThreshold) {
      matches.add(
        RadiologyCatalogSimilarityMatch(
          test: test,
          score: score,
          reasons: const <String>['name'],
          isExact: false,
        ),
      );
    }
  }

  matches.sort(
    (RadiologyCatalogSimilarityMatch left,
            RadiologyCatalogSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return RadiologyCatalogDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    exactCodeConflict: exactCodeConflict,
    similarMatches: matches,
  );
}
