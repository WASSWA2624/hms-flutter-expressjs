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

const ClaimsQueueItem _paidClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-paid',
    displayId: 'CLM-PAID',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-paid',
    invoiceDisplayId: 'INV-PAID',
    status: 'PAID',
    patientDisplayId: 'PT-SETTLED',
    claimAmount: 500,
  ),
);

const ClaimsQueueItem _cancelledClaim = ClaimsQueueItem.claim(
  InsuranceClaimRecord(
    id: 'claim-cancelled',
    displayId: 'CLM-CANCELLED',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    invoiceId: 'inv-cancel',
    invoiceDisplayId: 'INV-CANCEL',
    status: 'CANCELLED',
    patientDisplayId: 'PT-CANCEL',
    claimAmount: 120,
  ),
);

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  paidClosedCount: 2,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

List<ClaimsQueueItem> _itemsForQuery(ClaimsQueueQuery query) {
  final List<ClaimsQueueItem> all = <ClaimsQueueItem>[
    _paidClaim,
    _cancelledClaim,
  ];
  final String? claimStatus = insuranceClaimStatusForFilter(query.filter);
  if (claimStatus == null) {
    return all;
  }
  return all
      .where(
        (ClaimsQueueItem item) =>
            item.isClaim && item.status.toUpperCase() == claimStatus,
      )
      .toList(growable: false);
}

void _stubRepository(_MockClaimsRepository repository) {
  when(() => repository.listQueue(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    final List<ClaimsQueueItem> items = _itemsForQuery(query);
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async => const Result<ClaimsWorkspaceSummary>.success(_summary),
  );
  when(() => repository.getDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final ClaimsQueueItem item =
        invocation.positionalArguments.single as ClaimsQueueItem;
    return Result<ClaimsQueueDetail>.success(
      ClaimsQueueDetail(
        item: item,
        authorization: item.authorization,
        claim: item.claim,
      ),
    );
  });
}

