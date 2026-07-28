import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int bedSimilarityThreshold = tenantSimilarityThreshold;
const int bedLabelWeight = 70;
const int bedWardWeight = 15;
const int bedRoomWeight = 10;
const int bedStatusWeight = 5;

typedef BedFieldComparisonStatus = TenantFieldComparisonStatus;

final class BedFieldComparison {
  const BedFieldComparison({
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
  final BedFieldComparisonStatus status;
}

final class BedSimilarityProposedValues {
  const BedSimilarityProposedValues({
    required this.label,
    required this.statusLabel,
    this.wardName,
    this.roomName,
  });

  final String label;
  final String statusLabel;
  final String? wardName;
  final String? roomName;
}

final class BedSimilarityMatch {
  const BedSimilarityMatch({
    required this.bed,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactLabelConflict = false,
    this.labelScore,
    this.wardScore,
    this.roomScore,
    this.statusScore,
    this.fieldComparisons = const <BedFieldComparison>[],
    this.wardName,
    this.roomName,
  });

  final BedProfile bed;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactLabelConflict;
  final int? labelScore;
  final int? wardScore;
  final int? roomScore;
  final int? statusScore;
  final List<BedFieldComparison> fieldComparisons;
  final String? wardName;
  final String? roomName;
}

final class BedDuplicateCheckResult {
  const BedDuplicateCheckResult({
    this.exactLabelConflict = false,
    this.similarMatches = const <BedSimilarityMatch>[],
  });

  final bool exactLabelConflict;
  final List<BedSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactLabelConflict;
}

String normalizeBedLabel(String value) => normalizeTenantName(value);

int compositeBedSimilarityScore({
  int? labelScore,
  int? wardScore,
  int? roomScore,
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

  include(labelScore, bedLabelWeight);
  include(wardScore, bedWardWeight);
  include(roomScore, bedRoomWeight);
  include(statusScore, bedStatusWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

BedFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return BedFieldComparisonStatus.match;
  }
  if (score == null) {
    return BedFieldComparisonStatus.missing;
  }
  if (score >= bedSimilarityThreshold) {
    return BedFieldComparisonStatus.similar;
  }
  return BedFieldComparisonStatus.different;
}

BedFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return BedFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool bedMatchesExcludeId(BedProfile bed, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  return bed.id == excludeId.trim();
}

BedDuplicateCheckResult checkBedDuplicates({
  required String label,
  required BedSetupStatus status,
  required List<BedProfile> existing,
  required String wardId,
  String? roomId,
  String? wardName,
  String? roomName,
  Map<String, String> wardNamesById = const <String, String>{},
  Map<String, String> roomNamesById = const <String, String>{},
  String? excludeBedId,
  BedProfile? excludeBed,
}) {
  final String normalizedLabel = normalizeBedLabel(label);
  final String normalizedWardId = wardId.trim();
  final String? normalizedRoomId = roomId?.trim();
  var exactLabelConflict = false;
  final List<BedSimilarityMatch> matches = <BedSimilarityMatch>[];

  for (final BedProfile bed in existing) {
    final bool excluded =
        bedMatchesExcludeId(bed, excludeBedId) ||
        (excludeBed != null && bed.id == excludeBed.id);
    if (excluded) {
      continue;
    }

    final String bedLabel = normalizeBedLabel(bed.label);
    final bool labelExact =
        normalizedLabel.isNotEmpty && bedLabel == normalizedLabel;
    final bool sameWard =
        normalizedWardId.isNotEmpty && bed.wardId.trim() == normalizedWardId;
    final bool sameRoom =
        normalizedRoomId != null &&
        normalizedRoomId.isNotEmpty &&
        (bed.roomId?.trim() ?? '') == normalizedRoomId;
    final bool statusExact = bed.status == status;

    int? labelScore;
    int? wardScore;
    int? roomScore;
    int? statusScore;
    final List<String> reasons = <String>[];

    if (normalizedLabel.isNotEmpty && bedLabel.isNotEmpty) {
      labelScore = labelExact
          ? 100
          : nameSimilarityScore(normalizedLabel, bedLabel);
      if (labelExact || labelScore >= bedSimilarityThreshold) {
        reasons.add('label');
      }
    }

    if (normalizedWardId.isNotEmpty) {
      wardScore = sameWard ? 100 : 0;
      if (sameWard) {
        reasons.add('ward');
      }
    }

    if (normalizedRoomId != null &&
        normalizedRoomId.isNotEmpty &&
        (bed.roomId?.trim().isNotEmpty ?? false)) {
      roomScore = sameRoom ? 100 : 0;
      if (sameRoom) {
        reasons.add('room');
      }
    }

    statusScore = statusExact ? 100 : 0;
    if (statusExact) {
      reasons.add('status');
    }

    final int score = compositeBedSimilarityScore(
      labelScore: labelScore,
      wardScore: wardScore,
      roomScore: roomScore,
      statusScore: statusScore,
    );

    final bool qualifies =
        labelExact ||
        (labelScore != null && labelScore >= bedSimilarityThreshold);
    if (!qualifies) {
      continue;
    }

    // Exact conflict when label + ward both match (ward is the required scope).
    final bool exactConflict = labelExact && sameWard;
    if (exactConflict) {
      exactLabelConflict = true;
    }

    final String? candidateWardName =
        wardNamesById[bed.wardId] ??
        (bed.wardId == normalizedWardId ? wardName : null);
    final String? candidateRoomName =
        roomNamesById[bed.roomId ?? ''] ??
        (bed.roomId == normalizedRoomId ? roomName : null);

    matches.add(
      BedSimilarityMatch(
        bed: bed,
        score: score,
        reasons: reasons,
        isExact: exactConflict,
        exactLabelConflict: exactConflict,
        labelScore: labelScore,
        wardScore: wardScore,
        roomScore: roomScore,
        statusScore: statusScore,
        wardName: candidateWardName,
        roomName: candidateRoomName,
        fieldComparisons: <BedFieldComparison>[
          _fieldComparison(
            field: 'label',
            inputValue: label,
            candidateValue: bed.label,
            score: labelScore,
            exact: labelExact,
          ),
          _fieldComparison(
            field: 'ward',
            inputValue: wardName,
            candidateValue: candidateWardName,
            score: wardScore,
            exact: sameWard,
          ),
          _fieldComparison(
            field: 'room',
            inputValue: roomName,
            candidateValue: candidateRoomName,
            score: roomScore,
            exact: sameRoom,
          ),
          _fieldComparison(
            field: 'status',
            inputValue: status.apiValue,
            candidateValue: bed.status.apiValue,
            score: statusScore,
            exact: statusExact,
          ),
        ],
      ),
    );
  }

  matches.sort(
    (BedSimilarityMatch a, BedSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );

  return BedDuplicateCheckResult(
    exactLabelConflict: exactLabelConflict,
    similarMatches: matches,
  );
}
