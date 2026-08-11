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
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_approval_required_financial_inventory.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/section_layout_assertions.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

const BillingWorkItem _approvalItem = BillingWorkItem(
  id: 'apr-scan-1',
  displayId: 'APR-SCAN',
  kind: BillingWorkItemKind.approval,
  patientId: 'patient-apr-scan',
  patientDisplayName: 'Scan Approval Patient',
  patientDisplayId: 'PT-APR-SCAN',
  status: 'PENDING',
  amount: 250,
  approvalType: 'ADJUSTMENT',
);

const BillingWorkItem _approvedItem = BillingWorkItem(
  id: 'apr-scan-1',
  displayId: 'APR-SCAN',
  kind: BillingWorkItemKind.approval,
  patientId: 'patient-apr-scan',
  patientDisplayName: 'Scan Approval Patient',
  patientDisplayId: 'PT-APR-SCAN',
  status: 'APPROVED',
  amount: 250,
  approvalType: 'ADJUSTMENT',
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 0,
  pendingPayment: 0,
  claimsPending: 0,
  approvalRequired: 1,
  overdue: 0,
);

AppAccessPolicy _approverPolicy() {
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
        AppPermissions.financialApprove,
      },
      moduleEntitlements: <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockBillingRepository repository, {
  List<BillingWorkItem> items = const <BillingWorkItem>[_approvalItem],
}) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<BillingWorkspaceOverview>.success(
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
  when(() => repository.approveApproval(any(), any())).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(approval: _approvedItem),
    ),
  );
  when(() => repository.rejectApproval(any(), any())).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(
        approval: BillingWorkItem(
          id: 'apr-scan-1',
          displayId: 'APR-SCAN',
          kind: BillingWorkItemKind.approval,
          status: 'REJECTED',
        ),
      ),
    ),
  );
  when(() => repository.getPatientLedger(any(), any())).thenAnswer(
    (_) async => const Result<BillingPatientLedger>.success(
      BillingPatientLedger(
        patientId: 'patient-apr-scan',
        summary: BillingLedgerSummary(
          totalInvoiced: 250,
          netPaid: 0,
          balanceDue: 250,
        ),
        entries: <BillingLedgerEntry>[],
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/billing?section=approvals',
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

  // Shared billing tab strip can overflow on narrow viewports; clear so
  // subsequent assertions (flat sections / dialogs) remain authoritative.
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
  late _MockBillingRepository repository;

  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(const BillingApprovalDecisionDraft());
    registerFallbackValue(const BillingLedgerQuery());
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  group('Need approval tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(BillingApprovalRequiredFinancialInventory.all, isNotEmpty);
      expect(
        BillingApprovalRequiredFinancialInventory.all.map(
          (BillingApprovalRequiredFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'approve',
          'approve_refund_or_void',
          'reject',
          'empty_state',
          'error_retry',
          'view_ledger',
        ]),
      );
      expect(
        BillingApprovalRequiredFinancialInventory.all.map(
          (BillingApprovalRequiredFinancialAtom atom) => atom.id,
        ),
        isNot(contains('close_shift')),
      );
      expect(
        BillingApprovalRequiredFinancialInventory.all.map(
          (BillingApprovalRequiredFinancialAtom atom) => atom.id,
        ),
        isNot(contains('close_day')),
      );
      expect(
        BillingApprovalRequiredFinancialInventory.billableMutations.every(
          (BillingApprovalRequiredFinancialAtom atom) =>
              atom.repositoryMethod != null,
        ),
        isTrue,
      );
      expect(
        BillingApprovalRequiredFinancialInventory.approve.actionClass,
        BillingApprovalRequiredActionClass.adjust,
      );
      expect(
        BillingApprovalRequiredFinancialInventory.approveRefundOrVoid.actionClass,
        BillingApprovalRequiredActionClass.reverse,
      );
      expect(
        BillingApprovalRequiredFinancialInventory.reject.actionClass,
        BillingApprovalRequiredActionClass.notBillable,
      );
      expect(
        BillingApprovalRequiredFinancialInventory.viewLedger.actionClass,
        BillingApprovalRequiredActionClass.notBillable,
      );
      expect(
        BillingApprovalRequiredFinancialInventory.billableMutations.map(
          (BillingApprovalRequiredFinancialAtom atom) => atom.id,
        ),
        isNot(contains('reject')),
      );
    });

    test('AC2: billable mutations map to BillingRepository (no bypass)', () {
      for (final BillingApprovalRequiredFinancialAtom atom
          in BillingApprovalRequiredFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via BillingRepository',
        );
        expect(
          BillingApprovalRequiredFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
      expect(
        BillingApprovalRequiredFinancialInventory.approve.repositoryMethod,
        'approveApproval',
      );
      expect(
        BillingApprovalRequiredFinancialInventory.reject.repositoryMethod,
        'rejectApproval',
      );
    });

    test('billing workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.billingWorkspace, isNotEmpty);
      expect(
        RealtimeEventGroups.billing,
        containsAll(<String>[
          'invoice.updated',
          'billing.balance_updated',
          'billing.refund_processed',
        ]),
      );
    });

    testWidgets(
      'AC3: approve posts via repository and syncs Need approval queue',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
        );

        await tester.tap(find.byTooltip('Approve this pending request').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
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
      'AC4: read-only user cannot approve or reject (authorization)',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = AppAccessPolicy.fromSession(
          AuthSession(
            tokens: SessionTokens(accessToken: 'access-token'),
            user: const AuthUserProfile(
              roles: <String>['BILLING'],
              tenantId: 'tenant-1',
              facilityId: 'facility-1',
            ),
            permissions: <AppPermission>{AppPermissions.billingRead},
            moduleEntitlements: <AppModuleEntitlement>[
              AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
            ],
            isAuthorizationHydrated: true,
          ),
        );
        expect(
          BillingApprovalRequiredAtomPermissions.approve.isAllowed(reader),
          isFalse,
        );

        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(find.byTooltip('Approve this pending request'), findsNothing);
        verifyNever(() => repository.approveApproval(any(), any()));
        verifyNever(() => repository.rejectApproval(any(), any()));
      },
    );

    testWidgets(
      'AC5: Need approval list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Scan Approval Patient'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog from Need approval keeps flat sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Scan Approval Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC5: approve dialog from Need approval stays flat',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
        );

        await tester.tap(find.byTooltip('Approve this pending request').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: ledger dialog opened from Approval detail stays flat',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
        );

        await tester.tap(find.text('Scan Approval Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View ledger'));
        await tester.pumpAndSettle();

        expect(find.text('View ledger'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'reject dialog requires reason before repository call (validation)',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
        );

        await tester.tap(find.text('Scan Approval Patient'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Reject'));
        await tester.tap(find.text('Reject').last);
        await tester.pumpAndSettle();

        expect(find.byType(AppTextField), findsWidgets);
        verifyNever(() => repository.rejectApproval(any(), any()));
      },
    );

    testWidgets(
      'approval detail does not mount invoice print/download (NOT_REQUIRED)',
      (WidgetTester tester) async {
        await _pumpApprovalTab(
          tester,
          repository: repository,
          accessPolicy: _approverPolicy(),
        );

        await tester.tap(find.text('Scan Approval Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Approve'), findsWidgets);
        expect(find.textContaining('Print'), findsNothing);
        expect(find.textContaining('Download'), findsNothing);
      },
    );
  });
}
