import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';

const int radiologyCatalogSimilarityThreshold = 80;
const int radiologyCatalogTokenMatchThreshold = 85;
const int radiologyCatalogNameWeight = 50;
const int radiologyCatalogCodeWeight = 30;
const int radiologyCatalogModalityWeight = 20;

final class RadiologyCatalogSimilarityMatch {
  const RadiologyCatalogSimilarityMatch({
    required this.procedure,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.nameScore,
    this.codeScore,
    this.modalityScore,
  });

  final RadiologyCatalogProcedure procedure;

  /// Composite match score across available parameters (name/code/modality).
  final int score;
  final List<String> reasons;
  final bool isExact;
  final int? nameScore;
  final int? codeScore;
  final int? modalityScore;
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

String normalizeRadiologyCatalogModality(String value) {
  // Same shape as names so modality misspellings score consistently.
  return normalizeRadiologyCatalogName(value);
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

  // Always compute the real edit/token score so misspellings surface in the
  // composite % even when they sit below the match threshold.
  final int fullScore = _levenshteinSimilarityPercent(left, right);
  if (!includeTokenSimilarity) {
    return fullScore;
  }
  final int tokenScore = _tokenSimilarityPercent(left, right);
  return fullScore > tokenScore ? fullScore : tokenScore;
}

/// Weighted composite of available parameter scores (name/code/modality).
int radiologyCompositeSimilarityScore({
  int? nameScore,
  int? codeScore,
  int? modalityScore,
}) {
  var weightedTotal = 0;
  var weightSum = 0;

  if (nameScore != null) {
    weightedTotal += nameScore * radiologyCatalogNameWeight;
    weightSum += radiologyCatalogNameWeight;
  }
  if (codeScore != null) {
    weightedTotal += codeScore * radiologyCatalogCodeWeight;
    weightSum += radiologyCatalogCodeWeight;
  }
  if (modalityScore != null) {
    weightedTotal += modalityScore * radiologyCatalogModalityWeight;
    weightSum += radiologyCatalogModalityWeight;
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
  final List<String> leftTokens = radiologyCatalogTokens(left);
  final List<String> rightTokens = radiologyCatalogTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
  }
  // Single-token pairs: use edit distance directly so misspellings
  // do not collapse to 100% via Jaccard.
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

bool radiologyCatalogProcedureMatchesExcludeId(
  RadiologyCatalogProcedure procedure,
  String? excludeProcedureId, {
  Iterable<String> excludeProcedureIds = const <String>[],
}) {
  final Set<String> excluded = <String>{
    if (excludeProcedureId != null && excludeProcedureId.trim().isNotEmpty)
      excludeProcedureId.trim(),
    for (final String id in excludeProcedureIds)
      if (id.trim().isNotEmpty) id.trim(),
  };
  if (excluded.isEmpty) {
    return false;
  }
  final Set<String> candidates = <String>{
    procedure.id.trim(),
    procedure.apiId.trim(),
    procedure.effectiveId.trim(),
    if ((procedure.displayId ?? '').trim().isNotEmpty)
      procedure.displayId!.trim(),
  }..removeWhere((String value) => value.isEmpty);
  for (final String candidate in candidates) {
    for (final String excludedId in excluded) {
      if (candidate == excludedId ||
          candidate.toUpperCase() == excludedId.toUpperCase()) {
        return true;
      }
    }
  }
  return false;
}

RadiologyCatalogDuplicateCheckResult checkRadiologyCatalogDuplicates({
  required String name,
  String? code,
  String? modality,
  required List<RadiologyCatalogProcedure> existing,
  String? excludeProcedureId,
  Iterable<String> excludeProcedureIds = const <String>[],
  bool includeTokenSimilarity = true,
}) {
  final String normalizedName = normalizeRadiologyCatalogName(name);
  final String normalizedCode = normalizeRadiologyCatalogCode(code ?? '');
  final String similarityCode = normalizeRadiologyCatalogCodeForSimilarity(
    code ?? '',
  );
  final String normalizedModality = normalizeRadiologyCatalogModality(
    modality ?? '',
  );

  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<RadiologyCatalogSimilarityMatch> matches =
      <RadiologyCatalogSimilarityMatch>[];

  for (final RadiologyCatalogProcedure test in existing) {
    if (radiologyCatalogProcedureMatchesExcludeId(
      test,
      excludeProcedureId,
      excludeProcedureIds: excludeProcedureIds,
    )) {
      continue;
    }

    final String testName = normalizeRadiologyCatalogName(test.name);
    final String testCode = normalizeRadiologyCatalogCode(test.code ?? '');
    final String testSimilarityCode = normalizeRadiologyCatalogCodeForSimilarity(
      test.code ?? '',
    );
    final String testModality = normalizeRadiologyCatalogModality(
      test.modality ?? '',
    );

    final bool nameExact =
        normalizedName.isNotEmpty && testName == normalizedName;
    final bool codeExact =
        normalizedCode.isNotEmpty &&
        testCode.isNotEmpty &&
        (testCode == normalizedCode ||
            (similarityCode.isNotEmpty &&
                testSimilarityCode == similarityCode));
    final bool modalityExact =
        normalizedModality.isNotEmpty &&
        testModality.isNotEmpty &&
        normalizedModality == testModality;

    int? nameScore;
    int? codeScore;
    int? modalityScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && testName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : radiologyTextSimilarityScore(
              normalizedName,
              testName,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (nameExact || nameScore >= radiologyCatalogSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (similarityCode.isNotEmpty && testSimilarityCode.isNotEmpty) {
      codeScore = codeExact
          ? 100
          : radiologyTextSimilarityScore(
              similarityCode,
              testSimilarityCode,
              includeTokenSimilarity: false,
            );
      if (codeExact || codeScore >= radiologyCatalogSimilarityThreshold) {
        reasons.add('code');
      }
    }

    if (normalizedModality.isNotEmpty && testModality.isNotEmpty) {
      modalityScore = modalityExact
          ? 100
          : radiologyTextSimilarityScore(
              normalizedModality,
              testModality,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (modalityExact ||
          modalityScore >= radiologyCatalogSimilarityThreshold) {
        reasons.add('modality');
      }
    }

    final int compositeScore = radiologyCompositeSimilarityScore(
      nameScore: nameScore,
      codeScore: codeScore,
      modalityScore: modalityScore,
    );

    // Same name with a different modality is a near match, not a hard block.
    // Composite % still weights every available parameter, including misspellings.
    final bool bothModalitiesPresent =
        normalizedModality.isNotEmpty && testModality.isNotEmpty;
    final bool hardNameConflict =
        nameExact && (!bothModalitiesPresent || modalityExact);
    final bool isExact = hardNameConflict || codeExact;
    if (isExact) {
      if (hardNameConflict) {
        exactNameConflict = true;
      }
      if (codeExact) {
        exactCodeConflict = true;
      }
      matches.add(
        RadiologyCatalogSimilarityMatch(
          procedure: test,
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
          modalityScore: modalityScore,
        ),
      );
      continue;
    }

    // Modality contributes to composite %, but alone must not surface every
    // row that shares a common modality.
    final bool strongFieldSignal =
        (nameScore != null &&
            nameScore >= radiologyCatalogSimilarityThreshold) ||
        (codeScore != null &&
            codeScore >= radiologyCatalogSimilarityThreshold);
    final bool compositeSignal =
        compositeScore >= radiologyCatalogSimilarityThreshold;

    if (!strongFieldSignal && !compositeSignal) {
      continue;
    }

    matches.add(
      RadiologyCatalogSimilarityMatch(
        procedure: test,
        score: compositeScore,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: false,
        nameScore: nameScore,
        codeScore: codeScore,
        modalityScore: modalityScore,
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
