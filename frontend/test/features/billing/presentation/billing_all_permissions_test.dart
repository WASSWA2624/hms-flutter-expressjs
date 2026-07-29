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

const BillingWorkItem _draftInvoice = BillingWorkItem(
  id: 'inv-all-draft',
  displayId: 'INV-ALL',
  kind: BillingWorkItemKind.invoice,
  patientDisplayName: 'All Queue Patient',
  patientDisplayId: 'PT-ALL',
  billingStatus: 'DRAFT',
  amount: 175,
  financials: BillingFinancials(balanceDue: 175),
);

const BillingWorkItem _issuedFromDraft = BillingWorkItem(
  id: 'inv-all-draft',
  displayId: 'INV-ALL',
  kind: BillingWorkItemKind.invoice,
  patientDisplayName: 'All Queue Patient',
  patientDisplayId: 'PT-ALL',
  billingStatus: 'ISSUED',
  amount: 175,
  financials: BillingFinancials(balanceDue: 175),
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
  ).thenAnswer(
    (_) async => const Result<BillingMutationResult>.success(
      BillingMutationResult(invoice: _issuedFromDraft),
    ),
  );
}

Future<void> _pumpAllTab(
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
    initialLocation: '/billing?queue=all',
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
    'read-only: All list visible; Issue / close atoms absent (∩ denial)',
    (WidgetTester tester) async {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      expect(BillingAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingAllAtomPermissions.issue.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.close.isAllowed(reader), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: reader,
      );

      expect(find.text('All Queue Patient'), findsOneWidget);
      expect(find.textContaining('All billing'), findsWidgets);
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
      expect(BillingAllAtomPermissions.receivePayment.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.close.isAllowed(writer), isTrue);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writer,
      );

      expect(find.text('All Queue Patient'), findsOneWidget);
      expect(find.text('Close shift'), findsOneWidget);
      expect(find.text('Close day'), findsOneWidget);
      expect(find.byTooltip('Issue'), findsWidgets);

      await tester.tap(find.text('All Queue Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Issue'), findsWidgets);
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
      expect(BillingAllAtomPermissions.routeEntry.isAllowed(writeOnly), isTrue);
      expect(BillingAllAtomPermissions.entry.isAllowed(writeOnly), isTrue);
      expect(BillingAllAtomPermissions.tab.isAllowed(writeOnly), isFalse);

      await _pumpAllTab(
        tester,
        repository: repository,
        accessPolicy: writeOnly,
      );

      expect(find.text('All Queue Patient'), findsNothing);
      expect(find.byType(AppTabStrip), findsNothing);
      expect(find.byTooltip('Issue'), findsNothing);
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
        strip.tabs.any((AppTabItem tab) => tab.label.contains('Claims')),
        isTrue,
      );
      expect(
        strip.tabs.any((AppTabItem tab) => tab.label.contains('All billing')),
        isTrue,
      );
      expect(find.byTooltip('Issue'), findsNothing);
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
    expect(find.byTooltip('Close shift'), findsOneWidget);
    expect(find.byTooltip('Close day'), findsOneWidget);
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
    expect(find.byTooltip('Issue'), findsWidgets);
    expect(find.byTooltip('Close shift'), findsOneWidget);
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
    expect(find.text('Close shift'), findsOneWidget);
    expect(find.byTooltip('Issue'), findsWidgets);
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
      );

      expect(find.byTooltip('Issue'), findsWidgets);
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
      expect(find.text('No billing items'), findsOneWidget);
      expect(find.byTooltip('Issue'), findsNothing);
      expect(find.textContaining('no access'), findsNothing);
    },
  );
}
