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
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 0,
  authorizationApprovedCount: 0,
  submittedClaimsCount: 0,
  approvedClaimsCount: 0,
  paidClosedCount: 0,
);

AuthSession _sessionForPolicy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AuthSession(
    tokens: SessionTokens(accessToken: 'access-token'),
    user: const AuthUserProfile(
      roles: <String>['BILLING'],
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
    ),
    permissions: permissions,
    moduleEntitlements: modules,
    isAuthorizationHydrated: true,
  );
}

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    _sessionForPolicy(permissions: permissions, modules: modules),
  );
}

void _stubClaimsRepository(_MockClaimsRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: const <ClaimsQueueItem>[],
        request: const AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
  );
}

Future<void> _pumpInsuranceSetupTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/claims?section=insurance-setup',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubClaimsRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/claims',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClaimsWorkspacePage(
              initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        claimsRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  testWidgets(
    'read ∩ without write: setup chrome visible; create atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(reader),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expect(
        find.textContaining('Manage insurance companies'),
        findsOneWidget,
      );
      // Create strip collapses when all permissionActions are filtered.
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('Add scheme'), findsNothing);
      expect(find.textContaining('Add offer'), findsNothing);
      expect(find.textContaining('Enroll patient'), findsNothing);
      expect(find.textContaining('Add price'), findsNothing);
      expect(find.textContaining('Insurer API'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
      expect(find.byType(AppListTable<ClaimsQueueItem>), findsNothing);
      // Catalog hub: omit count badge and queue table chrome.
      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem setup = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.id == ClaimsDeskSection.insuranceSetup.name,
      );
      expect(setup.count, isNull);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byTooltip('Filters'), findsNothing);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
    },
  );

  testWidgets(
    'Insurance Setup catalog hub: no table chrome; create dialogs stay in-desk',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byType(AppListTable<ClaimsQueueItem>), findsNothing);
      final AppTabStrip strip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem setup = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.id == ClaimsDeskSection.insuranceSetup.name,
      );
      expect(setup.count, isNull);
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);

      await tester.tap(find.textContaining('Add company'));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      // Action/surface title — not a concrete company identity (dialogs.mdc).
      expect(find.textContaining('ADD'), findsWidgets);
    },
  );

  testWidgets(
    'full write ∩: catalog create actions mount on Insurance Setup panel',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(writer),
        isTrue,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.textContaining('Add company'), findsOneWidget);
      expect(find.textContaining('Add scheme'), findsOneWidget);
      expect(find.textContaining('Add offer'), findsOneWidget);
      expect(find.textContaining('Enroll patient'), findsOneWidget);
      expect(find.textContaining('Add price'), findsOneWidget);
      expect(find.textContaining('Insurer API'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppTabStrip),
          matching: find.textContaining('Add company'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read ∪: facility:admin without billing:read shows Insurance Setup tab',
    (WidgetTester tester) async {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(facilityAdmin),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.read.isAllowed(facilityAdmin),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(facilityAdmin),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: facilityAdmin,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expect(
        find.textContaining('Manage insurance companies'),
        findsOneWidget,
      );
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read ∪ + write ∩: facility:admin with billing:write shows creates',
    (WidgetTester tester) async {
      final AppAccessPolicy facilityWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.facilityAdmin,
          AppPermissions.billingWrite,
        },
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(facilityWriter),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(facilityWriter),
        isTrue,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: facilityWriter,
      );

      expect(find.textContaining('Add company'), findsOneWidget);
      expect(find.textContaining('Insurer API'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'read ∪: tenant:admin without billing:read shows Insurance Setup tab',
    (WidgetTester tester) async {
      final AppAccessPolicy tenantAdmin = _policy(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(tenantAdmin),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(tenantAdmin),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: tenantAdmin,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expect(
        find.textContaining('Manage insurance companies'),
        findsOneWidget,
      );
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪ financial:approve alone omits Insurance Setup tab',
    (WidgetTester tester) async {
      final AppAccessPolicy approveOnly = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.routeEntry.isAllowed(approveOnly),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(approveOnly),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: approveOnly,
      );

      expect(find.textContaining('Insurance Setup'), findsNothing);
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('Manage insurance companies'), findsNothing);
      // Queue tabs need billing:read ∩ — approve-only yields empty chrome
      // (no routine "no access" banner).
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪ billing:write alone without read ∪ omits Insurance Setup',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.routeEntry.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(writeOnly),
        isTrue,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.textContaining('Insurance Setup'), findsNothing);
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: insurance-claims missing omits Insurance Setup',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.facilityAdmin,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.textContaining('Insurance Setup'), findsNothing);
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing denies create ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy noBillingModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.facilityAdmin,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'insurance-claims',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      // Tab ∪ still allows facility:admin (core right); create needs billing
      // module for grants(billing:write).
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(noBillingModule),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(noBillingModule),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: noBillingModule,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module rows n/a: create absent without billing:write',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.financialApprove,
          },
        ),
      );

      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('Insurer API'), findsNothing);
      expect(find.textContaining('Manage insurance companies'), findsOneWidget);
    },
  );

  testWidgets('mobile viewport keeps authorized setup creates readable', (
    WidgetTester tester,
  ) async {
    await _pumpInsuranceSetupTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Add company'), findsOneWidget);
    expect(find.textContaining('Insurer API'), findsOneWidget);
  });

  testWidgets('desktop viewport shows Insurance Setup create actions', (
    WidgetTester tester,
  ) async {
    await _pumpInsuranceSetupTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Add company'), findsOneWidget);
    expect(find.textContaining('Add scheme'), findsOneWidget);
  });

  testWidgets('light theme: authorized Insurance Setup chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInsuranceSetupTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
    );

    expect(find.textContaining('Add company'), findsOneWidget);
    expect(
      find.textContaining('Manage insurance companies'),
      findsOneWidget,
    );
  });

  testWidgets('dark theme: authorized Insurance Setup chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpInsuranceSetupTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.textContaining('Add company'), findsOneWidget);
    expect(
      find.textContaining('Manage insurance companies'),
      findsOneWidget,
    );
  });

  testWidgets(
    'authorized Add company: validation + nested dialog reuse write ∩ (sync wiring)',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.textContaining('Add company'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Save company'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Save company'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter the insurance company name'),
        findsWidgets,
      );
      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.textContaining('Insurance configuration saved'), findsNothing);

      // Nested catalog dialogs call claimsWorkspaceController.refresh() on
      // success (see openClaimsInsuranceCompanyDialog) → reference sync.
      // Dialog openers also gate on ClaimsInsuranceSetupAtomPermissions.create.
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.addCompany,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.create,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.update,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.delete,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'loading / empty authorized states remain observable on Insurance Setup',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      // Read-only: description remains; create panel collapses (empty filtered).
      expect(
        find.textContaining('Manage insurance companies'),
        findsOneWidget,
      );
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.byType(AppTabStrip), findsOneWidget);
    },
  );

  testWidgets(
    'ABAC: missing facility context still allows Insurance Setup read ∪ chrome '
    '(row scope remains backend-authoritative)',
    (WidgetTester tester) async {
      final AppAccessPolicy noFacility = AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(
            roles: <String>['BILLING'],
            tenantId: 'tenant-1',
          ),
          permissions: <AppPermission>{AppPermissions.billingRead},
          moduleEntitlements: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'insurance-claims',
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
      expect(noFacility.hasFacilityContext, isFalse);
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(noFacility),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(noFacility),
        isFalse,
      );

      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(find.textContaining('Insurance Setup'), findsWidgets);
      expect(
        find.textContaining('Manage insurance companies'),
        findsOneWidget,
      );
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: insurance-claims EXPIRED omits Insurance Setup',
    (WidgetTester tester) async {
      await _pumpInsuranceSetupTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.facilityAdmin,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'insurance-claims',
              licenseStatus: 'EXPIRED',
            ),
          ],
        ),
      );

      expect(find.textContaining('Insurance Setup'), findsNothing);
      expect(find.textContaining('Add company'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized load error exposes retry', (
    WidgetTester tester,
  ) async {
    when(() => repository.listQueue(any())).thenAnswer(
      (_) async => const Result<AppPage<ClaimsQueueItem>>.failure(
        AppFailure.unexpected(),
      ),
    );
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
    );
    when(() => repository.loadWorkspaceSummary()).thenAnswer(
      (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/claims?section=insurance-setup',
      routes: <RouteBase>[
        GoRoute(
          path: '/claims',
          builder: (BuildContext context, GoRouterState state) {
            return Scaffold(
              body: ClaimsWorkspacePage(
                initialQuery: ClaimsWorkspaceQuery.fromUri(state.uri),
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          claimsRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.billingRead,
                AppPermissions.billingWrite,
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.light,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Try again'), findsWidgets);
  });
}
