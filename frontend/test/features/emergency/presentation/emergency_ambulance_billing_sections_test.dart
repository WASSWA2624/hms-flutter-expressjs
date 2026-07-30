import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_ambulance_billing_inventory.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyAmbulanceDispatch _dispatch = EmergencyAmbulanceDispatch(
  id: 'ADS-AMB-BILL-1',
  displayId: 'ADS-AMB-BILL-1',
  emergencyCaseId: 'EME-AMB-BILL-1',
  ambulanceId: 'AMB-1',
  ambulanceDisplayId: 'AMB-1',
  ambulanceLabel: 'Ambulance 1',
  status: 'DISPATCHED',
);

const EmergencyAmbulanceTrip _completedTrip = EmergencyAmbulanceTrip(
  id: 'TRP-AMB-BILL-1',
  displayId: 'TRP-AMB-BILL-1',
  emergencyCaseId: 'EME-AMB-BILL-1',
  ambulanceId: 'AMB-1',
  ambulanceLabel: 'Ambulance 1',
  startedAt: null,
  endedAt: null,
  billingDeferred: true,
  billingPaymentStatus: 'PENDING',
  billingInvoiceId: 'inv-amb-1',
);

const EmergencyCaseSummary _ambulanceCase = EmergencyCaseSummary(
  id: 'EME-AMB-BILL-1',
  displayId: 'EME-AMB-BILL-1',
  patientId: 'patient-uuid-amb',
  patientDisplayId: 'PAT-AMB-BILL-1',
  patientDisplayName: 'Ambulance Billing Patient',
  severity: 'HIGH',
  status: 'OPEN',
  latestDispatch: _dispatch,
  activeTrip: EmergencyAmbulanceTrip(
    id: 'TRP-AMB-ACTIVE',
    ambulanceId: 'AMB-1',
    ambulanceLabel: 'Ambulance 1',
  ),
);

const EmergencyCaseSummary _deferredCase = EmergencyCaseSummary(
  id: 'EME-AMB-BILL-2',
  displayId: 'EME-AMB-BILL-2',
  patientId: 'patient-uuid-amb-2',
  patientDisplayId: 'PAT-AMB-BILL-2',
  patientDisplayName: 'Deferred Trip Patient',
  severity: 'CRITICAL',
  status: 'OPEN',
  latestDispatch: _dispatch,
  handoff: EmergencyHandoffOutcome(
    destination: 'IPD',
    route: 'ipd',
    receivingDisplayId: 'ADM-AMB-1',
    billingDeferred: true,
    billingPaymentStatus: 'PENDING',
    billingInvoiceId: 'inv-handoff-amb',
  ),
);

const EmergencyCaseDetail _ambulanceDetail = EmergencyCaseDetail(
  summary: _ambulanceCase,
  dispatches: <EmergencyAmbulanceDispatch>[_dispatch],
  trips: <EmergencyAmbulanceTrip>[
    EmergencyAmbulanceTrip(
      id: 'TRP-AMB-BILL-1',
      displayId: 'TRP-AMB-BILL-1',
      ambulanceId: 'AMB-1',
      ambulanceLabel: 'Ambulance 1',
      endedAt: null,
      billingDeferred: true,
      billingPaymentStatus: 'PENDING',
      billingInvoiceId: 'inv-amb-1',
    ),
  ],
);

