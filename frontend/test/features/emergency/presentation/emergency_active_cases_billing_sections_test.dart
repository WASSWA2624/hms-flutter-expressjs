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
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_active_cases_billing_inventory.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyHandoffOutcome _deferredHandoff = EmergencyHandoffOutcome(
  destination: 'IPD',
  route: 'ipd',
  receivingDisplayId: 'ADM-ACTIVE-1',
  admissionDisplayId: 'ADM-ACTIVE-1',
  stage: 'ADMITTED',
  billingDeferred: true,
  billingPaymentStatus: 'PENDING',
  billingInvoiceId: 'inv-deferred-1',
);

const EmergencyCaseSummary _activeCase = EmergencyCaseSummary(
  id: 'EME-ACTIVE-BILL-1',
  displayId: 'EME-ACTIVE-BILL-1',
  patientId: 'PAT-ACTIVE-BILL-1',
  patientDisplayId: 'PAT-ACTIVE-BILL-1',
  patientDisplayName: 'Active Billing Patient',
  severity: 'HIGH',
  status: 'OPEN',
  handoff: _deferredHandoff,
);

const EmergencyCaseDetail _activeDetail = EmergencyCaseDetail(
  summary: _activeCase,
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['NURSE'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
          modules ??
          <AppModuleEntitlement>[
            const AppModuleEntitlement(
              code: 'scheduling-queue',
              licenseStatus: 'ACTIVE',
            ),
            if (needsBilling)
              const AppModuleEntitlement(
                code: 'billing-payments',
                licenseStatus: 'ACTIVE',
              ),
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_activeCase],
  EmergencyCaseDetail detail = _activeDetail,
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((invocation) {
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Future<Result<AppPage<EmergencyCaseSummary>>>.value(
      Result<AppPage<EmergencyCaseSummary>>.success(
        AppPage<EmergencyCaseSummary>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_activeCase],
  EmergencyCaseDetail detail = _activeDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=active',
    routes: <RouteBase>[
      GoRoute(
        path: '/emergency',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: EmergencyWorkspacePage(
              initialQuery: EmergencyWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Billing workspace'));
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emergencyRepositoryProvider.overrideWithValue(repository),
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockEmergencyRepository repository;

  setUp(() {
    repository = _MockEmergencyRepository();
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(const EmergencyCaseSummary(id: 'fallback'));
  });

  group('Emergency Active cases billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(EmergencyActiveCasesBillingInventory.all, isNotEmpty);
      for (final EmergencyActiveCasesFinancialAtom atom
          in EmergencyActiveCasesBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass ==
                EmergencyActiveCasesFinancialClass.createCharge ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.settle ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.adjust ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.reverse ||
            atom.financialClass == EmergencyActiveCasesFinancialClass.defer;
        if (billable && atom.mounted) {
          expect(
            atom.billingPath,
            isNotNull,
            reason: '${atom.id} must declare billingPath',
          );
        }
        if (!billable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} must declare NOT_* audit code',
          );
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      for (final EmergencyActiveCasesFinancialAtom atom
          in EmergencyActiveCasesBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('consultation'),
            contains('admission'),
            contains('theatre'),
            contains('ambulance'),
          ),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(EmergencyActiveCasesBillingInventory.collectPayment.mounted, isFalse);
      expect(EmergencyActiveCasesBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        EmergencyActiveCasesBillingInventory.forbidsInlineCashier(
          EmergencyActiveCasesFinancialClass.settle,
        ),
        isTrue,
      );
    });
  });

  group('Emergency Active cases billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.emergencyRead},
          ),
        );

        expect(find.text('Active Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text(EmergencyText.openBilling), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Active Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing and deferred status parity',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Active Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsWidgets);
        expect(find.textContaining('Pending'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(
          canOpenEmergencyBilling(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.emergencyRead,
                AppPermissions.billingRead,
              },
            ),
          ),
          isTrue,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        ),
      );

      expect(find.text(EmergencyText.activeCases), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('Emergency Active cases section layout (AC5)', () {
    testWidgets('desktop Active: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Active Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(find.text(EmergencyText.handoffOutcome), findsOneWidget);
    });

    testWidgets('mobile Active: flat sections', (WidgetTester tester) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.billingRead,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Active Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.billingRead,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Active Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Emergency Active cases UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        ),
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.text(EmergencyText.activeCases), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
