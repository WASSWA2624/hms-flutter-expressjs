import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/router/shell_route_access.dart';
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
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccessAdminRepository extends Mock
    implements AccessAdminRepository {}

const AccessAdminItem _registration = AccessAdminItem(
  id: 'reg-1',
  resource: AccessAdminResource.registrationFollowUps,
  displayId: 'REG-1',
  title: 'Pending Clinic',
  email: 'pending.clinic@example.com',
  status: 'PENDING',
  subtitle: 'Awaiting activation',
);

AccessAdminWorkspaceData _registrationsData({
  bool canWrite = true,
  List<AccessAdminItem> items = const <AccessAdminItem>[_registration],
}) {
  return AccessAdminWorkspaceData(
    permissions: AccessAdminWorkspacePermissions(
      canRead: true,
      canWrite: canWrite,
    ),
    items: items,
    page: AppPage<AccessAdminItem>(
      items: items,
      request: const AppPageRequest(pageSize: 12),
      totalItemCount: items.length,
    ),
    query: const AccessAdminWorkspaceQuery(
      panel: AccessAdminPanel.registrations,
      resource: AccessAdminResource.registrationFollowUps,
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

AppAccessPolicy _elevatedPolicy({
  Set<AppPermission>? permissions,
  bool canWriteKeys = true,
}) {
  return _policy(
    permissions: permissions ??
        <AppPermission>{
          AppPermissions.systemAdmin,
          if (canWriteKeys) AppPermissions.tenantAdmin,
        },
    roles: const <String>['SUPER_ADMIN'],
  );
}

void _stubWorkspace(
  _MockAccessAdminRepository repository, {
  AccessAdminWorkspaceData? data,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => Result<AccessAdminWorkspaceData>.success(
      data ?? _registrationsData(),
    ),
  );
}

Future<void> _pumpRegistrations(
  WidgetTester tester, {
  required _MockAccessAdminRepository repository,
  required AppAccessPolicy policy,
  AccessAdminWorkspaceData? data,
  Size viewport = const Size(1280, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubWorkspace(repository, data: data);

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/admin/access?panel=registrations',
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

  group('access_admin_access helpers (Registrations matrix)', () {
    test('source elevated-only: tenant:admin cannot read Registrations', () {
      final AppAccessPolicy tenant = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(canReadAccessAdminRegistrations(tenant), isFalse);
      expect(canAccessAccessAdminRegistrations(tenant), isFalse);
      expect(
        accessAdminAllowedPanels(tenant)
            .contains(AccessAdminPanel.registrations),
        isFalse,
      );
    });

    test('source elevated-only: facility:admin ∪ cannot open Registrations', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      // Workspace ∪ allows entry; Registrations tab stays elevated-only.
      expect(canReadAccessAdmin(facilityOnly), isTrue);
      expect(canReadAccessAdminRegistrations(facilityOnly), isFalse);
      expect(
        accessAdminAllowedPanels(facilityOnly)
            .contains(AccessAdminPanel.registrations),
        isFalse,
      );
    });

    test(
      'matrix ∩ system:admin maps to elevated gate (source wins over bare key)',
      () {
        final AppAccessPolicy bareSystem = _policy(
          permissions: <AppPermission>{AppPermissions.systemAdmin},
          roles: const <String>['TENANT_ADMIN'],
        );
        expect(
          accessAdminRegistrationsReadRequirement.isAllowed(bareSystem),
          isTrue,
        );
        // Source inventory: elevated-only — bare system:admin is not enough.
        expect(canReadAccessAdminRegistrations(bareSystem), isFalse);
      },
    );

    test('elevated SUPER_ADMIN satisfies Registrations read', () {
      final AppAccessPolicy elevated = _elevatedPolicy();
      expect(canReadAccessAdminRegistrations(elevated), isTrue);
      expect(
        accessAdminAllowedPanels(elevated)
            .contains(AccessAdminPanel.registrations),
        isTrue,
      );
    });

    test('∪ workspace: system:admin alone satisfies route entry', () {
      final AppAccessPolicy systemOnly = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
      );
      expect(canReadAccessAdmin(systemOnly), isTrue);
      expect(canAccessShellRoute(AppRoutes.accessAdmin, systemOnly), isTrue);
    });

    test('∩ write: facility:admin without tenant:admin cannot mutate', () {
      final AppAccessPolicy facilityOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
        roles: const <String>['FACILITY_ADMIN'],
      );
      expect(
        canMutateAccessAdminRegistrations(
          facilityOnly,
          workspaceCanWrite: true,
        ),
        isFalse,
      );
      expect(
        AccessAdminRegistrationsAtomPermissions.write.isAllowed(facilityOnly),
        isFalse,
      );
    });

    test(
      'source elevated-only: tenant:admin write ∩ alone cannot mutate Registrations',
      () {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        // Directory write ∩ would pass; Registrations also needs elevated.
        expect(canWriteAccessAdmin(tenant, workspaceCanWrite: true), isTrue);
        expect(
          canMutateAccessAdminRegistrations(tenant, workspaceCanWrite: true),
          isFalse,
        );
      },
    );

    test('∩ write: elevated + workspace canWrite allows Registrations mutate', () {
      final AppAccessPolicy elevated = _elevatedPolicy();
      expect(
        canMutateAccessAdminRegistrations(elevated, workspaceCanWrite: true),
        isTrue,
      );
      expect(
        canMutateAccessAdminRegistrations(elevated, workspaceCanWrite: false),
        isFalse,
      );
    });

    test(
      'subscription commercial modules do not gate admin keys (platform)',
      () {
        final AppAccessPolicy elevated = _elevatedPolicy();
        expect(canReadAccessAdminRegistrations(elevated), isTrue);
        expect(
          canMutateAccessAdminRegistrations(elevated, workspaceCanWrite: true),
          isTrue,
        );
        expect(accessAdminModuleLabel, 'access administration');
        expect(accessAdminActiveModule, 'access_admin');
      },
    );

    test('elevated read does not require tenant ABAC context', () {
      final AppAccessPolicy platformElevated = _policy(
        permissions: <AppPermission>{AppPermissions.systemAdmin},
        roles: const <String>['SUPER_ADMIN'],
        tenantId: null,
        facilityId: null,
      );
      expect(canReadAccessAdminRegistrations(platformElevated), isTrue);
      expect(
        accessAdminAllowedPanels(platformElevated)
            .contains(AccessAdminPanel.registrations),
        isTrue,
      );
    });

    test('Registrations reuses shared AccessRequirement helpers', () {
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.create,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.update,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.delete,
          accessAdminWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.tab,
          accessAdminRegistrationsReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.write,
          accessAdminRegistrationsWriteRequirement,
        ),
        isTrue,
      );
      expect(accessAdminModuleLabel, 'access administration');
    });

    test('nested cross-module rows are n/a for Registrations matrix', () {
      // Matrix nested rows are n/a; write ∩ remains the reserved vocabulary.
      expect(
        AccessAdminRegistrationsAtomPermissions.write.allPermissions,
        isNotEmpty,
      );
      expect(
        identical(
          AccessAdminRegistrationsAtomPermissions.create,
          accessAdminRegistrationsCreateRequirement,
        ),
        isTrue,
      );
    });

    test('route integration denies clinical-only actors', () {
      expect(
        canAccessShellRoute(
          AppRoutes.accessAdmin,
          _policy(permissions: <AppPermission>{AppPermissions.clinicalRead}),
        ),
        isFalse,
      );
    });
  });

  group('Registrations UI permissions', () {
    testWidgets(
      'non-elevated tenant:admin: Registrations tab absent (source)',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        // Land on directory so workspace loads; Registrations must not appear.
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        when(() => repository.getWorkspace(any())).thenAnswer(
          (_) async => Result<AccessAdminWorkspaceData>.success(
            AccessAdminWorkspaceData(
              permissions: const AccessAdminWorkspacePermissions(
                canRead: true,
                canWrite: true,
              ),
              items: const <AccessAdminItem>[],
              page: const AppPage<AccessAdminItem>(
                items: <AccessAdminItem>[],
                request: AppPageRequest(pageSize: 12),
                totalItemCount: 0,
              ),
              query: const AccessAdminWorkspaceQuery(
                panel: AccessAdminPanel.directory,
                resource: AccessAdminResource.users,
              ),
            ),
          ),
        );

        tester.view.physicalSize = const Size(1280, 900);
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
                    initialQuery:
                        AccessAdminWorkspaceQuery.fromUri(state.uri),
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
              appAccessPolicyProvider.overrideWithValue(tenant),
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

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelRegistrations), findsNothing);
      },
    );

    testWidgets(
      'deep link panel=registrations: non-elevated hides Registrations atoms',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = _policy(
          permissions: <AppPermission>{AppPermissions.tenantAdmin},
        );
        when(() => repository.getWorkspace(any())).thenAnswer((
          Invocation invocation,
        ) async {
          final AccessAdminWorkspaceQuery query =
              invocation.positionalArguments.first as AccessAdminWorkspaceQuery;
          if (query.panel == AccessAdminPanel.registrations) {
            return Result<AccessAdminWorkspaceData>.success(
              _registrationsData(canWrite: true),
            );
          }
          return Result<AccessAdminWorkspaceData>.success(
            AccessAdminWorkspaceData(
              permissions: const AccessAdminWorkspacePermissions(
                canRead: true,
                canWrite: true,
              ),
              lookups: const AccessAdminLookups(
                userStatuses: <String>['ACTIVE', 'INACTIVE'],
              ),
              items: const <AccessAdminItem>[],
              page: const AppPage<AccessAdminItem>(
                items: <AccessAdminItem>[],
                request: AppPageRequest(pageSize: 12),
                totalItemCount: 0,
              ),
              query: query.copyWith(
                panel: AccessAdminPanel.directory,
                resource: AccessAdminResource.users,
              ),
            ),
          );
        });

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();

        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final GoRouter router = GoRouter(
          initialLocation: '/admin/access?panel=registrations',
          routes: <RouteBase>[
            GoRoute(
              path: '/admin/access',
              builder: (BuildContext context, GoRouterState state) {
                return Scaffold(
                  body: AccessAdminWorkspacePage(
                    initialQuery:
                        AccessAdminWorkspaceQuery.fromUri(state.uri),
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
              appAccessPolicyProvider.overrideWithValue(tenant),
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

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        // Forbidden deep link: no Registrations chrome / row data mounted.
        expect(find.text(l10n.accessAdminPanelRegistrations), findsNothing);
        expect(find.text('Pending Clinic'), findsNothing);
        expect(
          find.text(l10n.accessAdminActivateRegistrationAction),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets(
      'missing admin permissions: workspace gate hides Registrations surface',
      (WidgetTester tester) async {
        final AppAccessPolicy none = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
          roles: const <String>['DOCTOR'],
        );
        await _pumpRegistrations(
          tester,
          repository: repository,
          policy: none,
        );

        expect(find.text('Pending Clinic'), findsNothing);
        expect(find.byType(AppTabStrip), findsNothing);
      },
    );

    testWidgets(
      '∪ allowance: facility:admin sees Directory, not Registrations',
      (WidgetTester tester) async {
        final AppAccessPolicy facilityOnly = _policy(
          permissions: <AppPermission>{AppPermissions.facilityAdmin},
          roles: const <String>['FACILITY_ADMIN'],
        );
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        when(() => repository.getWorkspace(any())).thenAnswer(
          (_) async => Result<AccessAdminWorkspaceData>.success(
            AccessAdminWorkspaceData(
              permissions: const AccessAdminWorkspacePermissions(
                canRead: true,
                canWrite: true,
              ),
              lookups: const AccessAdminLookups(
                userStatuses: <String>['ACTIVE', 'INACTIVE'],
              ),
              items: const <AccessAdminItem>[],
              page: const AppPage<AccessAdminItem>(
                items: <AccessAdminItem>[],
                request: AppPageRequest(pageSize: 12),
                totalItemCount: 0,
              ),
              query: const AccessAdminWorkspaceQuery(
                panel: AccessAdminPanel.directory,
                resource: AccessAdminResource.users,
              ),
            ),
          ),
        );

        tester.view.physicalSize = const Size(1280, 900);
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
                    initialQuery:
                        AccessAdminWorkspaceQuery.fromUri(state.uri),
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
              appAccessPolicyProvider.overrideWithValue(facilityOnly),
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

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelDirectory), findsOneWidget);
        expect(find.text(l10n.accessAdminPanelRegistrations), findsNothing);
      },
    );

    testWidgets(
      'elevated writer: list + Activate present (∩ full set via elevated)',
      (WidgetTester tester) async {
        await _pumpRegistrations(
          tester,
          repository: repository,
          policy: _elevatedPolicy(),
          data: _registrationsData(canWrite: true),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);
        expect(find.text('Pending Clinic'), findsWidgets);
        expect(
          find.text(l10n.accessAdminActivateRegistrationAction),
          findsWidgets,
        );
        // Create chrome is for users/roles resources only.
        expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
        expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
      },
    );

    testWidgets(
      'elevated + canWrite false: Activate absent (∩ / workspace strip)',
      (WidgetTester tester) async {
        await _pumpRegistrations(
          tester,
          repository: repository,
          policy: _elevatedPolicy(),
          data: _registrationsData(canWrite: false),
        );

        final BuildContext context = tester.element(
          find.byType(AccessAdminWorkspacePage),
        );
        final AppLocalizations l10n = context.l10n;

        expect(find.text('Pending Clinic'), findsWidgets);
        expect(
          find.text(l10n.accessAdminActivateRegistrationAction),
          findsNothing,
        );
        expect(
          find.text(l10n.accessAdminRejectRegistrationAction),
          findsNothing,
        );
        expect(find.textContaining('no access'), findsNothing);
      },
    );

    testWidgets('empty authorized Registrations keeps empty state', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(
          canWrite: true,
          items: const <AccessAdminItem>[],
        ),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);
    });

    testWidgets('activate registration syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy elevated = _elevatedPolicy();
      var activated = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final List<AccessAdminItem> items = activated
            ? const <AccessAdminItem>[]
            : const <AccessAdminItem>[_registration];
        return Result<AccessAdminWorkspaceData>.success(
          _registrationsData(items: items),
        );
      });
      when(() => repository.activateRegistration(any())).thenAnswer((
        _,
      ) async {
        activated = true;
        return const Result<void>.success(null);
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=registrations',
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
            appAccessPolicyProvider.overrideWithValue(elevated),
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

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      // Column header shares the activate label; tap the button, not the header.
      final Finder activateButton = find.widgetWithText(
        AppButton,
        l10n.accessAdminActivateRegistrationAction,
      );
      expect(activateButton, findsWidgets);
      await tester.tap(activateButton.first);
      await tester.pumpAndSettle();

      verify(() => repository.activateRegistration('REG-1')).called(1);
      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('detail Reject syncs worklist after mutation', (
      WidgetTester tester,
    ) async {
      final AppAccessPolicy elevated = _elevatedPolicy();
      var rejected = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final List<AccessAdminItem> items = rejected
            ? const <AccessAdminItem>[]
            : const <AccessAdminItem>[_registration];
        return Result<AccessAdminWorkspaceData>.success(
          _registrationsData(items: items),
        );
      });
      when(() => repository.rejectRegistration(any())).thenAnswer((_) async {
        rejected = true;
        return const Result<void>.success(null);
      });

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/admin/access?panel=registrations',
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
            appAccessPolicyProvider.overrideWithValue(elevated),
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

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text('Pending Clinic').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.accessAdminRejectRegistrationAction));
      await tester.pumpAndSettle();

      verify(() => repository.rejectRegistration('REG-1')).called(1);
      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('detail Reject present for elevated writer', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: true),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text('Pending Clinic').first);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.accessAdminRejectRegistrationAction),
        findsOneWidget,
      );
    });

    testWidgets('detail Reject absent when workspace canWrite is false', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: false),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      await tester.tap(find.text('Pending Clinic').first);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.accessAdminRejectRegistrationAction),
        findsNothing,
      );
    });

    testWidgets('mobile viewport: Activate present for elevated writer', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: true),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);
      expect(find.byType(AppListTableMobileItem), findsWidgets);
      expect(
        find.text(l10n.accessAdminActivateRegistrationAction),
        findsWidgets,
      );
    });

    testWidgets('mobile viewport: Activate absent without write', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: false),
        viewport: const Size(390, 844),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.byType(AccessAdminWorkspacePage), findsOneWidget);
      expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);
      expect(
        find.text(l10n.accessAdminActivateRegistrationAction),
        findsNothing,
      );
    });

    testWidgets('dark theme: authorized Registrations atoms remain visible', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: true),
        themeMode: ThemeMode.dark,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      expect(find.text(l10n.accessAdminPanelRegistrations), findsOneWidget);
      expect(find.text('Pending Clinic'), findsWidgets);
      expect(
        find.text(l10n.accessAdminActivateRegistrationAction),
        findsWidgets,
      );
    });

    testWidgets('error/retry remains for authorized Registrations readers', (
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
        initialLocation: '/admin/access?panel=registrations',
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
            appAccessPolicyProvider.overrideWithValue(_elevatedPolicy()),
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

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;
      expect(find.text(l10n.errorNetworkMessage), findsWidgets);
    });
  });

  group('accessAdminDefaultColumns Registrations next_action gate', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (BuildContext context) => child),
      );
    }

    testWidgets(
      'omits next_action for registrationFollowUps when canWrite is false',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const SizedBox.shrink()));
        final BuildContext context = tester.element(find.byType(SizedBox));

        final List<String> ids = accessAdminDefaultColumns(
              context,
              resource: AccessAdminResource.registrationFollowUps,
              canWrite: false,
              onUserStatusToggle: (_) async {},
              onRoleEdit: (_) {},
              onRegistrationActivate: (_) async {},
            )
            .map((AppListTableColumn<AccessAdminItem> column) => column.id)
            .whereType<String>()
            .toList();

        expect(ids, isNot(contains('next_action')));
      },
    );

    testWidgets(
      'includes next_action for registrationFollowUps when canWrite is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(wrap(const SizedBox.shrink()));
        final BuildContext context = tester.element(find.byType(SizedBox));

        final List<String> ids = accessAdminDefaultColumns(
              context,
              resource: AccessAdminResource.registrationFollowUps,
              canWrite: true,
              onUserStatusToggle: (_) async {},
              onRoleEdit: (_) {},
              onRegistrationActivate: (_) async {},
            )
            .map((AppListTableColumn<AccessAdminItem> column) => column.id)
            .whereType<String>()
            .toList();

        expect(ids, contains('next_action'));
      },
    );

    testWidgets('mobile Registrations next-action null when unauthorized', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrap(const SizedBox.shrink()));
      final BuildContext context = tester.element(find.byType(SizedBox));

      expect(
        accessAdminMobileNextAction(
          context,
          resource: AccessAdminResource.registrationFollowUps,
          item: _registration,
          canWrite: false,
          onUserStatusToggle: (_) async {},
          onRoleEdit: (_) {},
          onRegistrationActivate: (_) async {},
        ),
        isNull,
      );
    });
  });
}
