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
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_directory_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_dialogs.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/user_similarity_dialog.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../helpers/test_harness.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _directoryUser = AccessAdminItem(
  id: 'user-1',
  resource: AccessAdminResource.users,
  displayId: 'USR-1',
  title: 'Ada Lovelace',
  email: 'ada@example.com',
  status: 'ACTIVE',
  facilityName: 'Main Campus',
);

const AccessAdminItem _billingRoleUser = AccessAdminItem(
  id: 'user-bill',
  resource: AccessAdminResource.users,
  displayId: 'USR-BILL',
  title: 'Billing Clerk',
  email: 'billing@example.com',
  status: 'ACTIVE',
  facilityName: 'Main Campus',
  roles: <AccessAdminRoleRef>[
    AccessAdminRoleRef(id: 'role-bill', name: 'BILLING'),
  ],
);

AccessAdminWorkspaceData _directoryData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_directoryUser],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
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
      panel: AccessAdminPanel.directory,
      resource: AccessAdminResource.users,
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
      data ?? _directoryData(),
    ),
  );
}

Future<void> _pumpDirectory(
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
    initialLocation: '/admin/access?panel=directory',
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
    registerFallbackValue(
      const AccessAdminUserDraft(
        tenantId: 'tenant-1',
        email: 'fallback@example.com',
        positionTitle: 'Staff',
        firstName: 'Fallback',
      ),
    );
  });

  setUp(() {
    repository = _MockAccessAdminRepository();
  });

  group('Directory financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit reason', () {
      expect(accessAdminDirectoryTabHasNoBillableActions(), isTrue);
      expect(AccessAdminDirectoryBillingInventory.mountedAtoms, isNotEmpty);
      expect(AccessAdminDirectoryBillingInventory.billableClasses, isEmpty);
      for (final AccessAdminDirectoryFinancialAtom atom
          in AccessAdminDirectoryBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isNot(
            isIn(<AccessAdminDirectoryFinancialClass>[
              AccessAdminDirectoryFinancialClass.createCharge,
              AccessAdminDirectoryFinancialClass.settle,
              AccessAdminDirectoryFinancialClass.adjust,
              AccessAdminDirectoryFinancialClass.reverse,
              AccessAdminDirectoryFinancialClass.defer,
            ]),
          ),
          reason: atom.id,
        );
        expect(atom.auditCode, isNotNull, reason: atom.id);
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('reserved off-tab atoms stay NO_CHARGE / not mounted', () {
      final AccessAdminDirectoryFinancialAtom edit = AccessAdminDirectoryBillingInventory
          .atoms
          .singleWhere((AccessAdminDirectoryFinancialAtom atom) => atom.id == 'edit_user');
      expect(edit.mounted, isFalse);
      expect(edit.auditCode, 'NO_CHARGE');
      expect(
        AccessAdminDirectoryBillingInventory.atoms
            .singleWhere(
              (AccessAdminDirectoryFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
    });

    test('scope note documents NOT_BILLED internal administration', () {
      expect(accessAdminDirectoryBillingScopeNote, contains('NOT_BILLED'));
      expect(accessAdminDirectoryBillingScopeNote, contains('Billing'));
    });

    test('Directory write gate intersects workspace canWrite', () {
      expect(
        AccessAdminDirectoryBillingInventory.canMutateDirectory(
          workspaceCanWrite: true,
          policyAllowsWrite: canMutateAccessAdminDirectory(_policy()),
        ),
        isTrue,
      );
      expect(
        AccessAdminDirectoryBillingInventory.canMutateDirectory(
          workspaceCanWrite: false,
          policyAllowsWrite: canMutateAccessAdminDirectory(_policy()),
        ),
        isFalse,
      );
    });
  });

  group('Directory billing bypass (AC2–AC5)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        data: _directoryData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelDirectory), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets(
      'user with billing role in detail is read-only metadata — no ledger mutation',
      (WidgetTester tester,
    ) async {
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(
            item: _billingRoleUser,
            effectivePermissions: <String>['billing:read', 'billing:write'],
          ),
        ),
      );

      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        data: _directoryData(
          canWrite: true,
          items: const <AccessAdminItem>[_billingRoleUser],
        ),
      );

      expect(find.text('Billing Clerk'), findsWidgets);

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_billingRoleUser);
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      verifyNever(() => repository.createUser(any()));
      expectFlatSections(tester);
    });

    testWidgets('detail dialog is Close-only for readers — no financial controls', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(item: _directoryUser),
        ),
      );

      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        ),
        data: _directoryData(canWrite: true),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_directoryUser);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
      expect(find.text(l10n.accessAdminDeactivateAction), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot reach billing collect chrome', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        ),
      );

      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('create user dialog refuses open without mutate ∩', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      final AccessAdminWorkspaceState state = AccessAdminWorkspaceState(
        data: _directoryData(canWrite: true),
        query: _directoryData().query,
      );

      AccessAdminItem? createResult = _directoryUser;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accessAdminRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(facilityOnly),
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
                    child: const Text('probe-create'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('probe-create'));
      await tester.pumpAndSettle();

      expect(createResult, isNull);
      expect(find.byType(AppDialog), findsNothing);
      verifyNever(() => repository.createUser(any()));
    });
  });

  group('Directory section layout (AC5)', () {
    testWidgets('desktop worklist: flat sections', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(1280, 900),
      );
      expectFlatSections(tester);
    });

    testWidgets('mobile worklist: flat sections', (WidgetTester tester) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        viewport: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('user detail dialog: sibling sections only, never nested', (
      WidgetTester tester,
    ) async {
      when(
        () => repository.getUserDetail(
          any(),
          tenantId: any(named: 'tenantId'),
          facilityId: any(named: 'facilityId'),
        ),
      ).thenAnswer(
        (_) async => const Result<AccessAdminUserDetail>.success(
          AccessAdminUserDetail(
            item: _directoryUser,
            effectivePermissions: <String>['clinical:read'],
          ),
        ),
      );

      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_directoryUser);
      await tester.pumpAndSettle();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AppDialog),
        contextLabel: 'Directory user detail',
      );
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
                    email: 'new@example.com',
                    positionTitle: 'Nurse',
                    firstName: 'New',
                    lastName: 'User',
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
        contextLabel: 'directory create-user similarity dialog',
      );
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.light,
      );
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });
  });

  group('Directory sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('status toggle syncs worklist without billing repository calls', (
      WidgetTester tester,
    ) async {
      var deactivated = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final AccessAdminItem item = deactivated
            ? _directoryUser.copyWith(status: 'INACTIVE')
            : _directoryUser;
        return Result<AccessAdminWorkspaceData>.success(
          _directoryData(items: <AccessAdminItem>[item]),
        );
      });
      when(
        () => repository.setUserStatus(any(), any()),
      ).thenAnswer((_) async {
        deactivated = true;
        return const Result<void>.success(null);
      });

      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text(l10n.accessAdminDeactivateAction).first);
      await tester.pumpAndSettle();

      verify(() => repository.setUserStatus('user-1', 'INACTIVE')).called(1);
      verifyNever(() => repository.createUser(any()));
      expect(find.text(l10n.accessAdminActivateAction), findsWidgets);
    });

    testWidgets('status toggle idempotent replay calls setUserStatus each time without billing', (
      WidgetTester tester,
    ) async {
      var status = 'ACTIVE';
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        return Result<AccessAdminWorkspaceData>.success(
          _directoryData(
            items: <AccessAdminItem>[_directoryUser.copyWith(status: status)],
          ),
        );
      });
      when(
        () => repository.setUserStatus(any(), any()),
      ).thenAnswer((Invocation invocation) async {
        status = invocation.positionalArguments[1] as String;
        return const Result<void>.success(null);
      });

      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text(l10n.accessAdminDeactivateAction).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accessAdminActivateAction).first);
      await tester.pumpAndSettle();

      verify(() => repository.setUserStatus('user-1', 'INACTIVE')).called(1);
      verify(() => repository.setUserStatus('user-1', 'ACTIVE')).called(1);
      verifyNever(() => repository.createUser(any()));
    });

    testWidgets('empty authorized state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpDirectory(
        tester,
        repository: repository,
        policy: _policy(),
        data: _directoryData(canWrite: true, items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(context.l10n.accessAdminCreateUserAction), findsOneWidget);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<AccessAdminWorkspaceData>.failure(
          AppFailure.network(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=directory',
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
            appAccessPolicyProvider.overrideWithValue(_policy()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });
  });
}
