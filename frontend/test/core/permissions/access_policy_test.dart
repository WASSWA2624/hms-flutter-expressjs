import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/subscriptions/tenant_subscription_summary.dart';

void main() {
  group('AppAccessPolicy', () {
    test('merges direct permissions with permissions from multiple roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR', 'BILLING']),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.grants(AppPermissions.clinicalWrite), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isTrue);
      expect(policy.grants(AppPermissions.financialApprove), isTrue);
      expect(policy.grants(AppPermissions.systemAdmin), isFalse);
    });

    test(
      'uses backend explicit permissions as ceiling without role-pack expansion',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR', 'BILLING']),
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        final policy = AppAccessPolicy.fromSession(session);

        expect(policy.grants(AppPermissions.clinicalRead), isTrue);
        expect(policy.grants(AppPermissions.clinicalWrite), isFalse);
        expect(policy.grants(AppPermissions.billingWrite), isFalse);
      },
    );

    test('does not flash role-pack access from an authoritative JWT', () {
      final payload = base64Url
          .encode(
            utf8.encode(
              jsonEncode(<String, Object?>{
                'userId': 'user-1',
                'tenantId': 'tenant-1',
                'roles': <String>['DOCTOR'],
                'permissions': <String>[],
              }),
            ),
          )
          .replaceAll('=', '');
      final session = AuthSession.fromTokens(
        SessionTokens(accessToken: 'header.$payload.signature'),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(session.isAuthorizationHydrated, isTrue);
      expect(policy.hasRole(AppRole.doctor), isTrue);
      expect(policy.grants(AppPermissions.clinicalRead), isFalse);
      expect(policy.grants(AppPermissions.clinicalWrite), isFalse);
    });

    test('normalizes legacy role aliases to canonical backend roles', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          roles: <String>['charge_nurse', 'ambulance_driver'],
        ),
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasRole(AppRole.wardManager), isTrue);
      expect(policy.hasRole(AppRole.ambulanceOperator), isTrue);
      expect(policy.grants(AppPermissions.rosterPublish), isTrue);
      expect(policy.grants(AppPermissions.emergencyWrite), isTrue);
    });

    test(
      'grants pharmacist patient and reports read without patient write',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PHARMACIST']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'pharmacy-dispensing',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'reporting-analytics',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        final policy = AppAccessPolicy.fromSession(session);

        expect(policy.grants(AppPermissions.pharmacyRead), isTrue);
        expect(policy.grants(AppPermissions.patientRead), isTrue);
        expect(policy.grants(AppPermissions.reportsRead), isTrue);
        expect(policy.grants(AppPermissions.patientWrite), isFalse);
        expect(policy.hasActiveModule('pharmacy'), isTrue);
        expect(policy.hasActiveModule('reports'), isTrue);
        expect(AppRoutes.patients.accessRequirement.isAllowed(policy), isTrue);
        expect(AppRoutes.pharmacy.accessRequirement.isAllowed(policy), isTrue);
        expect(AppRoutes.reports.accessRequirement.isAllowed(policy), isTrue);
      },
    );

    test('normalizes display-form elevated role names', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['Super Admin']),
      );

      final policy = AppAccessPolicy.fromSession(session);
      const requirement = AccessRequirement(
        anyPermissions: <AppPermission>[AppPermissions.clinicalRead],
        requiresTenantContext: true,
        requiresFacilityContext: true,
      );

      expect(policy.hasRole(AppRole.superAdmin), isTrue);
      expect(policy.isElevated, isTrue);
      expect(requirement.isAllowed(policy), isTrue);
    });

    test('tenant-context super admin remains bounded by the active plan', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['SUPER_ADMIN'],
        ),
        permissions: const <AppPermission>[
          AppPermissions.clinicalRead,
          AppPermissions.billingWrite,
        ],
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.isElevated, isTrue);
      expect(policy.isPlatformElevated, isFalse);
      expect(policy.grants(AppPermissions.clinicalRead), isTrue);
      expect(policy.grants(AppPermissions.billingWrite), isFalse);
      expect(policy.hasActiveModule('billing-payments'), isFalse);
    });

    test('uses active module entitlements when they are present', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(roles: <String>['DOCTOR']),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'clinical-care', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing', isActive: false),
        ],
      );

      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasActiveModule('clinical_care'), isTrue);
      expect(policy.hasActiveModule('billing'), isFalse);
      expect(policy.hasAllActiveModules(<String>['clinical-care']), isTrue);
      expect(
        policy.hasAllActiveModules(<String>['clinical-care', 'billing']),
        isFalse,
      );
    });

    test('does not block modules before entitlements are loaded', () {
      final policy = AppAccessPolicy.fromSession(null);

      expect(policy.hasActiveModule('clinical-care'), isTrue);
    });

    test(
      'evaluates reusable requirements across roles permissions and scope',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['FACILITY_ADMIN'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'settings', licenseStatus: 'ACTIVE'),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.facilityAdmin],
          anyPermissions: <AppPermission>[
            AppPermissions.facilityAdmin,
            AppPermissions.systemAdmin,
          ],
          activeModules: <String>['settings'],
          requiresTenantContext: true,
          requiresFacilityContext: true,
        );

        expect(requirement.isAllowed(policy), isTrue);
      },
    );

    test('plan entitlements gate module-scoped role permissions', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['DOCTOR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.hasRole(AppRole.doctor), isTrue);
      expect(policy.grants(AppPermissions.patientRead), isTrue);
      expect(policy.grants(AppPermissions.labRead), isFalse);
      expect(policy.grants(AppPermissions.clinicalRead), isFalse);
      expect(AppRoutes.lab.accessRequirement.isAllowed(policy), isFalse);
      expect(AppRoutes.patients.accessRequirement.isAllowed(policy), isTrue);
    });

    test(
      'denies access when plan modules are missing before role or rights',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.doctor],
          anyPermissions: <AppPermission>[AppPermissions.clinicalRead],
          activeModules: <String>['lab-workflows'],
        );

        expect(policy.hasRole(AppRole.doctor), isTrue);
        expect(policy.grants(AppPermissions.clinicalRead), isTrue);
        expect(requirement.isAllowed(policy), isFalse);
      },
    );

    test('allows access only when plan modules role and rights all pass', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['DOCTOR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(
            code: 'encounters-vitals',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(
            code: 'scheduling-queue',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      final policy = AppAccessPolicy.fromSession(session);
      const requirement = AccessRequirement(
        anyRoles: <AppRole>[AppRole.doctor],
        anyPermissions: <AppPermission>[AppPermissions.labRead],
        activeModules: <String>['lab-workflows'],
      );

      expect(requirement.isAllowed(policy), isTrue);
    });

    test(
      'allows custom roles when their permission pack matches the route',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['TESTING'],
          ),
          permissions: const <AppPermission>[AppPermissions.patientRead],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);
        const requirement = AccessRequirement(
          anyRoles: <AppRole>[AppRole.doctor, AppRole.tenantAdmin],
          allPermissions: <AppPermission>[AppPermissions.patientRead],
          activeModules: <String>['patient-registry'],
        );

        expect(policy.hasAnyRole(requirement.anyRoles), isFalse);
        expect(requirement.isAllowed(policy), isTrue);
      },
    );

    test('strips module-scoped permissions that the plan does not entitle', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['TESTING'],
        ),
        permissions: const <AppPermission>[
          AppPermissions.patientRead,
          AppPermissions.labRead,
          AppPermissions.mortuaryRead,
          AppPermissions.profileRead,
        ],
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
          AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
        ],
      );
      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.permissions.contains(AppPermissions.patientRead), isTrue);
      expect(policy.permissions.contains(AppPermissions.labRead), isTrue);
      expect(policy.permissions.contains(AppPermissions.profileRead), isTrue);
      expect(policy.permissions.contains(AppPermissions.mortuaryRead), isFalse);
      expect(policy.grants(AppPermissions.mortuaryRead), isFalse);
    });

    test('allows subscription billing for admin roles even without module', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['TENANT_ADMIN'],
        ),
      );
      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.canManageSubscriptionBilling(), isTrue);
    });

    test('allows subscription billing for facility admins', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['FACILITY_ADMIN'],
        ),
      );
      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.canManageSubscriptionBilling(), isTrue);
    });

    test(
      'allows subscription billing for custom roles with write permission',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            roles: <String>['BILLING'],
          ),
          permissions: const <AppPermission>[AppPermissions.subscriptionsWrite],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'subscription-controls',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );
        final policy = AppAccessPolicy.fromSession(session);

        expect(policy.canManageSubscriptionBilling(), isTrue);
      },
    );

    test('denies subscription billing for clinical roles without write', () {
      final session = AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          roles: <String>['DOCTOR'],
        ),
      );
      final policy = AppAccessPolicy.fromSession(session);

      expect(policy.canManageSubscriptionBilling(), isFalse);
    });

    test('identifies lab-focused shell users', () {
      final labPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['LAB_TECH'],
          ),
        ),
      );
      final doctorPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
        ),
      );

      expect(labPolicy.isLabFocusedShellUser, isTrue);
      expect(doctorPolicy.isLabFocusedShellUser, isFalse);
    });

    test('marks pharmacist-only users as pharmacist-focused shell', () {
      final pharmacistPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['PHARMACIST'],
          ),
        ),
      );
      final doctorPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
        ),
      );

      expect(pharmacistPolicy.isPharmacistFocusedShellUser, isTrue);
      expect(doctorPolicy.isPharmacistFocusedShellUser, isFalse);
    });

    test('marks receptionist users as receptionist-focused shell', () {
      final receptionistPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['RECEPTIONIST'],
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'notifications-communications',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );
      final doctorPolicy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['DOCTOR'],
          ),
        ),
      );

      expect(receptionistPolicy.isReceptionistFocusedShellUser, isTrue);
      expect(receptionistPolicy.grants(AppPermissions.patientWrite), isTrue);
      expect(receptionistPolicy.grants(AppPermissions.emergencyWrite), isTrue);
      expect(receptionistPolicy.grants(AppPermissions.operationsRead), isFalse);
      expect(doctorPolicy.isReceptionistFocusedShellUser, isFalse);
    });

    test(
      'detects expanded grants outside the focused shell base pack',
      () {
        final AppAccessPolicy basePolicy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['RECEPTIONIST'],
            ),
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'patient-registry',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'scheduling-queue',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
              AppModuleEntitlement(
                code: 'notifications-communications',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );
        final AppAccessPolicy receptionistPolicy = basePolicy
            .copyWithPermissions(<AppPermission>{
              ...basePolicy.permissions,
              AppPermissions.billingRead,
            });

        expect(receptionistPolicy.isReceptionistFocusedShellUser, isTrue);
        expect(
          receptionistPolicy.isShellRouteUnlockedByExpandedGrant(
            allPermissions: const <AppPermission>[],
            anyPermissions: const <AppPermission>[
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            ],
          ),
          isTrue,
        );
        expect(
          receptionistPolicy.isShellRouteUnlockedByExpandedGrant(
            allPermissions: const <AppPermission>[],
            anyPermissions: const <AppPermission>[
              AppPermissions.patientRead,
              AppPermissions.lastOfficeRead,
            ],
          ),
          isFalse,
        );
      },
    );

    test(
      'Advanced plan hides Pro shell modules even when entitlement rows are stale',
      () {
        final session = AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['SUPER_ADMIN'],
          ),
          subscriptionSummary: const TenantSubscriptionSummary(
            tierCode: 'ADVANCED',
            headerState: TenantSubscriptionHeaderState.active,
          ),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'facilities-maintenance',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
            AppModuleEntitlement(
              code: 'hr-rosters',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
            AppModuleEntitlement(
              code: 'biomedical-engineering-suite',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
            AppModuleEntitlement(
              code: 'mortuary',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
            AppModuleEntitlement(
              code: 'theatre-anesthesia',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
              planTierCode: 'ADVANCED',
            ),
          ],
        );

        final policy = AppAccessPolicy.fromSession(session);

        expect(policy.hasActiveModule('lab-workflows'), isTrue);
        expect(policy.hasActiveModule('facilities-maintenance'), isFalse);
        expect(policy.hasActiveModule('hr-rosters'), isFalse);
        expect(policy.hasActiveModule('biomedical-engineering-suite'), isFalse);
        expect(policy.hasActiveModule('mortuary'), isFalse);
        expect(policy.hasActiveModule('theatre-anesthesia'), isFalse);
        expect(policy.grants(AppPermissions.operationsRead), isFalse);
        expect(policy.grants(AppPermissions.hrRead), isFalse);
        expect(policy.grants(AppPermissions.labRead), isTrue);
        expect(
          AppRoutes.housekeeping.accessRequirement.isAllowed(policy),
          isFalse,
        );
        expect(AppRoutes.hr.accessRequirement.isAllowed(policy), isFalse);
        expect(
          AppRoutes.biomedical.accessRequirement.isAllowed(policy),
          isFalse,
        );
        expect(AppRoutes.mortuary.accessRequirement.isAllowed(policy), isFalse);
        expect(AppRoutes.theater.accessRequirement.isAllowed(policy), isFalse);
      },
    );

    test('canMutateRadiologyCatalog grants radiology write and admin scopes', () {
      final radiologyTech = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['RADIOLOGY_TECH']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'radiology-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );
      final facilityAdmin = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['FACILITY_ADMIN']),
        ),
      );
      final nurse = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['NURSE']),
        ),
      );

      expect(radiologyTech.canMutateRadiologyCatalog(), isTrue);
      expect(facilityAdmin.canMutateRadiologyCatalog(), isTrue);
      expect(nurse.canMutateRadiologyCatalog(), isFalse);
    });

    test(
      'canMutateRadiologyCatalog respects explicit permission ceiling',
      () {
        final policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['RADIOLOGY_TECH']),
            permissions: <AppPermission>{AppPermissions.radiologyRead},
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'radiology-workflows',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        );

        expect(policy.canMutateRadiologyCatalog(), isFalse);
      },
    );

    test('canMutateLabCatalog grants lab write and admin scopes', () {
      final labTech = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['LAB_TECH']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );
      final facilityAdmin = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['FACILITY_ADMIN']),
        ),
      );
      final nurse = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['NURSE']),
        ),
      );

      expect(labTech.canMutateLabCatalog(), isTrue);
      expect(facilityAdmin.canMutateLabCatalog(), isTrue);
      expect(nurse.canMutateLabCatalog(), isFalse);
    });

    test('canMutateLabCatalog respects explicit permission ceiling', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['LAB_TECH']),
          permissions: <AppPermission>{AppPermissions.labRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(policy.canMutateLabCatalog(), isFalse);
    });

    test(
      'canMutateClinicalCatalog grants clinical write and admin scopes',
      () {
        final doctor = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['DOCTOR']),
          ),
        );
        final facilityAdmin = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['FACILITY_ADMIN']),
          ),
        );
        final receptionist = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
          ),
        );

        expect(doctor.canMutateClinicalCatalog(), isTrue);
        expect(facilityAdmin.canMutateClinicalCatalog(), isTrue);
        expect(receptionist.canMutateClinicalCatalog(), isFalse);
      },
    );

    test('canMutateClinicalCatalog respects explicit permission ceiling', () {
      final policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(policy.canMutateClinicalCatalog(), isFalse);
    });
  });
}
