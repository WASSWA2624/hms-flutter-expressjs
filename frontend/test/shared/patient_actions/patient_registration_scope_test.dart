import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_scope.dart';

void main() {
  group('PatientRegistrationScope.resolve', () {
    const PatientReferenceOption tenantA = PatientReferenceOption(
      id: 'tenant-a',
      label: 'Tenant A',
    );
    const PatientReferenceOption tenantB = PatientReferenceOption(
      id: 'tenant-b',
      label: 'Tenant B',
    );
    const PatientReferenceOption facilityA = PatientReferenceOption(
      id: 'facility-a',
      label: 'Facility A',
      tenantId: 'tenant-a',
    );
    const PatientReferenceOption facilityB = PatientReferenceOption(
      id: 'facility-b',
      label: 'Facility B',
      tenantId: 'tenant-b',
    );

    test(
      'hides pickers and pre-fills session scope for single-facility staff',
      () {
        final PatientRegistrationScope scope = PatientRegistrationScope.resolve(
          referenceData: const PatientReferenceData(
            tenants: <PatientReferenceOption>[tenantA],
            facilities: <PatientReferenceOption>[facilityA],
          ),
          accessPolicy: AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'token'),
              subject: 'nurse@example.com',
            user: const AuthUserProfile(
              id: 'user-1',
              email: 'nurse@example.com',
              roles: <String>['NURSE'],
              tenantId: 'tenant-a',
              facilityId: 'facility-a',
            ),
            ),
          ),
        );

        expect(scope.showTenantPicker, isFalse);
        expect(scope.showFacilityPicker, isFalse);
        expect(scope.defaultTenantId, 'tenant-a');
        expect(scope.defaultFacilityId, 'facility-a');
      },
    );

    test('shows tenant and facility pickers for global multi-tenant users', () {
      final PatientRegistrationScope scope = PatientRegistrationScope.resolve(
        referenceData: const PatientReferenceData(
          tenants: <PatientReferenceOption>[tenantA, tenantB],
          facilities: <PatientReferenceOption>[facilityA, facilityB],
        ),
        accessPolicy: AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            subject: 'admin@example.com',
            user: const AuthUserProfile(
              id: 'admin-1',
              email: 'admin@example.com',
              roles: <String>['SUPER_ADMIN'],
            ),
          ),
        ),
      );

      expect(scope.showTenantPicker, isTrue);
      expect(scope.showFacilityPicker, isTrue);
      expect(scope.defaultTenantId, isNull);
      expect(scope.defaultFacilityId, isNull);
    });

    test('filters facilities by selected tenant', () {
      final List<PatientReferenceOption> filtered =
          PatientRegistrationScope.facilitiesForTenant(
            const <PatientReferenceOption>[facilityA, facilityB],
            'tenant-a',
          );

      expect(filtered, <PatientReferenceOption>[facilityA]);
    });
  });
}
