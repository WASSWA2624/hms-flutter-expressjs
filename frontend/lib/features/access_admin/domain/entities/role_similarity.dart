import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int roleSimilarityThreshold = tenantSimilarityThreshold;
const int roleReviewCompositeThreshold = 72;
const int roleReviewFieldThreshold = 75;
const int roleDescriptionLedThreshold = 85;
const int roleIdentitySupportThreshold = 60;
const int roleTokenMatchThreshold = 85;
const int roleTokenSubsetThreshold = 78;

const int roleNameWeight = 45;
const int roleDisplayNameWeight = 35;
const int roleDescriptionWeight = 20;
const int roleCrossIdentityWeight = 25;

/// Tokens ignored during role identity normalization (noise / filler).
const Set<String> roleFillerTokens = <String>{
  'a',
  'an',
  'and',
  'for',
  'of',
  'role',
  'roles',
  'the',
  'to',
};

/// Common hospital-role abbreviations expanded before scoring.
const Map<String, String> roleAliasExpansions = <String, String>{
  'cna': 'certified nursing assistant',
  'dr': 'doctor',
  'hca': 'health care assistant',
  'hcw': 'health care worker',
  'lpn': 'licensed practical nurse',
  'md': 'medical doctor',
  'mo': 'medical officer',
  'np': 'nurse practitioner',
  'pa': 'physician assistant',
  'rn': 'registered nurse',
  'rns': 'registered nurse',
  'sho': 'senior house officer',
};

typedef RoleFieldComparisonStatus = TenantFieldComparisonStatus;

final class RoleFieldComparison {
  const RoleFieldComparison({
    required this.field,
    this.inputValue,
    this.candidateValue,
    this.score,
    required this.status,
  });

  final String field;
  final String? inputValue;
  final String? candidateValue;
  final int? score;
  final RoleFieldComparisonStatus status;
}

final class RoleSimilarityProposedValues {
  const RoleSimilarityProposedValues({
    required this.name,
    required this.displayName,
    this.description,
  });

  final String name;
  final String displayName;
  final String? description;
}

final class RoleSimilarityMatch {
  const RoleSimilarityMatch({
    required this.role,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.exactDisplayNameConflict = false,
    this.nameScore,
    this.displayNameScore,
    this.descriptionScore,
    this.crossIdentityScore,
    this.fieldComparisons = const <RoleFieldComparison>[],
  });

  final AccessAdminItem role;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final bool exactDisplayNameConflict;
  final int? nameScore;
  final int? displayNameScore;
  final int? descriptionScore;
  final int? crossIdentityScore;
  final List<RoleFieldComparison> fieldComparisons;
}

