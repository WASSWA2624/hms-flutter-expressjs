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
import 'package:hosspi_hms/features/billing/data/repositories/billing_price_book_repository_impl.dart';
import 'package:hosspi_hms/features/billing/data/repositories/billing_repository_impl.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_price_book_repository.dart';
import 'package:hosspi_hms/features/billing/domain/repositories/billing_repository.dart';
import 'package:hosspi_hms/features/billing/presentation/pages/billing_workspace_page.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockBillingRepository extends Mock implements BillingRepository {}

class _MockPriceBookRepository extends Mock
    implements BillingPriceBookRepository {}

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBilling(_MockBillingRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer(
    (_) async => const Result<BillingWorkspaceOverview>.success(
      BillingWorkspaceOverview(summary: BillingSummary()),
    ),
  );
  when(() => repository.listWorkItems(any())).thenAnswer(
    (_) async => const Result<AppPage<BillingWorkItem>>.success(
      AppPage<BillingWorkItem>(
        items: <BillingWorkItem>[],
        request: AppPageRequest(pageSize: 20),
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubPrices(_MockPriceBookRepository repository) {
  when(
    () => repository.listEntries(
      any(),
      tenantId: any(named: 'tenantId'),
      facilityId: any(named: 'facilityId'),
    ),
  ).thenAnswer(
    (_) async => const Result<AppPage<BillingPriceBookEntry>>.success(
      AppPage<BillingPriceBookEntry>(
        items: <BillingPriceBookEntry>[],
        request: AppPageRequest(pageSize: 100),
        totalItemCount: 0,
      ),
    ),
  );
}

Future<GoRouter> _pumpPriceBook(
  WidgetTester tester, {
  required AppAccessPolicy accessPolicy,
  String location = '/billing?section=prices',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockBillingRepository billing = _MockBillingRepository();
  final _MockPriceBookRepository prices = _MockPriceBookRepository();
  _stubBilling(billing);
  _stubPrices(prices);

  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: location,
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
        billingRepositoryProvider.overrideWithValue(billing),
        billingPriceBookRepositoryProvider.overrideWithValue(prices),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(accessPolicy),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.light,
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
  setUpAll(() {
    registerFallbackValue(const BillingWorkspaceQuery());
    registerFallbackValue(const BillingPriceBookQuery());
  });

  testWidgets('Price book tab visible; Add absent without pricing write', (
    WidgetTester tester,
  ) async {
    await _pumpPriceBook(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
    );

    expect(find.byType(BillingWorkspacePage), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(BillingPriceBookPanel), findsOneWidget);
    expect(find.text('No prices match.'), findsOneWidget);
    expect(find.byTooltip('Add'), findsNothing);
    final AppListTable<BillingPriceBookEntry> table = tester
        .widget<AppListTable<BillingPriceBookEntry>>(
          find.byType(AppListTable<BillingPriceBookEntry>),
        );
    expect(table.enablePrint, isTrue);
    expect(table.canExport, isFalse);
    expect(table.canPrint, isFalse);
    expect(find.byTooltip('Print'), findsNothing);
  });

  testWidgets('Price book export/print mount with evidence:export', (
    WidgetTester tester,
  ) async {
    await _pumpPriceBook(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.evidenceExport,
        },
      ),
    );

    final AppListTable<BillingPriceBookEntry> table = tester
        .widget<AppListTable<BillingPriceBookEntry>>(
          find.byType(AppListTable<BillingPriceBookEntry>),
        );
    expect(table.canExport, isTrue);
    expect(table.canPrint, isTrue);
    expect(find.byTooltip('Export'), findsOneWidget);
    expect(find.byTooltip('Print'), findsOneWidget);
  });

  testWidgets('Price book alias price-book selects section=prices body', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPriceBook(
      tester,
      location: '/billing?section=price-book',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.pricingFacilityWrite,
        },
      ),
    );

    expect(find.byType(BillingPriceBookPanel), findsOneWidget);
    expect(find.byTooltip('Add'), findsOneWidget);
    expect(router.state.uri.queryParameters['section'], 'prices');
  });

  testWidgets('tab=prices alias writes section=prices', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpPriceBook(
      tester,
      location: '/billing?tab=prices',
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
    );

    expect(find.byType(BillingPriceBookPanel), findsOneWidget);
    expect(router.state.uri.queryParameters['section'], 'prices');
  });

  testWidgets('Cashier Close shift/day absent on Price book', (
    WidgetTester tester,
  ) async {
    await _pumpPriceBook(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.pricingFacilityWrite,
        },
      ),
    );

    expect(find.byTooltip('Close shift'), findsNothing);
    expect(find.byTooltip('Close day'), findsNothing);
    expect(find.byTooltip('Charge'), findsNothing);
    expect(find.byTooltip('Issue all'), findsNothing);
  });

  testWidgets('Price book tooltip present for authorized readers', (
    WidgetTester tester,
  ) async {
    await _pumpPriceBook(
      tester,
      accessPolicy: _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      ),
    );

    expect(
      find.byTooltip('Service and item prices used when charging'),
      findsWidgets,
    );
  });
}
