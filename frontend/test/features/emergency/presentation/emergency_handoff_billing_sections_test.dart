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
import 'package:hosspi_hms/features/emergency/presentation/emergency_handoff_billing_inventory.dart';
import 'package:hosspi_hms/features/emergency/presentation/pages/emergency_workspace_page.dart';
import 'package:hosspi_hms/features/emergency/presentation/widgets/emergency_workspace_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockEmergencyRepository extends Mock implements EmergencyRepository {}

const EmergencyTriageAssessment _triage = EmergencyTriageAssessment(
  id: 'TRA-HO-1',
  emergencyCaseId: 'EME-HO-1',
  triageLevel: 'LEVEL_2',
);

const EmergencyResponseRecord _response = EmergencyResponseRecord(
  id: 'ERS-HO-1',
  emergencyCaseId: 'EME-HO-1',
  notes: 'Stabilized for handoff',
);

const EmergencyCaseSummary _handoffReady = EmergencyCaseSummary(
  id: 'EME-HO-1',
  displayId: 'EME-HO-1',
  patientId: 'patient-uuid-ho',
  patientDisplayId: 'PAT-HO-1',
  patientDisplayName: 'Handoff Ready Patient',
  severity: 'HIGH',
  status: 'OPEN',
  latestTriage: _triage,
  latestResponse: _response,
);

const EmergencyCaseSummary _deferredAfterHandoff = EmergencyCaseSummary(
  id: 'EME-HO-2',
  displayId: 'EME-HO-2',
  patientId: 'patient-uuid-ho-2',
  patientDisplayId: 'PAT-HO-2',
  patientDisplayName: 'Deferred Handoff Patient',
  severity: 'CRITICAL',
  status: 'OPEN',
  latestTriage: _triage,
  latestResponse: _response,
  handoff: EmergencyHandoffOutcome(
    destination: 'IPD',
    route: 'ipd',
    receivingDisplayId: 'ADM-HO-1',
    admissionDisplayId: 'ADM-HO-1',
    stage: 'ADMITTED',
    billingDeferred: true,
    billingPaymentStatus: 'PENDING',
    billingInvoiceId: 'inv-handoff-ho',
  ),
);

const EmergencyCaseDetail _handoffDetail = EmergencyCaseDetail(
  summary: _handoffReady,
  triageAssessments: <EmergencyTriageAssessment>[_triage],
  responses: <EmergencyResponseRecord>[_response],
);

const EmergencyCaseDetail _deferredDetail = EmergencyCaseDetail(
  summary: _deferredAfterHandoff,
  triageAssessments: <EmergencyTriageAssessment>[_triage],
  responses: <EmergencyResponseRecord>[_response],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
}) {
  final bool needsBilling = permissions.contains(AppPermissions.billingRead) ||
      permissions.contains(AppPermissions.billingWrite);
  final bool needsClinical = permissions.contains(AppPermissions.clinicalWrite) ||
      permissions.contains(AppPermissions.clinicalRead);
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
            if (needsClinical)
              const AppModuleEntitlement(
                code: 'encounters-vitals',
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
    _handoffReady,
  ],
  EmergencyCaseDetail detail = _handoffDetail,
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
    if (summary.id == _deferredAfterHandoff.id) {
      return const Result<EmergencyCaseDetail>.success(_deferredDetail);
    }
    if (summary.id == _handoffReady.id) {
      return const Result<EmergencyCaseDetail>.success(_handoffDetail);
    }
    return Result<EmergencyCaseDetail>.success(
      EmergencyCaseDetail(summary: summary),
    );
  });
}

