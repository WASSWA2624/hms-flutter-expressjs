import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

const BillingWorkItem _claimItem = BillingWorkItem(
  id: 'claim-1',
  displayId: 'CLM-001',
  kind: BillingWorkItemKind.claim,
  patientDisplayName: 'Cara Claim',
  patientDisplayId: 'PT-CLAIM',
  status: 'PENDING',
  amount: 800,
  financials: BillingFinancials(balanceDue: 800),
);

const BillingWorkItem _paymentItem = BillingWorkItem(
  id: 'inv-pay',
  displayId: 'INV-PAY',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Ben Payment',
  patientDisplayId: 'PT-PAY',
  billingStatus: 'ISSUED',
  amount: 500,
  financials: BillingFinancials(balanceDue: 500),
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 1,
  claimsPending: 1,
  approvalRequired: 0,
  overdue: 0,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
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

void _stubRepository(_MockBillingRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<BillingWorkspaceOverview>.success(
      BillingWorkspaceOverview(summary: _summary),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    final List<BillingWorkItem> items =
        query.queue == BillingQueueType.claimsPending
        ? const <BillingWorkItem>[_claimItem]
        : const <BillingWorkItem>[_paymentItem];
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(
    () => repository.submitClaim(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(claim: _claimItem),
    ),
  );
}

Future<void> _pumpClaimsPendingTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/billing?queue=claims-pending',
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
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: BillingWorkspacePage(
              initialQuery: BillingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        billingRepositoryProvider.overrideWithValue(repository),
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
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(const BillingClaimActionDraft());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only ∩ insurance: Claims pending list visible; mutate atoms absent',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Submit claim'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Cara Claim'));
      await tester.pumpAndSettle();

      expect(find.text('Submit claim'), findsNothing);
      expect(find.text('Reconcile claim'), findsNothing);
    },
  );

  testWidgets(
    'write without insurance-claims: Claims pending tab omitted (∩ module denial)',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
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

      expect(find.text('Claims pending'), findsNothing);
      expect(find.text('Cara Claim'), findsNothing);
      // Deep link falls back to an authorized queue.
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full claim write ∩: Submit claim next-action and detail actions mount',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.byTooltip('Submit claim'), findsWidgets);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);

      await tester.tap(find.text('Cara Claim'));
      await tester.pumpAndSettle();

      expect(find.text('Submit claim'), findsWidgets);
    },
  );

  testWidgets(
    'route entry ∪: billing:write alone without billing:read omits read chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(billingWorkspaceEntryRequirement.isAllowed(writeOnly), isTrue);
      expect(BillingClaimsPendingAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Cara Claim'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: billing:read alone with insurance keeps Claims pending',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(billingWorkspaceEntryRequirement.isAllowed(readOnly), isTrue);
      expect(BillingClaimsPendingAtomPermissions.tab.isAllowed(readOnly), isTrue);
      expect(
        BillingClaimsPendingAtomPermissions.claimWrite.isAllowed(readOnly),
        isFalse,
      );

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: readOnly,
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Claims')),
        isTrue,
      );
      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.byTooltip('Submit claim'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized claim row readable', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsPendingTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      ),
      // Representative compact / phone-landscape width (full phone strip overflows
      // with six billing queues — product tab strip; not a permissions gap).
      physicalSize: const Size(800, 900),
    );

    expect(find.text('Cara Claim'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Submit claim'), findsWidgets);
  });

  testWidgets('desktop viewport shows Submit claim next-action', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsPendingTab(
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

    expect(find.text('Cara Claim'), findsOneWidget);
    expect(find.byTooltip('Submit claim'), findsWidgets);
  });

  testWidgets('dark theme: authorized Claims pending chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpClaimsPendingTab(
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

    expect(find.text('Cara Claim'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Submit claim'), findsWidgets);
  });

  testWidgets(
    'authorized submit-claim next-action opens nested dialog (sync path)',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Submit claim').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'billing-payments only role pack without insurance strips Claims pending',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(
        BillingClaimsPendingAtomPermissions.tab.isAllowed(
          _policy(
            permissions: <AppPermission>{AppPermissions.billingRead},
            modules: const <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            ],
          ),
        ),
        isFalse,
      );
      expect(find.text('Claims pending'), findsNothing);
    },
  );
}
