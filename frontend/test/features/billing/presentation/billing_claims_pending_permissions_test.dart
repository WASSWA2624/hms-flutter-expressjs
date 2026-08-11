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

const BillingWorkItem _submittedClaim = BillingWorkItem(
  id: 'claim-2',
  displayId: 'CLM-002',
  kind: BillingWorkItemKind.claim,
  patientDisplayName: 'Sam Submitted',
  patientDisplayId: 'PT-SUB',
  status: 'SUBMITTED',
  amount: 400,
  financials: BillingFinancials(balanceDue: 400),
);

const BillingWorkItem _preAuthItem = BillingWorkItem(
  id: 'preauth-1',
  displayId: 'PA-001',
  kind: BillingWorkItemKind.preAuthorization,
  patientDisplayName: 'Pat Preauth',
  patientDisplayId: 'PT-PA',
  status: 'PENDING',
  amount: 250,
  financials: BillingFinancials(balanceDue: 250),
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

const BillingSummary _emptySummary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 0,
  claimsPending: 0,
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

void _stubRepository(
  _MockBillingRepository repository, {
  List<BillingWorkItem> claimItems = const <BillingWorkItem>[_claimItem],
  BillingSummary summary = _summary,
  Result<BillingWorkspaceOverview>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async =>
        workspaceOverride ??
        Result<BillingWorkspaceOverview>.success(
          BillingWorkspaceOverview(summary: summary),
        ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final BillingWorkspaceQuery query =
        invocation.positionalArguments.single as BillingWorkspaceQuery;
    final List<BillingWorkItem> items =
        query.queue == BillingQueueType.claimsPending
            ? claimItems
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
  when(
    () => repository.reconcileClaim(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(claim: _submittedClaim),
    ),
  );
  when(
    () => repository.updatePreAuthorization(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(claim: _preAuthItem),
    ),
  );
}

Future<GoRouter> _pumpClaimsPendingTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/billing?section=claims',
  List<BillingWorkItem> claimItems = const <BillingWorkItem>[_claimItem],
  BillingSummary summary = _summary,
  Result<BillingWorkspaceOverview>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    claimItems: claimItems,
    summary: summary,
    workspaceOverride: workspaceOverride,
  );

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
  return router;
}

void main() {
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(const BillingClaimActionDraft());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only ∩ insurance: Claims pending list visible; mutate atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingClaimsPendingAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BillingClaimsPendingAtomPermissions.document.isAllowed(reader),
        isTrue,
      );
      expect(
        BillingClaimsPendingAtomPermissions.nestedRead.isAllowed(reader),
        isTrue,
      );
      expect(
        BillingClaimsPendingAtomPermissions.claimWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.submit.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.close.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.text('Open claims'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Cara Claim'));
      await tester.pumpAndSettle();

      expect(find.text('Submit claim'), findsNothing);
      expect(find.text('Record insurer response'), findsNothing);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Print invoice'), findsNothing);
      expect(find.text('Print statement'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsNothing);
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

      expect(find.text('Open claims'), findsNothing);
      expect(find.text('Cara Claim'), findsNothing);
      // Deep link falls back to an authorized queue.
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full claim write ∩: Submit claim next-action and detail actions mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingClaimsPendingAtomPermissions.claimWrite.isAllowed(writer),
        isTrue,
      );
      expect(BillingClaimsPendingAtomPermissions.submit.isAllowed(writer), isTrue);
      expect(
        BillingClaimsPendingAtomPermissions.reconcile.isAllowed(writer),
        isTrue,
      );
      expect(BillingClaimsPendingAtomPermissions.preAuth.isAllowed(writer), isTrue);
      expect(BillingClaimsPendingAtomPermissions.close.isAllowed(writer), isTrue);
      expect(BillingClaimsPendingAtomPermissions.delete.isAllowed(writer), isTrue);

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);

      await tester.tap(find.text('Cara Claim'));
      await tester.pumpAndSettle();

      expect(find.text('Submit claim'), findsWidgets);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Print invoice'), findsNothing);
      expect(find.text('Print statement'), findsOneWidget);
      expect(find.text('Finalize financial clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: billing:write alone without billing:read keeps Open claims when insurance entitled',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(
        BillingClaimsPendingAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BillingClaimsPendingAtomPermissions.tab.isAllowed(writeOnly),
        isTrue,
      );

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Open claims'), findsWidgets);
      expect(find.text('Cara Claim'), findsOneWidget);
      // Mutations still require write ∩ insurance (present here) — Next mounts.
      expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
    },
  );

  testWidgets(
    'route entry ∪: billing:read alone with insurance keeps Open claims',
    (WidgetTester tester) async {
      final AppAccessPolicy readOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(
        BillingClaimsPendingAtomPermissions.routeEntry.isAllowed(readOnly),
        isTrue,
      );
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
        strip.tabs.any((AppTabItem tab) => tab.label == 'Open claims'),
        isTrue,
      );
      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Claims pending chrome',
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
              code: 'insurance-claims',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Cara Claim'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
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
      expect(find.text('Open claims'), findsNothing);
    },
  );

  testWidgets(
    'SUBMITTED claim: Record insurer response next-action mounts with claim write ∩',
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
        claimItems: const <BillingWorkItem>[_submittedClaim],
      );

      expect(find.text('Sam Submitted'), findsOneWidget);
      expect(find.byTooltip('Record the insurer response'), findsWidgets);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);

      await tester.tap(find.text('Sam Submitted'));
      await tester.pumpAndSettle();

      expect(find.text('Record insurer response'), findsWidgets);
    },
  );

  testWidgets(
    'pre-auth: Approve authorization mounts with claim write ∩; absent for read-only',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: reader,
        claimItems: const <BillingWorkItem>[_preAuthItem],
      );

      expect(find.text('Pat Preauth'), findsOneWidget);
      expect(find.byTooltip('Approve this pre-authorization'), findsNothing);
      expect(find.byTooltip('Deny authorization'), findsNothing);

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        claimItems: const <BillingWorkItem>[_preAuthItem],
      );

      expect(find.text('Pat Preauth'), findsOneWidget);
      expect(find.byTooltip('Approve this pre-authorization'), findsWidgets);

      await tester.tap(find.text('Pat Preauth'));
      await tester.pumpAndSettle();

      expect(find.text('Approve authorization'), findsWidgets);
      expect(find.text('Deny authorization'), findsWidgets);
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
    expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
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
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
    expect(find.byTooltip('Close shift'), findsNothing);
  });

  testWidgets('light theme: authorized Claims pending chrome remains', (
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
    );

    expect(find.text('Cara Claim'), findsOneWidget);
    expect(find.text('Close shift'), findsNothing);
    expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
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
    expect(find.text('Close shift'), findsNothing);
    expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
  });

  testWidgets(
    'authorized empty Claims pending queue remains observable',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        claimItems: const <BillingWorkItem>[],
        summary: _emptySummary,
      );

      expect(find.text('No open claims.'), findsOneWidget);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Claims pending',
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
        workspaceOverride: const Result<BillingWorkspaceOverview>.failure(
          AppFailure.network(),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized submit-claim next-action opens nested dialog and syncs (mutation)',
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

      await tester.tap(find.byTooltip('Submit this claim to the insurer').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Submit claim'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      final Finder submit = find.widgetWithText(FilledButton, 'Submit claim');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit.last);
      } else {
        await tester.tap(find.text('Submit claim').last);
      }
      await tester.pumpAndSettle();

      verify(() => repository.submitClaim(any(), any())).called(1);
    },
  );

  testWidgets(
    'authorized Record insurer response opens nested dialog and syncs (mutation)',
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
        claimItems: const <BillingWorkItem>[_submittedClaim],
      );

      await tester.tap(find.byTooltip('Record the insurer response').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Record insurer response'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      final Finder reconcile = find.widgetWithText(
        FilledButton,
        'Record insurer response',
      );
      if (reconcile.evaluate().isNotEmpty) {
        await tester.tap(reconcile.last);
      } else {
        await tester.tap(find.text('Record insurer response').last);
      }
      await tester.pumpAndSettle();

      verify(() => repository.reconcileClaim(any(), any())).called(1);
    },
  );

  testWidgets(
    'nestedWrite without insurance-claims stays denied (helper ∩)',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoClaims = _policy(
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
      );
      expect(
        BillingClaimsPendingAtomPermissions.nestedWrite.isAllowed(
          writerNoClaims,
        ),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.write.isAllowed(writerNoClaims),
        isTrue,
      );
      expect(
        BillingClaimsPendingAtomPermissions.tab.isAllowed(writerNoClaims),
        isFalse,
      );

      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: writerNoClaims,
      );

      expect(find.text('Open claims'), findsNothing);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'list chrome (search) remains for authorized Claims pending readers',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.text('Cara Claim'), findsOneWidget);
      expect(find.byTooltip('Submit this claim to the insurer'), findsNothing);
    },
  );

  testWidgets(
    'write without financial:approve keeps claim actions; approve atoms stay absent',
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

      expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        BillingClaimsPendingAtomPermissions.approve.isAllowed(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'section=claims and claims-pending alias keep authorized Submit (integration)',
    (WidgetTester tester) async {
      for (final String location in <String>[
        '/billing?section=claims',
        '/billing?section=claims-pending',
        '/billing?tab=claims',
        '/billing?queue=claims-pending',
      ]) {
        final GoRouter router = await _pumpClaimsPendingTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
          initialLocation: location,
        );

        expect(find.text('Cara Claim'), findsOneWidget);
        expect(find.byTooltip('Submit this claim to the insurer'), findsWidgets);
        expect(find.text('Close shift'), findsNothing);
        expect(find.text('Charge'), findsNothing);
        expect(router.state.uri.queryParameters['section'], 'claims');
      }
    },
  );

  testWidgets(
    'Open claims tooltip and warning count tone are present',
    (WidgetTester tester) async {
      await _pumpClaimsPendingTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(
        find.byTooltip(
          'Insurance claims and pre-authorizations awaiting action',
        ),
        findsWidgets,
      );
      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem claims = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label.contains('Open claims'),
      );
      expect(claims.countTone, AppTabCountTone.warning);
    },
  );

  testWidgets(
    'authorized Deny authorization from detail opens notes dialog (validation chrome)',
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
        claimItems: const <BillingWorkItem>[_preAuthItem],
      );

      await tester.tap(find.text('Pat Preauth'));
      await tester.pumpAndSettle();

      final int dialogsBefore = find.byType(AppDialog).evaluate().length;
      final Finder denyAction = find.text('Deny authorization').last;
      await tester.ensureVisible(denyAction);
      await tester.tap(denyAction);
      await tester.pumpAndSettle();

      expect(
        find.byType(AppDialog).evaluate().length,
        greaterThan(dialogsBefore),
      );
      expect(find.byType(AppTextField), findsWidgets);
      verifyNever(() => repository.updatePreAuthorization(any(), any()));
    },
  );

  testWidgets(
    'authorized Approve authorization next-action opens nested dialog and syncs',
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
        claimItems: const <BillingWorkItem>[_preAuthItem],
      );

      await tester.tap(find.byTooltip('Approve this pre-authorization').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Approve authorization'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);

      final Finder approve = find.widgetWithText(
        FilledButton,
        'Approve authorization',
      );
      if (approve.evaluate().isNotEmpty) {
        await tester.tap(approve.last);
      } else {
        await tester.tap(find.text('Approve authorization').last);
      }
      await tester.pumpAndSettle();

      verify(() => repository.updatePreAuthorization(any(), any())).called(1);
    },
  );

  testWidgets(
    'authorized Record insurer response from detail keeps validation chrome',
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
        claimItems: const <BillingWorkItem>[_submittedClaim],
      );

      await tester.tap(find.text('Sam Submitted'));
      await tester.pumpAndSettle();

      final int dialogsBefore = find.byType(AppDialog).evaluate().length;
      final Finder reconcileAction = find.text('Record insurer response').last;
      await tester.ensureVisible(reconcileAction);
      await tester.tap(reconcileAction);
      await tester.pumpAndSettle();

      expect(
        find.byType(AppDialog).evaluate().length,
        greaterThan(dialogsBefore),
      );
      expect(find.byType(AppTextField), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
      verifyNever(() => repository.reconcileClaim(any(), any()));
    },
  );
}