Future<void> _pumpHandoffTab(
  WidgetTester tester, {
  required _MockEmergencyRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<EmergencyCaseSummary> items = const <EmergencyCaseSummary>[
    _handoffReady,
  ],
  EmergencyCaseDetail detail = _handoffDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/emergency?scope=handoff',
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

  group('Emergency Handoff ready billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(EmergencyHandoffBillingInventory.atoms, isNotEmpty);
      expect(
        EmergencyHandoffBillingInventory.atoms.map(
          (EmergencyHandoffFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'complete_trip',
          'handoff_opd',
          'handoff_ipd_icu',
          'handoff_theater',
          'handoff_terminal',
          'billing_deferred_chip',
          'open_billing',
          'collect_payment',
          'adjust_refund',
          'procedure_consumable',
          'hard_delete',
        ]),
      );
      for (final EmergencyHandoffFinancialAtom atom
          in EmergencyHandoffBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass == EmergencyHandoffFinancialClass.notBilled ||
            atom.financialClass == EmergencyHandoffFinancialClass.notRequired ||
            atom.financialClass == EmergencyHandoffFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(
        emergencyHandoffBillingScopeNote,
        contains('clinical-request-billing'),
      );
      expect(EmergencyHandoffBillingInventory.handoffOpd.financialClass,
          EmergencyHandoffFinancialClass.defer);
      expect(EmergencyHandoffBillingInventory.handoffTerminal.auditCode,
          'NOT_BILLED');
      expect(EmergencyHandoffBillingInventory.printSummary.auditCode,
          'NO_CHARGE');
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        EmergencyHandoffBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final EmergencyHandoffFinancialAtom atom
          in EmergencyHandoffBillingInventory.billableAtoms) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('handoff'),
            contains('admission'),
            contains('theatre'),
            contains('consultation'),
            contains('clinical-request'),
          ),
          reason: atom.id,
        );
      }
      expect(
        EmergencyHandoffBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        EmergencyHandoffBillingInventory.completeTrip.billingPath,
        contains('persistAmbulanceTripBilling'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Handoff ready', () {
      expect(EmergencyHandoffBillingInventory.collectPayment.mounted, isFalse);
      expect(EmergencyHandoffBillingInventory.adjustRefund.mounted, isFalse);
      expect(EmergencyHandoffBillingInventory.procedureConsumable.mounted,
          isFalse);
      expect(
        EmergencyHandoffBillingInventory.isInlineCollectionForbidden(
          EmergencyHandoffFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        EmergencyHandoffAtomPermissions.openBilling,
        same(billingReadRequirement),
      );
    });
  });

  group('Emergency Handoff ready billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.emergencyWorkspace,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'Open billing navigates; deferred parity; no cashier — desktop light',
      (WidgetTester tester) async {
        await _pumpHandoffTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredAfterHandoff],
          detail: _deferredDetail,
        );

        expect(find.text(EmergencyText.handoffReady), findsWidgets);

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expect(find.text(EmergencyText.openBilling), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text(EmergencyText.openBilling).first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=patient-uuid-ho-2'),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.emergencyRead},
        );
        expect(
          EmergencyHandoffAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpHandoffTab(
          tester,
          repository: repository,
          accessPolicy: reader,
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
          items: const <EmergencyCaseSummary>[_deferredAfterHandoff],
          detail: _deferredDetail,
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.openBilling), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        // Deferred chip remains visible as status parity, not settle.
        expect(find.text(EmergencyText.billingDeferred), findsWidgets);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'primary Record handoff affordance mounts for clinical write ∪',
      (WidgetTester tester) async {
        await _pumpHandoffTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.clinicalWrite,
            },
          ),
        );

        // Next-action column is the primary handoff affordance on this tab.
        expect(find.text(EmergencyText.recordHandoff), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.tap(find.text('Handoff Ready Patient'));
        await tester.pumpAndSettle();

        // Detail omits duplicate handoff; settle stays on Billing only.
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('Handoff'),
          ),
          findsNothing,
        );
        expect(find.textContaining('Receive payment'), findsNothing);
      },
    );
  });

  group('Emergency Handoff ready flat sections (AC5)', () {
    testWidgets(
      'detail panels are siblings — desktop light',
      (WidgetTester tester) async {
        await _pumpHandoffTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.emergencyRead,
              AppPermissions.emergencyWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <EmergencyCaseSummary>[_deferredAfterHandoff],
          detail: _deferredDetail,
        );

        await tester.tap(find.text('Deferred Handoff Patient'));
        await tester.pumpAndSettle();

        expect(find.text(EmergencyText.handoffOutcome), findsOneWidget);
        expect(find.text('Triage and response'), findsOneWidget);
        expect(find.text('Ambulance'), findsWidgets);
        expect(find.byType(AppCollapsibleSection), findsWidgets);
        expectFlatSections(tester);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'Handoff ready detail desktop light',
        );
      },
    );

    testWidgets(
      'detail panels are siblings — mobile dark',
      (WidgetTester tester) async {
        await _pumpHandoffTab(
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
          items: const <EmergencyCaseSummary>[_deferredAfterHandoff],
          detail: _deferredDetail,
        );

        final Finder row = find.text('Deferred Handoff Patient');
        await tester.ensureVisible(row);
        await tester.tap(row, warnIfMissed: false);
        await tester.pumpAndSettle();
        tester.takeException();

        expectFlatSections(tester);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'Handoff ready detail mobile dark',
        );
      },
    );
  });
}
