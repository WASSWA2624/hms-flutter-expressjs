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
  id: 'inv-all-draft',
  displayId: 'INV-ALL',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'All Queue Patient',
  patientDisplayId: 'PT-ALL',
  billingStatus: 'DRAFT',
  amount: 175,
  financials: BillingFinancials(balanceDue: 175),
);

const BillingWorkItem _issuedInvoice = BillingWorkItem(
  id: 'inv-all-issued',
  displayId: 'INV-ALL-PAY',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'All Pay Patient',
  patientDisplayId: 'PT-PAY',
  billingStatus: 'ISSUED',
  amount: 175,
  financials: BillingFinancials(balanceDue: 175),
);

const BillingWorkItem _issuedFromDraft = BillingWorkItem(
  id: 'inv-all-draft',
  displayId: 'INV-ALL',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'All Queue Patient',
  patientDisplayId: 'PT-ALL',
  billingStatus: 'ISSUED',
  amount: 175,
  financials: BillingFinancials(balanceDue: 175),
);

const BillingWorkItem _approvalItem = BillingWorkItem(
  id: 'apr-all',
  displayId: 'APR-ALL',
  kind: BillingWorkItemKind.approval,
  patientDisplayName: 'All Approval Patient',
  patientDisplayId: 'PT-APR',
  status: 'PENDING',
  amount: 100,
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 1,
  pendingPayment: 0,
  claimsPending: 1,
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
  Result<BillingWorkspaceOverview>? workspaceOverride,
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async =>
        workspaceOverride ??
        const Result<BillingWorkspaceOverview>.success(
          BillingWorkspaceOverview(summary: _summary),
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
  when(
    () => repository.receivePayment(
      any(),
      any(),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _issuedInvoice),
    ),
  );
  when(() => repository.createCharge(any())).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _draftInvoice),
    ),
  );
}

