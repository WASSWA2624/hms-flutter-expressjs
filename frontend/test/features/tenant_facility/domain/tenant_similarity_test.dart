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
        contactName: 'Jane Doe',
        contactEmail: 'jane@example.com',
        contactPhone: '+256700000000',
        currency: 'UGX',
        standardConsultationFee: '50000',
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
      expect(result.overridableMatches, isEmpty);
    });

    test('detects similar tenant names above threshold', () {
      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'Democare General Hospitl',
        slug: 'new-tenant',
        existing: existing,
      );

      expect(result.exactSlugConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.nameScore,
        greaterThanOrEqualTo(80),
      );
    });

    test('scores contact and config fields in the breakdown', () {
      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'Democare General Hospitl',
        slug: 'new-tenant',
        contactName: 'Jane Doe',
        contactEmail: 'jane@example.com',
        contactPhone: '256700000000',
        currency: 'UGX',
        standardConsultationFee: '50000',
        existing: existing,
      );

      final TenantSimilarityMatch match = result.overridableMatches.first;
      expect(match.fieldComparisons, isNotEmpty);
      expect(
        match.fieldComparisons.any(
          (TenantFieldComparison comparison) =>
              comparison.field == 'contact_email' &&
              comparison.status == TenantFieldComparisonStatus.match,
        ),
        isTrue,
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

    test('ignores excluded tenant by mutation resource uuid', () {
      final List<TenantProfile> withUuid = <TenantProfile>[
        TenantProfile(
          id: 'TEN0001',
          name: 'DemoCare General Hospital',
          slug: 'democare-general-hospital',
          resourceUuid: 'uuid-tenant-1',
          contactName: 'Jane Doe',
          contactEmail: 'jane@example.com',
          contactPhone: '+256700000000',
          currency: 'UGX',
          standardConsultationFee: '50000',
        ),
      ];

      final TenantDuplicateCheckResult result = checkTenantDuplicates(
        name: 'DemoCare General Hospital',
        slug: 'democare-general-hospital',
        existing: withUuid,
        excludeTenantId: 'uuid-tenant-1',
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

  group('compositeTenantSimilarityScore', () {
    test('weights identity fields more than configuration fields', () {
      final int identityHeavy = compositeTenantSimilarityScore(
        nameScore: 100,
        slugScore: 100,
        currencyScore: 0,
        feeScore: 0,
      );
      final int configHeavy = compositeTenantSimilarityScore(
        nameScore: 0,
        slugScore: 0,
        currencyScore: 100,
        feeScore: 100,
      );
      expect(identityHeavy, greaterThan(configHeavy));
    });
  });
}
