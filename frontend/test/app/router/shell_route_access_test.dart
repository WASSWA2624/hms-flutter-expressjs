import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';

const List<AppModuleEntitlement> _activeShellModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'inpatient-bed-management',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'icu-critical-care', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'physiotherapy', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'radiology-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'biomedical-engineering-suite',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'integrations-core', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'theatre-anesthesia', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'mortuary', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'subscription-controls', licenseStatus: 'ACTIVE'),
];

void main() {
  group('shell route access matrix', () {
    AppAccessPolicy policyForRole(String role) {
      return AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>[role],
          ),
          moduleEntitlements: _activeShellModules,
        ),
      );
    }

    bool canAccess(AppRouteData route, AppAccessPolicy policy) {
      return canAccessShellRoute(route, policy);
    }

    test('doctor access follows clinical permission pack', () {
      final policy = policyForRole('DOCTOR');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      // Nursing/physiotherapy share clinical/patient permission codes.
      expect(canAccess(AppRoutes.nursing, policy), isTrue);
      expect(canAccess(AppRoutes.physiotherapy, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
      expect(canAccess(AppRoutes.hr, policy), isFalse);
    });

    test('nurse access follows nursing permission pack', () {
      final policy = policyForRole('NURSE');

      expect(canAccess(AppRoutes.nursing, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('ambulance access follows emergency permission pack', () {
      final policy = policyForRole('AMBULANCE_OPERATOR');

      expect(canAccess(AppRoutes.emergency, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
      // Unique entry atoms: emergency:read must not open OPD.
      expect(canAccess(AppRoutes.opd, policy), isFalse);
    });

    test('lab access follows lab permission pack', () {
      final policy = policyForRole('LAB_TECH');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccess(AppRoutes.theater, policy), isFalse);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
    });

    test('pharmacist shell is limited to pharmacy-focused routes', () {
      final policy = policyForRole('PHARMACIST');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.pharmacy, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isFalse);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.lab, policy), isFalse);
      expect(canAccess(AppRoutes.clinical, policy), isFalse);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('receptionist shell is limited to front-desk routes', () {
      final policy = policyForRole('RECEPTIONIST');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.reception, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isTrue);
      expect(canAccess(AppRoutes.emergency, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.ipd, policy), isFalse);
      expect(canAccess(AppRoutes.roomsBeds, policy), isFalse);
      expect(canAccess(AppRoutes.icu, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.theater, policy), isFalse);
      expect(canAccess(AppRoutes.discharge, policy), isFalse);
      expect(canAccess(AppRoutes.pharmacy, policy), isFalse);
      expect(canAccess(AppRoutes.operations, policy), isFalse);
      expect(canAccess(AppRoutes.housekeeping, policy), isFalse);
      expect(canAccess(AppRoutes.biomedical, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccess(AppRoutes.billing, policy), isFalse);
    });

    test('billing access follows billing permission pack', () {
      final policy = policyForRole('BILLING');

      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isTrue);
      expect(canAccess(AppRoutes.claims, policy), isTrue);
      expect(canAccess(AppRoutes.communications, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.ipd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.theater, policy), isFalse);
      expect(canAccess(AppRoutes.radiology, policy), isFalse);
      expect(canAccess(AppRoutes.discharge, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccess(AppRoutes.pharmacy, policy), isFalse);
      expect(canAccess(AppRoutes.emergency, policy), isFalse);
    });

    test('operations access follows operations permission pack', () {
      final policy = policyForRole('OPERATIONS');

      expect(canAccess(AppRoutes.operations, policy), isTrue);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
    });

    test('hr sees hr workspace and reports but not admin setup', () {
      final policy = policyForRole('HR');

      expect(canAccess(AppRoutes.hr, policy), isTrue);
      expect(canAccess(AppRoutes.tenantFacilitySetup, policy), isFalse);
      expect(canAccess(AppRoutes.reports, policy), isTrue);
      expect(canAccess(AppRoutes.patients, policy), isFalse);
    });

    test('admins see full shell including integrations', () {
      for (final String role in <String>[
        'SUPER_ADMIN',
        'TENANT_ADMIN',
        'FACILITY_ADMIN',
      ]) {
        final policy = policyForRole(role);

        expect(canAccess(AppRoutes.integrations, policy), isTrue, reason: role);
        expect(canAccess(AppRoutes.nursing, policy), isTrue, reason: role);
        expect(canAccess(AppRoutes.tenantFacilitySetup, policy), isTrue, reason: role);
      }

      // subscriptions:read is on admin packs — all admins may open it when
      // the subscription-controls module is entitled.
      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('SUPER_ADMIN')),
        isTrue,
      );
      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('TENANT_ADMIN')),
        isTrue,
      );
      expect(
        canAccess(AppRoutes.subscriptions, policyForRole('FACILITY_ADMIN')),
        isTrue,
      );
    });

    test('custom role permissions unlock matching shell routes', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['TESTING'],
          ),
          permissions: <AppPermission>[
            AppPermissions.billingRead,
            AppPermissions.claimsRead,
            AppPermissions.clinicalRead,
            AppPermissions.labRead,
          ],
          isAuthorizationHydrated: true,
          moduleEntitlements: _activeShellModules,
        ),
      );

      expect(policy.isPermissionScopedShellUser, isTrue);
      expect(canAccess(AppRoutes.home, policy), isTrue);
      expect(canAccess(AppRoutes.settings, policy), isTrue);
      expect(canAccess(AppRoutes.billing, policy), isTrue);
      expect(canAccess(AppRoutes.claims, policy), isTrue);
      expect(canAccess(AppRoutes.clinical, policy), isTrue);
      expect(canAccess(AppRoutes.lab, policy), isTrue);
      // Unique entry atoms must not leak across routes.
      expect(canAccess(AppRoutes.patients, policy), isFalse);
      expect(canAccess(AppRoutes.opd, policy), isFalse);
      expect(canAccess(AppRoutes.nursing, policy), isFalse);
      expect(canAccess(AppRoutes.ipd, policy), isFalse);
      expect(canAccess(AppRoutes.icu, policy), isFalse);
      expect(canAccess(AppRoutes.theater, policy), isFalse);
      expect(canAccess(AppRoutes.physiotherapy, policy), isFalse);
      expect(canAccess(AppRoutes.discharge, policy), isFalse);
      expect(canAccess(AppRoutes.pharmacy, policy), isFalse);
      expect(canAccess(AppRoutes.hr, policy), isFalse);
      expect(canAccess(AppRoutes.communications, policy), isFalse);
    });

    test(
      'custom role with doctor-like unique entry permissions matches doctor shell',
      () {
        final AppAccessPolicy doctor = policyForRole('DOCTOR');
        final AppAccessPolicy custom = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['CUSTOM_CLINICIAN'],
            ),
            permissions: <AppPermission>[
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.communicationsRead,
              AppPermissions.communicationsWrite,
              AppPermissions.profileRead,
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
              AppPermissions.patientsRead,
              AppPermissions.opdRead,
              AppPermissions.ipdRead,
              AppPermissions.roomsBedsRead,
              AppPermissions.icuRead,
              AppPermissions.nursingRead,
              AppPermissions.physiotherapyRead,
              AppPermissions.theaterRead,
              AppPermissions.dischargeRead,
              AppPermissions.breakGlassRequest,
              AppPermissions.lastOfficeRead,
              AppPermissions.labRead,
              AppPermissions.radiologyRead,
              AppPermissions.pharmacyRead,
              AppPermissions.reportsRead,
            ],
            isAuthorizationHydrated: true,
            moduleEntitlements: _activeShellModules,
          ),
        );

        for (final AppRouteData route in <AppRouteData>[
          AppRoutes.home,
          AppRoutes.patients,
          AppRoutes.opd,
          AppRoutes.clinical,
          AppRoutes.lab,
          AppRoutes.pharmacy,
          AppRoutes.reports,
          AppRoutes.nursing,
          AppRoutes.physiotherapy,
          AppRoutes.ipd,
          AppRoutes.icu,
          AppRoutes.theater,
          AppRoutes.discharge,
          AppRoutes.emergency,
          AppRoutes.billing,
          AppRoutes.hr,
        ]) {
          expect(
            canAccess(route, custom),
            canAccess(route, doctor),
            reason: route.name,
          );
        }
      },
    );

    test(
      'custom patient grants unlock patient-flow workspaces only',
      () {
        final policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['FRONT_DESK_CUSTOM'],
            ),
            permissions: <AppPermission>[
              AppPermissions.patientsRead,
              AppPermissions.receptionRead,
              AppPermissions.opdRead,
              AppPermissions.patientRead,
              AppPermissions.patientWrite,
            ],
            isAuthorizationHydrated: true,
            moduleEntitlements: _activeShellModules,
          ),
        );

        expect(canAccess(AppRoutes.patients, policy), isTrue);
        expect(canAccess(AppRoutes.reception, policy), isTrue);
        expect(canAccess(AppRoutes.opd, policy), isTrue);
        expect(canAccess(AppRoutes.clinical, policy), isFalse);
        expect(canAccess(AppRoutes.billing, policy), isFalse);
        expect(canAccess(AppRoutes.lab, policy), isFalse);
      },
    );

    test(
      'extra grants unlock routes outside a focused shell without opening '
      'routes that only overlap the base pack',
      () {
        final receptionistPolicy = policyForRole('RECEPTIONIST')
            .copyWithPermissions(<AppPermission>{
              ...policyForRole('RECEPTIONIST').permissions,
              AppPermissions.billingRead,
              AppPermissions.pharmacyRead,
              AppPermissions.theaterRead,
              AppPermissions.dischargeRead,
            });

        expect(receptionistPolicy.isReceptionistFocusedShellUser, isTrue);
        expect(canAccess(AppRoutes.billing, receptionistPolicy), isTrue);
        expect(canAccess(AppRoutes.pharmacy, receptionistPolicy), isTrue);
        // Unique entry keys required — billing/pharmacy alone do not open these.
        expect(canAccess(AppRoutes.theater, receptionistPolicy), isTrue);
        expect(canAccess(AppRoutes.discharge, receptionistPolicy), isTrue);
        expect(canAccess(AppRoutes.nursing, receptionistPolicy), isFalse);
        expect(canAccess(AppRoutes.icu, receptionistPolicy), isFalse);
        expect(canAccess(AppRoutes.roomsBeds, receptionistPolicy), isFalse);

        final labPolicy = policyForRole('LAB_TECH').copyWithPermissions(
          <AppPermission>{
            ...policyForRole('LAB_TECH').permissions,
            AppPermissions.clinicalRead,
            AppPermissions.opdRead,
            AppPermissions.physiotherapyRead,
          },
        );
        expect(labPolicy.isLabFocusedShellUser, isTrue);
        expect(canAccess(AppRoutes.clinical, labPolicy), isTrue);
        expect(canAccess(AppRoutes.opd, labPolicy), isTrue);
        expect(canAccess(AppRoutes.physiotherapy, labPolicy), isTrue);
        expect(canAccess(AppRoutes.pharmacy, labPolicy), isFalse);
        expect(canAccess(AppRoutes.billing, labPolicy), isFalse);
      },
    );
  });
}
