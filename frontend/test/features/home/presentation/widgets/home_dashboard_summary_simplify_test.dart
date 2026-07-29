import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_layout.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_profiles.dart';
import 'package:hosspi_hms/features/home/presentation/widgets/home_dashboard_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_metric_strip.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_priority_panel.dart';

const List<AppModuleEntitlement> _activeModules = <AppModuleEntitlement>[
  AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'lab-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'radiology-workflows', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'pharmacy-dispensing', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'facilities-maintenance', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'hr-rosters', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'reporting-analytics', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'subscription-controls', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'integrations-core', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'notifications-communications',
    licenseStatus: 'ACTIVE',
  ),
  AppModuleEntitlement(code: 'emergency-trauma', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(code: 'mortuary', licenseStatus: 'ACTIVE'),
  AppModuleEntitlement(
    code: 'biomedical-engineering-suite',
    licenseStatus: 'ACTIVE',
  ),
];

AppAccessPolicy _policy({
  required List<String> roles,
  required Iterable<AppPermission> permissions,
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: facilityId,
        roles: roles,
      ),
      permissions: permissions,
      moduleEntitlements: _activeModules,
      isAuthorizationHydrated: true,
    ),
  );
}

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  group('home dashboard deep dedupe', () {
    test('tenant admin drops Create when Manage hubs cover them', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['TENANT_ADMIN'],
        permissions: AppPermissions.all,
      );
      final HomeDashboardProfile profile = homeProfileForAccessPolicy(policy);

      expect(profile.quickActionIds, isEmpty);
      final List<HomeActionDefinition> quick =
          homeDeduplicateQuickActionsAgainstManage(
            homeVisibleActions(
              profile.quickActionIds,
              policy,
              maxCount: profile.maxQuickActions,
            ),
            profile.emptyActionIds,
            policy,
          );
      final List<HomeActionDefinition> manage = homeVisibleEmptyActions(
        profile.emptyActionIds,
        policy,
      );

      expect(quick, isEmpty);
      expect(
        manage.map((HomeActionDefinition a) => a.id),
        containsAll(<String>[
          'manage_facilities',
          'manage_roles_access',
          'manage_users',
          'add_staff_profile',
        ]),
      );
      // Expansion must not reintroduce department Create rows onto org home.
      expect(profile.quickActionIds, isNot(contains('register_patient')));
      expect(profile.quickActionIds, isNot(contains('create_invoice')));
    });

    test('platform admin drops Create when Manage hubs cover them', () {
      // Platform elevated: no tenant context so grantsAll is unrestricted.
      final AppAccessPolicy policy = _policy(
        roles: <String>['SUPER_ADMIN'],
        permissions: AppPermissions.all,
        tenantId: null,
        facilityId: null,
      );
      final HomeDashboardProfile profile = homeProfileForAccessPolicy(policy);

      expect(profile.quickActionIds, isEmpty);
      final List<HomeActionDefinition> quick =
          homeDeduplicateQuickActionsAgainstManage(
            homeVisibleActions(
              profile.quickActionIds,
              policy,
              maxCount: profile.maxQuickActions,
            ),
            profile.emptyActionIds,
            policy,
          );
      final List<HomeActionDefinition> manage = homeVisibleEmptyActions(
        profile.emptyActionIds,
        policy,
      );

      expect(quick, isEmpty);
      expect(
        manage.map((HomeActionDefinition a) => a.id),
        <String>[
          'manage_tenants',
          'manage_facilities',
          'manage_roles_access',
          'manage_users',
        ],
      );
    });

    test('keeps Create when Manage hub is unauthorized', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['FACILITY_ADMIN'],
        permissions: const <AppPermission>[
          AppPermissions.facilityAdmin,
          AppPermissions.patientWrite,
        ],
      );

      final List<HomeActionDefinition> quick =
          homeDeduplicateQuickActionsAgainstManage(
            homeVisibleActions(
              <String>['create_facility', 'create_user'],
              policy,
            ),
            <String>['manage_facilities', 'manage_users'],
            policy,
          );

      expect(
        quick.map((HomeActionDefinition a) => a.id),
        contains('create_facility'),
      );
    });

    test('unauthorized manage and create ids are absent', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['PATIENT'],
        permissions: const <AppPermission>[
          AppPermissions.profileRead,
          AppPermissions.profileUpdate,
        ],
      );
      final HomeDashboardProfile tenant = homeProfileForRole(
        AppRole.tenantAdmin,
      );

      expect(homeVisibleEmptyActions(tenant.emptyActionIds, policy), isEmpty);
      expect(
        homeVisibleActions(
          <String>['create_facility', 'manage_users', 'update_own_profile'],
          policy,
        ).map((HomeActionDefinition a) => a.id),
        <String>['update_own_profile'],
      );
    });

    test('renamed Facility management title; no management description body', () {
      final AppLocalizationsEn l10n = AppLocalizationsEn();
      final HomeDashboardProfile tenant = homeProfileForRole(
        AppRole.tenantAdmin,
      );
      final HomeDashboardProfile platform = homeProfileForRole(
        AppRole.superAdmin,
      );

      expect(homeQueueTitle(AppRole.tenantAdmin), 'Facility management');
      expect(homeQueueTitle(AppRole.superAdmin), 'Platform management');
      expect(
        homeEmptyManagementSectionTitle(tenant, l10n),
        l10n.homeFacilityManagementTitle,
      );
      expect(
        homeEmptyManagementSectionTitle(platform, l10n),
        l10n.homePlatformManagementTitle,
      );
      expect(tenant.emptyMessage, isEmpty);
      expect(platform.emptyMessage, isEmpty);
    });

    test('shortcut floor is at least 4 when catalog supplies them', () {
      for (final AppRole role in <AppRole>[
        AppRole.superAdmin,
        AppRole.tenantAdmin,
        AppRole.facilityAdmin,
        AppRole.operations,
        AppRole.labTech,
        AppRole.pharmacist,
        AppRole.hr,
        AppRole.biomed,
      ]) {
        final HomeDashboardProfile profile = homeProfileForRole(role);
        if (profile.shortcutIds.isEmpty) {
          continue;
        }
        expect(
          profile.maxShortcutTiles,
          greaterThanOrEqualTo(4),
          reason: role.value,
        );
        expect(
          profile.shortcutIds.length,
          greaterThanOrEqualTo(4),
          reason: role.value,
        );
      }
    });

    test('authorized shortcuts reach at least 4 when grants allow', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['FACILITY_ADMIN'],
        permissions: AppPermissions.all,
      );
      final HomeDashboardProfile profile = homeProfileForRole(
        AppRole.facilityAdmin,
      );
      final List<HomeActionDefinition> quick = homeVisibleActions(
        profile.quickActionIds,
        policy,
        maxCount: profile.maxQuickActions,
      );
      final List<HomeShortcutDefinition> shortcuts =
          homeShortcutsExcludingQuickActions(
            homeVisibleShortcuts(profile.shortcutIds, policy),
            quick,
            profile,
          ).take(profile.maxShortcutTiles).toList(growable: false);

      expect(shortcuts.length, greaterThanOrEqualTo(4));
    });

    test(
      'role-default grants still yield ≥4 shortcuts when catalog permits',
      () {
        for (final String roleCode in <String>[
          'HR',
          'UNIT_MANAGER',
          'MORTUARY_STAFF',
          'MORTUARY_MANAGER',
          'INTEGRATION_ADMIN',
          'AMBULANCE_OPERATOR',
          'LAB_TECH',
          'PHARMACIST',
        ]) {
          final AppAccessPolicy policy = AppAccessPolicy.fromSession(
            AuthSession(
              tokens: SessionTokens(accessToken: 'token'),
              user: AuthUserProfile(
                tenantId: 'tenant-1',
                facilityId: 'facility-1',
                roles: <String>[roleCode],
              ),
              // Unhydrated + empty explicit set → client role pack defaults.
              permissions: const <AppPermission>{},
              moduleEntitlements: _activeModules,
              isAuthorizationHydrated: false,
            ),
          );
          final HomeDashboardProfile profile = homeProfileForRoles(policy.roles);
          if (profile.shortcutIds.isEmpty) {
            continue;
          }
          final List<HomeShortcutDefinition> shortcuts = homeVisibleShortcuts(
            profile.shortcutIds,
            policy,
          );
          expect(
            shortcuts.length,
            greaterThanOrEqualTo(4),
            reason: '$roleCode authorized=${shortcuts.map((s) => s.id).toList()}',
          );
        }
      },
    );

    test('lab shortcuts keep floor when quick actions share lab route', () {
      final AppAccessPolicy policy = _policy(
        roles: <String>['LAB_TECH'],
        permissions: const <AppPermission>[
          AppPermissions.labRead,
          AppPermissions.labWrite,
          AppPermissions.patientRead,
          AppPermissions.reportsRead,
          AppPermissions.profileRead,
          AppPermissions.communicationsRead,
        ],
      );
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.labTech);
      final List<HomeActionDefinition> quick = homeVisibleActions(
        profile.quickActionIds,
        policy,
        maxCount: profile.maxQuickActions,
      );
      final List<HomeShortcutDefinition> shortcuts =
          homeShortcutsExcludingQuickActions(
            homeVisibleShortcuts(profile.shortcutIds, policy),
            quick,
            profile,
          );

      expect(shortcuts.length, greaterThanOrEqualTo(4));
    });
  });

  group('dashboard metric strip readability', () {
    testWidgets(
      'six cards keep currency and long labels readable at desktop width',
      (WidgetTester tester) async {
        final Color accent = Colors.teal.shade700;
        await tester.pumpWidget(
          _harness(
            SizedBox(
              width: 1200,
              child: DashboardMetricStrip(
                maxCards: 6,
                cards: <DashboardMetricCardData>[
                  DashboardMetricCardData(
                    label: 'Facilities',
                    value: '12 / 14',
                    icon: Icons.apartment_outlined,
                    accent: accent,
                    semanticsLabel: 'Facilities: 12 / 14',
                  ),
                  DashboardMetricCardData(
                    label: 'Adoption',
                    value: '86%',
                    icon: Icons.trending_up_outlined,
                    accent: accent,
                    semanticsLabel: 'Adoption: 86%',
                  ),
                  DashboardMetricCardData(
                    label: 'Revenue',
                    value: 'UGX1.2M',
                    icon: Icons.payments_outlined,
                    accent: accent,
                    semanticsLabel: 'Revenue: UGX1.2M',
                  ),
                  DashboardMetricCardData(
                    label: 'Subscription',
                    value: '94%',
                    icon: Icons.workspace_premium_outlined,
                    accent: accent,
                    semanticsLabel: 'Subscription: 94%',
                  ),
                  DashboardMetricCardData(
                    label: 'Pending balances',
                    value: 'UGX480K',
                    icon: Icons.account_balance_wallet_outlined,
                    accent: accent,
                    semanticsLabel: 'Pending balances: UGX480K',
                  ),
                  DashboardMetricCardData(
                    label: 'Users',
                    value: '128',
                    icon: Icons.people_outline,
                    accent: accent,
                    semanticsLabel: 'Users: 128',
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Facilities'), findsOneWidget);
        expect(find.text('Adoption'), findsOneWidget);
        expect(find.text('UGX1.2M'), findsOneWidget);
        expect(find.text('Pending balances'), findsOneWidget);
        expect(find.textContaining('Facilit…'), findsNothing);
        expect(find.textContaining('Adopti…'), findsNothing);
        expect(find.textContaining('U…'), findsNothing);

        // Values stay at title size (scale down only when needed).
        final Size shortValue = tester.getSize(find.text('128'));
        final Size longValue = tester.getSize(find.text('UGX1.2M'));
        expect(shortValue.height, lessThanOrEqualTo(36));
        expect(longValue.width, greaterThan(40));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('management empty strip copy', () {
    testWidgets('shows Facility management without description body', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          DashboardPriorityPanel(
            data: DashboardPriorityPanelData(
              queueTitle: 'Facility management',
              emptySectionTitle: 'Facility management',
              emptyMessage: '',
              showAlerts: false,
              emptyActions: <DashboardQuickActionData>[
                DashboardQuickActionData(
                  label: 'Manage facilities',
                  icon: Icons.domain_outlined,
                  semanticsLabel: 'Manage facilities',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Facility management'), findsOneWidget);
      expect(
        find.text(
          'Create facilities, assign roles, and onboard users across your organization.',
        ),
        findsNothing,
      );
      expect(find.text('Manage facilities'), findsOneWidget);
    });
  });

  group('empty section collapse', () {
    test('no profile keeps Create beside covering Manage hubs', () {
      for (final AppRole role in AppRole.values) {
        final HomeDashboardProfile profile = homeProfileForRole(role);
        final Set<String> empty = profile.emptyActionIds
            .map(homeCanonicalActionId)
            .toSet();
        for (final MapEntry<String, String> entry
            in homeCreateCoveredByManageHub.entries) {
          if (empty.contains(entry.value)) {
            expect(
              profile.quickActionIds.map(homeCanonicalActionId),
              isNot(contains(entry.key)),
              reason: '${role.value}: ${entry.key} vs ${entry.value}',
            );
          }
        }
      }
    });

    test('billing navigates via Quick links, not a second review strip', () {
      final HomeDashboardProfile profile = homeProfileForRole(AppRole.billing);

      expect(profile.emptyActionIds, isEmpty);
      expect(profile.shortcutIds, <String>[
        'billing',
        'patients',
        'claims',
        'reports',
        'settings',
      ]);
      expect(profile.shortcutIds.length, greaterThanOrEqualTo(4));
      expect(profile.maxShortcutTiles, greaterThanOrEqualTo(4));
      expect(profile.quickActionIds, <String>[
        'create_invoice',
        'receive_payment',
        'process_refund',
        'close_shift',
      ]);
    });

    testWidgets('collapses empty results and follow-ups chrome', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          DashboardPriorityPanel(
            data: DashboardPriorityPanelData(
              queueTitle: 'Worklist',
              emptyMessage: 'No assigned clinical work right now.',
              showAlerts: true,
              alertsTitle: 'Critical alerts',
              alertItems: const <DashboardWorklistItemData>[],
              showResults: true,
              resultsTitle: 'Results ready',
              resultsItems: const <DashboardWorklistItemData>[],
              showFollowUps: true,
              followUpTitle: 'Follow-ups',
              followUpItems: const <DashboardWorklistItemData>[],
              showShortcuts: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Worklist'), findsOneWidget);
      expect(find.text('No assigned clinical work right now.'), findsOneWidget);
      expect(find.text('Results ready'), findsNothing);
      expect(find.text('Follow-ups'), findsNothing);
      expect(find.text('Critical alerts'), findsNothing);
      expect(find.text('Nothing pending'), findsNothing);
      expect(find.text('All clear'), findsNothing);
    });
  });
}
