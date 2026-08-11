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

const BillingWorkItem _overdueInvoice = BillingWorkItem(
  id: 'inv-overdue',
  displayId: 'INV-OVERDUE',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Omar Overdue',
  patientDisplayId: 'PT-OVD',
  billingStatus: 'ISSUED',
  status: 'OVERDUE',
  amount: 450,
  financials: BillingFinancials(balanceDue: 450),
);

const BillingWorkItem _partiallyPaid = BillingWorkItem(
  id: 'inv-overdue',
  displayId: 'INV-OVERDUE',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Omar Overdue',
  patientDisplayId: 'PT-OVD',
  billingStatus: 'PARTIAL',
  status: 'OVERDUE',
  amount: 450,
  financials: BillingFinancials(balanceDue: 200, netPaidTotal: 250),
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 0,
  claimsPending: 1,
  approvalRequired: 0,
  overdue: 1,
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
  List<BillingWorkItem> items = const <BillingWorkItem>[_overdueInvoice],
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
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    return Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: items,
        request: const AppPageRequest(pageSize: 20),
        totalItemCount: items.length,
      ),
    );
  });
  when(
    () => repository.receivePayment(
      any(),
      any(),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _partiallyPaid),
    ),
  );
}

Future<void> _pumpOverdueTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_overdueInvoice],
  BillingSummary summary = _summary,
  Result<BillingWorkspaceOverview>? workspaceOverride,
  String initialLocation = '/billing?queue=overdue',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
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
}

void main() {
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(
      const BillingWorkItem(id: 'invoice-1', kind: BillingWorkItemKind.invoice),
    );
    registerFallbackValue(
      const BillingPaymentDraft(amount: '1.00', method: 'CASH'),
    );
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only: Overdue list visible; payment / close atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingOverdueAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingOverdueAtomPermissions.document.isAllowed(reader), isTrue);
      expect(
        BillingOverdueAtomPermissions.receivePayment.isAllowed(reader),
        isFalse,
      );
      expect(BillingOverdueAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.close.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.waive.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.dunningSend.isAllowed(reader), isFalse);

      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Omar Overdue'), findsOneWidget);
      expect(find.text('Collect due'), findsWidgets);
      expect(find.text('Overdue'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Receive payment toward the balance due'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next'),
        ),
        findsNothing,
      );
      expect(find.text('Open claims'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Omar Overdue'));
      await tester.pumpAndSettle();

      expect(find.text('Pay'), findsNothing);
      expect(find.text('Adjust'), findsNothing);
      expect(find.text('Void'), findsNothing);
      expect(find.text('Send'), findsNothing);
      expect(find.text('Print invoice'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Receive payment next-action and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingOverdueAtomPermissions.receivePayment.isAllowed(writer),
        isTrue,
      );
      expect(BillingOverdueAtomPermissions.adjust.isAllowed(writer), isTrue);
      expect(BillingOverdueAtomPermissions.waive.isAllowed(writer), isTrue);
      expect(
        BillingOverdueAtomPermissions.voidInvoice.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingOverdueAtomPermissions.dunningSend.isAllowed(writer),
        isTrue,
      );
      expect(BillingOverdueAtomPermissions.close.isAllowed(writer), isTrue);

      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Omar Overdue'), findsOneWidget);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);

      await tester.tap(find.text('Omar Overdue'));
      await tester.pumpAndSettle();

      expect(find.text('Pay'), findsWidgets);
      expect(find.text('Adjust'), findsWidgets);
      expect(find.text('Send'), findsWidgets);
      expect(find.text('Void'), findsWidgets);
      expect(find.text('Print invoice'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Finalize financial clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: billing:write alone without billing:read omits read chrome',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(
        BillingOverdueAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(BillingOverdueAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Omar Overdue'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Overdue chrome',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Omar Overdue'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: Claims pending absent without insurance-claims',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(
        BillingOverdueAtomPermissions.claimsPendingTab.isAllowed(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
        ),
        isFalse,
      );
      expect(find.text('Open claims'), findsNothing);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module: insurance restores Claims pending on Overdue strip',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'billing-payments',
              licenseStatus: 'ACTIVE',
            ),
            AppModuleEntitlement(
              code: 'insurance-claims',
              licenseStatus: 'ACTIVE',
            ),
          ],
        ),
      );

      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      expect(
        strip.tabs.any(
          (AppTabItem tab) => tab.label.toLowerCase().contains('claims'),
        ),
        isTrue,
      );
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Collect due')),
        isTrue,
      );
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Overdue')),
        isFalse,
      );
      expect(find.byTooltip('Receive payment toward the balance due'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Overdue chrome', (
    WidgetTester tester,
  ) async {
    await _pumpOverdueTab(
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

    final Object? layoutException = tester.takeException();
    expect(
      layoutException == null ||
          layoutException.toString().contains('A RenderFlex overflowed'),
      isTrue,
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Close shift'), findsOneWidget);
    expect(find.byTooltip('Close day'), findsOneWidget);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop viewport keeps authorized Overdue row readable', (
    WidgetTester tester,
  ) async {
    await _pumpOverdueTab(
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

    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
    expect(find.byTooltip('Close shift'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Overdue chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverdueTab(
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

    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
  });

  testWidgets('light theme: authorized Overdue chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpOverdueTab(
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

    expect(find.text('Omar Overdue'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
  });

  testWidgets(
    'authorized Receive payment next-action submits and syncs (mutation path)',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Receive payment toward the balance due').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Pay'), findsWidgets);

      final Finder submit = find.widgetWithText(FilledButton, 'Pay');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit.last);
      } else {
        await tester.tap(find.text('Pay').last);
      }
      await tester.pumpAndSettle();

      verify(
        () => repository.receivePayment(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'write without financial:approve keeps collections; approve atoms stay absent',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        BillingOverdueAtomPermissions.approve.isAllowed(
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
    'empty authorized Overdue queue still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        items: const <BillingWorkItem>[],
        summary: _emptySummary,
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No balances due.'), findsOneWidget);
      expect(find.byTooltip('Receive payment toward the balance due'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Overdue',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
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
    'nestedWrite without insurance-claims stays denied on Overdue',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoClaims = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingOverdueAtomPermissions.nestedWrite.isAllowed(writerNoClaims),
        isFalse,
      );
      expect(
        BillingOverdueAtomPermissions.write.isAllowed(writerNoClaims),
        isTrue,
      );
      expect(
        BillingOverdueAtomPermissions.dunningSend.isAllowed(writerNoClaims),
        isTrue,
      );

      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: writerNoClaims,
      );

      expect(find.text('Open claims'), findsNothing);
      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'action=pay deep link opens payment only when write-authorized',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation:
            '/billing?queue=overdue&invoice=INV-OVERDUE&action=pay',
      );

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Pay'), findsWidgets);
    },
  );

  testWidgets(
    'action=pay deep link omitted for read-only (no payment dialog)',
    (WidgetTester tester) async {
      await _pumpOverdueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        initialLocation:
            '/billing?queue=overdue&invoice=INV-OVERDUE&action=pay',
      );

      expect(find.text('Omar Overdue'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
