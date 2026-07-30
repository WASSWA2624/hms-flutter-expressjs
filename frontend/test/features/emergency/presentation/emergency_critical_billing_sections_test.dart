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
import 'package:hosspi_hms/features/emergency/presentation/emergency_critical_billing_inventory.dart';
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
  id: 'ADS-CRIT-BILL-1',
  displayId: 'ADS-CRIT-BILL-1',
  emergencyCaseId: 'EME-CRIT-BILL-1',
  ambulanceId: 'AMB-1',
  ambulanceDisplayId: 'AMB-1',
  ambulanceLabel: 'Ambulance 1',
  status: 'DISPATCHED',
);

const EmergencyHandoffOutcome _deferredHandoff = EmergencyHandoffOutcome(
  destination: 'IPD',
  route: 'ipd',
  receivingDisplayId: 'ADM-CRIT-1',
  admissionDisplayId: 'ADM-CRIT-1',
  stage: 'ADMITTED',
  billingDeferred: true,
  billingPaymentStatus: 'PENDING',
  billingInvoiceId: 'inv-crit-deferred-1',
);

const EmergencyCaseSummary _criticalCase = EmergencyCaseSummary(
  id: 'EME-CRIT-BILL-1',
  displayId: 'EME-CRIT-BILL-1',
  patientId: 'patient-uuid-crit',
  patientDisplayId: 'PAT-CRIT-BILL-1',
  patientDisplayName: 'Critical Billing Patient',
  severity: 'CRITICAL',
  status: 'OPEN',
  handoff: _deferredHandoff,
  latestDispatch: _dispatch,
  activeTrip: EmergencyAmbulanceTrip(
    id: 'TRP-CRIT-ACTIVE',
    ambulanceId: 'AMB-1',
    ambulanceLabel: 'Ambulance 1',
    billingDeferred: true,
    billingPaymentStatus: 'PENDING',
    billingInvoiceId: 'inv-crit-trip-1',
  ),
);

const EmergencyCaseDetail _criticalDetail = EmergencyCaseDetail(
  summary: _criticalCase,
  dispatches: <EmergencyAmbulanceDispatch>[_dispatch],
  trips: <EmergencyAmbulanceTrip>[
    EmergencyAmbulanceTrip(
      id: 'TRP-CRIT-ACTIVE',
      ambulanceId: 'AMB-1',
      ambulanceLabel: 'Ambulance 1',
      billingDeferred: true,
      billingPaymentStatus: 'PENDING',
      billingInvoiceId: 'inv-crit-trip-1',
    ),
  ],
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
    _criticalCase,
  ],
  EmergencyCaseDetail detail = _criticalDetail,
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
  when(() => repository.loadEmergencyDetail(any())).thenAnswer(
    (_) async => Result<EmergencyCaseDetail>.success(detail),
  );
}

Future<void> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _criticalCase,
  ],
  EmergencyCaseDetail detail = _criticalDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=critical',
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
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

  group('Emergency Critical billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(EmergencyCriticalBillingInventory.all, isNotEmpty);
      expect(
        EmergencyCriticalBillingInventory.all.map(
          (EmergencyCriticalFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'critical_chip',
          'start_trip',
          'complete_trip',
          'handoff_opd',
          'handoff_ipd_icu',
          'handoff_theater',
          'billing_deferred_badge',
          'trip_billing_status',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(
        emergencyCriticalBillingScopeNote,
        contains('persistAmbulanceTripBilling'),
      );

      for (final EmergencyCriticalFinancialAtom atom
          in EmergencyCriticalBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass ==
                EmergencyCriticalFinancialClass.createCharge ||
            atom.financialClass == EmergencyCriticalFinancialClass.settle ||
            atom.financialClass == EmergencyCriticalFinancialClass.adjust ||
            atom.financialClass == EmergencyCriticalFinancialClass.reverse ||
            atom.financialClass == EmergencyCriticalFinancialClass.defer;
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

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        EmergencyCriticalBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final EmergencyCriticalFinancialAtom atom
          in EmergencyCriticalBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('consultation'),
            contains('admission'),
            contains('theatre'),
            contains('ambulance'),
            contains('handoff'),
          ),
          reason: atom.id,
        );
      }
      expect(
        EmergencyCriticalBillingInventory.completeTrip.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Critical', () {
      expect(EmergencyCriticalBillingInventory.collectPayment.mounted, isFalse);
      expect(EmergencyCriticalBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        EmergencyCriticalBillingInventory.isInlineCollectionForbidden(
          EmergencyCriticalFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        EmergencyCriticalAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
    });
  });

  group('Emergency Critical billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.emergencyWorkspace,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.emergencyRead},
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('Critical Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text(EmergencyText.openBilling), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Critical Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing — desktop light',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Critical Billing Patient'));
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

        await tester.tap(find.text(EmergencyText.openBilling).first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id=patient-uuid-crit'),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'trip Billing status parity surfaces on Critical detail',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Critical Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Ambulance'), findsWidgets);
        expect(
          find.textContaining('${EmergencyText.billingStatus}: Pending'),
          findsWidgets,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.emergencyWrite,
          },
        ),
      );

      expect(find.text(EmergencyText.critical), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('Emergency Critical section layout (AC5)', () {
    testWidgets('desktop Critical: flat sibling sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
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

      await tester.tap(find.text('Critical Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(find.text(EmergencyText.handoffOutcome), findsOneWidget);
      expect(find.text('Triage and response'), findsOneWidget);
      expect(find.text('Ambulance'), findsWidgets);
    });

    testWidgets('mobile Critical: flat sections', (WidgetTester tester) async {
      await _pumpCriticalTab(
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
      await _pumpCriticalTab(
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
      await tester.tap(find.text('Critical Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
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
      await tester.tap(find.text('Critical Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Emergency Critical UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        ),
        items: const <EmergencyCaseSummary>[],
      );

      expect(find.text(EmergencyText.critical), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
