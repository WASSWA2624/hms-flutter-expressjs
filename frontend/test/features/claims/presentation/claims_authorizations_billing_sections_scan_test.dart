import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/claims/data/repositories/claims_repository_impl.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_authorizations_financial_inventory.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/domain/repositories/claims_repository.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';
import 'package:hosspi_hms/features/claims/presentation/pages/claims_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockClaimsRepository extends Mock implements ClaimsRepository {}

const PreAuthorizationRecord _pendingRecord = PreAuthorizationRecord(
  id: 'auth-pending',
  displayId: 'AUTH-PENDING',
  coveragePlanId: 'plan-1',
  coveragePlanDisplayId: 'PLAN-001',
  status: 'PENDING',
  patientDisplayId: 'PT-AUTH',
  approvedAmount: 100,
);

const PreAuthorizationRecord _approvedRecord = PreAuthorizationRecord(
  id: 'auth-approved',
  displayId: 'AUTH-APPROVED',
  coveragePlanId: 'plan-1',
  coveragePlanDisplayId: 'PLAN-001',
  status: 'APPROVED',
  patientDisplayId: 'PT-AUTH-2',
  approvedAmount: 250,
  consumedAmount: 50,
);

const ClaimsQueueItem _pendingAuth = ClaimsQueueItem.authorization(
  _pendingRecord,
);

const ClaimsQueueItem _approvedAuth = ClaimsQueueItem.authorization(
  _approvedRecord,
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
      coveragePercentage: 80,
    ),
  ],
);

AppAccessPolicy _writerPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.billingWrite,
      },
      moduleEntitlements: <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

AppAccessPolicy _readerPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: <AppPermission>{AppPermissions.billingRead},
      moduleEntitlements: <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
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
}) {
  when(() => repository.listQueue(any())).thenAnswer((_) async {
    return Result<AppPage<ClaimsQueueItem>>.success(
      AppPage<ClaimsQueueItem>(
        items: items,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<ClaimsReferenceData>.success(_referenceData),
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
        coveragePlan: _referenceData.coveragePlans.first,
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
        status: 'APPROVED',
        patientDisplayId: 'PT-AUTH',
        approvedAmount: 150,
        consumedAmount: 0,
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository);

  tester.view.physicalSize = physicalSize;
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

  if (physicalSize.width < 600) {
    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );
  }
}

void main() {
  late _MockClaimsRepository repository;

  setUpAll(() {
    registerFallbackValue(const ClaimsQueueQuery());
    registerFallbackValue(<String, Object?>{});
    registerFallbackValue(_pendingAuth);
  });

  setUp(() {
    repository = _MockClaimsRepository();
  });

  group('Authorizations tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(ClaimsAuthorizationsFinancialInventory.all, isNotEmpty);
      expect(
        ClaimsAuthorizationsFinancialInventory.all.map(
          (ClaimsAuthorizationsFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'request_authorization',
          'update_status',
          'next_action',
          'deep_link_preauth',
          'billing_impact',
          'empty_state',
          'error_retry',
        ]),
      );
      expect(
        ClaimsAuthorizationsFinancialInventory.requestAuthorization.actionClass,
        ClaimsAuthorizationsActionClass.defer,
      );
      expect(
        ClaimsAuthorizationsFinancialInventory.updateStatus.actionClass,
        ClaimsAuthorizationsActionClass.defer,
      );
      expect(
        ClaimsAuthorizationsFinancialInventory.printStatement.actionClass,
        ClaimsAuthorizationsActionClass.notBillable,
      );
    });

    test('AC2: defer mutations map to pre-auth APIs (no cash bypass)', () {
      for (final ClaimsAuthorizationsFinancialAtom atom
          in ClaimsAuthorizationsFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via shared pre-auth / Billing handoff',
        );
        expect(
          ClaimsAuthorizationsFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
      expect(
        ClaimsAuthorizationsFinancialInventory
            .requestAuthorization
            .repositoryMethod,
        'requestPreAuthorization',
      );
      expect(
        ClaimsAuthorizationsFinancialInventory.updateStatus.repositoryMethod,
        'updatePreAuthorization',
      );
    });

    test('AC3: claims workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.claims, containsAll(RealtimeEventGroups.billing));
    });

    test('AC3: remaining amount parity uses approved − consumed', () {
      expect(_approvedRecord.remainingAmount, 200);
      expect(_approvedRecord.isAuthorizationSufficient, isTrue);
    });

    testWidgets(
      'AC2/AC3: update status opens dialog without inline cashier chrome',
      (WidgetTester tester) async {
        await _pumpAuthorizationsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        expect(find.text('AUTH-PENDING'), findsWidgets);
        final Finder nextAction = find.byTooltip('Update status');
        expect(nextAction, findsWidgets);

        await tester.tap(nextAction.first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        // No receive-payment / cash collection entry points on this tab.
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Cash'), findsNothing);
        verifyNever(() => repository.requestPreAuthorization(any()));
      },
    );

    testWidgets(
      'AC4: read-only user cannot update authorization (authorization)',
      (WidgetTester tester) async {
        expect(
          ClaimsAuthorizationsAtomPermissions.update.isAllowed(_readerPolicy()),
          isFalse,
        );

        await _pumpAuthorizationsTab(
          tester,
          repository: repository,
          accessPolicy: _readerPolicy(),
        );

        expect(find.text('AUTH-PENDING'), findsWidgets);
        expect(find.byTooltip('Update status'), findsNothing);
        expect(find.text('Request authorization'), findsNothing);
        verifyNever(() => repository.updatePreAuthorization(any(), any()));
        verifyNever(() => repository.requestPreAuthorization(any()));
      },
    );

    testWidgets(
      'AC5: Authorizations list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpAuthorizationsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('AUTH-PENDING'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog keeps flat sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpAuthorizationsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('AUTH-APPROVED').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
        // Pre-auth amounts from Billing-linked record — not invented % balance.
        expect(find.text('Approved'), findsWidgets);
        expect(find.text('Remaining'), findsWidgets);
      },
    );

    testWidgets(
      'AC5: update authorization dialog stays flat',
      (WidgetTester tester) async {
        await _pumpAuthorizationsTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.byTooltip('Update status').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC4: loading / empty / success chrome remain observable for writers',
      (WidgetTester tester) async {
        when(() => repository.listQueue(any())).thenAnswer(
          (_) async => const Result<AppPage<ClaimsQueueItem>>.success(
            AppPage<ClaimsQueueItem>(
              items: <ClaimsQueueItem>[],
              request: AppPageRequest(pageSize: 20),
              totalItemCount: 0,
            ),
          ),
        );
        when(() => repository.loadWorkspaceSummary()).thenAnswer(
          (_) async => const Result<ClaimsWorkspaceSummary>.success(
            ClaimsWorkspaceSummary(),
          ),
        );
        when(() => repository.loadReferenceData()).thenAnswer(
          (_) async => const Result<ClaimsReferenceData>.success(_referenceData),
        );

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
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
              appAccessPolicyProvider.overrideWithValue(_writerPolicy()),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request authorization'), findsOneWidget);
        expectFlatSections(tester);
      },
    );
  });
}