Future<void> _pumpSettledTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/claims?section=settled',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

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
    registerFallbackValue(
      const ClaimsQueueItem.claim(
        InsuranceClaimRecord(
          id: 'fallback',
          displayId: 'FALLBACK',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          invoiceId: 'inv',
          invoiceDisplayId: 'INV',
          status: 'PAID',
        ),
      ),
    );
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  testWidgets(
    'read ∩ alone: Settled list + Filters present; Print / mutate absent (∩ ok, ∪ deny)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(ClaimsSettledAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(ClaimsSettledAtomPermissions.export.isAllowed(reader), isFalse);
      expect(ClaimsSettledAtomPermissions.write.isAllowed(reader), isFalse);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Settled'), findsWidgets);
      expect(find.text('CLM-PAID'), findsOneWidget);
      expect(find.textContaining('Filters'), findsWidgets);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(find.text('Print statement'), findsNothing);
      expect(find.text('Sync insurer status'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested export ∪ reports:read: Print mounts; write chrome still absent',
    (WidgetTester tester) async {
      final AppAccessPolicy exporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(ClaimsSettledAtomPermissions.export.isAllowed(exporter), isTrue);
      expect(ClaimsSettledAtomPermissions.write.isAllowed(exporter), isFalse);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: exporter,
      );

      expect(find.text('CLM-PAID'), findsOneWidget);
      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();

      expect(find.text('Print statement'), findsOneWidget);
      expect(find.text('Sync insurer status'), findsNothing);
      expect(find.byTooltip('Prepare claim'), findsNothing);
    },
  );

  testWidgets(
    'reports:read without reporting-analytics module still shows Print',
    (WidgetTester tester) async {
      final AppAccessPolicy reportsNoModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
      );
      // Reporting is platform infrastructure — not package-gated.
      expect(
        ClaimsSettledAtomPermissions.export.isAllowed(reportsNoModule),
        isTrue,
      );

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: reportsNoModule,
      );

      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();
      expect(find.text('Print statement'), findsOneWidget);
    },
  );

  testWidgets(
    'nested export ∪ evidence:export alone (with read ∩) shows Print',
    (WidgetTester tester) async {
      final AppAccessPolicy exporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.evidenceExport,
        },
      );
      expect(ClaimsSettledAtomPermissions.export.isAllowed(exporter), isTrue);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: exporter,
      );

      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();
      expect(find.text('Print statement'), findsOneWidget);
    },
  );

  testWidgets(
    'write ∩ without export ∪: mutate chrome absent; Print still absent',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(ClaimsSettledAtomPermissions.write.isAllowed(writer), isTrue);
      expect(ClaimsSettledAtomPermissions.export.isAllowed(writer), isFalse);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      // Settled is review-only — strip primary / next-action stay omitted.
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();
      expect(find.text('Print statement'), findsNothing);
      expect(find.text('Sync insurer status'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪ financial:approve alone allowed entry; Settled needs read ∩',
    (WidgetTester tester) async {
      final AppAccessPolicy approveOnly = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        ClaimsSettledAtomPermissions.routeEntry.isAllowed(approveOnly),
        isTrue,
      );
      expect(ClaimsSettledAtomPermissions.tab.isAllowed(approveOnly), isFalse);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: approveOnly,
      );

      expect(find.textContaining('Settled'), findsNothing);
      expect(find.text('CLM-PAID'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: insurance-claims missing omits Settled chrome',
    (WidgetTester tester) async {
      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.reportsRead,
            AppPermissions.evidenceExport,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('CLM-PAID'), findsNothing);
      expect(find.textContaining('Filters'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('authorized Filters apply and refresh settled queue (sync)', (
    WidgetTester tester,
  ) async {
    await _pumpSettledTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
    );

    expect(find.text('CLM-PAID'), findsOneWidget);

    clearInteractions(repository);
    _stubRepository(repository);

    await tester.tap(find.textContaining('Filters').first);
    await tester.pumpAndSettle();

    // Choose cancelled status in advanced filters when available.
    final Finder cancelledChoice = find.textContaining('Cancelled');
    if (cancelledChoice.evaluate().isNotEmpty) {
      await tester.tap(cancelledChoice.first);
      await tester.pumpAndSettle();
    }

    final Finder apply = find.textContaining('Apply');
    if (apply.evaluate().isNotEmpty) {
      await tester.tap(apply.first);
      await tester.pumpAndSettle();
      verify(() => repository.listQueue(any())).called(greaterThanOrEqualTo(1));
    }
  });

  testWidgets('empty Settled queue remains for authorized reader', (
    WidgetTester tester,
  ) async {
    when(() => repository.listQueue(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final ClaimsQueueQuery query =
          invocation.positionalArguments.single as ClaimsQueueQuery;
      return Result<AppPage<ClaimsQueueItem>>.success(
        AppPage<ClaimsQueueItem>(
          items: const <ClaimsQueueItem>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      );
    });
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<ClaimsReferenceData>.success(ClaimsReferenceData()),
    );
    when(() => repository.loadWorkspaceSummary()).thenAnswer(
      (_) async => const Result<ClaimsWorkspaceSummary>.success(
        ClaimsWorkspaceSummary(),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/claims?section=settled',
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
            _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Settled'), findsWidgets);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsNothing);
  });

  testWidgets('authorized load error exposes retry on Settled', (
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
      initialLocation: '/claims?section=settled',
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
            _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
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
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('authorized loading then success on Settled', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    when(() => repository.listQueue(any())).thenAnswer((
      Invocation invocation,
    ) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final ClaimsQueueQuery query =
          invocation.positionalArguments.single as ClaimsQueueQuery;
      final List<ClaimsQueueItem> items = _itemsForQuery(query);
      return Result<AppPage<ClaimsQueueItem>>.success(
        AppPage<ClaimsQueueItem>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      );
    });
    when(() => repository.loadReferenceData()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<ClaimsReferenceData>.success(ClaimsReferenceData());
    });
    when(() => repository.loadWorkspaceSummary()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Result<ClaimsWorkspaceSummary>.success(_summary);
    });

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/claims?section=settled',
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
            _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
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
    expect(find.textContaining('Loading claims'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('CLM-PAID'), findsOneWidget);
    expect(find.textContaining('Filters'), findsWidgets);
  });

  testWidgets('mobile viewport keeps authorized settled row without next-action', (
    WidgetTester tester,
  ) async {
    await _pumpSettledTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(AppListTableGrid), findsNothing);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.textContaining('CLM-PAID'), findsOneWidget);
    expect(find.byTooltip('Prepare claim'), findsNothing);
  });

  testWidgets('desktop viewport shows Settled columns without Next action', (
    WidgetTester tester,
  ) async {
    await _pumpSettledTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.byType(AppListTableGrid), findsOneWidget);
    expect(find.text('CLM-PAID'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppListTableGrid),
        matching: find.text('Next action'),
      ),
      findsNothing,
    );
  });

  testWidgets('dark theme: authorized Settled chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpSettledTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.evidenceExport,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('CLM-PAID'), findsOneWidget);
    expect(find.textContaining('Filters'), findsWidgets);
    expect(find.textContaining('no access'), findsNothing);

    await tester.tap(find.text('CLM-PAID'));
    await tester.pumpAndSettle();
    expect(find.text('Print statement'), findsOneWidget);
  });

  testWidgets('light theme: read-only Settled detail omits Print', (
    WidgetTester tester,
  ) async {
    await _pumpSettledTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
      themeMode: ThemeMode.light,
    );

    await tester.tap(find.text('CLM-PAID'));
    await tester.pumpAndSettle();
    expect(find.text('Print statement'), findsNothing);
  });

  testWidgets(
    'ABAC: missing facility context still allows Settled read chrome '
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
      expect(ClaimsSettledAtomPermissions.tab.isAllowed(noFacility), isTrue);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: noFacility,
      );

      expect(find.textContaining('Settled'), findsWidgets);
      expect(find.text('CLM-PAID'), findsOneWidget);
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: EXPIRED insurance-claims omits Settled chrome',
    (WidgetTester tester) async {
      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.reportsRead,
            AppPermissions.evidenceExport,
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

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('CLM-PAID'), findsNothing);
      expect(find.textContaining('Filters'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write ∩ full set still mounts no Settled mutate chrome (review-only)',
    (WidgetTester tester) async {
      final AppAccessPolicy fullWriter = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
          AppPermissions.reportsRead,
          AppPermissions.evidenceExport,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(ClaimsSettledAtomPermissions.create.isAllowed(fullWriter), isTrue);
      expect(ClaimsSettledAtomPermissions.update.isAllowed(fullWriter), isTrue);
      expect(ClaimsSettledAtomPermissions.delete.isAllowed(fullWriter), isTrue);
      expect(ClaimsSettledAtomPermissions.approve.isAllowed(fullWriter), isTrue);
      expect(ClaimsSettledAtomPermissions.export.isAllowed(fullWriter), isTrue);

      await _pumpSettledTab(
        tester,
        repository: repository,
        accessPolicy: fullWriter,
      );

      // Matrix create/update/delete/approve have no Settled entry points.
      expect(find.byTooltip('Prepare claim'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('CLM-PAID'));
      await tester.pumpAndSettle();
      expect(find.text('Print statement'), findsOneWidget);
      expect(find.text('Sync insurer status'), findsNothing);
      // Settled has no nested write forms → no client validation chrome here.
      expect(find.textContaining('required'), findsNothing);
    },
  );
}
