import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int userSimilarityThreshold = tenantSimilarityThreshold;
const int userReviewCompositeThreshold = 72;
const int userReviewFieldThreshold = 75;

const int userEmailWeight = 50;
const int userPhoneWeight = 30;
const int userPositionTitleWeight = 20;

typedef UserFieldComparisonStatus = TenantFieldComparisonStatus;

final class UserFieldComparison {
  const UserFieldComparison({
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
  final UserFieldComparisonStatus status;
}

final class UserSimilarityProposedValues {
  const UserSimilarityProposedValues({
    required this.email,
    this.phone,
    this.positionTitle,
    this.tenantId,
    this.facilityId,
    this.tenantName,
    this.facilityName,
  });

  final String email;
  final String? phone;
  final String? positionTitle;
  final String? tenantId;
  final String? facilityId;
  final String? tenantName;
  final String? facilityName;
}

final class UserSimilarityMatch {
  const UserSimilarityMatch({
    required this.user,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactEmailConflict = false,
    this.exactPhoneConflict = false,
    this.emailScore,
    this.phoneScore,
    this.positionScore,
    this.fieldComparisons = const <UserFieldComparison>[],
  });

  final AccessAdminItem user;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactEmailConflict;
  final bool exactPhoneConflict;
  final int? emailScore;
  final int? phoneScore;
  final int? positionScore;
  final List<UserFieldComparison> fieldComparisons;
}

final class UserDuplicateCheckResult {
  const UserDuplicateCheckResult({
    this.exactEmailConflict = false,
    this.exactPhoneConflict = false,
    this.similarMatches = const <UserSimilarityMatch>[],
  });

  final bool exactEmailConflict;
  final bool exactPhoneConflict;
  final List<UserSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactEmailConflict || exactPhoneConflict;

  List<UserSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((UserSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }

  List<UserSimilarityMatch> get overridableMatches {
    return similarMatches
        .where(
          (UserSimilarityMatch match) =>
              !match.exactEmailConflict && !match.exactPhoneConflict,
        )
        .toList(growable: false);
  }
}

/// Hydrates review rows from backend uniqueness conflict `errors[].matches`.
List<UserSimilarityMatch> userSimilarityMatchesFromConflictEntries(
  List<Map<String, Object?>> entries,
) {
  final List<UserSimilarityMatch> matches = <UserSimilarityMatch>[];
  final Set<String> seen = <String>{};

  for (final Map<String, Object?> entry in entries) {
    final String id = _conflictString(
      entry['display_id'] ??
          entry['human_friendly_id'] ??
          entry['id'] ??
          entry['resource_uuid'],
    );
    if (id.isEmpty || !seen.add(id)) {
      continue;
    }

    final String email = _conflictString(entry['email']);
    final String? phone = _nullIfEmpty(_conflictString(entry['phone']));
    final String? positionTitle = _nullIfEmpty(
      _conflictString(entry['position_title'] ?? entry['positionTitle']),
    );
    final String? tenantId = _nullIfEmpty(
      _conflictString(entry['tenant_id'] ?? entry['tenantId']),
    );
    final String? facilityId = _nullIfEmpty(
      _conflictString(entry['facility_id'] ?? entry['facilityId']),
    );
    final String? tenantName = _nullIfEmpty(
      _conflictString(entry['tenant_name'] ?? entry['tenantName']),
    );
    final String? facilityName = _nullIfEmpty(
      _conflictString(entry['facility_name'] ?? entry['facilityName']),
    );

    final int score = _conflictInt(entry['score']) ?? 0;
    final bool exactEmailConflict = entry['exactEmailConflict'] == true;
    final bool exactPhoneConflict = entry['exactPhoneConflict'] == true;
    final bool isExact =
        entry['isExact'] == true || exactEmailConflict || exactPhoneConflict;

    matches.add(
      UserSimilarityMatch(
        user: AccessAdminItem(
          id: id,
          resource: AccessAdminResource.users,
          displayId: id,
          title: email.isNotEmpty ? email : id,
          resourceUuid: _nullIfEmpty(_conflictString(entry['id'])),
          email: email.isEmpty ? null : email,
          phone: phone,
          positionTitle: positionTitle,
          subtitle: positionTitle,
          tenantId: tenantId,
          tenantName: tenantName,
          facilityId: facilityId,
          facilityName: facilityName,
        ),
        score: score,
        reasons: _conflictStringList(entry['reasons']),
        isExact: isExact,
        exactEmailConflict: exactEmailConflict,
        exactPhoneConflict: exactPhoneConflict,
        emailScore: _conflictInt(entry['emailScore']),
        phoneScore: _conflictInt(entry['phoneScore']),
        positionScore: _conflictInt(entry['positionScore']),
        fieldComparisons: _conflictFieldComparisons(
          entry['field_comparisons'] ?? entry['fieldComparisons'],
        ),
      ),
    );
  }

  return matches;
}

String _conflictString(Object? value) {
  if (value == null) {
    return '';
  }
  return value.toString().trim();
}

int? _conflictInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(_conflictString(value));
}

List<String> _conflictStringList(Object? value) {
  if (value is! List<Object?>) {
    return const <String>['email'];
  }
  final List<String> values = value
      .map(_conflictString)
      .where((String entry) => entry.isNotEmpty)
      .toList(growable: false);
  return values.isEmpty ? const <String>['email'] : values;
}

List<UserFieldComparison> _conflictFieldComparisons(Object? value) {
  if (value is! List<Object?>) {
    return const <UserFieldComparison>[];
  }
  final List<UserFieldComparison> comparisons = <UserFieldComparison>[];
  for (final Object? entry in value) {
    if (entry is! Map<Object?, Object?> && entry is! Map<String, Object?>) {
      continue;
    }
    final Map<String, Object?> map = entry is Map<String, Object?>
        ? entry
        : <String, Object?>{
            for (final MapEntry<Object?, Object?> item
                in (entry as Map<Object?, Object?>).entries)
              if (item.key != null) item.key.toString(): item.value,
          };
    final String field = _conflictString(map['field']);
    if (field.isEmpty) {
      continue;
    }
    comparisons.add(
      UserFieldComparison(
        field: field,
        inputValue: _nullIfEmpty(
          _conflictString(map['input_value'] ?? map['inputValue']),
        ),
        candidateValue: _nullIfEmpty(
          _conflictString(map['candidate_value'] ?? map['candidateValue']),
        ),
        score: _conflictInt(map['score']),
        status: _conflictFieldStatus(map['status']),
      ),
    );
  }
  return comparisons;
}

UserFieldComparisonStatus _conflictFieldStatus(Object? value) {
  switch (_conflictString(value).toUpperCase()) {
    case 'MATCH':
      return UserFieldComparisonStatus.match;
    case 'SIMILAR':
      return UserFieldComparisonStatus.similar;
    case 'MISSING':
      return UserFieldComparisonStatus.missing;
    default:
      return UserFieldComparisonStatus.different;
  }
}

String? _nullIfEmpty(String? value) {
  final String trimmed = (value ?? '').trim();
  return trimmed.isEmpty ? null : trimmed;
}

String normalizeUserEmail(String? value) => normalizeTenantEmail(value);

String normalizeUserPhoneDigits(String? value) => normalizeTenantPhone(value);

String canonicalizeUserPositionTitle(String? value) =>
    normalizeTenantName(value ?? '');

int compositeUserSimilarityScore({
  int? emailScore,
  int? phoneScore,
  int? positionScore,
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

  include(emailScore, userEmailWeight);
  include(phoneScore, userPhoneWeight);
  include(positionScore, userPositionTitleWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

UserFieldComparisonStatus _comparisonStatus(int? score, {bool exact = false}) {
  if (exact || score == 100) {
    return UserFieldComparisonStatus.match;
  }
  if (score == null) {
    return UserFieldComparisonStatus.missing;
  }
  if (score >= userSimilarityThreshold) {
    return UserFieldComparisonStatus.similar;
  }
  return UserFieldComparisonStatus.different;
}

UserFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return UserFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool _userMatchesExcludeId(AccessAdminItem user, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  final String needle = excludeId.trim();
  return user.id == needle ||
      user.mutationId == needle ||
      user.effectiveDisplayId == needle ||
      (user.resourceUuid != null && user.resourceUuid == needle);
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

UserDuplicateCheckResult checkUserDuplicates({
  required String email,
  String? phone,
  String? positionTitle,
  String? tenantId,
  required List<AccessAdminItem> existing,
  String? excludeUserId,
}) {
  final String normalizedEmail = normalizeUserEmail(email);
  final String normalizedPhone = normalizeUserPhoneDigits(phone);
  final String normalizedPosition = canonicalizeUserPositionTitle(positionTitle);

  var exactEmailConflict = false;
  var exactPhoneConflict = false;
  final List<UserSimilarityMatch> matches = <UserSimilarityMatch>[];
  final Set<String> seenUserKeys = <String>{};

  for (final AccessAdminItem user in existing) {
    if (_userMatchesExcludeId(user, excludeUserId)) {
      continue;
    }

    final String userKey = <String?>[
      user.id,
      user.mutationId,
      user.resourceUuid,
      user.effectiveDisplayId,
    ].whereType<String>().firstWhere(
      (String value) => value.trim().isNotEmpty,
      orElse: () => user.email ?? user.title,
    );
    if (!seenUserKeys.add(userKey)) {
      continue;
    }

    final String peerEmail = normalizeUserEmail(user.email);
    final String peerPhone = normalizeUserPhoneDigits(user.phone);
    final String peerPosition = canonicalizeUserPositionTitle(
      user.positionTitle,
    );

    final bool emailExact =
        normalizedEmail.isNotEmpty &&
        peerEmail.isNotEmpty &&
        peerEmail == normalizedEmail;
    final bool phoneExact =
        normalizedPhone.isNotEmpty &&
        peerPhone.isNotEmpty &&
        peerPhone == normalizedPhone;
    final bool positionExact =
        normalizedPosition.isNotEmpty &&
        peerPosition.isNotEmpty &&
        peerPosition == normalizedPosition;

    int? emailScore;
    int? phoneScore;
    int? positionScore;
    final List<String> reasons = <String>[];

    if (normalizedEmail.isNotEmpty && peerEmail.isNotEmpty) {
      emailScore = emailExact
          ? 100
          : nameSimilarityScore(normalizedEmail, peerEmail);
      if (emailExact || emailScore >= userReviewFieldThreshold) {
        reasons.add('email');
      }
    }

    if (normalizedPhone.isNotEmpty && peerPhone.isNotEmpty) {
      phoneScore = phoneExact
          ? 100
          : nameSimilarityScore(normalizedPhone, peerPhone);
      if (phoneExact || phoneScore >= userReviewFieldThreshold) {
        reasons.add('phone');
      }
    }

    if (normalizedPosition.isNotEmpty && peerPosition.isNotEmpty) {
      positionScore = positionExact
          ? 100
          : nameSimilarityScore(normalizedPosition, peerPosition);
      if (positionExact || positionScore >= userReviewFieldThreshold) {
        reasons.add('position_title');
      }
    }

    final int score = compositeUserSimilarityScore(
      emailScore: emailScore,
      phoneScore: phoneScore,
      positionScore: positionScore,
    );
    final int? strongestField = _maxScore(<int?>[
      emailScore,
      phoneScore,
      positionScore,
    ]);

    final List<UserFieldComparison> fieldComparisons = <UserFieldComparison>[
      _fieldComparison(
        field: 'email',
        inputValue: email,
        candidateValue: user.email,
        score: emailScore,
        exact: emailExact,
      ),
      _fieldComparison(
        field: 'phone',
        inputValue: phone,
        candidateValue: user.phone,
        score: phoneScore,
        exact: phoneExact,
      ),
      _fieldComparison(
        field: 'position_title',
        inputValue: positionTitle,
        candidateValue: user.positionTitle,
        score: positionScore,
        exact: positionExact,
      ),
      _fieldComparison(
        field: 'display_id',
        candidateValue: user.effectiveDisplayId,
      ),
    ].where((UserFieldComparison entry) {
      return entry.inputValue != null || entry.candidateValue != null;
    }).toList(growable: false);

    if (emailExact) {
      exactEmailConflict = true;
    }
    if (phoneExact) {
      exactPhoneConflict = true;
    }

    final bool isExact = emailExact || phoneExact;
    final bool strongIdentitySignal =
        strongestField != null && strongestField >= userSimilarityThreshold;
    final bool compositeSignal = score >= userSimilarityThreshold;
    final bool softCompositeSignal =
        score >= userReviewCompositeThreshold &&
        strongestField != null &&
        strongestField >= userReviewFieldThreshold;

    if (!isExact &&
        !strongIdentitySignal &&
        !compositeSignal &&
        !softCompositeSignal) {
      continue;
    }

    matches.add(
      UserSimilarityMatch(
        user: user,
        score: score,
        reasons: reasons.isEmpty
            ? const <String>['email']
            : reasons.toSet().toList(growable: false),
        isExact: isExact,
        exactEmailConflict: emailExact,
        exactPhoneConflict: phoneExact,
        emailScore: emailScore,
        phoneScore: phoneScore,
        positionScore: positionScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort((UserSimilarityMatch left, UserSimilarityMatch right) {
    final int leftBlocking =
        (left.exactEmailConflict || left.exactPhoneConflict) ? 1 : 0;
    final int rightBlocking =
        (right.exactEmailConflict || right.exactPhoneConflict) ? 1 : 0;
    final int byBlocking = rightBlocking.compareTo(leftBlocking);
    if (byBlocking != 0) {
      return byBlocking;
    }
    final int byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    final int leftExact = left.isExact ? 1 : 0;
    final int rightExact = right.isExact ? 1 : 0;
    return rightExact.compareTo(leftExact);
  });

  return UserDuplicateCheckResult(
    exactEmailConflict: exactEmailConflict,
    exactPhoneConflict: exactPhoneConflict,
    similarMatches: matches,
  );
}
