import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int roleSimilarityThreshold = tenantSimilarityThreshold;
const int roleNameWeight = 50;
const int roleDisplayNameWeight = 30;
const int roleDescriptionWeight = 20;

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
    this.nameScore,
    this.displayNameScore,
    this.descriptionScore,
    this.fieldComparisons = const <RoleFieldComparison>[],
  });

  final AccessAdminItem role;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? displayNameScore;
  final int? descriptionScore;
  final List<RoleFieldComparison> fieldComparisons;
}

final class RoleDuplicateCheckResult {
  const RoleDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <RoleSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<RoleSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;

  List<RoleSimilarityMatch> get overridableMatches {
    return similarMatches
        .where((RoleSimilarityMatch match) => !match.exactNameConflict)
        .toList(growable: false);
  }
}

String normalizeRoleText(String? value) => normalizeTenantName(value ?? '');

int compositeRoleSimilarityScore({
  int? nameScore,
  int? displayNameScore,
  int? descriptionScore,
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

    final bool nameExact =
        normalizedName.isNotEmpty && roleName == normalizedName;
    final bool displayNameExact =
        normalizedDisplayName.isNotEmpty &&
        roleDisplayName.isNotEmpty &&
        roleDisplayName == normalizedDisplayName;
    final bool descriptionExact =
        normalizedDescription.isNotEmpty &&
        roleDescription.isNotEmpty &&
        roleDescription == normalizedDescription;

    int? nameScore;
    int? displayNameScore;
    int? descriptionScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && roleName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, roleName);
      if (nameExact || nameScore >= roleSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (normalizedDisplayName.isNotEmpty && roleDisplayName.isNotEmpty) {
      displayNameScore = displayNameExact
          ? 100
          : nameSimilarityScore(normalizedDisplayName, roleDisplayName);
      if (displayNameExact || displayNameScore >= roleSimilarityThreshold) {
        reasons.add('display_name');
      }
    }

    if (normalizedDescription.isNotEmpty && roleDescription.isNotEmpty) {
      descriptionScore = descriptionExact
          ? 100
          : nameSimilarityScore(normalizedDescription, roleDescription);
      if (descriptionExact || descriptionScore >= roleSimilarityThreshold) {
        reasons.add('description');
      }
    }

    final int score = compositeRoleSimilarityScore(
      nameScore: nameScore,
      displayNameScore: displayNameScore,
      descriptionScore: descriptionScore,
    );

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
        field: 'display_id',
        candidateValue: role.effectiveDisplayId,
      ),
    ].where((RoleFieldComparison entry) {
      return entry.inputValue != null || entry.candidateValue != null;
    }).toList(growable: false);

    if (nameExact) {
      exactNameConflict = true;
    }

    final bool isExact = nameExact;
    final bool strongIdentitySignal =
        (nameScore != null && nameScore >= roleSimilarityThreshold) ||
        (displayNameScore != null &&
            displayNameScore >= roleSimilarityThreshold);
    final bool compositeSignal = score >= roleSimilarityThreshold;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.add(
      RoleSimilarityMatch(
        role: role,
        score: score,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: isExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        displayNameScore: displayNameScore,
        descriptionScore: descriptionScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort(
    (RoleSimilarityMatch left, RoleSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return RoleDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
