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
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/controllers/emergency_workspace_controller.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_all_billing_inventory.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyCaseSummary _openCase = EmergencyCaseSummary(
  id: 'EME-ALL-BILL-1',
  displayId: 'EME-ALL-BILL-1',
  patientId: 'patient-uuid-1',
  patientDisplayName: 'All Billing Patient',
  patientDisplayId: 'PAT-ALL-BILL-1',
  severity: 'HIGH',
  status: 'OPEN',
);

const EmergencyCaseSummary _deferredHandoff = EmergencyCaseSummary(
  id: 'EME-ALL-BILL-2',
  displayId: 'EME-ALL-BILL-2',
  patientId: 'patient-uuid-2',
  patientDisplayName: 'Deferred Handoff Patient',
  patientDisplayId: 'PAT-ALL-BILL-2',
  severity: 'CRITICAL',
  status: 'CLOSED',
  handoff: EmergencyHandoffOutcome(
    destination: 'IPD',
    route: 'ipd',
    receivingDisplayId: 'ADM-1',
    billingDeferred: true,
    billingPaymentStatus: 'PENDING',
    billingInvoiceId: 'inv-deferred-1',
  ),
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

void _stubBoard(
  _MockEmergencyRepository repository, {
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_openCase],
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer(
    (invocation) async => Result<AppPage<EmergencyCaseSummary>>.success(
      AppPage<EmergencyCaseSummary>(
        items: items,
        request:
            (invocation.positionalArguments.single as EmergencyBoardQuery)
                .pageRequest,
        totalItemCount: items.length,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async => const Result<EmergencyReferenceData>.success(
      EmergencyReferenceData(),
    ),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((invocation) {
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.single as EmergencyCaseSummary;
    return Future<Result<EmergencyCaseDetail>>.value(
      Result<EmergencyCaseDetail>.success(
        EmergencyCaseDetail(
          summary: items.firstWhere(
            (EmergencyCaseSummary item) => item.id == summary.id,
            orElse: () => summary,
          ),
        ),
      ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[_openCase],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  String? navigatedLocation;
  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=all',
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
          navigatedLocation = state.uri.toString();
          return Scaffold(
            body: Text('Billing workspace ${state.uri.query}'),
          );
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
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  addTearDown(() {
    expect(
      navigatedLocation,
      anyOf(isNull, contains('/billing')),
      reason: 'navigation should only go to Billing when Open billing tapped',
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockEmergencyRepository repository;

  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(const EmergencyCaseSummary(id: 'fallback'));
    registerFallbackValue(
      const EmergencyCaseDetail(
        summary: EmergencyCaseSummary(id: 'fallback'),
      ),
    );
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('Emergency All billing inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(EmergencyAllBillingInventory.atoms, isNotEmpty);
      for (final EmergencyAllFinancialAtom atom
          in EmergencyAllBillingInventory.atoms) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        if (atom.financialClass == EmergencyAllFinancialClass.notBilled ||
            atom.financialClass == EmergencyAllFinancialClass.notRequired ||
            atom.financialClass == EmergencyAllFinancialClass.noCharge) {
          expect(atom.auditCode, isNotNull);
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      for (final EmergencyAllFinancialAtom atom
          in EmergencyAllBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('consultation'),
            contains('admission'),
            contains('ambulance'),
            contains('theatre'),
          ),
        );
      }
      expect(
        EmergencyAllBillingInventory.completeTrip.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
      expect(
        EmergencyAllBillingInventory.handoffOpd.billingPath,
        contains('create_consultation_invoice'),
      );
    });

    test('settle/adjust never use inline collection on this tab', () {
      expect(
        EmergencyAllBillingInventory.forbidsInlineCashier(
          EmergencyAllFinancialClass.settle,
        ),
        isTrue,
      );
      expect(EmergencyAllBillingInventory.collectPayment.mounted, isFalse);
      expect(EmergencyAllBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        EmergencyAllAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
    });
  });

  group('Emergency All billing wiring (AC2-AC4)', () {
    test('emergency workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.emergencyWorkspace,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect (no bypass)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.emergencyRead},
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
          items: const <EmergencyCaseSummary>[_deferredHandoff],
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing (reuse, no fork) — desktop light',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredHandoff],
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.tap(find.text(EmergencyText.openBilling).first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(find.textContaining('patient_id=patient-uuid-2'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'list chrome has no cashier entry points — mobile dark',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
            },
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('All Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'deferred handoff shows Billing status parity tile',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredHandoff],
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingStatus), findsOneWidget);
        expect(find.textContaining('Pending'), findsWidgets);
        expectFlatSections(tester);
      },
    );
  });

  group('Emergency All flat sections (AC5)', () {
    testWidgets(
      'detail panels are siblings — no section-in-section',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredHandoff],
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.handoffOutcome), findsOneWidget);
        expectFlatSections(tester);
      },
    );
  });
}
