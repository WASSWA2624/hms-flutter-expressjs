import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int roomSimilarityThreshold = tenantSimilarityThreshold;
const int roomNameWeight = 70;
const int roomWardWeight = 20;
const int roomFloorWeight = 10;

typedef RoomFieldComparisonStatus = TenantFieldComparisonStatus;

final class RoomFieldComparison {
  const RoomFieldComparison({
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
  final RoomFieldComparisonStatus status;
}

final class RoomSimilarityProposedValues {
  const RoomSimilarityProposedValues({
    required this.name,
    this.wardName,
    this.floor,
  });

  final String name;
  final String? wardName;
  final String? floor;
}

final class RoomSimilarityMatch {
  const RoomSimilarityMatch({
    required this.room,
    required this.score,
    required this.reasons,
    required this.isExact,
    this.exactNameConflict = false,
    this.nameScore,
    this.wardScore,
    this.floorScore,
    this.fieldComparisons = const <RoomFieldComparison>[],
    this.wardName,
  });

  final RoomProfile room;
  final int score;
  final List<String> reasons;
  final bool isExact;
  final bool exactNameConflict;
  final int? nameScore;
  final int? wardScore;
  final int? floorScore;
  final List<RoomFieldComparison> fieldComparisons;
  final String? wardName;
}

final class RoomDuplicateCheckResult {
  const RoomDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <RoomSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<RoomSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;
}

String normalizeRoomName(String value) => normalizeTenantName(value);

String normalizeRoomFloor(String? value) {
  final String trimmed = value?.trim() ?? '';
  return normalizeTenantName(trimmed);
}

int compositeRoomSimilarityScore({
  int? nameScore,
  int? wardScore,
  int? floorScore,
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

  include(nameScore, roomNameWeight);
  include(wardScore, roomWardWeight);
  include(floorScore, roomFloorWeight);

  if (weightSum == 0) {
    return 0;
  }
  return (weightedTotal / weightSum).round();
}

RoomFieldComparisonStatus _comparisonStatus(
  int? score, {
  bool exact = false,
}) {
  if (exact || score == 100) {
    return RoomFieldComparisonStatus.match;
  }
  if (score == null) {
    return RoomFieldComparisonStatus.missing;
  }
  if (score >= roomSimilarityThreshold) {
    return RoomFieldComparisonStatus.similar;
  }
  return RoomFieldComparisonStatus.different;
}

RoomFieldComparison _fieldComparison({
  required String field,
  String? inputValue,
  String? candidateValue,
  int? score,
  bool exact = false,
}) {
  return RoomFieldComparison(
    field: field,
    inputValue: inputValue?.trim().isEmpty == true ? null : inputValue?.trim(),
    candidateValue: candidateValue?.trim().isEmpty == true
        ? null
        : candidateValue?.trim(),
    score: score,
    status: _comparisonStatus(score, exact: exact),
  );
}

bool roomMatchesExcludeId(RoomProfile room, String? excludeId) {
  if (excludeId == null || excludeId.trim().isEmpty) {
    return false;
  }
  return room.id == excludeId.trim();
}

RoomDuplicateCheckResult checkRoomDuplicates({
  required String name,
  required List<RoomProfile> existing,
  String? wardId,
  String? wardName,
  String? floor,
  Map<String, String> wardNamesById = const <String, String>{},
  String? excludeRoomId,
  RoomProfile? excludeRoom,
}) {
  final String normalizedName = normalizeRoomName(name);
  final String? normalizedWardId = wardId?.trim();
  final String normalizedFloor = normalizeRoomFloor(floor);
  var exactNameConflict = false;
  final List<RoomSimilarityMatch> matches = <RoomSimilarityMatch>[];

  for (final RoomProfile room in existing) {
    final bool excluded =
        roomMatchesExcludeId(room, excludeRoomId) ||
        (excludeRoom != null && room.id == excludeRoom.id);
    if (excluded) {
      continue;
    }

    final String roomName = normalizeRoomName(room.name);
    final bool nameExact =
        normalizedName.isNotEmpty && roomName == normalizedName;
    final bool sameWard =
        (normalizedWardId == null || normalizedWardId.isEmpty)
        ? (room.wardId == null || room.wardId!.trim().isEmpty)
        : room.wardId?.trim() == normalizedWardId;
    final String candidateFloor = normalizeRoomFloor(room.floor);
    final bool floorExact =
        normalizedFloor.isNotEmpty &&
        candidateFloor.isNotEmpty &&
        normalizedFloor == candidateFloor;

    int? nameScore;
    int? wardScore;
    int? floorScore;
    final List<String> reasons = <String>[];

    if (normalizedName.isNotEmpty && roomName.isNotEmpty) {
      nameScore = nameExact
          ? 100
          : nameSimilarityScore(normalizedName, roomName);
      if (nameExact || nameScore >= roomSimilarityThreshold) {
        reasons.add('name');
      }
    }

    if (normalizedWardId != null &&
        normalizedWardId.isNotEmpty &&
        room.wardId != null &&
        room.wardId!.trim().isNotEmpty) {
      wardScore = sameWard ? 100 : 0;
      if (sameWard) {
        reasons.add('ward');
      }
    } else if ((normalizedWardId == null || normalizedWardId.isEmpty) &&
        (room.wardId == null || room.wardId!.trim().isEmpty)) {
      wardScore = 100;
      reasons.add('ward');
    }

    if (normalizedFloor.isNotEmpty && candidateFloor.isNotEmpty) {
      floorScore = floorExact
          ? 100
          : nameSimilarityScore(normalizedFloor, candidateFloor);
      if (floorExact || floorScore >= roomSimilarityThreshold) {
        reasons.add('floor');
      }
    }

    final int score = compositeRoomSimilarityScore(
      nameScore: nameScore,
      wardScore: wardScore,
      floorScore: floorScore,
    );

    final bool qualifies =
        nameExact ||
        (nameScore != null && nameScore >= roomSimilarityThreshold);
    if (!qualifies) {
      continue;
    }

    // Exact conflict is facility-scoped name uniqueness (ward optional).
    if (nameExact) {
      exactNameConflict = true;
    }

    final String? candidateWardName =
        wardNamesById[room.wardId ?? ''] ??
        (room.wardId == normalizedWardId ? wardName : null);

    matches.add(
      RoomSimilarityMatch(
        room: room,
        score: score,
        reasons: reasons,
        isExact: nameExact,
        exactNameConflict: nameExact,
        nameScore: nameScore,
        wardScore: wardScore,
        floorScore: floorScore,
        wardName: candidateWardName,
        fieldComparisons: <RoomFieldComparison>[
          _fieldComparison(
            field: 'name',
            inputValue: name,
            candidateValue: room.name,
            score: nameScore,
            exact: nameExact,
          ),
          _fieldComparison(
            field: 'ward',
            inputValue: wardName,
            candidateValue: candidateWardName,
            score: wardScore,
            exact: sameWard,
          ),
          _fieldComparison(
            field: 'floor',
            inputValue: floor,
            candidateValue: room.floor,
            score: floorScore,
            exact: floorExact,
          ),
        ],
      ),
    );
  }

  matches.sort(
    (RoomSimilarityMatch a, RoomSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );

  return RoomDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
