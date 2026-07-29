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

const ClaimsQueueItem _pendingAuth = ClaimsQueueItem.authorization(
  PreAuthorizationRecord(
    id: 'auth-pending',
    displayId: 'AUTH-PENDING',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    status: 'PENDING',
    patientDisplayId: 'PT-AUTH',
    approvedAmount: 100,
  ),
);

const ClaimsQueueItem _approvedAuth = ClaimsQueueItem.authorization(
  PreAuthorizationRecord(
    id: 'auth-approved',
    displayId: 'AUTH-APPROVED',
    coveragePlanId: 'plan-1',
    coveragePlanDisplayId: 'PLAN-001',
    status: 'APPROVED',
    patientDisplayId: 'PT-AUTH-2',
    approvedAmount: 250,
  ),
);

const ClaimsWorkspaceSummary _summary = ClaimsWorkspaceSummary(
  authorizationPendingCount: 1,
  authorizationApprovedCount: 1,
);

const ClaimsReferenceData _referenceData = ClaimsReferenceData(
  coveragePlans: <CoveragePlanOption>[
    CoveragePlanOption(
      id: 'plan-1',
      displayId: 'PLAN-001',
      name: 'Standard Plan',
    ),
  ],
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

void _stubRepository(
  _MockClaimsRepository repository, {
  List<ClaimsQueueItem> items = const <ClaimsQueueItem>[
    _pendingAuth,
    _approvedAuth,
  ],
  ClaimsWorkspaceSummary summary = _summary,
  Result<AppPage<ClaimsQueueItem>>? queueOverride,
  Result<ClaimsWorkspaceSummary>? summaryOverride,
  Result<ClaimsReferenceData>? referenceOverride,
}) {
  when(() => repository.listQueue(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (queueOverride != null) {
      return queueOverride;
    }
    final ClaimsQueueQuery query =
        invocation.positionalArguments.single as ClaimsQueueQuery;
    List<ClaimsQueueItem> filtered = List<ClaimsQueueItem>.of(items);
    final String? authStatus = preAuthorizationStatusForFilter(query.filter);
    if (authStatus != null) {
      filtered = filtered
          .where(
            (ClaimsQueueItem item) =>
                item.isAuthorization &&
                item.status.toUpperCase() == authStatus,
          )
          .toList(growable: false);
    }
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: filtered,
        request: query.pageRequest,
        totalItemCount: filtered.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        referenceOverride ??
        const Result<ClaimsReferenceData>.success(_referenceData),
  );
  when(() => repository.loadWorkspaceSummary()).thenAnswer(
    (_) async =>
        summaryOverride ??
        Result<ClaimsWorkspaceSummary>.success(summary),
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
  when(() => repository.updatePreAuthorization(any(), any())).thenAnswer(
    (_) async => const Result<PreAuthorizationRecord>.success(
      PreAuthorizationRecord(
        id: 'auth-pending',
        displayId: 'AUTH-PENDING',
        coveragePlanId: 'plan-1',
        coveragePlanDisplayId: 'PLAN-001',
        status: 'DENIED',
        patientDisplayId: 'PT-AUTH',
      ),
    ),
  );
  when(() => repository.requestPreAuthorization(any())).thenAnswer(
    (_) async => const Result<PreAuthorizationRecord>.success(
      PreAuthorizationRecord(
        id: 'auth-new',
        displayId: 'AUTH-NEW',
        coveragePlanId: 'plan-1',
        coveragePlanDisplayId: 'PLAN-001',
        status: 'PENDING',
      ),
    ),
  );
}

Future<void> _pumpAuthorizationsTab(
  WidgetTester tester, {
  required _MockClaimsRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/claims?section=authorizations',
  List<ClaimsQueueItem> items = const <ClaimsQueueItem>[
    _pendingAuth,
    _approvedAuth,
  ],
  ClaimsWorkspaceSummary summary = _summary,
  Result<AppPage<ClaimsQueueItem>>? queueOverride,
  Result<ClaimsWorkspaceSummary>? summaryOverride,
  Result<ClaimsReferenceData>? referenceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
    summary: summary,
    queueOverride: queueOverride,
    summaryOverride: summaryOverride,
    referenceOverride: referenceOverride,
  );

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
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(
      const ClaimsQueueItem.authorization(
        PreAuthorizationRecord(
          id: 'fallback',
          displayId: 'FALLBACK',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          status: 'PENDING',
        ),
      ),
    );
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  group('ClaimsAuthorizationsAtomPermissions mapping', () {
    test('atom helpers reuse feature *Requirement vocabulary', () {
      expect(
        identical(
          ClaimsAuthorizationsAtomPermissions.tab,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsAuthorizationsAtomPermissions.create,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsAuthorizationsAtomPermissions.nextAction,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsAuthorizationsAtomPermissions.routeEntry,
          claimsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('∩ denial: billing:read alone cannot write / next-action', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(ClaimsAuthorizationsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClaimsAuthorizationsAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.nextAction.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.requestAuthorization.isAllowed(
          reader,
        ),
        isFalse,
      );
    });

    test('∩ presence: billing:read + billing:write mounts write atoms', () {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(ClaimsAuthorizationsAtomPermissions.tab.isAllowed(writer), isTrue);
      expect(
        ClaimsAuthorizationsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.nextAction.isAllowed(writer),
        isTrue,
      );
    });

    test('∪ route entry: financial:approve alone enters but not Authorizations tab', () {
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.routeEntry.isAllowed(approver),
        isTrue,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(approver),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.entry.isAllowed(approver),
        isTrue,
      );
    });
  });

  testWidgets(
    'read-only ∩: Authorizations list visible; write atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.textContaining('Authorizations'), findsWidgets);
      expect(find.text('AUTH-PENDING'), findsOneWidget);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Update status'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('AUTH-PENDING'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Update status'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.text('Print statement'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'full write ∩: Request authorization + Update status next-action mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.byTooltip('Request authorization'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Update status'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: billing:write alone without billing:read omits Authorizations',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('AUTH-PENDING'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: financial:approve alone allows entry mapping but strips Authorizations',
    (WidgetTester tester) async {
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.routeEntry.isAllowed(approver),
        isTrue,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(approver),
        isFalse,
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: approver,
      );

      expect(find.text('AUTH-PENDING'), findsNothing);
      expect(find.byTooltip('Update status'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: insurance-claims missing omits Authorizations chrome',
    (WidgetTester tester) async {
      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.text('AUTH-PENDING'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Authorizations (plan ∩)',
    (WidgetTester tester) async {
      final AppAccessPolicy noBillingModule = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'insurance-claims',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(noBillingModule),
        isFalse,
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: noBillingModule,
      );

      expect(find.text('AUTH-PENDING'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module write n/a: no facility-admin-only create without billing:write',
    (WidgetTester tester) async {
      final AppAccessPolicy facilityAdmin = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.facilityAdmin,
        },
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.create.isAllowed(facilityAdmin),
        isFalse,
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: facilityAdmin,
      );

      expect(find.text('AUTH-PENDING'), findsOneWidget);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(find.byTooltip('Update status'), findsNothing);
    },
  );

  testWidgets(
    'facility:admin ∪ setup without billing:read never mounts Authorizations body',
    (WidgetTester tester) async {
      final AppAccessPolicy setupOnly = _policy(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(setupOnly),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(setupOnly),
        isTrue,
      );

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: setupOnly,
      );

      // Deep link targeted Authorizations, but body must fall back immediately
      // (no queue leakage before post-frame section sync).
      expect(find.text('AUTH-PENDING'), findsNothing);
      expect(find.byTooltip('Request authorization'), findsNothing);
      expect(find.byTooltip('Update status'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Update status next-action opens nested dialog and syncs queue',
    (WidgetTester tester) async {
      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      clearInteractions(repository);
      _stubRepository(repository);

      final Finder nextAction = find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Update status'),
      );
      await tester.ensureVisible(nextAction);
      await tester.tap(nextAction);
      await tester.pumpAndSettle();

      expect(find.text('UPDATE AUTHORIZATION STATUS'), findsOneWidget);
      verifyNever(() => repository.getDetail(any()));

      // Submit with current PENDING status (no amount required) → queue sync.
      await tester.tap(find.text('Update status').last);
      await tester.pumpAndSettle();

      verify(() => repository.updatePreAuthorization(any(), any())).called(1);
      verify(() => repository.listQueue(any())).called(greaterThanOrEqualTo(1));
    },
  );

  testWidgets('authorized empty queue state remains observable', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      items: const <ClaimsQueueItem>[],
      summary: const ClaimsWorkspaceSummary(),
    );

    expect(find.byTooltip('Request authorization'), findsOneWidget);
    expect(find.textContaining('No claims'), findsWidgets);
  });

  testWidgets('authorized load error exposes retry', (WidgetTester tester) async {
    when(() => repository.listQueue(any())).thenAnswer(
      (_) async => const Result<AppPage<ClaimsQueueItem>>.failure(
        AppFailure.unexpected(),
      ),
    );
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<ClaimsReferenceData>.success(_referenceData),
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
      initialLocation: '/claims?section=authorizations',
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

  testWidgets('mobile viewport: next-action trailing mounts for writers', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
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

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(AppListTableMobileItem), findsWidgets);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
    expect(find.byTooltip('Update status'), findsOneWidget);
  });

  testWidgets('mobile viewport: read-only omits next-action trailing', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
      physicalSize: const Size(390, 844),
    );

    expect(find.textContaining('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsNothing);
    expect(find.byTooltip('Update status'), findsNothing);
  });

  testWidgets('desktop viewport shows Update status next-action column', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
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

    expect(find.byType(DataTable), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Update status'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('light theme: authorized Authorizations chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      themeMode: ThemeMode.light,
    );

    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Authorizations chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAuthorizationsTab(
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

    expect(find.text('AUTH-PENDING'), findsOneWidget);
    expect(find.byTooltip('Request authorization'), findsOneWidget);
    expect(find.byTooltip('Update status'), findsOneWidget);
  });

  testWidgets(
    'deep link action=preauth opens request dialog only when write ∩ granted',
    (WidgetTester tester) async {
      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        initialLocation: '/claims?section=authorizations&action=preauth',
      );

      expect(find.textContaining('REQUEST'), findsNothing);

      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation: '/claims?section=authorizations&action=preauth',
      );

      expect(find.textContaining('REQUEST'), findsWidgets);
    },
  );

  testWidgets(
    'authorized Request authorization dialog validates required coverage scheme',
    (WidgetTester tester) async {
      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Request authorization'));
      await tester.pumpAndSettle();

      expect(find.textContaining('REQUEST'), findsWidgets);
      // Submit without selecting coverage → validation; no mutation.
      clearInteractions(repository);
      _stubRepository(repository);
      await tester.tap(find.text('Request authorization').last);
      await tester.pumpAndSettle();

      verifyNever(() => repository.requestPreAuthorization(any()));
      expect(find.textContaining('REQUEST'), findsWidgets);
    },
  );

  testWidgets(
    'read chrome: summary chips mount when counts > 0 for billing:read ∩',
    (WidgetTester tester) async {
      await _pumpAuthorizationsTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.textContaining('Auth pending'), findsOneWidget);
      expect(find.textContaining('Auth approved'), findsOneWidget);
      expect(find.byTooltip('Request authorization'), findsNothing);
    },
  );
}
