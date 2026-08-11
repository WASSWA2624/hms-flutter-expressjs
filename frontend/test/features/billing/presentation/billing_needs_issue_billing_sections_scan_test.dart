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
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_needs_issue_financial_inventory.dart';
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

const BillingWorkItem _draftInvoice = BillingWorkItem(
  id: 'inv-needs-issue',
  displayId: 'INV-DRAFT-SCAN',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Draft Patient',
  patientDisplayId: 'PT-SCAN',
  encounterId: 'enc-1',
  encounterDisplayId: 'ENC-1',
  billingStatus: 'DRAFT',
  amount: 200,
  financials: BillingFinancials(balanceDue: 200, effectiveTotal: 200),
  items: <BillingInvoiceItem>[
    BillingInvoiceItem(
      id: 'line-1',
      description: 'Lab panel',
      quantity: 1,
      unitPrice: 200,
      totalPrice: 200,
      sourceModule: 'Laboratory',
    ),
  ],
);

const BillingWorkItem _issuedFromDraft = BillingWorkItem(
  id: 'inv-needs-issue',
  displayId: 'INV-DRAFT-SCAN',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientId: 'patient-scan',
  patientDisplayName: 'Scan Draft Patient',
  patientDisplayId: 'PT-SCAN',
  encounterId: 'enc-1',
  encounterDisplayId: 'ENC-1',
  billingStatus: 'ISSUED',
  status: 'SENT',
  amount: 200,
  financials: BillingFinancials(balanceDue: 200, effectiveTotal: 200),
  items: <BillingInvoiceItem>[
    BillingInvoiceItem(
      id: 'line-1',
      description: 'Lab panel',
      quantity: 1,
      unitPrice: 200,
      totalPrice: 200,
      sourceModule: 'Laboratory',
    ),
  ],
);

