import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

const int facilitySimilarityThreshold = tenantSimilarityThreshold;

final class FacilitySimilarityMatch {
  const FacilitySimilarityMatch({
    required this.facility,
    required this.score,
    required this.isExact,
  });

  final FacilityProfile facility;
  final int score;
  final bool isExact;
}

final class FacilityDuplicateCheckResult {
  const FacilityDuplicateCheckResult({
    this.exactNameConflict = false,
    this.similarMatches = const <FacilitySimilarityMatch>[],
  });

  final bool exactNameConflict;
  final List<FacilitySimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict;

  List<FacilitySimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((FacilitySimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }
}

String normalizeFacilityName(String value) => normalizeTenantName(value);

FacilityDuplicateCheckResult checkFacilityDuplicates({
  required String name,
  required List<FacilityProfile> existing,
  String? excludeFacilityId,
}) {
  final String normalizedName = normalizeFacilityName(name);
  var exactNameConflict = false;
  final List<FacilitySimilarityMatch> matches = <FacilitySimilarityMatch>[];

  for (final FacilityProfile facility in existing) {
    if (excludeFacilityId != null && facility.id == excludeFacilityId) {
      continue;
    }

    final String facilityName = normalizeFacilityName(facility.name);
    final bool nameExact =
        normalizedName.isNotEmpty && facilityName == normalizedName;

    if (nameExact) {
      exactNameConflict = true;
      matches.add(
        FacilitySimilarityMatch(
          facility: facility,
          score: 100,
          isExact: true,
        ),
      );
      continue;
    }

    if (normalizedName.isEmpty || facilityName.isEmpty) {
      continue;
    }

    final int score = nameSimilarityScore(normalizedName, facilityName);
    if (score >= facilitySimilarityThreshold) {
      matches.add(
        FacilitySimilarityMatch(
          facility: facility,
          score: score,
          isExact: false,
        ),
      );
    }
  }

  matches.sort(
    (FacilitySimilarityMatch left, FacilitySimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return FacilityDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    similarMatches: matches,
  );
}
