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

const BillingWorkItem _pendingInvoice = BillingWorkItem(
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

const BillingWorkItem _partiallyPaid = BillingWorkItem(
  id: 'inv-pay',
  displayId: 'INV-PAY',
  kind: BillingWorkItemKind.invoice,
  tenantId: 'tenant-1',
  patientDisplayName: 'Ben Payment',
  patientDisplayId: 'PT-PAY',
  billingStatus: 'PARTIAL',
  amount: 500,
  financials: BillingFinancials(balanceDue: 250, netPaidTotal: 250),
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
  when(() => repository.listWorkItems(any())).thenAnswer((_) async {
    return const Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[_pendingInvoice],
        request: AppPageRequest(pageSize: 20),
        totalItemCount: 1,
      ),
    );
  });
  when(
    () => repository.receivePayment(any(), any()),
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _partiallyPaid),
    ),
  );
}

Future<void> _pumpAwaitingPaymentTab(
  WidgetTester tester, {
  required _MockBillingRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/billing?queue=awaiting-payment',
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
    'read-only: Awaiting payment list visible; payment / close atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingAwaitingPaymentAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BillingAwaitingPaymentAtomPermissions.receivePayment.isAllowed(reader),
        isFalse,
      );

      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.text('Awaiting payment'), findsWidgets);
      expect(find.text('Close shift'), findsNothing);
      expect(find.text('Close day'), findsNothing);
      expect(find.byTooltip('Receive payment'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('Next action'),
        ),
        findsNothing,
      );
      expect(find.text('Claims pending'), findsNothing);
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
        BillingAwaitingPaymentAtomPermissions.receivePayment.isAllowed(writer),
        isTrue,
      );
      expect(BillingAwaitingPaymentAtomPermissions.adjust.isAllowed(writer), isTrue);
      expect(BillingAwaitingPaymentAtomPermissions.send.isAllowed(writer), isTrue);
      expect(
        BillingAwaitingPaymentAtomPermissions.voidInvoice.isAllowed(writer),
        isTrue,
      );

      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);
      expect(find.byTooltip('Receive payment'), findsWidgets);

      await tester.tap(find.text('Ben Payment'));
      await tester.pumpAndSettle();

      expect(find.text('Receive payment'), findsWidgets);
      expect(find.text('Adjust'), findsWidgets);
      expect(find.text('Send'), findsWidgets);
      expect(find.text('Void'), findsWidgets);
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
        BillingAwaitingPaymentAtomPermissions.routeEntry.isAllowed(writeOnly),
        isTrue,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.tab.isAllowed(writeOnly),
        isFalse,
      );

      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('Ben Payment'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Receive payment'), findsNothing);
    },
  );

  testWidgets(
    'subscription strip: billing-payments missing omits Awaiting payment chrome',
    (WidgetTester tester) async {
      await _pumpAwaitingPaymentTab(
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
      expect(find.text('Ben Payment'), findsNothing);
      expect(find.text('Close shift'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );

  testWidgets(
    'nested cross-module: insurance restores Claims pending on Awaiting payment strip',
    (WidgetTester tester) async {
      await _pumpAwaitingPaymentTab(
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
        strip.tabs.any(
          (AppTabItem tab) => tab.label.contains('Awaiting payment'),
        ),
        isTrue,
      );
      expect(find.byTooltip('Receive payment'), findsNothing);
    },
  );

  testWidgets('mobile viewport keeps authorized Awaiting payment chrome', (
    WidgetTester tester,
  ) async {
    await _pumpAwaitingPaymentTab(
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

  testWidgets('desktop viewport keeps authorized Awaiting payment row readable', (
    WidgetTester tester,
  ) async {
    await _pumpAwaitingPaymentTab(
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

    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byTooltip('Receive payment'), findsWidgets);
    expect(find.byTooltip('Close shift'), findsOneWidget);
  });

  testWidgets('dark theme: authorized Awaiting payment chrome remains', (
    WidgetTester tester,
  ) async {
    await _pumpAwaitingPaymentTab(
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

    expect(find.text('Ben Payment'), findsOneWidget);
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Receive payment'), findsWidgets);
  });

  testWidgets(
    'authorized Receive payment next-action opens nested dialog (sync path)',
    (WidgetTester tester) async {
      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      await tester.tap(find.byTooltip('Receive payment').first);
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsWidgets);
      expect(find.text('Receive payment'), findsWidgets);
    },
  );

  testWidgets(
    'write without financial:approve keeps collections; approve atoms stay absent',
    (WidgetTester tester) async {
      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
      );

      expect(find.byTooltip('Receive payment'), findsWidgets);
      expect(find.byTooltip('Approve'), findsNothing);
      expect(
        BillingAwaitingPaymentAtomPermissions.approve.isAllowed(
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
    'pending-payment queue slug keeps authorized Receive payment (integration)',
    (WidgetTester tester) async {
      await _pumpAwaitingPaymentTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        ),
        initialLocation: '/billing?queue=pending-payment',
      );

      expect(find.text('Ben Payment'), findsOneWidget);
      expect(find.byTooltip('Receive payment'), findsWidgets);
      expect(find.text('Close shift'), findsOneWidget);
    },
  );
}
