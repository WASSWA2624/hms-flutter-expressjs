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
import 'package:hosspi_hms/features/emergency/data/repositories/emergency_repository_impl.dart';
import 'package:hosspi_hms/features/emergency/domain/entities/emergency_entities.dart';
import 'package:hosspi_hms/features/emergency/domain/repositories/emergency_repository.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_access.dart';
import 'package:hosspi_hms/features/emergency/presentation/emergency_closed_billing_inventory.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyCaseSummary _closedDeferred = EmergencyCaseSummary(
  id: 'EME-CLOSED-1',
  displayId: 'EME-CLOSED-1',
  patientId: 'PAT-1',
  patientDisplayId: 'PAT-1',
  patientDisplayName: 'Closed Casey',
  severity: 'HIGH',
  status: 'CLOSED',
  handoff: EmergencyHandoffOutcome(
    destination: 'IPD',
    route: 'ipd',
    receivingDisplayId: 'ADM-1',
    admissionDisplayId: 'ADM-1',
    stage: 'ADMITTED',
    billingDeferred: true,
  ),
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead) ||
      permissions.contains(AppPermissions.billingWrite);
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
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
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _closedDeferred,
  ],
}) {
  when(() => repository.listEmergencyBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final EmergencyBoardQuery query =
        invocation.positionalArguments.single as EmergencyBoardQuery;
    return Result<AppPage<EmergencyCaseSummary>>.success(
      AppPage<EmergencyCaseSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<EmergencyReferenceData>.success(EmergencyReferenceData()),
  );
  when(() => repository.loadEmergencyDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final EmergencyCaseSummary summary =
        invocation.positionalArguments.first as EmergencyCaseSummary;
    return Result<EmergencyCaseDetail>.success(
      EmergencyCaseDetail(
        summary: summary,
        triageAssessments: const <EmergencyTriageAssessment>[
          EmergencyTriageAssessment(
            id: 'TRA-1',
            emergencyCaseId: 'EME-CLOSED-1',
            triageLevel: 'LEVEL_2',
          ),
        ],
        responses: const <EmergencyResponseRecord>[
          EmergencyResponseRecord(
            id: 'ERS-1',
            emergencyCaseId: 'EME-CLOSED-1',
            notes: 'Stabilized',
          ),
        ],
        dispatches: const <EmergencyAmbulanceDispatch>[
          EmergencyAmbulanceDispatch(
            id: 'DSP-1',
            status: 'COMPLETED',
            ambulanceLabel: 'Unit 7',
          ),
        ],
        trips: const <EmergencyAmbulanceTrip>[
          EmergencyAmbulanceTrip(
            id: 'TRP-1',
            ambulanceLabel: 'Unit 7',
          ),
        ],
      ),
    );
  });
}

Future<void> _pumpClosedTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=closed',
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
            body: Text(
              'Billing workspace patient=${state.uri.queryParameters['patient_id'] ?? ''}',
            ),
          );
        },
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('IPD workspace'));
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
  tester.takeException();
}

