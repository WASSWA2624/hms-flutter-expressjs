import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
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
        phone: '+256700000000',
        email: 'info@democare.test',
        addressLine1: '12 Kampala Road',
        city: 'Kampala',
        country: 'Uganda',
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
        type: FacilitySetupType.hospital,
        isActive: true,
        existing: existing,
      );

      expect(result.exactNameConflict, isTrue);
      expect(result.similarMatches, isNotEmpty);
      expect(result.overridableMatches, isEmpty);
    });

    test('detects similar facility names above threshold', () {
      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'Democare General Hospitl',
        type: FacilitySetupType.hospital,
        isActive: true,
        phone: '+256700000000',
        existing: existing,
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.nonExactSimilarMatches, isNotEmpty);
      expect(
        result.nonExactSimilarMatches.first.score,
        greaterThanOrEqualTo(80),
      );
      expect(
        result.nonExactSimilarMatches.first.fieldComparisons,
        isNotEmpty,
      );
    });

    test('ignores excluded facility when editing', () {
      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'DemoCare General Hospital',
        type: FacilitySetupType.hospital,
        isActive: true,
        existing: existing,
        excludeFacilityId: 'FAC0001',
      );

      expect(result.hasExactConflict, isFalse);
      expect(result.similarMatches, isEmpty);
    });

    test('ignores excluded facility by resource uuid alias', () {
      const List<FacilityProfile> withUuid = <FacilityProfile>[
        FacilityProfile(
          id: 'FAC0001',
          tenantId: 'TEN0001',
          name: 'DemoCare General Hospital',
          type: FacilitySetupType.hospital,
          resourceUuid: 'uuid-facility-1',
          displayId: 'FAC0001',
        ),
      ];

      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'DemoCare General Hospital',
        type: FacilitySetupType.hospital,
        isActive: true,
        existing: withUuid,
        excludeFacilityId: 'uuid-facility-1',
      );

      expect(result.hasExactConflict, isFalse);
    });

    test('ignores excluded FacilityProfile across id aliases', () {
      const FacilityProfile editing = FacilityProfile(
        id: 'FAC0001',
        tenantId: 'TEN0001',
        name: 'DemoCare General Hospital',
        type: FacilitySetupType.hospital,
        resourceUuid: 'uuid-facility-1',
      );

      final FacilityDuplicateCheckResult result = checkFacilityDuplicates(
        name: 'DemoCare General Hospital',
        type: FacilitySetupType.hospital,
        isActive: true,
        existing: existing,
        excludeFacility: editing,
      );

      expect(result.hasExactConflict, isFalse);
    });
  });

  group('facility admin create/delete permissions', () {
    test('facility admin can manage but not create or delete', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['FACILITY_ADMIN'],
            tenantId: 'TEN0001',
            facilityId: 'FAC0001',
          ),
        ),
      );

      expect(policy.canManageFacility(), isTrue);
      expect(policy.canCreateFacility(), isFalse);
      expect(policy.canDeleteFacility(), isFalse);
    });

    test('tenant admin can create and delete facilities', () {
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 't'),
          user: const AuthUserProfile(
            roles: <String>['TENANT_ADMIN'],
            tenantId: 'TEN0001',
          ),
        ),
      );

      expect(policy.canManageFacility(), isTrue);
      expect(policy.canCreateFacility(), isTrue);
      expect(policy.canDeleteFacility(), isTrue);
    });
  });
}
