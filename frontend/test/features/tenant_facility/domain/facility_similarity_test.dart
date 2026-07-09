import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  group('checkFacilityDuplicates', () {
    const List<FacilityProfile> existing = <FacilityProfile>[
      FacilityProfile(
        id: 'FAC0001',
        tenantId: 'TEN0001',
        name: 'DemoCare General Hospital',
        type: FacilitySetupType.hospital,
        isActive: true,
      ),
      FacilityProfile(
        id: 'FAC0002',
        tenantId: 'TEN0001',
        name: 'Acme Clinic',
        type: FacilitySetupType.clinic,
        isActive: false,
      ),
    ];

    test('detects exact name conflict within tenant', () {
      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'DemoCare General Hospital',
        existing: existing,
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
    });

    test('detects similar facility names above threshold', () {
      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'Democare General Hospitl',
        existing: existing,
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.score,
        greaterThanOrEqualTo(80),
      );
    });

    test('ignores excluded facility when editing', () {
      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'DemoCare General Hospital',
        existing: existing,
        excludeFacilityId: 'FAC0001',
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });
  });
}