final class RoleDuplicateCheckResult {
  const RoleDuplicateCheckResult({
    this.exactNameConflict = false,
    this.exactDisplayNameConflict = false,
    this.similarMatches = const <RoleSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final bool exactDisplayNameConflict;
  final List<RoleSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict || exactDisplayNameConflict;

  List<RoleSimilarityMatch> get overridableMatches {
    return similarMatches
        .where(
          (RoleSimilarityMatch match) =>
              !match.exactNameConflict && !match.exactDisplayNameConflict,
        )
        .toList(growable: false);
  }
}

String? _nullIfEmpty(String? value) {
  final String trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Platform / tenant / facility scope equality for duplicate checks.
bool roleScopesMatch({
  String? leftTenantId,
  String? leftFacilityId,
  String? rightTenantId,
  String? rightFacilityId,
}) {
  final String? leftTenant = _nullIfEmpty(leftTenantId);
  final String? leftFacility = _nullIfEmpty(leftFacilityId);
  final String? rightTenant = _nullIfEmpty(rightTenantId);
  final String? rightFacility = _nullIfEmpty(rightFacilityId);

  if (leftFacility != null || rightFacility != null) {
    if (leftFacility != rightFacility) {
      return false;
    }
    // Facility peers must share tenant when both tenant ids are known.
    if (leftTenant != null && rightTenant != null && leftTenant != rightTenant) {
      return false;
    }
    return true;
  }

  // Tenant-wide or platform (both facilities null): tenants must match,
  // including both-null platform scope.
  return leftTenant == rightTenant;
}

String normalizeRoleText(String? value) => normalizeTenantName(value ?? '');

List<String> roleTokensOf(String value) {
  return value
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

List<String> roleSignificantTokens(String value) {
  return roleTokensOf(value)
      .where((String token) => !roleFillerTokens.contains(token))
      .toList(growable: false);
}

/// Expands known abbreviations and drops filler tokens for identity compare.
String canonicalizeRoleText(String? value) {
  final String normalized = normalizeRoleText(value);
  if (normalized.isEmpty) {
    return '';
  }

  final List<String> expanded = <String>[];
  for (final String token in roleTokensOf(normalized)) {
    final String? alias = roleAliasExpansions[token];
    if (alias != null) {
      expanded.addAll(roleTokensOf(alias));
    } else if (!roleFillerTokens.contains(token)) {
      expanded.add(token);
    }
  }
  return expanded.join(' ');
}

String normalizeRoleCompactKey(String? value) =>
    canonicalizeRoleText(value).replaceAll(RegExp(r'\s+'), '');

String normalizeRoleSortedTokens(String? value) {
  final List<String> tokens = roleSignificantTokens(canonicalizeRoleText(value))
    ..sort();
  return tokens.join(' ');
}

String roleInitialsKey(String? value) {
  final List<String> tokens = roleSignificantTokens(canonicalizeRoleText(value));
  if (tokens.length < 2) {
    return '';
  }
  return tokens.map((String token) => token[0]).join();
}

int _levenshteinSimilarityPercent(String left, String right) {
  return nameSimilarityScore(left, right);
}

int _averageBestTokenScore(List<String> source, List<String> target) {
  if (source.isEmpty || target.isEmpty) {
    return 0;
  }
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
  return (total / source.length).round();
}

int roleTokenSimilarityPercent(String left, String right) {
  final List<String> leftTokens = roleSignificantTokens(left);
  final List<String> rightTokens = roleSignificantTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
  }
  if (leftTokens.length == 1 && rightTokens.length == 1) {
    return _levenshteinSimilarityPercent(leftTokens.first, rightTokens.first);
  }

  final int forward = _averageBestTokenScore(leftTokens, rightTokens);
  final int reverse = _averageBestTokenScore(rightTokens, leftTokens);
  final int averageDirectional = ((forward + reverse) / 2).round();

  final List<bool> used = List<bool>.filled(rightTokens.length, false);
  var fuzzyIntersection = 0;
  for (final String leftToken in leftTokens) {
    var bestIndex = -1;
    var bestScore = -1;
    for (int i = 0; i < rightTokens.length; i += 1) {
      if (used[i]) {
        continue;
      }
      final int score = _levenshteinSimilarityPercent(leftToken, rightTokens[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestScore >= roleTokenMatchThreshold) {
      used[bestIndex] = true;
      fuzzyIntersection += 1;
    }
  }

  final int union = leftTokens.length + rightTokens.length - fuzzyIntersection;
  final int jaccard = union == 0
      ? 0
      : ((fuzzyIntersection / union) * 100).round();
  return averageDirectional > jaccard ? averageDirectional : jaccard;
}

/// True when the shorter significant-token set is covered by the longer one.
int? roleTokenSubsetScore(String left, String right) {
  final List<String> leftTokens = roleSignificantTokens(left);
  final List<String> rightTokens = roleSignificantTokens(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return null;
  }
  final List<String> shorter =
      leftTokens.length <= rightTokens.length ? leftTokens : rightTokens;
  final List<String> longer =
      leftTokens.length <= rightTokens.length ? rightTokens : leftTokens;
  if (shorter.length < 2) {
    return null;
  }

  final Set<String> longerSet = longer.toSet();
  final int covered = shorter
      .where((String token) => longerSet.contains(token))
      .length;
  if (covered != shorter.length) {
    return null;
  }
  final double coverage = shorter.length / longer.length;
  final int score = (roleTokenSubsetThreshold + coverage * 20).round();
  return score > 99 ? 99 : score;
}

int? scoreRoleTextPair(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return null;
  }
  if (left == right) {
    return 100;
  }

  final String canonicalLeft = canonicalizeRoleText(left);
  final String canonicalRight = canonicalizeRoleText(right);
  if (canonicalLeft.isEmpty || canonicalRight.isEmpty) {
    return null;
  }
  if (canonicalLeft == canonicalRight) {
    return 100;
  }

  final int direct = nameSimilarityScore(canonicalLeft, canonicalRight);

  final String compactLeft = normalizeRoleCompactKey(canonicalLeft);
  final String compactRight = normalizeRoleCompactKey(canonicalRight);
  final int compact = compactLeft.isEmpty || compactRight.isEmpty
      ? 0
      : compactLeft == compactRight
      ? 100
      : nameSimilarityScore(compactLeft, compactRight);

  final String sortedLeft = normalizeRoleSortedTokens(canonicalLeft);
  final String sortedRight = normalizeRoleSortedTokens(canonicalRight);
  final int sorted = sortedLeft.isEmpty || sortedRight.isEmpty
      ? 0
      : sortedLeft == sortedRight
      ? 100
      : nameSimilarityScore(sortedLeft, sortedRight);

  final int tokenScore = roleTokenSimilarityPercent(
    canonicalLeft,
    canonicalRight,
  );
  final int subsetScore = roleTokenSubsetScore(canonicalLeft, canonicalRight) ?? 0;

  final String leftInitials = roleInitialsKey(canonicalLeft);
  final String rightInitials = roleInitialsKey(canonicalRight);
  var initialsScore = 0;
  if (leftInitials.isNotEmpty &&
      (leftInitials == compactRight || leftInitials == rightInitials)) {
    initialsScore = 100;
  } else if (rightInitials.isNotEmpty && rightInitials == compactLeft) {
    initialsScore = 100;
  }

  return <int>[
    direct,
    compact,
    sorted,
    tokenScore,
    subsetScore,
    initialsScore,
  ].reduce((int a, int b) => a > b ? a : b);
}

bool isExactRoleTextMatch(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  final String canonicalLeft = canonicalizeRoleText(left);
  final String canonicalRight = canonicalizeRoleText(right);
  if (canonicalLeft.isEmpty || canonicalRight.isEmpty) {
    return false;
  }
  if (canonicalLeft == canonicalRight) {
    return true;
  }
  if (normalizeRoleCompactKey(canonicalLeft) ==
      normalizeRoleCompactKey(canonicalRight)) {
    return true;
  }
  final String sortedLeft = normalizeRoleSortedTokens(canonicalLeft);
  final String sortedRight = normalizeRoleSortedTokens(canonicalRight);
  if (sortedLeft.isNotEmpty && sortedLeft == sortedRight) {
    return true;
  }

  final String leftInitials = roleInitialsKey(canonicalLeft);
  final String rightCompact = normalizeRoleCompactKey(canonicalRight);
  final String rightInitials = roleInitialsKey(canonicalRight);
  final String leftCompact = normalizeRoleCompactKey(canonicalLeft);
  if (leftInitials.isNotEmpty && leftInitials == rightCompact) {
    return true;
  }
  if (rightInitials.isNotEmpty && rightInitials == leftCompact) {
    return true;
  }
  return false;
}

int compositeRoleSimilarityScore({
  int? nameScore,
  int? displayNameScore,
  int? descriptionScore,
  int? crossIdentityScore,
}) {
  var weightedTotal = 0;
  var weightSum = 0;

  void include(int? score, int weight) {
    if (score == null) {
      return;
    }
    weightedTotal += score * weight;
    weightSum += weight;
  }

  include(nameScore, roleNameWeight);
  include(displayNameScore, roleDisplayNameWeight);
  include(descriptionScore, roleDescriptionWeight);
  include(crossIdentityScore, roleCrossIdentityWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

RoleFieldComparisonStatus _comparisonStatus(int? score, {bool exact = false}) {
  if (exact || score == 100) {
    return RoleFieldComparisonStatus.match;
  }
  if (score == null) {
    return RoleFieldComparisonStatus.missing;
  }
  if (score >= roleSimilarityThreshold) {
    return RoleFieldComparisonStatus.similar;
  }
  return RoleFieldComparisonStatus.different;
}

RoleFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return RoleFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool roleMatchesExcludeId(AccessAdminItem role, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  final String needle = excludeId.trim();
  return role.id == needle ||
      role.mutationId == needle ||
      role.effectiveDisplayId == needle ||
      (role.resourceUuid != null && role.resourceUuid == needle);
}

int? _maxScore(List<int?> scores) {
  int? best;
  for (final int? score in scores) {
    if (score == null) {
      continue;
    }
    if (best == null || score > best) {
      best = score;
    }
  }
  return best;
}

RoleDuplicateCheckResult checkRoleDuplicates({
  required String name,
  required String displayName,
  String? description,
  String? tenantId,
  String? facilityId,
  required List<AccessAdminItem> existing,
  String? excludeRoleId,
}) {
  final String normalizedName = canonicalizeRoleText(name);
  final String normalizedDisplayName = canonicalizeRoleText(displayName);
  final String normalizedDescription = canonicalizeRoleText(description);
  var exactNameConflict = false;
  var exactDisplayNameConflict = false;
  final List<RoleSimilarityMatch> matches = <RoleSimilarityMatch>[];
  final Set<String> seenRoleKeys = <String>{};

  for (final AccessAdminItem role in existing) {
    if (!roleScopesMatch(
      leftTenantId: tenantId,
      leftFacilityId: facilityId,
      rightTenantId: role.tenantId,
      rightFacilityId: role.facilityId,
    )) {
      continue;
    }
    if (roleMatchesExcludeId(role, excludeRoleId)) {
      continue;
    }

    final String roleKey = <String?>[
      role.id,
      role.mutationId,
      role.resourceUuid,
      role.effectiveDisplayId,
    ].whereType<String>().firstWhere(
      (String value) => value.trim().isNotEmpty,
      orElse: () => role.title,
    );
    if (!seenRoleKeys.add(roleKey)) {
      continue;
    }

    final String roleName = canonicalizeRoleText(role.name ?? role.title);
    final String roleDisplayName = canonicalizeRoleText(
      role.displayName ?? role.title,
    );
    final String roleDescription = canonicalizeRoleText(role.subtitle);

    final bool nameExact = isExactRoleTextMatch(normalizedName, roleName);
    final bool displayNameExact = isExactRoleTextMatch(
      normalizedDisplayName,
      roleDisplayName,
    );
    final bool descriptionExact = isExactRoleTextMatch(
      normalizedDescription,
      roleDescription,
    );
    final bool nameMatchesCandidateDisplay = isExactRoleTextMatch(
      normalizedName,
      roleDisplayName,
    );
    final bool displayMatchesCandidateName = isExactRoleTextMatch(
      normalizedDisplayName,
      roleName,
    );

    int? nameScore;
    int? displayNameScore;
    int? descriptionScore;
    int? crossIdentityScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && roleName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : scoreRoleTextPair(normalizedName, roleName);
      if (nameExact ||
          (nameScore != null && nameScore >= roleReviewFieldThreshold)) {
        reasons.add('name');
      }
    }

    if (normalizedDisplayName.isNotEmpty && roleDisplayName.isNotEmpty) {
      displayNameScore = displayNameExact
          ? 100
          : scoreRoleTextPair(normalizedDisplayName, roleDisplayName);
      if (displayNameExact ||
          (displayNameScore != null &&
              displayNameScore >= roleReviewFieldThreshold)) {
        reasons.add('display_name');
      }
    }

    if (normalizedDescription.isNotEmpty && roleDescription.isNotEmpty) {
      descriptionScore = descriptionExact
          ? 100
          : scoreRoleTextPair(normalizedDescription, roleDescription);
      if (descriptionExact ||
          (descriptionScore != null &&
              descriptionScore >= roleReviewFieldThreshold)) {
        reasons.add('description');
      }
    }

    final List<int?> crossScores = <int?>[];
    if (normalizedName.isNotEmpty && roleDisplayName.isNotEmpty) {
      crossScores.add(
        nameMatchesCandidateDisplay
            ? 100
            : scoreRoleTextPair(normalizedName, roleDisplayName),
      );
    }
    if (normalizedDisplayName.isNotEmpty && roleName.isNotEmpty) {
      crossScores.add(
        displayMatchesCandidateName
            ? 100
            : scoreRoleTextPair(normalizedDisplayName, roleName),
      );
    }
    if (normalizedName.isNotEmpty &&
        normalizedDisplayName.isNotEmpty &&
        roleName.isNotEmpty &&
        roleDisplayName.isNotEmpty) {
      final String inputIdentity = canonicalizeRoleText(
        '$normalizedName $normalizedDisplayName',
      );
      final String candidateIdentity = canonicalizeRoleText(
        '$roleName $roleDisplayName',
      );
      crossScores.add(scoreRoleTextPair(inputIdentity, candidateIdentity));
    }
    crossIdentityScore = _maxScore(crossScores);
    if (crossIdentityScore != null &&
        crossIdentityScore >= roleReviewFieldThreshold) {
      reasons.add('cross_identity');
    }

    final int score = compositeRoleSimilarityScore(
      nameScore: nameScore,
      displayNameScore: displayNameScore,
      descriptionScore: descriptionScore,
      crossIdentityScore: crossIdentityScore,
    );

    final int? strongestIdentity = _maxScore(<int?>[
      nameScore,
      displayNameScore,
      crossIdentityScore,
    ]);
    final int? strongestField = _maxScore(<int?>[
      nameScore,
      displayNameScore,
      descriptionScore,
      crossIdentityScore,
    ]);

    final String inputCrossLabel = <String?>[name, displayName]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' / ');
    final String candidateCrossLabel =
        <String?>[role.name ?? role.title, role.displayName ?? role.title]
            .whereType<String>()
            .map((String value) => value.trim())
            .where((String value) => value.isNotEmpty)
            .join(' / ');

    final List<RoleFieldComparison> fieldComparisons = <RoleFieldComparison>[
      _fieldComparison(
        field: 'name',
        inputValue: name,
        candidateValue: role.name ?? role.title,
        score: nameScore,
        exact: nameExact,
      ),
      _fieldComparison(
        field: 'display_name',
        inputValue: displayName,
        candidateValue: role.displayName ?? role.title,
        score: displayNameScore,
        exact: displayNameExact,
      ),
      _fieldComparison(
        field: 'description',
        inputValue: description,
        candidateValue: role.subtitle,
        score: descriptionScore,
        exact: descriptionExact,
      ),
      _fieldComparison(
        field: 'cross_identity',
        inputValue: inputCrossLabel.isEmpty ? null : inputCrossLabel,
        candidateValue: candidateCrossLabel.isEmpty
            ? null
            : candidateCrossLabel,
        score: crossIdentityScore,
        exact:
            nameMatchesCandidateDisplay ||
            displayMatchesCandidateName ||
            crossIdentityScore == 100,
      ),
      _fieldComparison(
        field: 'display_id',
        candidateValue: role.effectiveDisplayId,
      ),
    ].where((RoleFieldComparison entry) {
      return entry.inputValue != null || entry.candidateValue != null;
    }).toList(growable: false);

    if (nameExact ||
        nameMatchesCandidateDisplay ||
        displayMatchesCandidateName) {
      exactNameConflict = true;
    }
    if (displayNameExact) {
      exactDisplayNameConflict = true;
    }

    final bool isExact =
        nameExact ||
        displayNameExact ||
        nameMatchesCandidateDisplay ||
        displayMatchesCandidateName;

    final bool strongIdentitySignal =
        strongestIdentity != null &&
        strongestIdentity >= roleSimilarityThreshold;
    final bool strongFieldSignal =
        strongestField != null && strongestField >= roleSimilarityThreshold;
    final bool compositeSignal = score >= roleSimilarityThreshold;
    final bool softCompositeSignal =
        score >= roleReviewCompositeThreshold &&
        strongestField != null &&
        strongestField >= roleReviewFieldThreshold;
    final bool descriptionLedSignal =
        descriptionScore != null &&
        descriptionScore >= roleDescriptionLedThreshold &&
        strongestIdentity != null &&
        strongestIdentity >= roleIdentitySupportThreshold;
    final bool tokenSubsetSignal =
        (nameScore != null && nameScore >= roleTokenSubsetThreshold) ||
        (displayNameScore != null &&
            displayNameScore >= roleTokenSubsetThreshold);

    if (!isExact &&
        !strongIdentitySignal &&
        !strongFieldSignal &&
        !compositeSignal &&
        !softCompositeSignal &&
        !descriptionLedSignal &&
        !tokenSubsetSignal) {
      continue;
    }

    matches.add(
      RoleSimilarityMatch(
        role: role,
        score: score,
        reasons: reasons.isEmpty
            ? const <String>['name']
            : reasons.toSet().toList(growable: false),
        isExact: isExact,
        exactNameConflict:
            nameExact ||
            nameMatchesCandidateDisplay ||
            displayMatchesCandidateName,
        exactDisplayNameConflict: displayNameExact,
        nameScore: nameScore,
        displayNameScore: displayNameScore,
        descriptionScore: descriptionScore,
        crossIdentityScore: crossIdentityScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort((RoleSimilarityMatch left, RoleSimilarityMatch right) {
    final int byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    final int leftExact = left.isExact ? 1 : 0;
    final int rightExact = right.isExact ? 1 : 0;
    return rightExact.compareTo(leftExact);
  });

  return RoleDuplicateCheckResult(
    exactNameConflict: exactNameConflict || exactDisplayNameConflict,
    exactDisplayNameConflict: exactDisplayNameConflict,
    similarMatches: matches,
  );
}
