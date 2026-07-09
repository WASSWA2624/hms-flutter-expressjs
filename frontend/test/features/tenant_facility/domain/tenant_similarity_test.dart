import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';

void main() {
  group('checkTenantDuplicates', () {
    const List<TenantProfile> existing = <TenantProfile>[
      TenantProfile(
        id: 'TEN0001',
        name: 'DemoCare General Hospital',
        slug: 'democare-general-hospital',
        isActive: true,
      ),
      TenantProfile(
        id: 'TEN0002',
        name: 'Acme Health',
        slug: 'acme-health',
        isActive: false,
      ),
    ];

    test('detects exact name and slug conflicts', () {
      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'DemoCare General Hospital',
        slug: 'democare-general-hospital',
        existing: existing,
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.exactSlugConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
    });

    test('detects similar tenant names above threshold', () {
      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'Democare General Hospitl',
        slug: 'new-tenant',
        existing: existing,
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.score,
        greaterThanOrEqualTo(80),
      );
    });

    test('ignores excluded tenant when editing', () {
      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'DemoCare General Hospital',
        slug: 'democare-general-hospital',
        existing: existing,
        excludeTenantId: 'TEN0001',
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });
  });

  group('nameSimilarityScore', () {
    test('returns 100 for identical normalized names', () {
      expect(nameSimilarityScore('acme health', 'acme health'), 100);
    });
  });
}
