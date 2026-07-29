import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/patient_registry_access.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('isPharmacyRegistryReader', () {
    test('returns true for pharmacist without patient write', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
        ),
      );

      expect(isPharmacyRegistryReader(policy), isTrue);
    });

    test('returns false for pharmacist with patient write', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
          permissions: const <AppPermission>[AppPermissions.patientWrite],
        ),
      );

      expect(isPharmacyRegistryReader(policy), isFalse);
    });
  });

  group('patient registry requirements', () {
    AppAccessPolicy policyFor({
      required Set<AppPermission> permissions,
      List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: patientRegistryModule,
          licenseStatus: 'ACTIVE',
        ),
      ],
    }) {
      return AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            roles: <String>['DOCTOR'],
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          permissions: permissions,
          moduleEntitlements: modules,
          isAuthorizationHydrated: true,
        ),
      );
    }

    test('read ∩ allows Active tab; write ∩ gates Register', () {
      final AppAccessPolicy read = policyFor(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );
      expect(canViewPatientActiveTab(read), isTrue);
      expect(canWritePatientRegistry(read), isFalse);
      expect(canDeletePatientRegistry(read), isFalse);

      final AppAccessPolicy write = policyFor(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.patientWrite,
        },
      );
      expect(canWritePatientRegistry(write), isTrue);
      expect(
        patientRegistryAllowedSections(write),
        equals(PatientRegistrySection.values),
      );
    });
  });
}
