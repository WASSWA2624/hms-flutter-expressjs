import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int roleSimilarityThreshold = tenantSimilarityThreshold;
const int roleReviewCompositeThreshold = 72;
const int roleReviewFieldThreshold = 75;
const int roleDescriptionLedThreshold = 85;
const int roleIdentitySupportThreshold = 60;

const int roleNameWeight = 45;
const int roleDisplayNameWeight = 35;
const int roleDescriptionWeight = 20;
const int roleCrossIdentityWeight = 25;

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

String normalizeRoleText(String? value) => normalizeTenantName(value ?? '');

String normalizeRoleCompactKey(String? value) =>
    normalizeRoleText(value).replaceAll(RegExp(r'\s+'), '');

String normalizeRoleSortedTokens(String? value) {
  final String normalized = normalizeRoleText(value);
  if (normalized.isEmpty) {
    return '';
  }
  final List<String> tokens = normalized
      .split(RegExp(r'\s+'))
      .where((String token) => token.isNotEmpty)
      .toList(growable: false)
    ..sort();
  return tokens.join(' ');
}

int? scoreRoleTextPair(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return null;
  }
  if (left == right) {
    return 100;
  }

  final int direct = nameSimilarityScore(left, right);
  final String compactLeft = normalizeRoleCompactKey(left);
  final String compactRight = normalizeRoleCompactKey(right);
  final int compact = compactLeft.isEmpty || compactRight.isEmpty
      ? 0
      : compactLeft == compactRight
      ? 100
      : nameSimilarityScore(compactLeft, compactRight);

  final String sortedLeft = normalizeRoleSortedTokens(left);
  final String sortedRight = normalizeRoleSortedTokens(right);
  final int sorted = sortedLeft.isEmpty || sortedRight.isEmpty
      ? 0
      : sortedLeft == sortedRight
      ? 100
      : nameSimilarityScore(sortedLeft, sortedRight);

  return <int>[direct, compact, sorted].reduce(
    (int a, int b) => a > b ? a : b,
  );
}

bool isExactRoleTextMatch(String left, String right) {
  if (left.isEmpty || right.isEmpty) {
    return false;
  }
  if (left == right) {
    return true;
  }
  if (normalizeRoleCompactKey(left) == normalizeRoleCompactKey(right)) {
    return true;
  }
  final String sortedLeft = normalizeRoleSortedTokens(left);
  final String sortedRight = normalizeRoleSortedTokens(right);
  return sortedLeft.isNotEmpty && sortedLeft == sortedRight;
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

bool _sameScopeFacility(String? left, String? right) {
  final String? leftId = (left ?? '').trim().isEmpty ? null : left!.trim();
  final String? rightId = (right ?? '').trim().isEmpty ? null : right!.trim();
  return leftId == rightId;
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
  String? facilityId,
  required List<AccessAdminItem> existing,
  String? excludeRoleId,
}) {
  final String normalizedName = normalizeRoleText(name);
  final String normalizedDisplayName = normalizeRoleText(displayName);
  final String normalizedDescription = normalizeRoleText(description);
  var exactNameConflict = false;
  var exactDisplayNameConflict = false;
  final List<RoleSimilarityMatch> matches = <RoleSimilarityMatch>[];

  for (final AccessAdminItem role in existing) {
    if (!_sameScopeFacility(facilityId, role.facilityId)) {
      continue;
    }
    if (roleMatchesExcludeId(role, excludeRoleId)) {
      continue;
    }

    final String roleName = normalizeRoleText(role.name ?? role.title);
    final String roleDisplayName = normalizeRoleText(
      role.displayName ?? role.title,
    );
    final String roleDescription = normalizeRoleText(role.subtitle);

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
      final String inputIdentity = normalizeRoleText(
        '$normalizedName $normalizedDisplayName',
      );
      final String candidateIdentity = normalizeRoleText(
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

    if (!isExact &&
        !strongIdentitySignal &&
        !strongFieldSignal &&
        !compositeSignal &&
        !softCompositeSignal &&
        !descriptionLedSignal) {
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

  matches.sort(
    (RoleSimilarityMatch left, RoleSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return RoleDuplicateCheckResult(
    exactNameConflict: exactNameConflict || exactDisplayNameConflict,
    exactDisplayNameConflict: exactDisplayNameConflict,
    similarMatches: matches,
  );
}
