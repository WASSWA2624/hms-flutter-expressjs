import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int userSimilarityThreshold = tenantSimilarityThreshold;
const int userReviewCompositeThreshold = 72;
const int userReviewFieldThreshold = 75;
const int userPhoneCompositeMin = 85;
const int userNameLedThreshold = 88;
const int userIdentitySupportThreshold = 60;
const int userTokenMatchThreshold = 85;
const int userTokenSubsetThreshold = 78;

const int userEmailWeight = 34;
const int userPhoneWeight = 20;
const int userFullNameWeight = 24;
const int userPositionTitleWeight = 14;
const int userFacilityWeight = 8;

const Set<String> _nameFillerTokens = <String>{
  'a',
  'an',
  'and',
  'dr',
  'jr',
  'md',
  'miss',
  'mr',
  'mrs',
  'ms',
  'of',
  'prof',
  'sir',
  'sr',
  'the',
};

const Map<String, String> _positionAliasExpansions = <String, String>{
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
    this.firstName,
    this.lastName,
    this.tenantId,
    this.facilityId,
    this.tenantName,
    this.facilityName,
  });

  final String email;
  final String? phone;
  final String? positionTitle;
  final String? firstName;
  final String? lastName;
  final String? tenantId;
  final String? facilityId;
  final String? tenantName;
  final String? facilityName;

  String get fullName {
    return <String?>[firstName, lastName]
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' ');
  }
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
    this.firstNameScore,
    this.lastNameScore,
    this.fullNameScore,
    this.positionScore,
    this.facilityScore,
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
  final int? firstNameScore;
  final int? lastNameScore;
  final int? fullNameScore;
  final int? positionScore;
  final int? facilityScore;
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
    final String? firstName = _nullIfEmpty(
      _conflictString(entry['first_name'] ?? entry['firstName']),
    );
    final String? lastName = _nullIfEmpty(
      _conflictString(entry['last_name'] ?? entry['lastName']),
    );
    final String? profileName = _nullIfEmpty(
      _conflictString(entry['full_name'] ?? entry['profile_name']),
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
          title: email.isNotEmpty
              ? email
              : (profileName ??
                    <String?>[firstName, lastName]
                        .whereType<String>()
                        .join(' ')
                        .trim()),
          resourceUuid: _nullIfEmpty(_conflictString(entry['id'])),
          email: email.isEmpty ? null : email,
          phone: phone,
          positionTitle: positionTitle,
          subtitle: positionTitle,
          tenantId: tenantId,
          tenantName: tenantName,
          facilityId: facilityId,
          facilityName: facilityName,
          firstName: firstName,
          lastName: lastName,
          profileName: profileName,
        ),
        score: score,
        reasons: _conflictStringList(entry['reasons']),
        isExact: isExact,
        exactEmailConflict: exactEmailConflict,
        exactPhoneConflict: exactPhoneConflict,
        emailScore: _conflictInt(entry['emailScore']),
        phoneScore: _conflictInt(entry['phoneScore']),
        firstNameScore: _conflictInt(entry['firstNameScore']),
        lastNameScore: _conflictInt(entry['lastNameScore']),
        fullNameScore: _conflictInt(entry['fullNameScore']),
        positionScore: _conflictInt(entry['positionScore']),
        facilityScore: _conflictInt(entry['facilityScore']),
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

List<String> _tokensOf(String value) {
  return value.split(RegExp(r'\s+')).where((String token) => token.isNotEmpty).toList();
}

String canonicalizePersonName(String? value) {
  final String normalized = normalizeTenantName(value ?? '');
  if (normalized.isEmpty) {
    return '';
  }
  return _tokensOf(normalized)
      .where((String token) => !_nameFillerTokens.contains(token))
      .join(' ');
}

String canonicalizeUserPositionTitle(String? value) {
  final String normalized = normalizeTenantName(value ?? '');
  if (normalized.isEmpty) {
    return '';
  }
  final List<String> expanded = <String>[];
  for (final String token in _tokensOf(normalized)) {
    final String? alias = _positionAliasExpansions[token];
    if (alias != null) {
      expanded.addAll(_tokensOf(alias));
    } else if (!_nameFillerTokens.contains(token)) {
      expanded.add(token);
    }
  }
  return expanded.join(' ');
}

String _compactKey(String value) => value.replaceAll(RegExp(r'\s+'), '');

String _sortedTokenKey(String value) {
  final List<String> tokens = _tokensOf(value)
    ..sort();
  return tokens.join(' ');
}

String _initialsKey(String value) {
  final List<String> tokens = _tokensOf(value);
  if (tokens.length < 2) {
    return '';
  }
  return tokens.map((String token) => token[0]).join();
}

