import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

const int radiologyCatalogSimilarityThreshold = 80;
const int radiologyCatalogTokenMatchThreshold = 85;

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

RadiologyCatalogDuplicateCheckResult mergeRadiologyCatalogDuplicateChecks(
  Iterable<RadiologyCatalogDuplicateCheckResult> checks,
) {
  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<RadiologyCatalogSimilarityMatch> matches =
      <RadiologyCatalogSimilarityMatch>[];

  for (final RadiologyCatalogDuplicateCheckResult check in checks) {
    exactNameConflict = exactNameConflict || check.exactNameConflict;
    exactCodeConflict = exactCodeConflict || check.exactCodeConflict;
    matches.addAll(check.similarMatches);
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

String normalizeRadiologyCatalogCodeForSimilarity(String value) {
  return normalizeRadiologyCatalogCode(value).replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

List<String> radiologyCatalogTokens(String normalizedValue) {
  return normalizedValue
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

int radiologyTextSimilarityScore(
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
  if (!_canReachSimilarityThreshold(left.length, right.length)) {
    return 0;
  }

  final int fullScore = _levenshteinSimilarityPercent(left, right);
  if (!includeTokenSimilarity) {
    return fullScore;
  }
  final int tokenScore = _tokenSimilarityPercent(left, right);
  return fullScore > tokenScore ? fullScore : tokenScore;
}

bool _canReachSimilarityThreshold(int leftLength, int rightLength) {
  final int maxLength = leftLength > rightLength ? leftLength : rightLength;
  if (maxLength == 0) {
    return true;
  }
  final int lengthDelta = (leftLength - rightLength).abs();
  final int maxDistance =
      ((maxLength * (100 - radiologyCatalogSimilarityThreshold)) / 100)
          .floor();
  return lengthDelta <= maxDistance;
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
  final List<String> leftTokens = radiologyCatalogTokens(left);
  final List<String> rightTokens = radiologyCatalogTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
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
    if (bestIndex >= 0 && bestScore >= radiologyCatalogTokenMatchThreshold) {
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

RadiologyCatalogDuplicateCheckResult checkRadiologyCatalogDuplicates({
  required String name,
  String? code,
  required List<RadiologyCatalogTest> existing,
  String? excludeTestId,
  bool includeTokenSimilarity = true,
}) {
  final String normalizedName = normalizeRadiologyCatalogName(name);
  final String normalizedCode = normalizeRadiologyCatalogCode(code ?? '');
  final String similarityCode = normalizeRadiologyCatalogCodeForSimilarity(
    code ?? '',
  );

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
    final String testSimilarityCode = normalizeRadiologyCatalogCodeForSimilarity(
      test.code ?? '',
    );
    final bool nameExact =
        normalizedName.isNotEmpty && testName == normalizedName;
    final bool codeExact =
        normalizedCode.isNotEmpty &&
        testCode.isNotEmpty &&
        (testCode == normalizedCode ||
            (similarityCode.isNotEmpty &&
                testSimilarityCode == similarityCode));

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

    final List<String> reasons = <String>[];
    var bestScore = 0;

    if (normalizedName.isNotEmpty && testName.isNotEmpty) {
      final int nameScore = radiologyTextSimilarityScore(
        normalizedName,
        testName,
        includeTokenSimilarity: includeTokenSimilarity,
      );
      if (nameScore >= radiologyCatalogSimilarityThreshold) {
        reasons.add('name');
        if (nameScore > bestScore) {
          bestScore = nameScore;
        }
      }
    }

    if (similarityCode.isNotEmpty && testSimilarityCode.isNotEmpty) {
      final int codeScore = radiologyTextSimilarityScore(
        similarityCode,
        testSimilarityCode,
        includeTokenSimilarity: false,
      );
      if (codeScore >= radiologyCatalogSimilarityThreshold) {
        reasons.add('code');
        if (codeScore > bestScore) {
          bestScore = codeScore;
        }
      }
    }

    if (reasons.isEmpty) {
      continue;
    }

    matches.add(
      RadiologyCatalogSimilarityMatch(
        test: test,
        score: bestScore,
        reasons: reasons,
        isExact: false,
      ),
    );
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
