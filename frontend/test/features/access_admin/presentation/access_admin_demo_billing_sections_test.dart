import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/access_admin/data/repositories/access_admin_repository_impl.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/repositories/access_admin_repository.dart';
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_access.dart';
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_demo_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/user_similarity_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../helpers/test_harness.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _demoUser = AccessAdminItem(
  id: 'demo-1',
  resource: AccessAdminResource.demoUsers,
  displayId: 'DEM-1',
  title: 'Demo Nurse',
  email: 'demo.nurse@example.com',
  status: 'ACTIVE',
  facilityName: 'Main Campus',
  isDemo: true,
);

AccessAdminWorkspaceData _demoData({
  bool canWrite = true,
  bool canResetDemoPasswords = false,
  List<AccessAdminItem> items = const <AccessAdminItem>[_demoUser],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
      canResetDemoPasswords: canResetDemoPasswords,
    ),
    lookups: const AccessAdminLookups(
      userStatuses: <String>['ACTIVE', 'INACTIVE'],
    ),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      panel: AccessAdminPanel.demo,
      resource: AccessAdminResource.demoUsers,
    ),
  );
}

AppAccessPolicy _policy({
  Set<AppPermission>? permissions,
  List<String> roles = const <String>['TENANT_ADMIN'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: tenantId,
        facilityId: facilityId,
        roles: roles,
      ),
      permissions: permissions ??
          <AppPermission>{
            AppPermissions.tenantAdmin,
            AppPermissions.facilityAdmin,
          },
      moduleEntitlements: const <AppModuleEntitlement>[],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubWorkspace(
  _MockAccessAdminRepository repository, {
  AccessAdminWorkspaceData? data,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      data ?? _demoData(),
    ),
  );
  when(
    () => repository.getUserDetail(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => Result<AccessAdminUserDetail>.success(
      AccessAdminUserDetail(
        item: (data ?? _demoData()).items.isNotEmpty
            ? (data ?? _demoData()).items.first
            : _demoUser,
        effectivePermissions: const <String>['billing:read', 'clinical:read'],
      ),
    ),
  );
}

Future<void> _pumpDemo(
  WidgetTester tester, {
  required _MockAccessAdminRepository repository,
  required AppAccessPolicy policy,
  AccessAdminWorkspaceData? data,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
  bool stubWorkspace = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubWorkspace) {
    _stubWorkspace(repository, data: data);
  }

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/admin/access?panel=demo',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/access',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: AccessAdminWorkspacePage(
              initialQuery: AccessAdminWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accessAdminRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(policy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  late _MockAccessAdminRepository repository;

  setUpAll(() {
    registerFallbackValue(const AccessAdminWorkspaceQuery());
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('AccessAdminDemoBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(
        AccessAdminDemoBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(AccessAdminDemoBillingInventory.billableClasses, isEmpty);
    });

    test('reserved financial atoms are unmounted', () {
      final List<String> unmounted = AccessAdminDemoBillingInventory.atoms
          .where((AccessAdminDemoFinancialAtom atom) => !atom.mounted)
          .map((AccessAdminDemoFinancialAtom atom) => atom.id)
          .toList();
      expect(unmounted, containsAll(<String>[
        'delete_user',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]));
    });

    test('role/permissions display uses NOT_BILLED audit (display-only grants)', () {
      final AccessAdminDemoFinancialAtom displayAtom =
          AccessAdminDemoBillingInventory.atoms.firstWhere(
        (AccessAdminDemoFinancialAtom atom) =>
            atom.id == 'role_permissions_display',
      );
      expect(displayAtom.auditCode, 'NOT_BILLED');
      expect(
        displayAtom.financialClass,
        AccessAdminDemoFinancialClass.notBilled,
      );
    });

    test('scope note documents no patient ledger mutation', () {
      expect(accessAdminDemoBillingScopeNote, contains('Billing'));
      expect(accessAdminDemoBillingScopeNote, contains('provisioning'));
    });

    test('helper reports no billable mounted actions', () {
      expect(accessAdminDemoTabHasNoBillableActions(), isTrue);
    });
  });

  group('Demo billing bypass + authorization (AC2, AC4)', () {
    testWidgets('no payment/issue/collect affordances on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        data: _demoData(canWrite: true, canResetDemoPasswords: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminCreateUserAction), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Open billing'), findsNothing);
    });

    testWidgets('facility:admin cannot reset password or collect (∩ denial)', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        ),
        data: _demoData(canWrite: true, canResetDemoPasswords: true),
      );

      await tester.tap(find.text('Demo Nurse').first);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      final AppLocalizations l10n = context.l10n;

      expect(
        find.text(l10n.accessAdminResetDemoPasswordAction),
        findsNothing,
      );
    });

    testWidgets('unauthorized actor sees no demo worklist or pay chrome', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.text('Demo Nurse'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
    });

    testWidgets('nested create dialog refuses open without Demo mutate ∩', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      _stubWorkspace(repository, data: _demoData(canWrite: true));
      AccessAdminItem? createResult = _demoUser;
      final AccessAdminWorkspaceState state = AccessAdminWorkspaceState(
        data: _demoData(canWrite: true),
        query: _demoData().query,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessAdminRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.facilityAdmin},
                roles: const <String>['FACILITY_ADMIN'],
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  return TextButton(
                    onPressed: () async {
                      createResult = await openAccessAdminCreateUserDialog(
                        context,
                        ref,
                        state,
                      );
                    },
                    child: const Text('probe-demo-create'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('probe-demo-create'));
      await tester.pumpAndSettle();

      expect(createResult, isNull);
      expect(find.byType(AppDialog), findsNothing);
    });
  });

  group('Demo sync parity (AC3)', () {
    testWidgets('status toggle syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      var deactivated = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final AccessAdminItem item = deactivated
            ? _demoUser.copyWith(status: 'INACTIVE')
            : _demoUser;
        return Result<AccessAdminWorkspaceData>.success(
          _demoData(items: <AccessAdminItem>[item]),
        );
      });
      when(() => repository.setUserStatus(any(), any())).thenAnswer((
        _,
      ) async {
        deactivated = true;
        return const Result<void>.success(null);
      });
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(item: _demoUser),
        ),
      );

      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        data: _demoData(canWrite: true),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminDeactivateAction), findsWidgets);
      await tester.tap(find.text(l10n.accessAdminDeactivateAction).first);
      await tester.pumpAndSettle();

      verify(() => repository.setUserStatus('demo-1', 'INACTIVE')).called(1);
      verifyNever(() => repository.resetDemoUserPassword(any()));
      expect(find.text(l10n.accessAdminActivateAction), findsWidgets);
    });

    testWidgets('idempotent getWorkspace replay returns stable demo list', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => Result<AccessAdminWorkspaceData>.success(_demoData()),
      );
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(item: _demoUser),
        ),
      );

      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        stubWorkspace: false,
      );
      verify(() => repository.getWorkspace(any())).called(greaterThan(0));
      expect(find.text('Demo Nurse'), findsWidgets);
    });
  });

  group('Flat titled sections (AC5)', () {
    testWidgets('desktop light: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'demo worklist desktop light',
      );
    });

    testWidgets('mobile dark: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'demo worklist mobile dark',
      );
    });

    testWidgets('detail dialog: sibling access panels without nesting', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        data: _demoData(canWrite: true, canResetDemoPasswords: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_demoUser);
      await tester.pumpAndSettle();

      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AppDialog),
        contextLabel: 'demo detail dialog',
      );
      expectFlatSections(tester);
    });

    testWidgets('similarity review dialog: flat sections', (
      WidgetTester tester,
    ) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                showUserSimilarityDialog(
                  context,
                  proposed: const UserSimilarityProposedValues(
                    email: 'demo.new@example.com',
                    positionTitle: 'Demo Nurse',
                    firstName: 'New',
                    lastName: 'Demo',
                  ),
                  matches: const <UserSimilarityMatch>[],
                  allowProceed: true,
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AppDialog),
        contextLabel: 'demo create-user similarity dialog',
      );
    });

    testWidgets('dark theme desktop: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'demo worklist desktop dark',
      );
    });
  });

  group('Authorized UI states (AC4, AC6)', () {
    testWidgets('empty state remains observable', (WidgetTester tester) async {
      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        data: _demoData(canWrite: true, items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(context.l10n.accessAdminCreateUserAction), findsOneWidget);
    });

    testWidgets('error state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<AccessAdminWorkspaceData>.failure(
          AppFailure.network(),
        ),
      );

      await _pumpDemo(
        tester,
        repository: repository,
        policy: _policy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.errorNetworkMessage), findsWidgets);
    });

    test('Demo atom permissions align with billing inventory mounted set', () {
      expect(
        AccessAdminDemoAtomPermissions.create,
        accessAdminCreateRequirement,
      );
      expect(canMutateAccessAdminDemo(_policy()), isTrue);
      expect(
        AccessAdminDemoBillingInventory.mountedAtoms.length,
        greaterThan(10),
      );
    });
  });
}