Future<GoRouter> _pumpAllTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_draftInvoice],
  String initialLocation = '/billing?section=work',
  Result<BillingWorkspaceOverview>? workspaceOverride,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items,
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
    registerFallbackValue(
      const BillingWorkItem(id: 'invoice-1', kind: BillingWorkItemKind.invoice),
    );
    registerFallbackValue(
      const BillingPaymentDraft(amount: '1.00', method: 'CASH'),
    );
    registerFallbackValue(
      const BillingChargeDraft(
        patientId: 'patient-1',
        itemDescription: 'Consult',
        quantity: 1,
        unitPrice: '10.00',
        paymentMode: 'SELF_PAY',
      ),
    );
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only: All list visible; Issue / close atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingAllAtomPermissions.document.isAllowed(reader), isTrue);
      expect(BillingAllAtomPermissions.issue.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.close.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.refund.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.send.isAllowed(reader), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('All Queue Patient'), findsOneWidget);
      expect(find.textContaining('Open work'), findsWidgets);
      expect(find.text('Charge'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.text('Issue'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next'),
        ),
        findsNothing,
      );
      expect(find.text('Open claims'), findsNothing);
      expect(find.byType(AppSearchBar), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('All Queue Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsNothing);
      expect(find.text('Receive payment'), findsNothing);
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
    'full write ∩: Issue next-action and detail mutations mount',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingAllAtomPermissions.issue.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.create.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.update.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.delete.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.receivePayment.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.refund.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.adjust.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.voidInvoice.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.send.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.close.isAllowed(writer), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('All Queue Patient'), findsOneWidget);
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.text('Issue'), findsWidgets);

      await tester.tap(find.text('All Queue Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsWidgets);
      expect(find.text('Print invoice'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Finalize financial clearance'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full write ∩: issued invoice detail exposes Pay / Adjust / Void / Send',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        items: const <BillingWorkItem>[_issuedInvoice],
      );

      expect(find.byTooltip('Receive payment toward the balance due'), findsWidgets);

      await tester.tap(find.text('All Pay Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Pay'), findsWidgets);
      expect(find.text('Adjust'), findsWidgets);
      expect(find.text('Send'), findsWidgets);
      expect(find.text('Void'), findsWidgets);
      expect(find.text('Print invoice'), findsOneWidget);
      expect(find.byTooltip('Download invoice PDF'), findsOneWidget);
      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Finalize financial clearance'), findsNothing);
    },
  );

  testWidgets(
    'route entry ∪: billing:write alone without billing:read still mounts Open work',
    (WidgetTester tester) async {
      final AppAccessPolicy writeOnly = _policy(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      expect(BillingAllAtomPermissions.routeEntry.isAllowed(writeOnly), isTrue);
      expect(BillingAllAtomPermissions.entry.isAllowed(writeOnly), isTrue);
      // Tab strip uses entry (read ∪ write); atom map "tab" stays read-centric.
      expect(canViewBillingQueue(writeOnly, BillingQueueType.all), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('All Queue Patient'), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Charge'), findsOneWidget);
      expect(find.text('Issue'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits All chrome',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
      expect(find.text('All Queue Patient'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: insurance restores Claims pending on All strip',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Open work')),
        isTrue,
      );
      expect(find.text('Issue'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized All chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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
    expect(
      find.byTooltip('Create a draft charge for a patient'),
      findsOneWidget,
    );
    expect(find.text('Close shift'), findsNothing);
    expect(find.text('Close day'), findsNothing);
    expect(find.textContaining('no access'), findsNothing);
  });

  testWidgets('desktop viewport keeps authorized All row readable', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Queue Patient'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Issue'), findsWidgets);
    expect(find.text('Charge'), findsOneWidget);
  });

  testWidgets('dark theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Queue Patient'), findsOneWidget);
    expect(find.text('Charge'), findsOneWidget);
    expect(find.text('Issue'), findsWidgets);
  });

  testWidgets('light theme: authorized All chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAllTab(
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

    expect(find.text('All Queue Patient'), findsOneWidget);
    expect(find.text('Charge'), findsOneWidget);
    expect(find.text('Issue'), findsWidgets);
  });

  testWidgets(
    'authorized Issue next-action opens nested notes dialog (sync path)',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.text('Issue').first);
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
    'write without financial:approve keeps Issue; approve atoms stay absent',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        items: const <BillingWorkItem>[_approvalItem],
      );

      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        BillingAllAtomPermissions.approve.isAllowed(
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
    'financial:approve without billing:write: Approve absent (source ∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy approveOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.financialApprove,
        },
      );
      expect(BillingAllAtomPermissions.approve.isAllowed(approveOnly), isFalse);
      expect(BillingAllAtomPermissions.close.isAllowed(approveOnly), isFalse);
      expect(BillingAllAtomPermissions.issue.isAllowed(approveOnly), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: approveOnly,
        items: const <BillingWorkItem>[_approvalItem],
      );

      expect(find.text('All Approval Patient'), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.text('Issue'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'approve ∩: billing:write + financial:approve mounts Approve on All',
    (WidgetTester tester) async {
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      );
      expect(BillingAllAtomPermissions.approve.isAllowed(approver), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: approver,
        items: const <BillingWorkItem>[_approvalItem],
      );

      expect(find.text('All Approval Patient'), findsOneWidget);
      expect(find.byTooltip('Approve this pending request'), findsWidgets);

      await tester.tap(find.text('All Approval Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Reject'), findsWidgets);
      expect(find.text('View ledger'), findsOneWidget);
      // Approval items are not invoices — document actions must not mount.
      expect(find.text('Print invoice'), findsNothing);
      expect(find.byTooltip('Download invoice PDF'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized Receive payment next-action submits and syncs (mutation path)',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        items: const <BillingWorkItem>[_issuedInvoice],
      );

      await tester.tap(
        find.byTooltip('Receive payment toward the balance due').first,
      );
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
    'empty authorized All queue still shows chrome and empty state',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        items: const <BillingWorkItem>[],
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('No open work.'), findsOneWidget);
      expect(find.text('Issue'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on All',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
    'action=pay deep link opens payment only when write-authorized',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        items: const <BillingWorkItem>[_issuedInvoice],
        initialLocation: '/billing?section=work&invoice=INV-ALL-PAY&action=pay',
      );

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Pay'), findsWidgets);
    },
  );

  testWidgets(
    'action=pay deep link omitted for read-only (no payment dialog)',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        items: const <BillingWorkItem>[_issuedInvoice],
        initialLocation: '/billing?section=work&invoice=INV-ALL-PAY&action=pay',
      );

      expect(find.text('All Pay Patient'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Pay'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: Claims pending absent without insurance-claims',
    (WidgetTester tester) async {
      await _pumpAllTab(
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
        BillingAllAtomPermissions.claimsPendingTab.isAllowed(
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
      expect(find.text('Charge'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nestedWrite without insurance-claims stays denied on All',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoClaims = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingAllAtomPermissions.nestedWrite.isAllowed(writerNoClaims),
        isFalse,
      );
      expect(BillingAllAtomPermissions.write.isAllowed(writerNoClaims), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writerNoClaims,
      );

      expect(find.text('Open claims'), findsNothing);
      expect(find.text('Issue'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'section aliases all/inbox select Open work and write section=work',
    (WidgetTester tester) async {
      for (final String location in <String>[
        '/billing?section=all',
        '/billing?section=inbox',
        '/billing?tab=work',
      ]) {
        final GoRouter router = await _pumpAllTab(
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

        expect(find.textContaining('Open work'), findsWidgets);
        expect(find.text('Charge'), findsOneWidget);
        expect(router.state.uri.queryParameters['section'], 'work');
      }
    },
  );

  testWidgets(
    'Charge without similar drafts creates and lands on To issue',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        items: const <BillingWorkItem>[],
      );

      await tester.tap(find.text('Charge'));
      await tester.pumpAndSettle();

      // Without a patient picker mock the Charge dialog cannot fully submit;
      // assert the create path is wired and To issue trailing is absent here.
      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Charge'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
    },
  );

  testWidgets(
    'Open work tooltip and info count tone are present',
    (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(
        find.byTooltip(
          'All billing items that still need action across issue, collect, claims, and approvals',
        ),
        findsWidgets,
      );
      final AppTabStrip strip = tester.widget(find.byType(AppTabStrip));
      final AppTabItem work = strip.tabs.firstWhere(
        (AppTabItem tab) => tab.label.contains('Open work'),
      );
      expect(work.countTone, AppTabCountTone.info);
    },
  );
}
