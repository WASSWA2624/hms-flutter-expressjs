import 'package:hosspi_hms/features/hr/domain/entities/hr_staff_position.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int hrStaffPositionSimilarityThreshold = tenantSimilarityThreshold;

final class HrStaffPositionSimilarityMatch {
  const HrStaffPositionSimilarityMatch({
    required this.position,
    required this.score,
    required this.exactNameConflict,
  });

  final HrStaffPosition position;
  final int score;
  final bool exactNameConflict;
}

final class HrStaffPositionDuplicateCheckResult {
  const HrStaffPositionDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <HrStaffPositionSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<HrStaffPositionSimilarityMatch> similarMatches;

  List<HrStaffPositionSimilarityMatch> get overridableMatches => similarMatches
      .where((HrStaffPositionSimilarityMatch match) => !match.exactNameConflict)
      .toList(growable: false);
}

HrStaffPositionDuplicateCheckResult checkHrStaffPositionDuplicates({
  required String name,
  required List<HrStaffPosition> existing,
  String? excludePositionId,
}) {
  final String normalizedName = normalizeTenantName(name);
  final String excludeId = (excludePositionId ?? '').trim();
  var exactNameConflict = false;
  final List<HrStaffPositionSimilarityMatch> matches =
      <HrStaffPositionSimilarityMatch>[];

  for (final HrStaffPosition position in existing) {
    if (position.isDeleted) {
      continue;
    }
    final String positionId = position.id.trim();
    final String displayId = (position.displayId ?? '').trim();
    if (excludeId.isNotEmpty &&
        (positionId == excludeId || displayId == excludeId)) {
      continue;
    }

    final String candidateName = normalizeTenantName(position.name);
    if (normalizedName.isEmpty || candidateName.isEmpty) {
      continue;
    }

    final bool nameExact = candidateName == normalizedName;
    final int nameScore = nameExact
        ? 100
        : nameSimilarityScore(normalizedName, candidateName);
    if (!nameExact && nameScore < hrStaffPositionSimilarityThreshold) {
      continue;
    }
    if (nameExact) {
      exactNameConflict = true;
    }
    matches.add(
      HrStaffPositionSimilarityMatch(
        position: position,
        score: nameScore,
        exactNameConflict: nameExact,
      ),
    );
  }

  matches.sort((HrStaffPositionSimilarityMatch left,
      HrStaffPositionSimilarityMatch right) {
    if (left.exactNameConflict != right.exactNameConflict) {
      return left.exactNameConflict ? -1 : 1;
    }
    return right.score.compareTo(left.score);
  });

  return HrStaffPositionDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