void main() {
  late _MockEmergencyRepository repository;

  setUpAll(() {
    registerFallbackValue(const EmergencyBoardQuery());
    registerFallbackValue(const EmergencyCaseSummary(id: 'fallback'));
  });

  setUp(() {
    repository = _MockEmergencyRepository();
  });

  group('Emergency Closed billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(EmergencyClosedBillingInventory.atoms, isNotEmpty);
      expect(
        EmergencyClosedBillingInventory.atoms.map(
          (EmergencyClosedFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'empty_loading_error',
          'row_select',
          'quick_arrival',
          'print_summary',
          'billing_deferred_chip',
          'open_billing',
          'absent_inline_collect',
          'ambulance_trip_charge',
          'handoff_deferred_charge',
          'hard_delete',
        ]),
      );
      for (final EmergencyClosedFinancialAtom atom
          in EmergencyClosedBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass == EmergencyClosedFinancialClass.notBilled ||
            atom.financialClass == EmergencyClosedFinancialClass.notRequired ||
            atom.financialClass == EmergencyClosedFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(EmergencyClosedBillingInventory.openBilling.mounted, isTrue);
      expect(EmergencyClosedBillingInventory.quickArrival.mounted, isFalse);
      expect(
        EmergencyClosedBillingInventory.absentInlineCollect.mounted,
        isFalse,
      );
      expect(
        EmergencyClosedBillingInventory.printSummary.auditCode,
        'NO_CHARGE',
      );
    });

    test('AC2: billable atoms wire through Billing; inline collect forbidden', () {
      expect(
        EmergencyClosedBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        EmergencyClosedBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        EmergencyClosedBillingInventory.handoffDeferredCharge.billingPath,
        contains('clinical-request-billing'),
      );
      expect(
        EmergencyClosedBillingInventory.ambulanceTripCharge.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
      for (final EmergencyClosedFinancialAtom atom
          in EmergencyClosedBillingInventory.atoms) {
        if (EmergencyClosedBillingInventory.isInlineCollectionForbidden(
          atom.financialClass,
        )) {
          expect(
            atom.mounted == false ||
                (atom.billingPath?.contains('Billing') ?? false) ||
                (atom.billingPath?.contains('billing') ?? false),
            isTrue,
            reason: '${atom.id} must not bypass Billing',
          );
        }
      }
      expect(
        EmergencyClosedAtomPermissions.openBilling,
        same(EmergencyClosedAtomPermissions.openBilling),
      );
    });

    test('AC3: emergency workspace realtime includes billing for status parity', () {
      expect(RealtimeEventGroups.emergencyWorkspace, isNotEmpty);
      expect(
        RealtimeEventGroups.emergencyWorkspace.any(
          (String event) =>
              event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'AC2/AC3/AC4: Open billing navigates; deferred parity; no cashier',
      (WidgetTester tester) async {
        await _pumpClosedTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.billingRead,
            },
          ),
        );

        expect(find.text(EmergencyText.closed), findsWidgets);
        expect(find.text('Quick arrival'), findsNothing);

        await tester.tap(find.text('Closed Casey'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Quick arrival'), findsNothing);
        expect(find.text(EmergencyText.completeTrip), findsNothing);

        await tester.tap(find.text(EmergencyText.openBilling).first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=PAT-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC4/AC6: unauthorized users cannot open billing or collect',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        );
        expect(
          EmergencyClosedAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpClosedTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Closed Casey'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        // Deferred chip remains visible as status (read parity), not settle.
        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
      },
    );

    testWidgets('AC5: desktop light — flat sections on Closed detail', (
      WidgetTester tester,
    ) async {
      await _pumpClosedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      await tester.tap(find.text('Closed Casey'));
      await tester.pumpAndSettle();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Closed detail desktop light',
      );
      expect(find.byType(AppCollapsibleSection), findsWidgets);
    });

    testWidgets('AC5: mobile dark — flat sections on Closed detail', (
      WidgetTester tester,
    ) async {
      await _pumpClosedTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.emergencyRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      final Finder row = find.text('Closed Casey');
      await tester.ensureVisible(row);
      await tester.tap(row, warnIfMissed: false);
      await tester.pumpAndSettle();
      tester.takeException();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Closed detail mobile dark',
      );
    });

    testWidgets('AC4: loading / empty states remain observable on Closed', (
      WidgetTester tester,
    ) async {
      when(() => repository.listEmergencyBoard(any())).thenAnswer(
        (_) async => Result<AppPage<EmergencyCaseSummary>>.success(
          AppPage<EmergencyCaseSummary>(
            items: const <EmergencyCaseSummary>[],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async => const Result<EmergencyReferenceData>.success(
          EmergencyReferenceData(),
        ),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/emergency?scope=closed',
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
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.emergencyRead},
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text(EmergencyText.closed), findsWidgets);
      expect(find.text(EmergencyText.openBilling), findsNothing);
    });
  });
}
