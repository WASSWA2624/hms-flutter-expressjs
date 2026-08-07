import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_metric_routes.dart';

AppAccessPolicy _policyForRoles(List<String> roles) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(roles: roles),
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'hr'),
      ],
    ),
  );
}

void main() {
  group('home metric routes', () {
    test('HR profile exposes modal actions for leave and shift cards', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.hr);
      final AppAccessPolicy policy = _policyForRoles(<String>['HR']);

      final HomeMetricAction? leaveAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_leaves',
          label: 'Pending leave approvals',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricAction? shiftAction = homeMetricAction(
        profile: profile,
        card: const HomeStatusCard(
          id: 'unassigned_shifts',
          label: 'Unassigned shifts',
          value: 1,
        ),
        policy: policy,
      );

      expect(leaveAction?.target.kind, HomeMetricActionKind.hrWorkQueue);
      expect(leaveAction?.target.hrQueue, 'LEAVE_REQUESTS');
      expect(shiftAction?.target.hrQueue, 'UNASSIGNED_SHIFTS');
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'pending_leaves',
            label: 'Pending leave approvals',
            value: 2,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('HR queue targets map to workspace deep links', () {
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'staff-leaves'),
        ),
        <String, String>{
          'queue': 'LEAVE_REQUESTS',
          'section': 'leave-requests',
        },
      );
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'hr', resource: 'payroll-runs'),
        ),
        <String, String>{'queue': 'PAYROLL_DRAFTS', 'section': 'payroll'},
      );
      expect(
        homeHrQueryForTarget(
          const HomeRouteTarget(
            moduleSlug: 'hr',
            resource: 'shift-swap-requests',
          ),
        ),
        <String, String>{
          'queue': 'SWAP_REQUESTS',
          'section': 'leave-requests',
        },
      );
    });

    test('lab queue targets map to order deep links', () {
      expect(
        homeLabQueryForTarget(
          const HomeRouteTarget(
            moduleSlug: 'lab',
            resource: 'results',
            publicId: 'LAB0000010',
            action: 'enter',
          ),
        ),
        <String, String>{'section': 'worklist', 'order': 'LAB0000010'},
      );
      expect(
        homeRouteQueryForTarget(
          const HomeRouteTarget(moduleSlug: 'lab', resource: 'results'),
        ),
        <String, String>{'section': 'worklist'},
      );
    });

    test('doctor profile cards navigate to clinical workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'clinical'),
            AppModuleEntitlement(code: 'lab'),
          ],
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'results_pending_review',
            label: 'Results to review',
            value: 2,
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricAction(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        ),
        isNull,
      );
    });

    test('doctor secondary cards navigate into clinical care workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['CUSTOM'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.clinicalRead,
            AppPermissions.opdRead,
            AppPermissions.patientRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'radiology_pending',
            label: 'Radiology results',
            value: 1,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'prescriptions_pending',
            label: 'Prescriptions pending',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'opd_notifications_attention',
            label: 'OPD alerts',
            value: 1,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.opd,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'prescriptions_pending',
            label: 'Prescriptions pending',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.pharmacyRead],
          ),
          policy: AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'access-token'),
              user: const AuthUserProfile(
                tenantId: 'tenant-1',
                facilityId: 'facility-1',
                roles: <String>['CUSTOM'],
              ),
              permissions: const <AppPermission>[AppPermissions.clinicalRead],
              moduleEntitlements: const <AppModuleEntitlement>[
                AppModuleEntitlement(
                  code: 'pharmacy-dispensing',
                  licenseStatus: 'ACTIVE',
                ),
              ],
              isAuthorizationHydrated: true,
            ),
          ),
        ),
        isNull,
      );
    });

    test('pharmacist profile cards navigate to pharmacy workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.pharmacist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['PHARMACIST']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'pharmacy'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
          ],
        ),
      );

      final HomeMetricNavigation? pending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_dispense',
          label: 'Pending',
          value: 4,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? lowStock = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'low_stock',
          label: 'Low stock',
          value: 2,
        ),
        policy: policy,
      );

      expect(pending?.route, AppRoutes.pharmacy);
      expect(pending?.queryParameters['section'], 'pending');
      expect(lowStock?.route, AppRoutes.pharmacy);
      expect(lowStock?.queryParameters, <String, String>{
        'section': 'low-stock',
      });

      final HomeMetricNavigation? outOfStock = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'out_of_stock',
          label: 'Out of stock',
          value: 3,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? nearExpiry = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'near_expiry',
          label: 'Near expiry',
          value: 4,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? expired = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'expired',
          label: 'Expired',
          value: 1,
        ),
        policy: policy,
      );
      expect(outOfStock?.route, AppRoutes.pharmacy);
      expect(outOfStock?.queryParameters, <String, String>{
        'section': 'out-of-stock',
      });
      expect(nearExpiry?.route, AppRoutes.pharmacy);
      expect(nearExpiry?.queryParameters, <String, String>{
        'section': 'near-expiry',
      });
      expect(expired?.route, AppRoutes.pharmacy);
      expect(expired?.queryParameters, <String, String>{
        'section': 'expired',
      });

      final HomeMetricNavigation? ordersToday = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'orders_today',
          label: 'Orders today',
          value: 3,
        ),
        policy: policy,
      );
      expect(ordersToday?.route, AppRoutes.pharmacy);
      expect(ordersToday?.queryParameters['section'], 'all');
      expect(ordersToday?.queryParameters.containsKey('from'), isTrue);
      expect(ordersToday?.queryParameters.containsKey('to'), isTrue);

      final HomeMetricNavigation? salesToday = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'sales_today',
          label: 'Total sales today',
          value: 100,
          format: 'currency',
        ),
        policy: policy,
      );
      final HomeMetricNavigation? salesThisWeek = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'sales_this_week',
          label: 'Total sales (last 7 days)',
          value: 500,
          format: 'currency',
        ),
        policy: policy,
      );
      expect(salesToday, isNull);
      expect(salesThisWeek, isNull);
    });

    test('status-mix legend query carries section and period window', () {
      final DateTime now = DateTime(2026, 8, 6, 15, 30);
      final Map<String, String> query = homePharmacyStatusMixQuery(
        section: 'completed',
        period: HomeMostSoldPeriod.lastWeek,
        now: now,
      );

      expect(query['section'], 'completed');
      expect(
        DateTime.parse(query['from']!).toLocal(),
        DateTime(2026, 7, 31),
      );
      expect(
        DateTime.parse(query['to']!).toLocal(),
        DateTime(2026, 8, 7),
      );
    });

    test('pharmacist billing_pending navigates to billing when granted', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.pharmacist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['PHARMACIST'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.pharmacyRead,
            AppPermissions.pharmacyWrite,
            AppPermissions.billingRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'pharmacy'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
            AppModuleEntitlement(code: 'billing-payments'),
          ],
        ),
      );

      final HomeMetricNavigation? billingPending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'billing_pending',
          label: 'Billing pending',
          value: 120,
          format: 'currency',
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(billingPending?.route, AppRoutes.billing);
      expect(billingPending?.queryParameters, <String, String>{
        'queue': 'pendingPayment',
      });
    });

    test('receptionist metric cards navigate to front-desk workspaces', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.receptionist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
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
          ],
        ),
      );

      final HomeMetricNavigation? appointments = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'appointments_today',
          label: 'Appointments today',
          value: 3,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? deskQueue = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'desk_queue',
          label: 'Desk queue',
          value: 4,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? followUps = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'no_show_pressure',
          label: 'Follow-ups',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? activeVisits = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'turnaround_pressure',
          label: 'Active visits',
          value: 1,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? registrations = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'registrations_today',
          label: 'Registrations today',
          value: 2,
        ),
        policy: policy,
      );
      final HomeMetricNavigation? emergency = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'emergency_cases_today',
          label: 'High priority',
          value: 1,
        ),
        policy: policy,
      );

      expect(appointments?.route, AppRoutes.reception);
      expect(appointments?.queryParameters['section'], 'appointments');
      expect(appointments?.queryParameters.containsKey('from'), isTrue);
      expect(appointments?.queryParameters.containsKey('to'), isTrue);
      expect(deskQueue?.route, AppRoutes.reception);
      expect(deskQueue?.queryParameters, <String, String>{
        'section': 'desk-queue',
      });
      expect(followUps?.route, AppRoutes.reception);
      expect(followUps?.queryParameters, <String, String>{
        'section': 'follow-ups',
      });
      expect(activeVisits?.route, AppRoutes.reception);
      expect(activeVisits?.queryParameters, <String, String>{
        'section': 'active',
      });
      expect(registrations?.route, AppRoutes.patients);
      expect(emergency?.route, AppRoutes.reception);
      expect(emergency?.queryParameters['section'], 'high-priority');
    });

    test(
      'receptionist pending payments prefer payment-gate when reception open',
      () {
        final HomeDashboardProfile profile = homeProfileForRole(
          AppRole.receptionist,
        );
        final AppAccessPolicy policy = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: <String>['RECEPTIONIST'],
            ),
            permissions: const <AppPermission>[
              AppPermissions.patientRead,
              AppPermissions.billingRead,
            ],
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
            ],
            isAuthorizationHydrated: true,
          ),
        );

        final HomeMetricNavigation? pending = homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'pending_balance_amount',
            label: 'Pending payments',
            value: 4,
            requiredPermissions: <AppPermission>[AppPermissions.billingRead],
          ),
          policy: policy,
        );

        expect(pending?.route, AppRoutes.reception);
        expect(pending?.queryParameters, <String, String>{
          'section': 'payment-gate',
        });
      },
    );

    test('receptionist pending payments fall back to billing without reception', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.receptionist,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['RECEPTIONIST'],
          ),
          permissions: const <AppPermission>[
            AppPermissions.patientRead,
            AppPermissions.billingRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'patient-registry',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      final HomeMetricNavigation? pending = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'pending_balance_amount',
          label: 'Pending payments',
          value: 4,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(pending?.route, AppRoutes.billing);
      expect(pending?.queryParameters, <String, String>{
        'queue': 'pendingPayment',
      });
    });

    test('receptionAppointmentStatusSection maps desk sections', () {
      expect(
        receptionAppointmentStatusSection(segmentId: 'scheduled'),
        'desk-queue',
      );
      expect(
        receptionAppointmentStatusSection(segmentId: 'in_progress'),
        'active',
      );
      expect(
        receptionAppointmentStatusSection(label: 'No-show'),
        'follow-ups',
      );
      expect(
        receptionAppointmentStatusSection(segmentId: 'completed'),
        'appointments',
      );
    });

    test('homeHrMetricAccessAllowed gates HR modal actions', () {
      final AppAccessPolicy allowed = _policyForRoles(<String>['HR']);
      final AppAccessPolicy denied = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'hr'),
          ],
        ),
      );

      expect(homeHrMetricAccessAllowed(allowed), isTrue);
      expect(homeHrMetricAccessAllowed(denied), isFalse);
    });

    test('never navigates from a card missing required permissions', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
            roles: <String>['CUSTOM'],
          ),
          permissions: const <AppPermission>[AppPermissions.clinicalRead],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'encounters-vitals',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'lab-workflows',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'results_pending_review',
            label: 'Results',
            value: 2,
            requiredPermissions: <AppPermission>[AppPermissions.labRead],
          ),
          policy: policy,
        ),
        isNull,
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned',
            value: 3,
            requiredPermissions: <AppPermission>[AppPermissions.clinicalRead],
          ),
          policy: policy,
        )?.route,
        AppRoutes.clinical,
      );
    });

    test('facility admin revenue KPI navigates to billing workspace', () {
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.facilityAdmin,
      );
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['FACILITY_ADMIN']),
          permissions: const <AppPermission>[
            AppPermissions.billingRead,
            AppPermissions.patientRead,
          ],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      final HomeMetricNavigation? revenue = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'collections_today',
          label: 'Revenue',
          value: 100,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(revenue?.route, AppRoutes.billing);
    });

    test('patient open bills KPI navigates to billing pending queue', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.patient);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['PATIENT']),
          permissions: const <AppPermission>[AppPermissions.billingRead],
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
          isAuthorizationHydrated: true,
        ),
      );

      final HomeMetricNavigation? bills = homeMetricNavigation(
        profile: profile,
        card: const HomeStatusCard(
          id: 'my_open_bills',
          label: 'Bills',
          value: 2,
          requiredPermissions: <AppPermission>[AppPermissions.billingRead],
        ),
        policy: policy,
      );

      expect(bills?.route, AppRoutes.billing);
      expect(bills?.queryParameters['queue'], 'pendingPayment');
    });

    test('doctor KPI taps include filter-tallied section params', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.doctor);
      final AppAccessPolicy policy = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: AuthUserProfile(roles: <String>['DOCTOR']),
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(code: 'clinical'),
            AppModuleEntitlement(code: 'lab'),
            AppModuleEntitlement(code: 'pharmacy-dispensing'),
          ],
        ),
      );

      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'assigned',
            label: 'Assigned today',
            value: 3,
          ),
          policy: policy,
        )?.queryParameters,
        <String, String>{'section': 'assigned-to-me'},
      );
      expect(
        homeMetricNavigation(
          profile: profile,
          card: const HomeStatusCard(
            id: 'critical_labs',
            label: 'Critical labs',
            value: 1,
          ),
          policy: policy,
        )?.queryParameters,
        <String, String>{'section': 'results-ready'},
      );
      expect(
        profile.metricRouteTargets['prescriptions_pending']?.queryParameters,
        <String, String>{'section': 'assigned-to-me'},
      );
    });

    test('billing pending approvals uses approvalRequired queue', () {
      expect(
        homeDefaultBillingMetricQuery('pending_approvals'),
        <String, String>{'queue': 'approvalRequired'},
      );
      expect(
        homeProfileForRole(AppRole.billing)
            .metricRouteTargets['pending_approvals']
            ?.queryParameters,
        <String, String>{'queue': 'approvalRequired'},
      );
    });

    test('operations and biomed profiles declare filter-tallied metric routes', () {
      final HomeDashboardProfile ops = homeProfileForRole(AppRole.operations);
      expect(
        ops.metricRouteTargets['maintenance_open']?.queryParameters,
        <String, String>{'section': 'open'},
      );
      expect(
        ops.metricRouteTargets['occupied_beds']?.queryParameters,
        <String, String>{'section': 'occupied'},
      );

      final HomeDashboardProfile biomed = homeProfileForRole(AppRole.biomed);
      expect(
        biomed.metricRouteTargets['open_work_orders']?.queryParameters,
        <String, String>{
          'panel': 'work-orders',
          'queue': 'OPEN_WORK_ORDERS',
        },
      );
      expect(
        homeProfileForRole(AppRole.houseKeeper)
            .metricRouteTargets['overdue_tasks']
            ?.queryParameters,
        <String, String>{
          'section': 'tasks',
          'queue': 'OVERDUE_TASKS',
        },
      );
      expect(
        homeProfileForRole(AppRole.ambulanceOperator)
            .metricRouteTargets['critical_cases']
            ?.queryParameters,
        <String, String>{'scope': 'critical'},
      );
    });
  });
}
