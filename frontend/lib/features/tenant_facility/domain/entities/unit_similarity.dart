import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int unitSimilarityThreshold = tenantSimilarityThreshold;
const int unitNameWeight = 70;
const int unitDepartmentWeight = 20;
const int unitStatusWeight = 10;

typedef UnitFieldComparisonStatus = TenantFieldComparisonStatus;

final class UnitFieldComparison {
  const UnitFieldComparison({
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
  final UnitFieldComparisonStatus status;
}

final class UnitSimilarityProposedValues {
  const UnitSimilarityProposedValues({
    required this.name,
    required this.isActive,
    this.departmentName,
  });

  final String name;
  final bool isActive;
  final String? departmentName;
}

final class UnitSimilarityMatch {
  const UnitSimilarityMatch({
    required this.unit,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.nameScore,
    this.departmentScore,
    this.statusScore,
    this.fieldComparisons = const <UnitFieldComparison>[],
    this.departmentName,
  });

  final UnitProfile unit;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? departmentScore;
  final int? statusScore;
  final List<UnitFieldComparison> fieldComparisons;
  final String? departmentName;
}

final class UnitDuplicateCheckResult {
  const UnitDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <UnitSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<UnitSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;
}

String normalizeUnitName(String value) => normalizeTenantName(value);

int compositeUnitSimilarityScore({
  int? nameScore,
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

  include(nameScore, unitNameWeight);
  include(departmentScore, unitDepartmentWeight);
  include(statusScore, unitStatusWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

UnitFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return UnitFieldComparisonStatus.match;
  }
  if (score == null) {
    return UnitFieldComparisonStatus.missing;
  }
  if (score >= unitSimilarityThreshold) {
    return UnitFieldComparisonStatus.similar;
  }
  return UnitFieldComparisonStatus.different;
}

UnitFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return UnitFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool unitMatchesExcludeId(UnitProfile unit, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  return unit.id == excludeId.trim();
}

UnitDuplicateCheckResult checkUnitDuplicates({
  required String name,
  required bool isActive,
  required List<UnitProfile> existing,
  String? departmentId,
  String? departmentName,
  Map<String, String> departmentNamesById = const <String, String>{},
  String? excludeUnitId,
  UnitProfile? excludeUnit,
}) {
  final String normalizedName = normalizeUnitName(name);
  final String? normalizedDepartmentId = departmentId?.trim();
  var exactNameConflict = false;
  final List<UnitSimilarityMatch> matches = <UnitSimilarityMatch>[];

  for (final UnitProfile unit in existing) {
    final bool excluded =
        unitMatchesExcludeId(unit, excludeUnitId) ||
        (excludeUnit != null && unit.id == excludeUnit.id);
    if (excluded) {
      continue;
    }

    final String unitName = normalizeUnitName(unit.name);
    final bool nameExact =
        normalizedName.isNotEmpty && unitName == normalizedName;
    final bool sameDepartment =
        normalizedDepartmentId != null &&
        normalizedDepartmentId.isNotEmpty &&
        unit.departmentId?.trim() == normalizedDepartmentId;
    final bool statusExact = unit.isActive == isActive;

    int? nameScore;
    int? departmentScore;
    int? statusScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && unitName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, unitName);
      if (nameExact || nameScore >= unitSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (normalizedDepartmentId != null &&
        normalizedDepartmentId.isNotEmpty &&
        unit.departmentId != null) {
      departmentScore = sameDepartment ? 100 : 0;
      if (sameDepartment) {
        reasons.add('department');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.add('status');
    }

    final int score = compositeUnitSimilarityScore(
      nameScore: nameScore,
      departmentScore: departmentScore,
      statusScore: statusScore,
    );

    final bool qualifies =
        nameExact ||
        (nameScore != null && nameScore >= unitSimilarityThreshold);
    if (!qualifies) {
      continue;
    }

    // Exact conflict only when name + department both match (same scope).
    final bool exactConflict =
        nameExact &&
        (normalizedDepartmentId == null ||
            normalizedDepartmentId.isEmpty ||
            sameDepartment);
    if (exactConflict) {
      exactNameConflict = true;
    }

    final String? candidateDepartmentName =
        departmentNamesById[unit.departmentId ?? ''] ??
        (unit.departmentId == normalizedDepartmentId ? departmentName : null);

    matches.add(
      UnitSimilarityMatch(
        unit: unit,
        score: score,
        reasons: reasons,
        isExact: exactConflict,
        exactNameConflict: exactConflict,
        nameScore: nameScore,
        departmentScore: departmentScore,
        statusScore: statusScore,
        departmentName: candidateDepartmentName,
        fieldComparisons: <UnitFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: unit.name,
            score: nameScore,
            exact: nameExact,
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
            candidateValue: unit.isActive ? 'active' : 'inactive',
            score: statusScore,
            exact: statusExact,
          ),
        ],
      ),
    );
  }

  matches.sort(
    (UnitSimilarityMatch a, UnitSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );

  return UnitDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
