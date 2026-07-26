import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';

const int labCatalogSimilarityThreshold = 80;
const int labCatalogTokenMatchThreshold = 85;
const int labCatalogNameWeight = 50;
const int labCatalogCodeWeight = 30;
const int labCatalogCategoryWeight = 20;
const int labPanelNameWeight = 40;
const int labPanelCodeWeight = 25;
const int labPanelCategoryWeight = 15;
const int labPanelCompositionWeight = 20;

  final class LabCatalogSimilarityMatch {
  const LabCatalogSimilarityMatch({
    required this.item,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.nameScore,
    this.codeScore,
    this.categoryScore,
    this.compositionScore,
  });

  final LabCatalogItem item;

  /// Composite match score across available parameters
  /// (name/code/category[/composition for panels]).
  final int score;
  final List<String> reasons;
  final bool isExact;
  final int? nameScore;
  final int? codeScore;
  final int? categoryScore;
  final int? compositionScore;
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
  String? excludeTestId, {
  Iterable<String> excludeTestIds = const <String>[],
}) {
  final Set<String> excluded = <String>{
    if (excludeTestId != null && excludeTestId.trim().isNotEmpty)
      excludeTestId.trim(),
    for (final String id in excludeTestIds)
      if (id.trim().isNotEmpty) id.trim(),
  };
  if (excluded.isEmpty) {
    return false;
  }
  final Set<String> candidates = <String>{
    item.id.trim(),
    item.apiId.trim(),
    if ((item.displayId ?? '').trim().isNotEmpty) item.displayId!.trim(),
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

LabCatalogDuplicateCheckResult checkLabCatalogDuplicates({
  required String name,
  String? code,
  String? category,
  required List<LabCatalogItem> existing,
  String? excludeTestId,
  Iterable<String> excludeTestIds = const <String>[],
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
    if (labCatalogItemMatchesExcludeId(
      test,
      excludeTestId,
      excludeTestIds: excludeTestIds,
    )) {
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

    // Category contributes to composite %, but alone must not surface every
    // row that shares a common category (e.g. Hematology).
    final bool strongFieldSignal =
        (nameScore != null &&
            nameScore >= labCatalogSimilarityThreshold) ||
        (codeScore != null &&
            codeScore >= labCatalogSimilarityThreshold);
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

/// Weighted composite for panels (name/code/category/composition).
int labPanelCompositeSimilarityScore({
  int? nameScore,
  int? codeScore,
  int? categoryScore,
  int? compositionScore,
}) {
  var weightedTotal = 0;
  var weightSum = 0;

  if (nameScore != null) {
    weightedTotal += nameScore * labPanelNameWeight;
    weightSum += labPanelNameWeight;
  }
  if (codeScore != null) {
    weightedTotal += codeScore * labPanelCodeWeight;
    weightSum += labPanelCodeWeight;
  }
  if (categoryScore != null) {
    weightedTotal += categoryScore * labPanelCategoryWeight;
    weightSum += labPanelCategoryWeight;
  }
  if (compositionScore != null) {
    weightedTotal += compositionScore * labPanelCompositionWeight;
    weightSum += labPanelCompositionWeight;
  }

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round().clamp(0, 100);
}

void _addPanelMembershipIdKey(Set<String> keys, String? value) {
  final String raw = (value ?? '').trim().toUpperCase();
  if (raw.isEmpty) {
    return;
  }
  keys.add('ID:$raw');
  final String compact = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (compact.isNotEmpty && compact != raw) {
    keys.add('ID:$compact');
  }
}

Set<String> _membershipTokensForPanelItem(LabPanelItem item) {
  final Set<String> tokens = <String>{};
  final String codeKey = normalizeLabCatalogCodeForSimilarity(
    item.testCode ?? '',
  );
  if (codeKey.isNotEmpty) {
    tokens.add('CODE:$codeKey');
  }
  // Panel-item row ids are not shared across panels — only lab_test ids.
  _addPanelMembershipIdKey(tokens, item.labTestId);
  return tokens;
}

Set<String> _membershipTokensForSelectedTest(LabCatalogItem test) {
  final Set<String> tokens = <String>{};
  final String codeKey = normalizeLabCatalogCodeForSimilarity(test.code ?? '');
  if (codeKey.isNotEmpty) {
    tokens.add('CODE:$codeKey');
  }
  _addPanelMembershipIdKey(tokens, test.apiId);
  _addPanelMembershipIdKey(tokens, test.id);
  _addPanelMembershipIdKey(tokens, test.displayId);
  return tokens;
}

Set<String> labPanelMembershipKeys({
  List<LabPanelItem> panelItems = const <LabPanelItem>[],
  Iterable<LabCatalogItem> selectedTests = const <LabCatalogItem>[],
}) {
  final Set<String> keys = <String>{};
  for (final LabPanelItem item in panelItems) {
    keys.addAll(_membershipTokensForPanelItem(item));
  }
  for (final LabCatalogItem test in selectedTests) {
    keys.addAll(_membershipTokensForSelectedTest(test));
  }
  return keys;
}

List<Set<String>> labPanelMembershipUnits({
  List<LabPanelItem> panelItems = const <LabPanelItem>[],
  Iterable<LabCatalogItem> selectedTests = const <LabCatalogItem>[],
}) {
  final List<Set<String>> units = <Set<String>>[];
  for (final LabPanelItem item in panelItems) {
    final Set<String> tokens = _membershipTokensForPanelItem(item);
    if (tokens.isNotEmpty) {
      units.add(tokens);
    }
  }
  for (final LabCatalogItem test in selectedTests) {
    final Set<String> tokens = _membershipTokensForSelectedTest(test);
    if (tokens.isNotEmpty) {
      units.add(tokens);
    }
  }
  return units;
}

bool _setsIntersect(Set<String> left, Set<String> right) {
  for (final String value in left) {
    if (right.contains(value)) {
      return true;
    }
  }
  return false;
}

/// Jaccard overlap over member units. A proposed member matches an existing
/// member when any identity token overlaps (same lab_test id and/or code).
int labPanelCompositionOverlapPercent(
  List<Set<String>> leftUnits,
  List<Set<String>> rightUnits,
) {
  if (leftUnits.isEmpty || rightUnits.isEmpty) {
    return 0;
  }

  final Set<int> usedRight = <int>{};
  var matched = 0;
  for (final Set<String> leftUnit in leftUnits) {
    for (var index = 0; index < rightUnits.length; index++) {
      if (usedRight.contains(index)) {
        continue;
      }
      if (_setsIntersect(leftUnit, rightUnits[index])) {
        usedRight.add(index);
        matched += 1;
        break;
      }
    }
  }

  final int union = leftUnits.length + rightUnits.length - matched;
  if (union == 0) {
    return 0;
  }
  return ((matched / union) * 100).round().clamp(0, 100);
}

LabCatalogDuplicateCheckResult checkLabPanelDuplicates({
  required String name,
  String? code,
  String? category,
  List<LabPanelItem> panelItems = const <LabPanelItem>[],
  Iterable<LabCatalogItem> selectedTests = const <LabCatalogItem>[],
  required List<LabCatalogItem> existing,
  String? excludePanelId,
  Iterable<String> excludePanelIds = const <String>[],
  bool includeTokenSimilarity = true,
}) {
  final String normalizedName = normalizeLabCatalogName(name);
  final String normalizedCode = normalizeLabCatalogCode(code ?? '');
  final String similarityCode = normalizeLabCatalogCodeForSimilarity(
    code ?? '',
  );
  final String normalizedCategory = normalizeLabCatalogCategory(category ?? '');
  final List<Set<String>> proposedUnits = labPanelMembershipUnits(
    panelItems: panelItems,
    selectedTests: selectedTests,
  );

  var exactNameConflict = false;
  var exactCodeConflict = false;
  final List<LabCatalogSimilarityMatch> matches =
      <LabCatalogSimilarityMatch>[];

  for (final LabCatalogItem panel in existing) {
    if (panel.type != LabCatalogItemType.panel) {
      continue;
    }
    if (labCatalogItemMatchesExcludeId(
      panel,
      excludePanelId,
      excludeTestIds: excludePanelIds,
    )) {
      continue;
    }

    final String panelName = normalizeLabCatalogName(panel.name ?? '');
    final String panelCode = normalizeLabCatalogCode(panel.code ?? '');
    final String panelSimilarityCode = normalizeLabCatalogCodeForSimilarity(
      panel.code ?? '',
    );
    final String panelCategory = normalizeLabCatalogCategory(
      panel.category ?? '',
    );
    final List<Set<String>> existingUnits = labPanelMembershipUnits(
      panelItems: panel.panelItems,
    );

    final bool nameExact =
        normalizedName.isNotEmpty && panelName == normalizedName;
    final bool codeExact =
        normalizedCode.isNotEmpty &&
        panelCode.isNotEmpty &&
        (panelCode == normalizedCode ||
            (similarityCode.isNotEmpty &&
                panelSimilarityCode == similarityCode));
    final bool categoryExact =
        normalizedCategory.isNotEmpty &&
        panelCategory.isNotEmpty &&
        normalizedCategory == panelCategory;

    int? nameScore;
    int? codeScore;
    int? categoryScore;
    int? compositionScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && panelName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : labTextSimilarityScore(
              normalizedName,
              panelName,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (nameExact || nameScore >= labCatalogSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (similarityCode.isNotEmpty && panelSimilarityCode.isNotEmpty) {
      codeScore = codeExact
          ? 100
          : labTextSimilarityScore(
              similarityCode,
              panelSimilarityCode,
              includeTokenSimilarity: false,
            );
      if (codeExact || codeScore >= labCatalogSimilarityThreshold) {
        reasons.add('code');
      }
    }

    if (normalizedCategory.isNotEmpty && panelCategory.isNotEmpty) {
      categoryScore = categoryExact
          ? 100
          : labTextSimilarityScore(
              normalizedCategory,
              panelCategory,
              includeTokenSimilarity: includeTokenSimilarity,
            );
      if (categoryExact || categoryScore >= labCatalogSimilarityThreshold) {
        reasons.add('category');
      }
    }

    if (proposedUnits.isNotEmpty && existingUnits.isNotEmpty) {
      compositionScore = labPanelCompositionOverlapPercent(
        proposedUnits,
        existingUnits,
      );
      if (compositionScore >= labCatalogSimilarityThreshold) {
        reasons.add('composition');
      }
    }

    final int compositeScore = labPanelCompositeSimilarityScore(
      nameScore: nameScore,
      codeScore: codeScore,
      categoryScore: categoryScore,
      compositionScore: compositionScore,
    );

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
          item: panel,
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
          compositionScore: compositionScore,
        ),
      );
      continue;
    }

    final bool strongFieldSignal =
        (nameScore != null &&
            nameScore >= labCatalogSimilarityThreshold) ||
        (codeScore != null &&
            codeScore >= labCatalogSimilarityThreshold) ||
        (compositionScore != null &&
            compositionScore >= labCatalogSimilarityThreshold);
    final bool compositeSignal =
        compositeScore >= labCatalogSimilarityThreshold;

    if (!strongFieldSignal && !compositeSignal) {
      continue;
    }

    matches.add(
      LabCatalogSimilarityMatch(
        item: panel,
        score: compositeScore,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: false,
        nameScore: nameScore,
        codeScore: codeScore,
        categoryScore: categoryScore,
        compositionScore: compositionScore,
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
