import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int departmentSimilarityThreshold = tenantSimilarityThreshold;
const int departmentNameWeight = 50;
const int departmentShortNameWeight = 20;
const int departmentTypeWeight = 20;
const int departmentStatusWeight = 10;

typedef DepartmentFieldComparisonStatus = TenantFieldComparisonStatus;

final class DepartmentFieldComparison {
  const DepartmentFieldComparison({
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
  final DepartmentFieldComparisonStatus status;
}

final class DepartmentSimilarityProposedValues {
  const DepartmentSimilarityProposedValues({
    required this.name,
    required this.shortName,
    required this.type,
    required this.isActive,
  });

  final String name;
  final String shortName;
  final DepartmentSetupType type;
  final bool isActive;
}

final class DepartmentSimilarityMatch {
  const DepartmentSimilarityMatch({
    required this.department,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.nameScore,
    this.shortNameScore,
    this.typeScore,
    this.statusScore,
    this.fieldComparisons = const <DepartmentFieldComparison>[],
  });

  final DepartmentProfile department;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? shortNameScore;
  final int? typeScore;
  final int? statusScore;
  final List<DepartmentFieldComparison> fieldComparisons;
}

final class DepartmentDuplicateCheckResult {
  const DepartmentDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <DepartmentSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<DepartmentSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;

  List<DepartmentSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((DepartmentSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }

  List<DepartmentSimilarityMatch> get overridableMatches {
    return similarMatches
        .where((DepartmentSimilarityMatch match) => !match.exactNameConflict)
        .toList(growable: false);
  }
}

String normalizeDepartmentName(String value) => normalizeTenantName(value);

String resolveDepartmentShortName(String name, String? shortName) {
  final String trimmedShort = (shortName ?? '').trim();
  if (trimmedShort.isNotEmpty) {
    return trimmedShort;
  }
  return name.trim();
}

int compositeDepartmentSimilarityScore({
  int? nameScore,
  int? shortNameScore,
  int? typeScore,
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

  include(nameScore, departmentNameWeight);
  include(shortNameScore, departmentShortNameWeight);
  include(typeScore, departmentTypeWeight);
  include(statusScore, departmentStatusWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

DepartmentFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return DepartmentFieldComparisonStatus.match;
  }
  if (score == null) {
    return DepartmentFieldComparisonStatus.missing;
  }
  if (score >= departmentSimilarityThreshold) {
    return DepartmentFieldComparisonStatus.similar;
  }
  return DepartmentFieldComparisonStatus.different;
}

DepartmentFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return DepartmentFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool departmentMatchesExcludeId(
  DepartmentProfile department,
  String? excludeId,
) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  final String needle = excludeId.trim();
  return department.id == needle ||
      department.mutationId == needle ||
      (department.resourceUuid != null && department.resourceUuid == needle) ||
      (department.displayId != null && department.displayId == needle);
}

DepartmentDuplicateCheckResult checkDepartmentDuplicates({
  required String name,
  required String shortName,
  required DepartmentSetupType type,
  required bool isActive,
  required List<DepartmentProfile> existing,
  String? excludeDepartmentId,
  DepartmentProfile? excludeDepartment,
}) {
  final String normalizedName = normalizeDepartmentName(name);
  final String effectiveShortName = resolveDepartmentShortName(name, shortName);
  final String normalizedShortName = normalizeDepartmentName(effectiveShortName);
  var exactNameConflict = false;
  final List<DepartmentSimilarityMatch> matches = <DepartmentSimilarityMatch>[];

  for (final DepartmentProfile department in existing) {
    final bool excluded =
        departmentMatchesExcludeId(department, excludeDepartmentId) ||
        (excludeDepartment != null &&
            (department.id == excludeDepartment.id ||
                department.mutationId == excludeDepartment.mutationId ||
                (excludeDepartment.resourceUuid != null &&
                    department.resourceUuid ==
                        excludeDepartment.resourceUuid) ||
                (excludeDepartment.displayId != null &&
                    department.displayId == excludeDepartment.displayId)));
    if (excluded) {
      continue;
    }

    final String departmentName = normalizeDepartmentName(department.name);
    final String departmentShortName = normalizeDepartmentName(
      resolveDepartmentShortName(department.name, department.shortName),
    );

    final bool nameExact =
        normalizedName.isNotEmpty && departmentName == normalizedName;
    final bool shortNameExact =
        normalizedShortName.isNotEmpty &&
        departmentShortName.isNotEmpty &&
        departmentShortName == normalizedShortName;
    final bool typeExact = department.type == type;
    final bool statusExact = department.isActive == isActive;

    int? nameScore;
    int? shortNameScore;
    int? typeScore;
    int? statusScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && departmentName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, departmentName);
      if (nameExact || nameScore >= departmentSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (normalizedShortName.isNotEmpty && departmentShortName.isNotEmpty) {
      shortNameScore = shortNameExact
          ? 100
          : nameSimilarityScore(normalizedShortName, departmentShortName);
      if (shortNameExact || shortNameScore >= departmentSimilarityThreshold) {
        reasons.add('short_name');
      }
    }

    typeScore = typeExact ? 100 : 0;
    if (typeExact) {
      reasons.add('department_type');
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.add('status');
    }

    final int score = compositeDepartmentSimilarityScore(
      nameScore: nameScore,
      shortNameScore: shortNameScore,
      typeScore: typeScore,
      statusScore: statusScore,
    );

    final List<DepartmentFieldComparison> fieldComparisons =
        <DepartmentFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: department.name,
            score: nameScore,
            exact: nameExact,
          ),
          _fieldComparison(
            field: 'short_name',
            inputValue: effectiveShortName,
            candidateValue: resolveDepartmentShortName(
              department.name,
              department.shortName,
            ),
            score: shortNameScore,
            exact: shortNameExact,
          ),
          _fieldComparison(
            field: 'department_type',
            inputValue: type.name,
            candidateValue: department.type.name,
            score: typeScore,
            exact: typeExact,
          ),
          _fieldComparison(
            field: 'status',
            inputValue: isActive ? 'active' : 'inactive',
            candidateValue: department.isActive ? 'active' : 'inactive',
            score: statusScore,
            exact: statusExact,
          ),
          _fieldComparison(
            field: 'display_id',
            candidateValue: department.displayId ?? department.id,
          ),
        ].where(
          (DepartmentFieldComparison entry) =>
              entry.inputValue != null || entry.candidateValue != null,
        )
        .toList(growable: false);

    if (nameExact) {
      exactNameConflict = true;
    }

    final bool isExact = nameExact;
    final bool strongIdentitySignal =
        (nameScore != null && nameScore >= departmentSimilarityThreshold) ||
        (shortNameScore != null &&
            shortNameScore >= departmentSimilarityThreshold);
    final bool compositeSignal = score >= departmentSimilarityThreshold;

    if (!isExact && !strongIdentitySignal && !compositeSignal) {
      continue;
    }

    matches.add(
      DepartmentSimilarityMatch(
        department: department,
        score: score,
        reasons: reasons.isEmpty ? const <String>['name'] : reasons,
        isExact: isExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        shortNameScore: shortNameScore,
        typeScore: typeScore,
        statusScore: statusScore,
        fieldComparisons: fieldComparisons,
      ),
    );
  }

  matches.sort(
    (DepartmentSimilarityMatch left, DepartmentSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return DepartmentDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
