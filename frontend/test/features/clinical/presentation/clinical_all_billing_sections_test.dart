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
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_all_billing_inventory.dart';
import 'package:hosspi_hms/features/clinical/presentation/controllers/clinical_workspace_controller.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

const ClinicalWorklistEntry _encounter = ClinicalWorklistEntry(
  id: 'encounter-all-bill-1',
  sourceQueue: 'OPD',
  encounterId: 'encounter-all-bill-1',
  encounterPublicId: 'ENC-BILL-1',
  patientId: 'patient-uuid-1',
  patientDisplayName: 'All Billing Patient',
  patientPublicId: 'PAT-BILL-1',
  providerDisplayName: 'Dr Bill',
  encounterType: 'OUTPATIENT',
  currentLocation: 'Clinic A',
  status: 'OPEN',
  stage: 'WAITING_DOCTOR_REVIEW',
  opdFlowApiId: 'opd-flow-bill-1',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'encounters-vitals', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubClinical(
  _MockClinicalRepository repository, {
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
}) {
  when(() => repository.listEncounters(any())).thenAnswer((invocation) async {
    return Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: items,
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<ClinicalReferenceData>.success(ClinicalReferenceData()),
  );
  when(() => repository.loadEncounterBundle(any())).thenAnswer((invocation) {
    final ClinicalWorklistEntry entry =
        invocation.positionalArguments.single as ClinicalWorklistEntry;
    return Future<Result<ClinicalEncounterBundle>>.value(
      Result<ClinicalEncounterBundle>.success(
        ClinicalEncounterBundle(
          entry: entry,
          labOrders: const <ClinicalRelatedRecord>[
            ClinicalRelatedRecord(
              id: 'lab-1',
              kind: 'LAB_ORDER',
              status: 'ORDERED',
              title: 'CBC',
            ),
          ],
          procedures: const <ClinicalRelatedRecord>[
            ClinicalRelatedRecord(
              id: 'proc-1',
              kind: 'PROCEDURE',
              status: 'COMPLETED',
              title: 'Wound care',
            ),
          ],
          diagnoses: const <ClinicalRelatedRecord>[
            ClinicalRelatedRecord(
              id: 'dx-1',
              kind: 'DIAGNOSIS',
              status: 'ACTIVE',
              title: 'Hypertension',
            ),
          ],
        ),
      ),
    );
  });
}

void _stubOpd(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.getOpdFlow(any())).thenAnswer(
    (_) async => const Result<OpdFlowDetail>.success(
      OpdFlowDetail(
        summary: OpdFlowSummary(id: 'opd-flow-bill-1', publicId: 'OPD000001'),
      ),
    ),
  );
}

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (invocation) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<ClinicalWorklistEntry> items = const <ClinicalWorklistEntry>[_encounter],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final _MockOpdRepository opdRepository = _MockOpdRepository();
  final _MockIpdRepository ipdRepository = _MockIpdRepository();
  _stubClinical(clinicalRepository, items: items);
  _stubOpd(opdRepository);
  _stubIpd(ipdRepository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/clinical?section=all',
    routes: <RouteBase>[
      GoRoute(
        path: '/clinical',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: ClinicalWorkspacePage(
              initialQuery: ClinicalWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
        ipdRepositoryProvider.overrideWithValue(ipdRepository),
        followUpTabCountProvider.overrideWith(
          (Ref ref, FollowUpWorklistScope scope) => null,
        ),
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

  late _MockClinicalRepository clinicalRepository;

  setUpAll(() {
    registerFallbackValue(const ClinicalWorklistQuery());
    registerFallbackValue(
      const ClinicalWorklistEntry(
        id: 'encounter-fallback',
        sourceQueue: 'OPD',
        encounterId: 'encounter-fallback',
      ),
    );
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    clinicalRepository = _MockClinicalRepository();
  });

  group('Clinical All financial inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(ClinicalAllBillingInventory.all, isNotEmpty);
      expect(
        ClinicalAllBillingInventory.all.map(
          (ClinicalAllFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'request_lab',
          'request_radiology',
          'prescribe',
          'record_procedure',
          'cancel_delete_lab',
          'discharge_open_billing',
          'review_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(clinicalAllBillingScopeNote, contains('clinical-request-billing'));
    });

    test('billable mounted atoms declare a Billing path (no bypass)', () {
      for (final ClinicalAllFinancialAtom atom
          in ClinicalAllBillingInventory.billableMounted) {
        expect(
          atom.billingPath,
          isNotNull,
          reason: '${atom.id} must wire Billing',
        );
        expect(
          ClinicalAllBillingInventory.forbidsInlineCollection(
            atom.financialClass,
          ),
          isTrue,
          reason: '${atom.id} must not use shadow ledgers',
        );
      }
    });

    test('cashier settle/adjust atoms are unmounted on All tab', () {
      expect(ClinicalAllBillingInventory.collectPayment.mounted, isFalse);
      expect(ClinicalAllBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        ClinicalAllBillingInventory.recordProcedure.financialClass,
        ClinicalAllFinancialClass.createCharge,
      );
      expect(
        ClinicalAllBillingInventory.requestLab.financialClass,
        ClinicalAllFinancialClass.createCharge,
      );
    });

    test('clinical workspace realtime includes billing events (AC3)', () {
      expect(RealtimeEventGroups.clinical, containsAll(RealtimeEventGroups.billing));
    });
  });

  group('Clinical All billing posting / parity (AC2–AC4)', () {
    test('pending procedure billing payload is bill-later unpaid', () {
      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalActionCatalogOption>[
              ClinicalActionCatalogOption(
                id: 'PROC-1',
                name: 'Wound care',
                unitPrice: 40,
                currency: 'USD',
              ),
            ],
            catalogType: 'SERVICE',
            billingEntity: 'FACILITY',
          );
      expect(billing.mode, ClinicalRequestPaymentMode.billLater);
      expect(billing.paymentStatus, ClinicalRequestPaymentStatus.unpaid);
      expect(billing.toPayloadMap()['payment_status'], 'PENDING');
      expect(billing.lineItems, isNotEmpty);
    });

    test('sliceClinicalRequestBilling avoids multi-procedure double charge', () {
      final ClinicalRequestBillingSubmit billing =
          buildPendingClinicalRequestBillingSubmit(
            options: const <ClinicalActionCatalogOption>[
              ClinicalActionCatalogOption(
                id: 'PROC-A',
                name: 'A',
                unitPrice: 10,
                currency: 'USD',
              ),
              ClinicalActionCatalogOption(
                id: 'PROC-B',
                name: 'B',
                unitPrice: 20,
                currency: 'USD',
              ),
            ],
            catalogType: 'SERVICE',
          );
      final ClinicalRequestBillingSubmit? a =
          sliceClinicalRequestBillingForCatalogItem(billing, 'PROC-A');
      final ClinicalRequestBillingSubmit? b =
          sliceClinicalRequestBillingForCatalogItem(billing, 'PROC-B');
      expect(a!.totalAmount, 10);
      expect(b!.totalAmount, 20);
      expect(a.lineItems.single.id, 'PROC-A');
      expect(b.lineItems.single.id, 'PROC-B');
    });

    test('addProcedures posts billing payload via createProcedure (no bypass)', () async {
      when(
        () => clinicalRepository.createProcedure(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));
      when(
        () => clinicalRepository.createClinicalTermFavorite(any()),
      ).thenAnswer((_) async => const Result<void>.success(null));

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences = await SharedPreferences.getInstance();
      final _MockOpdRepository opd = _MockOpdRepository();
      final _MockIpdRepository ipd = _MockIpdRepository();
      _stubClinical(clinicalRepository);
      _stubOpd(opd);
      _stubIpd(ipd);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          clinicalRepositoryProvider.overrideWithValue(clinicalRepository),
          opdRepositoryProvider.overrideWithValue(opd),
          ipdRepositoryProvider.overrideWithValue(ipd),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          appAccessPolicyProvider.overrideWithValue(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.clinicalRead,
                AppPermissions.clinicalWrite,
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(clinicalWorkspaceControllerProvider.future);
      final ClinicalWorkspaceController controller = container.read(
        clinicalWorkspaceControllerProvider.notifier,
      );
      await controller.selectEntry(_encounter);

      final AppFailure? failure = await controller.addProcedures(
        procedures: const <ClinicalCatalogOption>[
          ClinicalCatalogOption(
            id: 'PROC-1',
            name: 'Wound care',
            unitPrice: 40,
            currency: 'USD',
          ),
        ],
      );
      expect(failure, isNull);

      final List<Object?> captured = verify(
        () => clinicalRepository.createProcedure(captureAny()),
      ).captured;
      expect(captured, hasLength(1));
      final Map<String, Object?> payload =
          captured.single as Map<String, Object?>;
      expect(payload['billing'], isA<Map<String, Object?>>());
      final Map<String, Object?> billing =
          payload['billing']! as Map<String, Object?>;
      expect(billing['payment_status'], 'PENDING');
      expect(billing['line_items'], isNotEmpty);
    });

    testWidgets(
      'unauthorized reader has no collect/adjust and no write billing chrome',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          clinicalRepository: clinicalRepository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        );

        expect(find.text('All Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(canViewClinicalAll(_policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        )), isTrue);
        expectFlatSections(tester);
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(_tab('Pending'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('Clinical All section layout (AC5)', () {
    testWidgets('desktop All: flat sections on list + encounter detail', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('All Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(find.text('All Billing Patient'), findsWidgets);
    });

    testWidgets('mobile All: flat sections', (WidgetTester tester) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        physicalSize: const Size(390, 844),
      );
      expectFlatSections(tester);
    });

    testWidgets('light theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('All Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('All Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Clinical All UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpAllTab(
        tester,
        clinicalRepository: clinicalRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <ClinicalWorklistEntry>[],
      );

      expect(_tab('Pending'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });
  });
}