String joinPersonName({
  String? firstName,
  String? middleName,
  String? lastName,
}) {
  return <String?>[firstName, middleName, lastName]
      .whereType<String>()
      .map((String value) => value.trim())
      .where((String value) => value.isNotEmpty)
      .join(' ');
}

String _emailLocalPart(String? email) {
  final String normalized = normalizeUserEmail(email);
  if (normalized.isEmpty) {
    return '';
  }
  final int at = normalized.indexOf('@');
  return at > 0 ? normalized.substring(0, at) : normalized;
}

String canonicalizeEmailLocalAsName(String? email) {
  final String local = _emailLocalPart(email);
  if (local.isEmpty) {
    return '';
  }
  return canonicalizePersonName(local.replaceAll(RegExp(r'[._+\-0-9]+'), ' '));
}

int _levenshteinPercent(String left, String right) {
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
      final int score = _levenshteinPercent(token, candidate);
      if (score > best) {
        best = score;
      }
    }
    total += best;
  }
  return (total / source.length).round();
}

int _tokenSimilarityPercent(String left, String right) {
  final List<String> leftTokens = _tokensOf(left);
  final List<String> rightTokens = _tokensOf(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return 0;
  }
  if (leftTokens.length == 1 && rightTokens.length == 1) {
    return _levenshteinPercent(leftTokens.first, rightTokens.first);
  }

  final int forward = _averageBestTokenScore(leftTokens, rightTokens);
  final int reverse = _averageBestTokenScore(rightTokens, leftTokens);
  final int averageDirectional = ((forward + reverse) / 2).round();

  final List<bool> used = List<bool>.filled(rightTokens.length, false);
  var fuzzyIntersection = 0;
  for (final String leftToken in leftTokens) {
    var bestIndex = -1;
    var bestScore = -1;
    for (var i = 0; i < rightTokens.length; i++) {
      if (used[i]) {
        continue;
      }
      final int score = _levenshteinPercent(leftToken, rightTokens[i]);
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    if (bestIndex >= 0 && bestScore >= userTokenMatchThreshold) {
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

int? _tokenSubsetScore(String left, String right) {
  final List<String> leftTokens = _tokensOf(left);
  final List<String> rightTokens = _tokensOf(right);
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return null;
  }

  final List<String> shorter = leftTokens.length <= rightTokens.length
      ? leftTokens
      : rightTokens;
  final List<String> longer = leftTokens.length <= rightTokens.length
      ? rightTokens
      : leftTokens;
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
  final int score = (userTokenSubsetThreshold + coverage * 20).round();
  return score > 99 ? 99 : score;
}

int? scorePersonTextPair(String? leftRaw, String? rightRaw) {
  final String left = canonicalizePersonName(leftRaw);
  final String right = canonicalizePersonName(rightRaw);
  if (left.isEmpty || right.isEmpty) {
    return null;
  }
  if (left == right) {
    return 100;
  }

  final int direct = nameSimilarityScore(left, right);
  final String leftCompact = _compactKey(left);
  final String rightCompact = _compactKey(right);
  final int compact = leftCompact.isNotEmpty && rightCompact.isNotEmpty
      ? (leftCompact == rightCompact
            ? 100
            : _levenshteinPercent(leftCompact, rightCompact))
      : 0;

  final String leftSorted = _sortedTokenKey(left);
  final String rightSorted = _sortedTokenKey(right);
  final int sorted = leftSorted.isNotEmpty && rightSorted.isNotEmpty
      ? (leftSorted == rightSorted
            ? 100
            : _levenshteinPercent(leftSorted, rightSorted))
      : 0;

  final String leftInitials = _initialsKey(left);
  final String rightInitials = _initialsKey(right);
  final int initials =
      leftInitials.isNotEmpty &&
          rightInitials.isNotEmpty &&
          leftInitials == rightInitials
      ? 82
      : 0;

  final int tokenScore = _tokenSimilarityPercent(left, right);
  final int subset = _tokenSubsetScore(left, right) ?? 0;

  return <int>[
    direct,
    compact,
    sorted,
    initials,
    tokenScore,
    subset,
  ].reduce((int a, int b) => a > b ? a : b);
}

int? scorePositionPair(String? leftRaw, String? rightRaw) {
  final String left = canonicalizeUserPositionTitle(leftRaw);
  final String right = canonicalizeUserPositionTitle(rightRaw);
  if (left.isEmpty || right.isEmpty) {
    return null;
  }
  if (left == right) {
    return 100;
  }
  return scorePersonTextPair(left, right);
}

int? scorePhonePair(String? leftDigits, String? rightDigits) {
  final String left = (leftDigits ?? '').trim();
  final String right = (rightDigits ?? '').trim();
  if (left.isEmpty || right.isEmpty) {
    return null;
  }
  if (left == right) {
    return 100;
  }

  final String shorter = left.length <= right.length ? left : right;
  final String longer = left.length <= right.length ? right : left;
  if (shorter.length >= 9 && longer.endsWith(shorter)) {
    return 100;
  }
  if (shorter.length >= 7 && longer.endsWith(shorter)) {
    return 94;
  }

  final String leftTail9 = left.length >= 9 ? left.substring(left.length - 9) : left;
  final String rightTail9 = right.length >= 9
      ? right.substring(right.length - 9)
      : right;
  if (leftTail9.length == 9 && leftTail9 == rightTail9) {
    return 98;
  }

  final String leftTail7 = left.length >= 7 ? left.substring(left.length - 7) : left;
  final String rightTail7 = right.length >= 7
      ? right.substring(right.length - 7)
      : right;
  if (leftTail7.length == 7 && leftTail7 == rightTail7) {
    return 90;
  }

  final int soft = _levenshteinPercent(left, right);
  if (soft < 88) {
    return soft < 50 ? 0 : soft;
  }
  return soft;
}

int? scoreFacilityPair(String? leftFacilityId, String? rightFacilityId) {
  final String? left = _nullIfEmpty(leftFacilityId);
  final String? right = _nullIfEmpty(rightFacilityId);
  if (left == null || right == null) {
    return null;
  }
  return left == right ? 100 : 0;
}

int compositeUserSimilarityScore({
  int? emailScore,
  int? phoneScore,
  int? fullNameScore,
  int? positionScore,
  int? facilityScore,
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
  include(fullNameScore, userFullNameWeight);
  include(positionScore, userPositionTitleWeight);
  include(facilityScore, userFacilityWeight);

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
  String? firstName,
  String? middleName,
  String? lastName,
  String? facilityId,
  String? tenantId,
  required List<AccessAdminItem> existing,
  String? excludeUserId,
}) {
  final String normalizedEmail = normalizeUserEmail(email);
  final String normalizedPhone = normalizeUserPhoneDigits(phone);
  final String normalizedPosition = canonicalizeUserPositionTitle(positionTitle);
  final String inputFirst = canonicalizePersonName(firstName);
  final String inputMiddle = canonicalizePersonName(middleName);
  final String inputLast = canonicalizePersonName(lastName);
  final String inputFullRaw = joinPersonName(
    firstName: firstName,
    middleName: middleName,
    lastName: lastName,
  );
  final String inputFull = canonicalizePersonName(inputFullRaw);
  final String inputSwapped = canonicalizePersonName(
    joinPersonName(firstName: lastName, lastName: firstName),
  );
  final String inputEmailLocalName = canonicalizeEmailLocalAsName(email);

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
    final String peerPosition = canonicalizeUserPositionTitle(user.positionTitle);
    final String peerFirst = canonicalizePersonName(user.firstName);
    final String peerLast = canonicalizePersonName(user.lastName);
    final String peerFullRaw =
        (user.profileName ?? '').trim().isNotEmpty
        ? user.profileName!.trim()
        : joinPersonName(firstName: user.firstName, lastName: user.lastName);
    final String peerFull = canonicalizePersonName(peerFullRaw);

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
    final bool firstExact =
        inputFirst.isNotEmpty && peerFirst.isNotEmpty && inputFirst == peerFirst;
    final bool lastExact =
        inputLast.isNotEmpty && peerLast.isNotEmpty && inputLast == peerLast;
    final bool fullExact =
        inputFull.isNotEmpty && peerFull.isNotEmpty && inputFull == peerFull;

    int? emailScore;
    int? phoneScore;
    int? phoneScoreForComposite;
    int? firstNameScore;
    int? lastNameScore;
    int? fullNameScore;
    int? positionScore;
    int? facilityScore;
    int? emailLocalNameScore;
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
      phoneScore = scorePhonePair(normalizedPhone, peerPhone);
      if (phoneExact ||
          (phoneScore != null && phoneScore >= userPhoneCompositeMin)) {
        phoneScoreForComposite = phoneScore;
      }
      if (phoneExact ||
          (phoneScore != null && phoneScore >= userReviewFieldThreshold)) {
        reasons.add('phone');
      }
    }

    if (inputFirst.isNotEmpty && peerFirst.isNotEmpty) {
      firstNameScore = firstExact
          ? 100
          : scorePersonTextPair(inputFirst, peerFirst);
    }
    if (inputLast.isNotEmpty && peerLast.isNotEmpty) {
      lastNameScore = lastExact ? 100 : scorePersonTextPair(inputLast, peerLast);
    }
    if (inputMiddle.isNotEmpty) {
      // Middle names are not persisted on AccessAdminItem peers; ignored on FE.
    }

    final List<int?> nameCandidates = <int?>[];
    if (inputFull.isNotEmpty && peerFull.isNotEmpty) {
      nameCandidates.add(
        fullExact ? 100 : scorePersonTextPair(inputFull, peerFull),
      );
    }
    if (inputSwapped.isNotEmpty && peerFull.isNotEmpty) {
      nameCandidates.add(scorePersonTextPair(inputSwapped, peerFull));
    }
    if (firstNameScore != null && lastNameScore != null) {
      nameCandidates.add(((firstNameScore + lastNameScore) / 2).round());
    } else if (firstNameScore != null) {
      nameCandidates.add(firstNameScore);
    } else if (lastNameScore != null) {
      nameCandidates.add(lastNameScore);
    }
    fullNameScore = _maxScore(nameCandidates);

    if (inputEmailLocalName.isNotEmpty && peerFull.isNotEmpty) {
      emailLocalNameScore = scorePersonTextPair(inputEmailLocalName, peerFull);
      if (emailLocalNameScore != null) {
        fullNameScore = _maxScore(<int?>[fullNameScore, emailLocalNameScore]);
      }
    }

    if (fullNameScore != null &&
        (fullExact || fullNameScore >= userReviewFieldThreshold)) {
      reasons.add('full_name');
    }
    if (firstNameScore != null &&
        (firstExact || firstNameScore >= userReviewFieldThreshold)) {
      reasons.add('first_name');
    }
    if (lastNameScore != null &&
        (lastExact || lastNameScore >= userReviewFieldThreshold)) {
      reasons.add('last_name');
    }
    if (emailLocalNameScore != null &&
        emailLocalNameScore >= userReviewFieldThreshold) {
      reasons.add('email_local_name');
    }

    if (normalizedPosition.isNotEmpty && peerPosition.isNotEmpty) {
      positionScore = positionExact
          ? 100
          : scorePositionPair(positionTitle, user.positionTitle);
      if (positionExact ||
          (positionScore != null &&
              positionScore >= userReviewFieldThreshold)) {
        reasons.add('position_title');
      }
    }

    facilityScore = scoreFacilityPair(facilityId, user.facilityId);
    if (facilityScore == 100) {
      reasons.add('facility');
    }

    final int score = compositeUserSimilarityScore(
      emailScore: emailScore,
      phoneScore: phoneScoreForComposite,
      fullNameScore: fullNameScore,
      positionScore: positionScore,
      facilityScore: facilityScore == 100 ? 100 : null,
    );
    final int? strongestField = _maxScore(<int?>[
      emailScore,
      phoneScoreForComposite,
      fullNameScore,
      positionScore,
      facilityScore == 100 ? 100 : null,
    ]);

    final List<UserFieldComparison> fieldComparisons = <UserFieldComparison>[
      _fieldComparison(
        field: 'first_name',
        inputValue: firstName,
        candidateValue: user.firstName,
        score: firstNameScore,
        exact: firstExact,
      ),
      _fieldComparison(
        field: 'last_name',
        inputValue: lastName,
        candidateValue: user.lastName,
        score: lastNameScore,
        exact: lastExact,
      ),
      _fieldComparison(
        field: 'full_name',
        inputValue: inputFullRaw.isEmpty ? null : inputFullRaw,
        candidateValue: peerFullRaw.isEmpty ? null : peerFullRaw,
        score: fullNameScore,
        exact: fullExact,
      ),
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
        field: 'facility',
        inputValue: facilityId,
        candidateValue: user.facilityId,
        score: facilityScore,
        exact: facilityScore == 100,
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
    final bool nameLedSignal =
        fullNameScore != null &&
        fullNameScore >= userNameLedThreshold &&
        ((emailScore != null && emailScore >= userIdentitySupportThreshold) ||
            (phoneScoreForComposite != null &&
                phoneScoreForComposite >= userIdentitySupportThreshold) ||
            (positionScore != null &&
                positionScore >= userIdentitySupportThreshold) ||
            facilityScore == 100);

    if (!isExact &&
        !strongIdentitySignal &&
        !compositeSignal &&
        !softCompositeSignal &&
        !nameLedSignal) {
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
        firstNameScore: firstNameScore,
        lastNameScore: lastNameScore,
        fullNameScore: fullNameScore,
        positionScore: positionScore,
        facilityScore: facilityScore,
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