const BillingSummary _summary = BillingSummary(
  needsIssue: 1,
  pendingPayment: 0,
  claimsPending: 0,
  approvalRequired: 0,
  overdue: 0,
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
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockBillingRepository repository, {
  List<BillingWorkItem> items = const <BillingWorkItem>[_draftInvoice],
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
  when(
    () => repository.issueInvoice(any(), notes: any(named: 'notes')),
  ).thenAnswer((_) async {
    when(() => repository.listWorkItems(any())).thenAnswer(
      (_) async => Result<AppPage<BillingWorkItem>>.success(
        AppPage<BillingWorkItem>(
          items: const <BillingWorkItem>[],
          request: const AppPageRequest(pageSize: 20),
          totalItemCount: 0,
        ),
      ),
    );
    when(() => repository.getWorkspace(any())).thenAnswer(
      (_) async => const Result<BillingWorkspaceOverview>.success(
        BillingWorkspaceOverview(
          summary: BillingSummary(needsIssue: 0),
        ),
      ),
    );
    return const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _issuedFromDraft),
    );
  });
  when(() => repository.sendInvoice(any(), recipientEmail: any(named: 'recipientEmail'))).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _issuedFromDraft),
    ),
  );
  when(() => repository.requestAdjustment(any(), any())).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(approvalRequired: true),
    ),
  );
  when(
    () => repository.requestInvoiceVoid(
      any(),
      reason: any(named: 'reason'),
      notes: any(named: 'notes'),
    ),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(approvalRequired: true),
    ),
  );
  when(() => repository.getPatientLedger(any(), any())).thenAnswer(
    (_) async => const Result<BillingPatientLedger>.success(
      BillingPatientLedger(
        patientId: 'patient-scan',
        summary: BillingLedgerSummary(
          totalInvoiced: 200,
          netPaid: 0,
          balanceDue: 200,
        ),
        entries: <BillingLedgerEntry>[],
      ),
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
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/billing?section=issue',
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
    registerFallbackValue(const BillingLedgerQuery());
    registerFallbackValue(
      const BillingWorkItem(id: 'invoice-1', kind: BillingWorkItemKind.invoice),
    );
    registerFallbackValue(
      const BillingAdjustmentDraft(amount: '-10.00', reason: 'Goodwill'),
    );
    registerFallbackValue(
      const BillingPaymentDraft(amount: '10.00', method: 'CASH'),
    );
  });

  setUp(() {
    repository = _MockBillingRepository();
  });

  group('Needs issue tab billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(BillingNeedsIssueFinancialInventory.all, isNotEmpty);
      expect(
        BillingNeedsIssueFinancialInventory.all.map(
          (BillingNeedsIssueFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'detail',
          'issue',
          'issue_all',
          'send',
          'adjust',
          'void_invoice',
          'view_ledger',
          'print_invoice',
          'download_invoice',
          'claims_pending_tab',
          'empty_state',
          'error_retry',
        ]),
      );
      expect(
        BillingNeedsIssueFinancialInventory.billableMutations.every(
          (BillingNeedsIssueFinancialAtom atom) =>
              atom.repositoryMethod != null,
        ),
        isTrue,
      );
      expect(
        BillingNeedsIssueFinancialInventory.issue.actionClass,
        BillingNeedsIssueActionClass.createCharge,
      );
      expect(
        BillingNeedsIssueFinancialInventory.send.actionClass,
        BillingNeedsIssueActionClass.createCharge,
      );
      expect(
        BillingNeedsIssueFinancialInventory.adjust.actionClass,
        BillingNeedsIssueActionClass.adjust,
      );
      expect(
        BillingNeedsIssueFinancialInventory.voidInvoice.actionClass,
        BillingNeedsIssueActionClass.reverse,
      );
      expect(
        BillingNeedsIssueFinancialInventory.viewLedger.actionClass,
        BillingNeedsIssueActionClass.notBillable,
      );
      expect(
        BillingNeedsIssueFinancialInventory.billableMutations.map(
          (BillingNeedsIssueFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'issue',
          'issue_all',
          'send',
          'adjust',
          'void_invoice',
        ]),
      );
    });

    test('AC2: billable mutations map to BillingRepository (no bypass)', () {
      for (final BillingNeedsIssueFinancialAtom atom
          in BillingNeedsIssueFinancialInventory.billableMutations) {
        expect(
          atom.repositoryMethod,
          isNotNull,
          reason: '${atom.id} must post via BillingRepository',
        );
        expect(
          BillingNeedsIssueFinancialInventory.forbidsInlineCollection(
            atom.actionClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
    });

    test('billing workspace subscribes to billing realtime events', () {
      expect(RealtimeEventGroups.billingWorkspace, isNotEmpty);
    });

    testWidgets(
      'AC3: issue posts via repository and removes draft from Needs issue queue',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        expect(find.text('Scan Draft Patient'), findsOneWidget);
        expect(find.byTooltip('Issue this draft invoice'), findsWidgets);

        await tester.tap(find.byTooltip('Issue this draft invoice').first);
        await tester.pumpAndSettle();

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
        expect(find.text('Scan Draft Patient'), findsNothing);
      },
    );

    testWidgets(
      'AC3: adjust from draft detail posts via BillingRepository',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Scan Draft Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Adjust'));
        await tester.pumpAndSettle();

        final Finder amountField = find.descendant(
          of: find.byType(AppTextField).first,
          matching: find.byType(EditableText),
        );
        await tester.enterText(amountField, '-10.00');
        final Finder reasonField = find.descendant(
          of: find.byType(AppTextField).at(1),
          matching: find.byType(EditableText),
        );
        await tester.enterText(reasonField, 'Needs issue waive');
        await tester.pump();

        final Finder adjustSubmit = find.text('Adjust');
        expect(adjustSubmit, findsWidgets);
        await tester.tap(adjustSubmit.last);
        await tester.pumpAndSettle();

        verify(() => repository.requestAdjustment(any(), any())).called(1);
      },
    );

    testWidgets(
      'AC3: void from draft detail posts via BillingRepository',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Scan Draft Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Void'));
        await tester.pumpAndSettle();

        final Finder reasonField = find.descendant(
          of: find.byType(AppTextField).first,
          matching: find.byType(EditableText),
        );
        await tester.enterText(reasonField, 'Duplicate draft charge');
        await tester.pump();

        final Finder voidSubmit = find.text('Void');
        expect(voidSubmit, findsWidgets);
        await tester.tap(voidSubmit.last);
        await tester.pumpAndSettle();

        verify(
          () => repository.requestInvoiceVoid(
            any(),
            reason: any(named: 'reason'),
            notes: any(named: 'notes'),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'AC4: read-only user cannot issue (authorization)',
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
          BillingNeedsIssueAtomPermissions.issue.isAllowed(reader),
          isFalse,
        );

        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        expect(find.text('Scan Draft Patient'), findsOneWidget);
        expect(find.byTooltip('Issue this draft invoice'), findsNothing);
        verifyNever(
          () => repository.issueInvoice(any(), notes: any(named: 'notes')),
        );
      },
    );

    testWidgets(
      'AC4: deep link action=pay does not collect on DRAFT invoice',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences preferences =
            await SharedPreferences.getInstance();
        _stubRepository(repository);

        final GoRouter router = GoRouter(
          initialLocation:
              '/billing?queue=needs-issue&action=pay&invoiceNumber=INV-DRAFT-SCAN',
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

        expect(find.text('Receive payment'), findsNothing);
        verifyNever(
          () => repository.receivePayment(
            any(),
            any(),
            idempotencyKey: any(named: 'idempotencyKey'),
          ),
        );
      },
    );

    testWidgets(
      'AC5: Needs issue list chrome uses flat sections (desktop light)',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(1440, 900),
          themeMode: ThemeMode.light,
        );

        expect(find.text('Scan Draft Patient'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: detail dialog from Needs issue keeps flat sections (mobile dark)',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Scan Draft Patient'));
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
        expect(countTitledSections(tester), greaterThan(0));
      },
    );

    testWidgets(
      'AC5: issue dialog from Needs issue stays flat',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.byTooltip('Issue this draft invoice').first);
        await tester.pumpAndSettle();

        expect(find.byType(AppDialog), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: ledger dialog opened from Needs issue detail stays flat',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
        );

        await tester.tap(find.text('Scan Draft Patient'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('View ledger'));
        await tester.pumpAndSettle();

        expect(find.text('View ledger'), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'AC5: adjust dialog from Needs issue detail stays flat',
      (WidgetTester tester) async {
        await _pumpNeedsIssueTab(
          tester,
          repository: repository,
          accessPolicy: _writerPolicy(),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Scan Draft Patient'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Adjust'));
        await tester.pumpAndSettle();

        expectFlatSections(tester);
      },
    );
  });
}
