import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

const int labCatalogSimilarityThreshold = 80;
const int labCatalogTokenMatchThreshold = 85;
const int labCatalogNameWeight = 50;
const int labCatalogCodeWeight = 30;
const int labCatalogCategoryWeight = 20;

final class LabCatalogSimilarityMatch {
  const LabCatalogSimilarityMatch({
    required this.item,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.nameScore,
    this.codeScore,
    this.categoryScore,
  });

  final LabCatalogItem item;

  /// Composite match score across available parameters (name/code/category).
  final int score;
  final List<String> reasons;
  final bool isExact;
  final int? nameScore;
  final int? codeScore;
  final int? categoryScore;
}

final class LabCatalogDuplicateCheckResult {
  const LabCatalogDuplicateCheckResult({
    this.exactNameConflict = false,
    this.exactCodeConflict = false,
    this.similarMatches = const <LabCatalogSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final bool exactCodeConflict;
  final List<LabCatalogSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict || exactCodeConflict;

  List<LabCatalogSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((LabCatalogSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }
}

LabCatalogDuplicateCheckResult mergeLabCatalogDuplicateChecks(
  Iterable<LabCatalogDuplicateCheckResult> checks,
) {
  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<LabCatalogSimilarityMatch> matches =
      <LabCatalogSimilarityMatch>[];

  for (final LabCatalogDuplicateCheckResult check in checks) {
    exactNameConflict = exactNameConflict || check.exactNameConflict;
    exactCodeConflict = exactCodeConflict || check.exactCodeConflict;
    matches.addAll(check.similarMatches);
  }

  matches.sort(
    (LabCatalogSimilarityMatch left, LabCatalogSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return LabCatalogDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    exactCodeConflict: exactCodeConflict,
    similarMatches: matches,
  );
}

String normalizeLabCatalogName(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeLabCatalogCode(String value) {
  return value.trim().toUpperCase();
}

String normalizeLabCatalogCodeForSimilarity(String value) {
  return normalizeLabCatalogCode(value).replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

String normalizeLabCatalogCategory(String value) {
  // Same shape as names so category misspellings score consistently.
  return normalizeLabCatalogName(value);
}

List<String> labCatalogTokens(String normalizedValue) {
  return normalizedValue
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

int labTextSimilarityScore(
  String left,
  String right, {
  bool includeTokenSimilarity = true,
}) {
  if (left == right) {
    return 100;
  }
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }

  // Always compute the real edit/token score so misspellings surface in the
  // composite % even when they sit below the match threshold.
  final int fullScore = _levenshteinSimilarityPercent(left, right);
  if (!includeTokenSimilarity) {
    return fullScore;
  }
  final int tokenScore = _tokenSimilarityPercent(left, right);
  return fullScore > tokenScore ? fullScore : tokenScore;
}

/// Weighted composite of available parameter scores (name/code/category).
int labCompositeSimilarityScore({
  int? nameScore,
  int? codeScore,
  int? categoryScore,
}) {
  var weightedTotal = 0;
  var weightSum = 0;

  if (nameScore != null) {
    weightedTotal += nameScore * labCatalogNameWeight;
    weightSum += labCatalogNameWeight;
  }
  if (codeScore != null) {
    weightedTotal += codeScore * labCatalogCodeWeight;
    weightSum += labCatalogCodeWeight;
  }
  if (categoryScore != null) {
    weightedTotal += categoryScore * labCatalogCategoryWeight;
    weightSum += labCatalogCategoryWeight;
  }

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round().clamp(0, 100);
}

int _levenshteinSimilarityPercent(String left, String right) {
  final int distance = _levenshteinDistance(left, right);
  final int maxLength = left.length > right.length ? left.length : right.length;
  if (maxLength == 0) {
    return 100;
  }
  return (((maxLength - distance) / maxLength) * 100).round().clamp(0, 100);
}

int _tokenSimilarityPercent(String left, String right) {
  final List<String> leftTokens = labCatalogTokens(left);
  final List<String> rightTokens = labCatalogTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
  }
  // Single-token pairs: use edit distance directly so misspellings
  // (e.g. Haematology vs Hematology) do not collapse to 100% via Jaccard.
  if (leftTokens.length == 1 && rightTokens.length == 1) {
    return _levenshteinSimilarityPercent(leftTokens.first, rightTokens.first);
  }

  final int forward = _averageBestTokenScore(leftTokens, rightTokens);
  final int reverse = _averageBestTokenScore(rightTokens, leftTokens);
  final int averageDirectional = ((forward + reverse) / 2).round();

  var fuzzyIntersection = 0;
  final List<bool> used = List<bool>.filled(rightTokens.length, false);
  for (final String leftToken in leftTokens) {
    var bestIndex = -1;
    var bestScore = -1;
    for (int i = 0; i < rightTokens.length; i++) {
      if (used[i]) {
        continue;
      }
      final int score = _levenshteinSimilarityPercent(leftToken, rightTokens[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestScore >= labCatalogTokenMatchThreshold) {
      used[bestIndex] = true;
      fuzzyIntersection += 1;
    }
  }
  final int union = leftTokens.length + rightTokens.length - fuzzyIntersection;
  final int jaccard = union == 0
      ? 0
      : ((fuzzyIntersection / union) * 100).round().clamp(0, 100);

  return averageDirectional > jaccard ? averageDirectional : jaccard;
}

int _averageBestTokenScore(List<String> source, List<String> target) {
  var total = 0;
  for (final String token in source) {
    var best = 0;
    for (final String candidate in target) {
      final int score = _levenshteinSimilarityPercent(token, candidate);
      if (score > best) {
        best = score;
      }
    }
    total += best;
  }
  return (total / source.length).round().clamp(0, 100);
}

int _levenshteinDistance(String left, String right) {
  if (left == right) {
    return 0;
  }
  if (left.isEmpty) {
    return right.length;
  }
  if (right.isEmpty) {
    return left.length;
  }

  final List<int> previous = List<int>.generate(
    right.length + 1,
    (int index) => index,
    growable: false,
  );
  final List<int> current = List<int>.filled(right.length + 1, 0);

  for (int i = 0; i < left.length; i++) {
    current[0] = i + 1;
    for (int j = 0; j < right.length; j++) {
      final int substitutionCost = left.codeUnitAt(i) == right.codeUnitAt(j)
          ? 0
          : 1;
      current[j + 1] = _min3(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + substitutionCost,
      );
    }
    for (int j = 0; j <= right.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous[right.length];
}

int _min3(int a, int b, int c) {
  return a < b ? (a < c ? a : c) : (b < c ? b : c);
}

bool labCatalogItemMatchesExcludeId(
  LabCatalogItem item,
  String? excludeTestId,
) {
  final String? excludeId = excludeTestId?.trim();
  if (excludeId == null || excludeId.isEmpty) {
    return false;
  }
  return item.id == excludeId ||
      item.apiId == excludeId ||
      (item.displayId?.trim().isNotEmpty == true &&
          item.displayId!.trim() == excludeId);
}

LabCatalogDuplicateCheckResult checkLabCatalogDuplicates({
  required String name,
  String? code,
  String? category,
  required List<LabCatalogItem> existing,
  String? excludeTestId,
  bool includeTokenSimilarity = true,
}) {
  final String normalizedName = normalizeLabCatalogName(name);
  final String normalizedCode = normalizeLabCatalogCode(code ?? '');
  final String similarityCode = normalizeLabCatalogCodeForSimilarity(
    code ?? '',
  );
  final String normalizedCategory = normalizeLabCatalogCategory(category ?? '');

  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<LabCatalogSimilarityMatch> matches =
      <LabCatalogSimilarityMatch>[];

  for (final LabCatalogItem test in existing) {
    if (labCatalogItemMatchesExcludeId(test, excludeTestId)) {
      continue;
    }

    final String testName = normalizeLabCatalogName(test.name ?? '');
    final String testCode = normalizeLabCatalogCode(test.code ?? '');
    final String testSimilarityCode = normalizeLabCatalogCodeForSimilarity(
      test.code ?? '',
    );
    final String testCategory = normalizeLabCatalogCategory(test.category ?? '');

    final bool nameExact =
        normalizedName.isNotEmpty && testName == normalizedName;
    final bool codeExact =
        normalizedCode.isNotEmpty &&
        testCode.isNotEmpty &&
        (testCode == normalizedCode ||
            (similarityCode.isNotEmpty &&
                testSimilarityCode == similarityCode));
    final bool categoryExact =
        normalizedCategory.isNotEmpty &&
        testCategory.isNotEmpty &&
        normalizedCategory == testCategory;

    int? nameScore;
    int? codeScore;
    int? categoryScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && testName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : labTextSimilarityScore(
              normalizedName,
              testName,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (nameExact || nameScore >= labCatalogSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (similarityCode.isNotEmpty && testSimilarityCode.isNotEmpty) {
      codeScore = codeExact
          ? 100
          : labTextSimilarityScore(
              similarityCode,
              testSimilarityCode,
              includeTokenSimilarity: false,
            );
      if (codeExact || codeScore >= labCatalogSimilarityThreshold) {
        reasons.add('code');
      }
    }

    if (normalizedCategory.isNotEmpty && testCategory.isNotEmpty) {
      categoryScore = categoryExact
          ? 100
          : labTextSimilarityScore(
              normalizedCategory,
              testCategory,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (categoryExact || categoryScore >= labCatalogSimilarityThreshold) {
        reasons.add('category');
      }
    }

    final int compositeScore = labCompositeSimilarityScore(
      nameScore: nameScore,
      codeScore: codeScore,
      categoryScore: categoryScore,
    );

    // Exact name/code is a hard uniqueness block. Composite % still weights
    // every available parameter (name, code, category), including misspellings.
    final bool hardNameConflict = nameExact;
    final bool isExact = hardNameConflict || codeExact;
    if (isExact) {
      if (hardNameConflict) {
        exactNameConflict = true;
      }
      if (codeExact) {
        exactCodeConflict = true;
      }
      matches.add(
        LabCatalogSimilarityMatch(
          item: test,
          score: compositeScore,
          reasons: reasons.isEmpty
              ? <String>[
                  if (hardNameConflict) 'name',
                  if (codeExact) 'code',
                ]
              : reasons,
          isExact: true,
          nameScore: nameScore,
          codeScore: codeScore,
          categoryScore: categoryScore,
        ),
      );
      continue;
    }

    final bool strongFieldSignal =
        (nameScore != null &&
            nameScore >= labCatalogSimilarityThreshold) ||
        (codeScore != null &&
            codeScore >= labCatalogSimilarityThreshold) ||
        (categoryScore != null &&
            categoryScore >= labCatalogSimilarityThreshold);
    final bool compositeSignal =
        compositeScore >= labCatalogSimilarityThreshold;

    if (!strongFieldSignal && !compositeSignal) {
      continue;
    }

    matches.add(
      LabCatalogSimilarityMatch(
        item: test,
        score: compositeScore,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: false,
        nameScore: nameScore,
        codeScore: codeScore,
        categoryScore: categoryScore,
      ),
    );
  }

  matches.sort(
    (LabCatalogSimilarityMatch left, LabCatalogSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return LabCatalogDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    exactCodeConflict: exactCodeConflict,
    similarMatches: matches,
  );
}
