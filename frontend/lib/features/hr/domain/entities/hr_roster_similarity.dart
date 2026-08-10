import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int hrRosterNameSimilarityThreshold = tenantSimilarityThreshold;

final class HrRosterNameSimilarityMatch {
  const HrRosterNameSimilarityMatch({
    required this.item,
    required this.score,
    required this.exactNameConflict,
  });

  final HrWorkItem item;
  final int score;
  final bool exactNameConflict;
}

final class HrRosterNameDuplicateCheckResult {
  const HrRosterNameDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <HrRosterNameSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<HrRosterNameSimilarityMatch> similarMatches;

  List<HrRosterNameSimilarityMatch> get overridableMatches => similarMatches
      .where((HrRosterNameSimilarityMatch match) => !match.exactNameConflict)
      .toList(growable: false);
}

/// Client-side name duplicate/similarity check against loaded roster drafts.
///
/// Complements the server weighted similarity check so the review dialog can
/// appear before the first POST when similar names are already on screen.
HrRosterNameDuplicateCheckResult checkHrRosterNameDuplicates({
  required String name,
  required List<HrWorkItem> existing,
  String? excludeRosterId,
}) {
  final String normalizedName = normalizeTenantName(name);
  final String excludeId = (excludeRosterId ?? '').trim();
  var exactNameConflict = false;
  final List<HrRosterNameSimilarityMatch> matches =
      <HrRosterNameSimilarityMatch>[];

  for (final HrWorkItem item in existing) {
    if (item.queue != HrQueue.rosterDrafts) {
      continue;
    }
    final String status = (item.status ?? '').trim().toUpperCase();
    if (status == 'DELETED') {
      continue;
    }
    final String rosterId = (item.rosterId ?? item.effectiveId).trim();
    final String displayId = (item.displayId ?? '').trim();
    final String id = item.id.trim();
    if (excludeId.isNotEmpty &&
        (rosterId == excludeId || displayId == excludeId || id == excludeId)) {
      continue;
    }

    final String candidateName = normalizeTenantName(item.rosterName ?? '');
    if (normalizedName.isEmpty || candidateName.isEmpty) {
      continue;
    }

    final bool nameExact = candidateName == normalizedName;
    final int nameScore = nameExact
        ? 100
        : nameSimilarityScore(normalizedName, candidateName);
    if (!nameExact && nameScore < hrRosterNameSimilarityThreshold) {
      continue;
    }
    if (nameExact) {
      exactNameConflict = true;
    }
    matches.add(
      HrRosterNameSimilarityMatch(
        item: item,
        score: nameScore,
        exactNameConflict: nameExact,
      ),
    );
  }

  matches.sort((
    HrRosterNameSimilarityMatch left,
    HrRosterNameSimilarityMatch right,
  ) {
    if (left.exactNameConflict != right.exactNameConflict) {
      return left.exactNameConflict ? -1 : 1;
    }
    return right.score.compareTo(left.score);
  });

  return HrRosterNameDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
