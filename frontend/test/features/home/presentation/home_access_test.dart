import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_atom_permissions.dart';
import 'package:hosspi_hms/features/home/presentation/home_access.dart';

AppAccessPolicy _policy(Iterable<AppPermission> permissions) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: <String>['CUSTOM'],
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'reporting-analytics',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('homeTabReadRequirement', () {
    test('denies without profile:read (matrix ∩)', () {
      final AppAccessPolicy policy = _policy(<AppPermission>[
        AppPermissions.clinicalRead,
      ]);
      expect(homeTabReadRequirement.isAllowed(policy), isFalse);
    });

    test('allows with profile:read', () {
      final AppAccessPolicy policy = _policy(<AppPermission>[
        AppPermissions.profileRead,
      ]);
      expect(homeTabReadRequirement.isAllowed(policy), isTrue);
    });
  });

  group('homeAtomRequirement / Dashboard.md mapping', () {
    test('homeAllows denies empty atom requirements (never public)', () {
      final AppAccessPolicy policy = _policy(<AppPermission>[
        AppPermissions.profileRead,
        AppPermissions.clinicalRead,
      ]);
      expect(
        homeAllows(policy, homeAtomRequirement(const <AppPermission>[])),
        isFalse,
      );
      expect(
        homeAllowsAll(policy, const <AppPermission>[]),
        isFalse,
      );
      expect(
        homeAllows(policy, homeStatusCardRequirement(id: 'unknown_metric_xyz')),
        isFalse,
      );
    });

    test('homeAllows matches homeChartsRequirement for reports:read', () {
      expect(
        homeAllows(
          _policy(<AppPermission>[AppPermissions.clinicalRead]),
          homeChartsRequirement,
        ),
        isFalse,
      );
      expect(
        homeAllows(
          _policy(<AppPermission>[AppPermissions.reportsRead]),
          homeChartsRequirement,
        ),
        isTrue,
      );
    });

    test(
      'ABAC facility context: homeTabRead still allows without facility when '
      'matrix has no facility gate',
      () {
        final AppAccessPolicy noFacility = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: null,
              roles: <String>['CUSTOM'],
            ),
            permissions: <AppPermission>[AppPermissions.profileRead],
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
            isAuthorizationHydrated: true,
          ),
        );
        expect(homeTabReadRequirement.isAllowed(noFacility), isTrue);
      },
    );

    test('intersection denial: financial:approve missing hides approvals atom', () {
      final AppAccessPolicy policy = _policy(<AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.profileRead,
      ]);
      expect(
        homeAtomRequirement(const <AppPermission>[
          AppPermissions.financialApprove,
        ]).isAllowed(policy),
        isFalse,
      );
      expect(
        homeStatusCardRequirement(id: 'pending_approvals').isAllowed(policy),
        isFalse,
      );
      expect(
        homeStatusCardRequirement(id: 'collections_today').isAllowed(policy),
        isTrue,
      );
    });

    test('full intersection set allows security_alerts', () {
      final AppAccessPolicy both = _policy(<AppPermission>[
        AppPermissions.complianceRead,
        AppPermissions.breakGlassReview,
      ]);
      final AppAccessPolicy complianceOnly = _policy(<AppPermission>[
        AppPermissions.complianceRead,
      ]);

      expect(
        homeAtomRequirement(
          HomeDashboardAtomPermissions.alerts['security_alerts']!,
        ).isAllowed(complianceOnly),
        isFalse,
      );
      expect(
        homeAtomRequirement(
          HomeDashboardAtomPermissions.alerts['security_alerts']!,
        ).isAllowed(both),
        isTrue,
      );
    });

    test('homeChartsRequirement maps to reports:read', () {
      expect(
        homeChartsRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.clinicalRead]),
        ),
        isFalse,
      );
      expect(
        homeChartsRequirement.isAllowed(
          _policy(<AppPermission>[AppPermissions.reportsRead]),
        ),
        isTrue,
      );
    });

    test('homeShortcutRequirement uses catalog (clinical vs pharmacy)', () {
      final AppAccessPolicy clinical = _policy(<AppPermission>[
        AppPermissions.clinicalRead,
      ]);
      expect(homeShortcutRequirement(id: 'clinical').isAllowed(clinical), isTrue);
      expect(
        homeShortcutRequirement(id: 'pharmacy').isAllowed(clinical),
        isFalse,
      );
    });

    test('homeQueueItemRequirement / homeAlertRequirement map catalog keys', () {
      final AppAccessPolicy clinical = _policy(<AppPermission>[
        AppPermissions.clinicalRead,
        AppPermissions.profileRead,
      ]);
      final AppAccessPolicy lab = _policy(<AppPermission>[
        AppPermissions.labRead,
        AppPermissions.profileRead,
      ]);

      expect(
        homeQueueItemRequirement(id: 'guided_clinical_queue').isAllowed(clinical),
        isTrue,
      );
      expect(
        homeQueueItemRequirement(id: 'guided_clinical_queue').isAllowed(lab),
        isFalse,
      );
      expect(
        homeAlertRequirement(id: 'guided_critical_labs').isAllowed(lab),
        isTrue,
      );
      expect(
        homeAlertRequirement(id: 'guided_critical_labs').isAllowed(clinical),
        isFalse,
      );
    });

    test(
      'subscription strips billing KPI when billing-payments module inactive',
      () {
        final AppAccessPolicy policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['BILLING'],
            ),
            permissions: <AppPermission>[
              AppPermissions.billingRead,
              AppPermissions.profileRead,
            ],
            // Role pack string present; plan module inactive.
            moduleEntitlements: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            ],
            isAuthorizationHydrated: true,
          ),
        );

        expect(
          homeStatusCardRequirement(id: 'collections_today').isAllowed(policy),
          isFalse,
        );
        expect(homeTabReadRequirement.isAllowed(policy), isTrue);
      },
    );
  });
}
