import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_similarity_dialog.dart';

void main() {
  group('patientRegistrationScopesMatch', () {
    test('same facility and tenant are same scope', () {
      expect(
        patientRegistrationScopesMatch(
          leftTenantId: 'tenant-1',
          leftFacilityId: 'facility-1',
          rightTenantId: 'tenant-1',
          rightFacilityId: 'facility-1',
        ),
        isTrue,
      );
    });

    test('different facilities are cross-scope', () {
      expect(
        patientRegistrationScopesMatch(
          leftTenantId: 'tenant-1',
          leftFacilityId: 'facility-1',
          rightTenantId: 'tenant-1',
          rightFacilityId: 'facility-2',
        ),
        isFalse,
      );
    });

    test('different tenants are cross-scope', () {
      expect(
        patientRegistrationScopesMatch(
          leftTenantId: 'tenant-1',
          leftFacilityId: null,
          rightTenantId: 'tenant-2',
          rightFacilityId: null,
        ),
        isFalse,
      );
    });

    test('both sides without tenant or facility match as same scope', () {
      expect(
        patientRegistrationScopesMatch(
          leftTenantId: null,
          leftFacilityId: null,
          rightTenantId: '',
          rightFacilityId: '  ',
        ),
        isTrue,
      );
    });

    test('facility match still requires tenant agreement when both known', () {
      expect(
        patientRegistrationScopesMatch(
          leftTenantId: 'tenant-1',
          leftFacilityId: 'facility-1',
          rightTenantId: 'tenant-2',
          rightFacilityId: 'facility-1',
        ),
        isFalse,
      );
    });
  });
}
