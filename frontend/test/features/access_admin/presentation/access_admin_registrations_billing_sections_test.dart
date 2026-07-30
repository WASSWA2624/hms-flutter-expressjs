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
import 'package:hosspi_hms/features/access_admin/presentation/access_admin_registrations_billing.dart';
import 'package:hosspi_hms/features/access_admin/presentation/pages/access_admin_workspace_page.dart';
import 'package:hosspi_hms/features/access_admin/presentation/widgets/access_admin_workspace_table.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/layout/flat_section_layout_test_helpers.dart';

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

AppAccessPolicy _elevatedPolicy({
  Set<AppPermission>? permissions,
  bool canWriteKeys = true,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
        roles: const <String>['SUPER_ADMIN'],
      ),
      permissions: permissions ??
          <AppPermission>{
            AppPermissions.systemAdmin,
            if (canWriteKeys) AppPermissions.tenantAdmin,
          },
      isAuthorizationHydrated: true,
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
  bool stubWorkspace = true,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  if (stubWorkspace) {
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => Result<AccessAdminWorkspaceData>.success(
        data ?? _registrationsData(),
      ),
    );
  }

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

  group('AccessAdminRegistrationsBillingInventory (AC1)', () {
    test('every mounted atom is explicitly not billable to patient ledgers', () {
      expect(accessAdminRegistrationsTabHasNoPatientBillableActions(), isTrue);
      expect(
        AccessAdminRegistrationsBillingInventory.mountedAtoms,
        isNotEmpty,
      );
      expect(
        AccessAdminRegistrationsBillingInventory.billableClasses,
        isEmpty,
      );
      for (final AccessAdminRegistrationsFinancialAtom atom
          in AccessAdminRegistrationsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isNot(
            isIn(<AccessAdminRegistrationsFinancialClass>[
              AccessAdminRegistrationsFinancialClass.createCharge,
              AccessAdminRegistrationsFinancialClass.settle,
              AccessAdminRegistrationsFinancialClass.adjust,
              AccessAdminRegistrationsFinancialClass.reverse,
              AccessAdminRegistrationsFinancialClass.defer,
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

    test('activate uses NOT_BILLED audit (subscriptions onboarding path)', () {
      final AccessAdminRegistrationsFinancialAtom activateAtom =
          AccessAdminRegistrationsBillingInventory.atoms.firstWhere(
        (AccessAdminRegistrationsFinancialAtom atom) =>
            atom.id == 'activate_registration',
      );
      expect(activateAtom.auditCode, 'NOT_BILLED');
      expect(
        activateAtom.financialClass,
        AccessAdminRegistrationsFinancialClass.notBilled,
      );
    });

    test('reserved financial atoms are unmounted', () {
      final List<String> unmounted =
          AccessAdminRegistrationsBillingInventory.atoms
              .where((AccessAdminRegistrationsFinancialAtom atom) => !atom.mounted)
              .map((AccessAdminRegistrationsFinancialAtom atom) => atom.id)
              .toList();
      expect(unmounted, containsAll(<String>[
        'create_user',
        'create_role',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]));
    });

    test('write ∩ uses Registrations atom permissions', () {
      expect(
        AccessAdminRegistrationsAtomPermissions.update,
        accessAdminRegistrationsWriteRequirement,
      );
      expect(
        AccessAdminRegistrationsAtomPermissions.delete,
        accessAdminRegistrationsWriteRequirement,
      );
    });

    test('Registrations write gate intersects workspace canWrite', () {
      final AppAccessPolicy elevated = _elevatedPolicy();
      expect(
        accessAdminRegistrationsCanMutate(
          workspaceCanWrite: true,
          policyAllowsWrite: canMutateAccessAdminRegistrations(
            elevated,
            workspaceCanWrite: true,
          ),
        ),
        isTrue,
      );
      expect(
        accessAdminRegistrationsCanMutate(
          workspaceCanWrite: false,
          policyAllowsWrite: canMutateAccessAdminRegistrations(
            elevated,
            workspaceCanWrite: true,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Registrations billing bypass + authorization (AC2, AC4)', () {
    testWidgets('no payment/issue/collect affordances on authorized UI', (
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

      expect(find.text(l10n.accessAdminCreateUserAction), findsNothing);
      expect(find.text(l10n.accessAdminCreateRoleAction), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
    });

    testWidgets(
      'non-elevated deep link hides registrations worklist and pay chrome',
      (WidgetTester tester) async {
        final AppAccessPolicy tenant = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: AuthUserProfile(
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
              roles: const <String>['TENANT_ADMIN'],
            ),
            permissions: <AppPermission>{AppPermissions.tenantAdmin},
            isAuthorizationHydrated: true,
          ),
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
        expect(find.text('Pending Clinic'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
      },
    );

    testWidgets('Activate absent when workspace canWrite is false', (
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

      expect(find.text('Pending Clinic'), findsWidgets);
      expect(
        find.text(l10n.accessAdminActivateRegistrationAction),
        findsNothing,
      );
    });

    testWidgets('detail Reject absent without write ∩', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(canWrite: false),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_registration);
      await tester.pumpAndSettle();

      final BuildContext context = tester.element(find.byType(AppDialog));
      expect(
        find.text(context.l10n.accessAdminRejectRegistrationAction),
        findsNothing,
      );
    });
  });

  group('Registrations sync parity (AC3)', () {
    testWidgets('activate registration refreshes worklist without billing repo', (
      WidgetTester tester,
    ) async {
      var activated = false;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        final List<AccessAdminItem> items = activated
            ? const <AccessAdminItem>[]
            : const <AccessAdminItem>[_registration];
        return Result<AccessAdminWorkspaceData>.success(
          _registrationsData(items: items),
        );
      });
      when(() => repository.activateRegistration(any())).thenAnswer((_) async {
        activated = true;
        return const Result<void>.success(null);
      });

      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      final Finder activateButton = find.widgetWithText(
        AppButton,
        l10n.accessAdminActivateRegistrationAction,
      );
      await tester.tap(activateButton.first);
      await tester.pumpAndSettle();

      verify(() => repository.activateRegistration('REG-1')).called(1);
      verify(() => repository.getWorkspace(any())).called(greaterThan(1));
      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('reject registration refreshes worklist', (
      WidgetTester tester,
    ) async {
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

      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      final AppLocalizations l10n = context.l10n;

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_registration);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.accessAdminRejectRegistrationAction));
      await tester.pumpAndSettle();

      verify(() => repository.rejectRegistration('REG-1')).called(1);
      expect(find.text(l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('idempotent getWorkspace replay returns stable list', (
      WidgetTester tester,
    ) async {
      var callCount = 0;
      when(() => repository.getWorkspace(any())).thenAnswer((_) async {
        callCount += 1;
        return Result<AccessAdminWorkspaceData>.success(_registrationsData());
      });

      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        stubWorkspace: false,
      );
      expect(callCount, greaterThan(0));
      expect(find.text('Pending Clinic'), findsWidgets);
    });
  });

  group('Flat titled sections (AC5)', () {
    testWidgets('desktop light: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'registrations worklist desktop light',
      );
    });

    testWidgets('mobile dark: no nested sections on worklist', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        viewport: const Size(480, 844),
        themeMode: ThemeMode.dark,
      );
      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AccessAdminWorkspacePage),
        contextLabel: 'registrations worklist mobile dark',
      );
    });

    testWidgets('detail dialog: no nested titled sections', (
      WidgetTester tester,
    ) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_registration);
      await tester.pumpAndSettle();

      expectFlatTitledSectionLayout(
        tester,
        scope: find.byType(AppDialog),
        contextLabel: 'registrations detail dialog',
      );
    });
  });

  group('Authorized UI states (AC4, AC6)', () {
    testWidgets('empty state remains observable', (WidgetTester tester) async {
      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        data: _registrationsData(items: const <AccessAdminItem>[]),
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.accessAdminEmptyTitle), findsOneWidget);
    });

    testWidgets('error state remains observable for authorized readers', (
      WidgetTester tester,
    ) async {
      when(() => repository.getWorkspace(any())).thenAnswer(
        (_) async => const Result<AccessAdminWorkspaceData>.failure(
          AppFailure.network(),
        ),
      );

      await _pumpRegistrations(
        tester,
        repository: repository,
        policy: _elevatedPolicy(),
        stubWorkspace: false,
      );

      final BuildContext context = tester.element(
        find.byType(AccessAdminWorkspacePage),
      );
      expect(find.text(context.l10n.errorNetworkMessage), findsWidgets);
    });

    testWidgets('elevated writer: Activate and detail Reject present', (
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

      expect(
        find.text(l10n.accessAdminActivateRegistrationAction),
        findsWidgets,
      );

      final AppListTable<AccessAdminItem> table = tester
          .widgetList<AppListTable<AccessAdminItem>>(
            find.byType(AppListTable<AccessAdminItem>),
          )
          .first;
      table.onRowSelected!(_registration);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.accessAdminRejectRegistrationAction),
        findsOneWidget,
      );
      expect(find.text(l10n.commonCloseActionLabel), findsOneWidget);
    });
  });
}
