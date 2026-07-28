import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int wardSimilarityThreshold = tenantSimilarityThreshold;
const int wardNameWeight = 60;
const int wardTypeWeight = 20;
const int wardDepartmentWeight = 10;
const int wardStatusWeight = 10;

typedef WardFieldComparisonStatus = TenantFieldComparisonStatus;

final class WardFieldComparison {
  const WardFieldComparison({
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
  final WardFieldComparisonStatus status;
}

final class WardSimilarityProposedValues {
  const WardSimilarityProposedValues({
    required this.name,
    required this.type,
    required this.isActive,
    this.departmentName,
  });

  final String name;
  final WardSetupType type;
  final bool isActive;
  final String? departmentName;
}

final class WardSimilarityMatch {
  const WardSimilarityMatch({
    required this.ward,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.nameScore,
    this.typeScore,
    this.departmentScore,
    this.statusScore,
    this.fieldComparisons = const <WardFieldComparison>[],
    this.departmentName,
  });

  final WardProfile ward;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? typeScore;
  final int? departmentScore;
  final int? statusScore;
  final List<WardFieldComparison> fieldComparisons;
  final String? departmentName;
}

final class WardDuplicateCheckResult {
  const WardDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <WardSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<WardSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;
}

String normalizeWardName(String value) => normalizeTenantName(value);

int compositeWardSimilarityScore({
  int? nameScore,
  int? typeScore,
  int? departmentScore,
  int? statusScore,
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

  include(nameScore, wardNameWeight);
  include(typeScore, wardTypeWeight);
  include(departmentScore, wardDepartmentWeight);
  include(statusScore, wardStatusWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

WardFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return WardFieldComparisonStatus.match;
  }
  if (score == null) {
    return WardFieldComparisonStatus.missing;
  }
  if (score >= wardSimilarityThreshold) {
    return WardFieldComparisonStatus.similar;
  }
  return WardFieldComparisonStatus.different;
}

WardFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return WardFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool wardMatchesExcludeId(WardProfile ward, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  return ward.id == excludeId.trim();
}

WardDuplicateCheckResult checkWardDuplicates({
  required String name,
  required WardSetupType type,
  required bool isActive,
  required List<WardProfile> existing,
  String? departmentId,
  String? departmentName,
  Map<String, String> departmentNamesById = const <String, String>{},
  String? excludeWardId,
  WardProfile? excludeWard,
}) {
  final String normalizedName = normalizeWardName(name);
  final String? normalizedDepartmentId = departmentId?.trim();
  var exactNameConflict = false;
  final List<WardSimilarityMatch> matches = <WardSimilarityMatch>[];

  for (final WardProfile ward in existing) {
    final bool excluded =
        wardMatchesExcludeId(ward, excludeWardId) ||
        (excludeWard != null && ward.id == excludeWard.id);
    if (excluded) {
      continue;
    }

    final String wardName = normalizeWardName(ward.name);
    final bool nameExact =
        normalizedName.isNotEmpty && wardName == normalizedName;
    final bool typeExact = ward.type == type;
    final bool sameDepartment =
        normalizedDepartmentId != null &&
        normalizedDepartmentId.isNotEmpty &&
        ward.departmentId?.trim() == normalizedDepartmentId;
    final bool statusExact = ward.isActive == isActive;

    int? nameScore;
    int? typeScore;
    int? departmentScore;
    int? statusScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && wardName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, wardName);
      if (nameExact || nameScore >= wardSimilarityThreshold) {
        reasons.add('name');
      }
    }

    typeScore = typeExact ? 100 : 0;
    if (typeExact) {
      reasons.add('type');
    }

    if (normalizedDepartmentId != null &&
        normalizedDepartmentId.isNotEmpty &&
        ward.departmentId != null) {
      departmentScore = sameDepartment ? 100 : 0;
      if (sameDepartment) {
        reasons.add('department');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.add('status');
    }

    final int score = compositeWardSimilarityScore(
      nameScore: nameScore,
      typeScore: typeScore,
      departmentScore: departmentScore,
      statusScore: statusScore,
    );

    final bool qualifies =
        nameExact ||
        (nameScore != null && nameScore >= wardSimilarityThreshold);
    if (!qualifies) {
      continue;
    }

    // Exact conflict is facility-scoped name uniqueness (department optional).
    if (nameExact) {
      exactNameConflict = true;
    }

    final String? candidateDepartmentName =
        departmentNamesById[ward.departmentId ?? ''] ??
        (ward.departmentId == normalizedDepartmentId ? departmentName : null);

    matches.add(
      WardSimilarityMatch(
        ward: ward,
        score: score,
        reasons: reasons,
        isExact: nameExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        typeScore: typeScore,
        departmentScore: departmentScore,
        statusScore: statusScore,
        departmentName: candidateDepartmentName,
        fieldComparisons: <WardFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: ward.name,
            score: nameScore,
            exact: nameExact,
          ),
          _fieldComparison(
            field: 'type',
            inputValue: type.apiValue,
            candidateValue: ward.type.apiValue,
            score: typeScore,
            exact: typeExact,
          ),
          _fieldComparison(
            field: 'department',
            inputValue: departmentName,
            candidateValue: candidateDepartmentName,
            score: departmentScore,
            exact: sameDepartment,
          ),
          _fieldComparison(
            field: 'status',
            inputValue: isActive ? 'active' : 'inactive',
            candidateValue: ward.isActive ? 'active' : 'inactive',
            score: statusScore,
            exact: statusExact,
          ),
        ],
      ),
    );
  }

  matches.sort(
    (WardSimilarityMatch a, WardSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );

  return WardDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
