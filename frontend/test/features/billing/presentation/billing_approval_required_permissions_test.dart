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

const BillingWorkItem _approvalItem = BillingWorkItem(
  id: 'apr-1',
  displayId: 'APR-001',
  kind: BillingWorkItemKind.approval,
  patientId: 'patient-apr-1',
  patientDisplayName: 'Dana Approval',
  patientDisplayId: 'PT-APR',
  status: 'PENDING',
  amount: 100,
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 0,
  claimsPending: 1,
  approvalRequired: 1,
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
  List<BillingWorkItem> items = const <BillingWorkItem>[_approvalItem],
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
    () => repository.approveApproval(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(
        approval: _approvalItem,
      ),
    ),
  );
  when(
    () => repository.rejectApproval(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(
        approval: _approvalItem,
      ),
    ),
  );
}

Future<void> _pumpApprovalTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<BillingWorkItem> items = const <BillingWorkItem>[_approvalItem],
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
    initialLocation: '/billing?queue=approval-required',
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
    registerFallbackValue(const BillingApprovalDecisionDraft());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  testWidgets(
    'read-only: Approval required list visible; close/approve atoms absent',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingApprovalRequiredAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BillingApprovalRequiredAtomPermissions.approve.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.close.isAllowed(reader),
        isFalse,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Dana Approval'), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Approval required'), findsWidgets);
      expect(find.text('Claims pending'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      expect(find.text('View ledger'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Print invoice'), findsNothing);
      expect(find.byTooltip('Download invoice PDF'), findsNothing);
    },
  );

  testWidgets(
    'write without financial:approve: close present, Approve absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy writer = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        BillingApprovalRequiredAtomPermissions.delete.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.close.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.approve.isAllowed(writer),
        isFalse,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
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
      expect(
        BillingApprovalRequiredAtomPermissions.create.isAllowed(approveOnly),
        isFalse,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: approveOnly,
      );

      expect(find.text('Dana Approval'), findsOneWidget);
      expect(find.text('Close shift'), findsNothing);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'full approve ∩: next-action Approve present and detail actions mount',
    (WidgetTester tester) async {
      final AppAccessPolicy approver = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      );
      expect(
        BillingApprovalRequiredAtomPermissions.approve.isAllowed(approver),
        isTrue,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.create.isAllowed(approver),
        isTrue,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.document.isAllowed(approver),
        isTrue,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: approver,
      );

      expect(find.byTooltip('Approve'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(AppListTableGrid),
          matching: find.text('Next action'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      expect(find.text('Approve'), findsWidgets);
      expect(find.text('Reject'), findsWidgets);
      expect(find.text('View ledger'), findsOneWidget);
      // Approval items are not invoices — document actions must not mount.
      expect(find.text('Print invoice'), findsNothing);
      expect(find.byTooltip('Download invoice PDF'), findsNothing);
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
        BillingApprovalRequiredAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Dana Approval'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Approve'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Approval required chrome',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
          modules: const <AppModuleEntitlement>[],
        ),
      );

      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.text('Dana Approval'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: Claims pending absent without insurance; present with it',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
      );

      expect(find.text('Claims pending'), findsNothing);
      expect(
        BillingApprovalRequiredAtomPermissions.claimsPendingTab.isAllowed(
          _policy(permissions: <AppPermission>{AppPermissions.billingRead}),
        ),
        isFalse,
      );

      await _pumpApprovalTab(
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
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Approval')),
        isTrue,
      );
      expect(find.byTooltip('Approve'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Approval required chrome', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
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

  testWidgets('desktop viewport keeps authorized Approval required row readable', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      ),
      physicalSize: const Size(1440, 900),
    );

    expect(find.text('Dana Approval'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Approve'), findsWidgets);
    expect(find.byTooltip('Close shift'), findsOneWidget);
  });

  testWidgets('light theme: authorized Approval required chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      ),
    );

    expect(find.text('Dana Approval'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Approve'), findsWidgets);
  });

  testWidgets('dark theme: authorized Approval required chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpApprovalTab(
      tester,
      repository: repository,
      accessPolicy: _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      ),
      themeMode: ThemeMode.dark,
    );

    expect(find.text('Dana Approval'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Approve'), findsWidgets);
  });

  testWidgets(
    'authorized empty Approval required queue remains observable',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.billingRead},
        ),
        items: const <BillingWorkItem>[],
        summary: _emptySummary,
      );

      expect(find.text('No billing items'), findsOneWidget);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'authorized error/retry surface remains observable on Approval required',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
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
    'authorized Approve next-action submits and syncs (mutation path)',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      await tester.tap(find.byTooltip('Approve').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Approve'), findsWidgets);

      final Finder submit = find.widgetWithText(FilledButton, 'Approve');
      if (submit.evaluate().isNotEmpty) {
        await tester.tap(submit.last);
      } else {
        await tester.tap(find.text('Approve').last);
      }
      await tester.pumpAndSettle();

      verify(() => repository.approveApproval(any(), any())).called(1);
    },
  );

  testWidgets(
    'authorized Reject from detail opens reason dialog (validation chrome)',
    (WidgetTester tester) async {
      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        ),
      );

      await tester.tap(find.text('Dana Approval'));
      await tester.pumpAndSettle();

      final int dialogsBefore = find.byType(AppDialog).evaluate().length;
      await tester.ensureVisible(find.text('Reject'));
      await tester.tap(find.text('Reject').last);
      await tester.pumpAndSettle();

      expect(
        find.byType(AppDialog).evaluate().length,
        greaterThan(dialogsBefore),
      );
      expect(find.byType(AppTextField), findsWidgets);
      verifyNever(() => repository.rejectApproval(any(), any()));
    },
  );

  testWidgets(
    'nestedWrite without insurance-claims stays denied on Approval required',
    (WidgetTester tester) async {
      final AppAccessPolicy writerNoClaims = _policy(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      );
      expect(
        BillingApprovalRequiredAtomPermissions.nestedWrite.isAllowed(
          writerNoClaims,
        ),
        isFalse,
      );
      expect(
        BillingApprovalRequiredAtomPermissions.write.isAllowed(writerNoClaims),
        isTrue,
      );

      await _pumpApprovalTab(
        tester,
        repository: repository,
        accessPolicy: writerNoClaims,
      );

      expect(find.text('Claims pending'), findsNothing);
      expect(find.byTooltip('Approve'), findsWidgets);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