const EmergencyCaseDetail _deferredDetail = EmergencyCaseDetail(
  summary: _deferredCase,
  dispatches: <EmergencyAmbulanceDispatch>[_dispatch],
  trips: <EmergencyAmbulanceTrip>[_completedTrip],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
  final bool needsOperations = permissions.contains(
    AppPermissions.operationsRead,
  );
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['AMBULANCE_OPERATOR'],
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
            if (needsOperations)
              const AppModuleEntitlement(
                code: 'facilities-maintenance',
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
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _ambulanceCase,
  ],
  EmergencyCaseDetail detail = _ambulanceDetail,
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
    (_) async => const Result<EmergencyReferenceData>.success(
      EmergencyReferenceData(
        ambulances: <EmergencyAmbulance>[
          EmergencyAmbulance(
            id: 'AMB-1',
            displayId: 'AMB-1',
            identifier: 'Ambulance 1',
            status: 'AVAILABLE',
          ),
        ],
      ),
    ),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((invocation) {
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.single as EmergencyCaseSummary;
    if (summary.id == _deferredCase.id) {
      return Future<Result<EmergencyCaseDetail>>.value(
        const Result<EmergencyCaseDetail>.success(_deferredDetail),
      );
    }
    if (summary.id == _ambulanceCase.id) {
      return Future<Result<EmergencyCaseDetail>>.value(
        const Result<EmergencyCaseDetail>.success(_ambulanceDetail),
      );
    }
    return Future<Result<EmergencyCaseDetail>>.value(
      Result<EmergencyCaseDetail>.success(
        EmergencyCaseDetail(summary: summary),
      ),
    );
  });
}

Future<void> _pumpAmbulanceTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _ambulanceCase,
  ],
  EmergencyCaseDetail detail = _ambulanceDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=ambulance',
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

  group('Emergency Ambulance billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(EmergencyAmbulanceBillingInventory.all, isNotEmpty);
      expect(
        EmergencyAmbulanceBillingInventory.all.map(
          (EmergencyAmbulanceFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'start_trip',
          'complete_trip',
          'handoff_deferred',
          'billing_deferred_chip',
          'trip_billing_status',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(
        emergencyAmbulanceBillingScopeNote,
        contains('persistAmbulanceTripBilling'),
      );
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        EmergencyAmbulanceBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final EmergencyAmbulanceFinancialAtom atom
          in EmergencyAmbulanceBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('ambulance'),
            contains('handoff'),
            contains('admission'),
            contains('theatre'),
            contains('consultation'),
          ),
          reason: atom.id,
        );
      }
      expect(
        EmergencyAmbulanceBillingInventory.startTrip.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
      expect(
        EmergencyAmbulanceBillingInventory.completeTrip.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Ambulance', () {
      expect(EmergencyAmbulanceBillingInventory.collectPayment.mounted, isFalse);
      expect(EmergencyAmbulanceBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        EmergencyAmbulanceBillingInventory.isInlineCollectionForbidden(
          EmergencyAmbulanceFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        EmergencyAmbulanceAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
    });
  });

  group('Emergency Ambulance billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.emergencyWorkspace,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        await _pumpAmbulanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.operationsRead,
            },
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
          items: const <EmergencyCaseSummary>[_deferredCase],
          detail: _deferredDetail,
        );

        await tester.tap(find.text('Deferred Trip Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing — desktop light',
      (WidgetTester tester) async {
        await _pumpAmbulanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.operationsRead,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredCase],
          detail: _deferredDetail,
        );

        await tester.tap(find.text('Deferred Trip Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.tap(find.text(EmergencyText.openBilling).first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id=patient-uuid-amb-2'),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'trip Billing status parity surfaces on Ambulance panel',
      (WidgetTester tester) async {
        await _pumpAmbulanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Ambulance Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Ambulance'), findsWidgets);
        expect(
          find.textContaining('${EmergencyText.billingStatus}: Pending'),
          findsWidgets,
        );
        expectFlatSections(tester);
      },
    );
  });

  group('Emergency Ambulance flat sections (AC5)', () {
    testWidgets(
      'detail panels are siblings — no section-in-section',
      (WidgetTester tester) async {
        await _pumpAmbulanceTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredCase],
          detail: _deferredDetail,
        );

        await tester.tap(find.text('Deferred Trip Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.handoffOutcome), findsOneWidget);
        expect(find.text('Ambulance'), findsWidgets);
        expect(find.text('Triage and response'), findsOneWidget);
        expectFlatSections(tester);
      },
    );
  });
}
