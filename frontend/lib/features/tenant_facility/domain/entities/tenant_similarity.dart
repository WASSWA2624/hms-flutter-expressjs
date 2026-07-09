import 'package:hosspi_hms/core/utils/app_slug.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

const int tenantSimilarityThreshold = 80;

final class TenantSimilarityMatch {
  const TenantSimilarityMatch({
    required this.tenant,
    required this.score,
    required this.reasons,
    required this.isExact,
  });

  final TenantProfile tenant;
  final int score;
  final List<String> reasons;
  final bool isExact;
}

final class TenantDuplicateCheckResult {
  const TenantDuplicateCheckResult({
    this.exactNameConflict = false,
    this.exactSlugConflict = false,
    this.similarMatches = const <TenantSimilarityMatch>[],
  });

  final bool exactNameConflict;
  final bool exactSlugConflict;
  final List<TenantSimilarityMatch> similarMatches;

  bool get hasExactConflict => exactNameConflict || exactSlugConflict;

  List<TenantSimilarityMatch> get nonExactSimilarMatches {
    return similarMatches
        .where((TenantSimilarityMatch match) => !match.isExact)
        .toList(growable: false);
  }
}

String normalizeTenantName(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

TenantDuplicateCheckResult checkTenantDuplicates({
  required String name,
  required String slug,
  required List<TenantProfile> existing,
  String? excludeTenantId,
}) {
  final String normalizedName = normalizeTenantName(name);
  final String normalizedSlug = slugify(slug.isEmpty ? name : slug);

  var exactNameConflict = false;
  var exactSlugConflict = false;
  final List<TenantSimilarityMatch> matches = <TenantSimilarityMatch>[];

  for (final TenantProfile tenant in existing) {
    if (excludeTenantId != null && tenant.id == excludeTenantId) {
      continue;
    }

    final String tenantName = normalizeTenantName(tenant.name);
    final String tenantSlug = slugify(tenant.slug ?? '');
    final bool nameExact =
        normalizedName.isNotEmpty && tenantName == normalizedName;
    final bool slugExact =
        normalizedSlug.isNotEmpty && tenantSlug == normalizedSlug;

    if (nameExact || slugExact) {
      if (nameExact) {
        exactNameConflict = true;
      }
      if (slugExact) {
        exactSlugConflict = true;
      }
      matches.add(
        TenantSimilarityMatch(
          tenant: tenant,
          score: 100,
          reasons: <String>[
            if (nameExact) 'name',
            if (slugExact) 'slug',
          ],
          isExact: true,
        ),
      );
      continue;
    }

    if (normalizedName.isEmpty || tenantName.isEmpty) {
      continue;
    }

    final int score = nameSimilarityScore(normalizedName, tenantName);
    if (score >= tenantSimilarityThreshold) {
      matches.add(
        TenantSimilarityMatch(
          tenant: tenant,
          score: score,
          reasons: const <String>['name'],
          isExact: false,
        ),
      );
    }
  }

  matches.sort(
    (TenantSimilarityMatch left, TenantSimilarityMatch right) =>
        right.score.compareTo(left.score),
  );

  return TenantDuplicateCheckResult(
    exactNameConflict: exactNameConflict,
    exactSlugConflict: exactSlugConflict,
    similarMatches: matches,
  );
}

int nameSimilarityScore(String left, String right) {
  if (left == right) {
    return 100;
  }
  if (left.isEmpty || right.isEmpty) {
    return 0;
  }

  final int distance = _levenshteinDistance(left, right);
  final int maxLength = left.length > right.length ? left.length : right.length;
  return (((maxLength - distance) / maxLength) * 100).round().clamp(0, 100);
}

int _levenshteinDistance(String left, String right) {
  if (left == right) {
    return 0;
  }
  if (left.isEmpty) {
    return right.length;
  }
  if (right.isEmpty) {
    return left.length;
  }

  final List<int> previous = List<int>.generate(
    right.length + 1,
    (int index) => index,
    growable: false,
  );
  final List<int> current = List<int>.filled(right.length + 1, 0);

  for (int i = 0; i < left.length; i++) {
    current[0] = i + 1;
    for (int j = 0; j < right.length; j++) {
      final int substitutionCost = left.codeUnitAt(i) == right.codeUnitAt(j)
          ? 0
          : 1;
      current[j + 1] = _min3(
        current[j] + 1,
        previous[j + 1] + 1,
        previous[j] + substitutionCost,
      );
    }
    for (int j = 0; j <= right.length; j++) {
      previous[j] = current[j];
    }
  }

  return previous[right.length];
}

int _min3(int a, int b, int c) {
  return a < b ? (a < c ? a : c) : (b < c ? b : c);
}
