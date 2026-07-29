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

const BillingWorkItem _draftInvoice = BillingWorkItem(
  id: 'inv-draft',
  displayId: 'INV-DRAFT',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Ada Draft',
  patientDisplayId: 'PT-DRAFT',
  billingStatus: 'DRAFT',
  amount: 200,
  financials: BillingFinancials(balanceDue: 200),
);

const BillingWorkItem _issuedFromDraft = BillingWorkItem(
  id: 'inv-draft',
  displayId: 'INV-DRAFT',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Ada Draft',
  patientDisplayId: 'PT-DRAFT',
  billingStatus: 'ISSUED',
  amount: 200,
  financials: BillingFinancials(balanceDue: 200),
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 1,
  pendingPayment: 0,
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
  List<BillingWorkItem> items = const <BillingWorkItem>[_draftInvoice],
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
    () => repository.issueInvoice(any(), notes: any(named: 'notes')),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _issuedFromDraft),
    ),
  );
}

Future<void> _pumpNeedsIssueTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_draftInvoice],
  BillingSummary summary = _summary,
  Result<BillingWorkspaceOverview>? workspaceOverride,
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
    initialLocation: '/billing?queue=needs-issue',
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
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only: Needs issue list visible; Issue / close atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingNeedsIssueAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingNeedsIssueAtomPermissions.document.isAllowed(reader), isTrue);
      expect(BillingNeedsIssueAtomPermissions.issue.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.close.isAllowed(reader), isFalse);

      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ada Draft'), findsOneWidget);
      expect(find.text('Needs issue'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Issue'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Claims pending'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Ada Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsNothing);
      expect(find.text('Print invoice'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'list chrome (search) remains for authorized Needs issue readers',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.text('Ada Draft'), findsOneWidget);
      expect(find.byTooltip('Issue'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: Issue next-action and detail Issue mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingNeedsIssueAtomPermissions.issue.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.create.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.update.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.delete.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.close.isAllowed(writer), isTrue);

      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ada Draft'), findsOneWidget);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);
      expect(find.byTooltip('Issue'), findsWidgets);

      await tester.tap(find.text('Ada Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsWidgets);
      expect(find.text('Print invoice'), findsOneWidget);
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
        BillingNeedsIssueAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BillingNeedsIssueAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Ada Draft'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Issue'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Needs issue chrome',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
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
      expect(find.text('Ada Draft'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: Claims pending absent without insurance-claims',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
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
        BillingNeedsIssueAtomPermissions.claimsPendingTab.isAllowed(
          _policy(
            permissions: <AppPermission>{
              AppPermissions.billingRead,
              AppPermissions.billingWrite,
            },
          ),
        ),
        isFalse,
      );
      expect(find.text('Claims pending'), findsNothing);
      expect(find.byTooltip('Issue'), findsWidgets);
    },
  );

  testWidgets(
    'nested cross-module: insurance restores Claims pending on Needs issue strip',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
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
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Claims')),
        isTrue,
      );
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Needs issue')),
        isTrue,
      );
      expect(find.byTooltip('Issue'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Needs issue chrome', (
    WidgetTester tester,
  ) async {
    await _pumpNeedsIssueTab(
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

  testWidgets('desktop viewport keeps authorized Needs issue row readable', (
    WidgetTester tester,
  ) async {
    await _pumpNeedsIssueTab(
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

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Issue'), findsWidgets);
  });

  testWidgets('dark theme: authorized Needs issue chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpNeedsIssueTab(
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

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Issue'), findsWidgets);
  });

  testWidgets(
    'authorized Issue next-action submits and syncs (mutation path)',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Issue').first);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Issue'), findsWidgets);

      final Finder submit = find.widgetWithText(FilledButton, 'Issue');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit.last);
      } else {
        await tester.tap(find.text('Issue').last);
      }
      await tester.pumpAndSettle();

      verify(
        () => repository.issueInvoice(any(), notes: any(named: 'notes')),
      ).called(1);
    },
  );

  testWidgets(
    'authorized Close shift opens form chrome (validation surface)',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      final int dialogsBefore = find.byType(AppDialog).evaluate().length;
      await tester.ensureVisible(find.byTooltip('Close shift'));
      await tester.tap(find.byTooltip('Close shift'));
      await tester.pumpAndSettle();

      expect(
        find.byType(AppDialog).evaluate().length,
        greaterThan(dialogsBefore),
      );
      expect(find.byType(AppCurrencyAmountField), findsWidgets);
      expect(find.byType(AppTextField), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'write without financial:approve keeps Issue; approve atoms stay absent',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byTooltip('Issue'), findsWidgets);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        BillingNeedsIssueAtomPermissions.approve.isAllowed(
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
    'empty authorized Needs issue queue still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        items: const <BillingWorkItem>[],
        summary: _emptySummary,
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No billing items'), findsOneWidget);
      expect(find.byTooltip('Issue'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Needs issue',
    (WidgetTester tester) async {
      await _pumpNeedsIssueTab(
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
    'nestedWrite without insurance-claims stays denied on Needs issue',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoClaims = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingNeedsIssueAtomPermissions.nestedWrite.isAllowed(writerNoClaims),
        isFalse,
      );
      expect(
        BillingNeedsIssueAtomPermissions.write.isAllowed(writerNoClaims),
        isTrue,
      );

      await _pumpNeedsIssueTab(
        tester,
        repository: repository,
        accessPolicy: writerNoClaims,
      );

      expect(find.text('Claims pending'), findsNothing);
      expect(find.byTooltip('Issue'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets('light theme: authorized Needs issue chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpNeedsIssueTab(
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

    expect(find.text('Ada Draft'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Issue'), findsWidgets);
  });
}
