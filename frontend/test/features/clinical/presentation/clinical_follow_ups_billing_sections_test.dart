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
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_access.dart';
import 'package:hosspi_hms/features/clinical/presentation/clinical_follow_ups_billing_inventory.dart';
import 'package:hosspi_hms/features/clinical/presentation/pages/clinical_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockClinicalRepository extends Mock implements ClinicalRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-clinical-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Callback about labs',
  status: 'SCHEDULED',
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

void main() {
  late _MockClinicalRepository clinicalRepository;
  late _MockOpdRepository opdRepository;
  late _MockIpdRepository ipdRepository;
  late _MockFollowUpRepository followUpRepository;

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
    opdRepository = _MockOpdRepository();
    ipdRepository = _MockIpdRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubClinical(clinicalRepository);
    _stubOpd(opdRepository);
    _stubIpd(ipdRepository);
    _stubFollowUps(followUpRepository);
  });

  group('Clinical Follow-ups financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        ClinicalFollowUpsBillingInventory.followUpsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        ClinicalFollowUpsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(ClinicalFollowUpsBillingInventory.atoms, isNotEmpty);
      expect(
        ClinicalFollowUpsBillingInventory.billableClasses.every(
          (ClinicalFollowUpsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(clinicalFollowUpsBillingScopeNote, contains('NOT_BILLED'));

      for (final ClinicalFollowUpsFinancialAtom atom
          in ClinicalFollowUpsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<ClinicalFollowUpsFinancialClass>[
            ClinicalFollowUpsFinancialClass.notRequired,
            ClinicalFollowUpsFinancialClass.notBilled,
            ClinicalFollowUpsFinancialClass.noCharge,
          ]),
          reason: atom.id,
        );
        expect(
          atom.auditCode,
          isIn(<String>['NOT_REQUIRED', 'NOT_BILLED', 'NO_CHARGE']),
          reason: atom.id,
        );
      }
    });

    test('Mark completed and reschedule stay NOT_BILLED', () {
      final ClinicalFollowUpsFinancialAtom complete =
          ClinicalFollowUpsBillingInventory.atoms.singleWhere(
            (ClinicalFollowUpsFinancialAtom atom) =>
                atom.id == 'detail_mark_completed',
          );
      expect(
        complete.financialClass,
        ClinicalFollowUpsFinancialClass.notBilled,
      );
      expect(complete.auditCode, 'NOT_BILLED');
      expect(complete.mounted, isTrue);

      final ClinicalFollowUpsFinancialAtom reschedule =
          ClinicalFollowUpsBillingInventory.atoms.singleWhere(
            (ClinicalFollowUpsFinancialAtom atom) =>
                atom.id == 'detail_reschedule',
          );
      expect(
        reschedule.financialClass,
        ClinicalFollowUpsFinancialClass.notBilled,
      );
      expect(reschedule.auditCode, 'NOT_BILLED');

      final ClinicalFollowUpsFinancialAtom save =
          ClinicalFollowUpsBillingInventory.atoms.singleWhere(
            (ClinicalFollowUpsFinancialAtom atom) =>
                atom.id == 'nested_save_follow_up',
          );
      expect(save.financialClass, ClinicalFollowUpsFinancialClass.notBilled);
      expect(save.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(
        ClinicalFollowUpsBillingInventory.atoms
            .singleWhere(
              (ClinicalFollowUpsFinancialAtom atom) =>
                  atom.id == 'follow_up_visit_charge',
            )
            .mounted,
        isFalse,
      );
      expect(
        ClinicalFollowUpsBillingInventory.atoms
            .singleWhere(
              (ClinicalFollowUpsFinancialAtom atom) =>
                  atom.id == 'collect_payment',
            )
            .mounted,
        isFalse,
      );
      expect(
        ClinicalFollowUpsBillingInventory.atoms
            .singleWhere(
              (ClinicalFollowUpsFinancialAtom atom) =>
                  atom.id == 'issue_invoice_adjust_refund',
            )
            .mounted,
        isFalse,
      );
      expect(clinicalFollowUpsBillingScopeNote, contains('Billing'));
    });
  });

  group('Clinical Follow-ups billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Collect'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsOneWidget);
      expect(find.text('Follow-up schedule'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect, adjust, or mutate', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      expect(find.text('Mark completed'), findsNothing);
      expect(find.text('Reschedule follow-up'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('Mark completed syncs list without billing gate', (
      WidgetTester tester,
    ) async {
      when(
        () => followUpRepository.completeFollowUp(
          any(),
          notes: any(named: 'notes'),
        ),
      ).thenAnswer((_) async => const Result<void>.success(null));

      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();

      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[],
        ),
      );

      await tester.tap(find.text('Mark completed'));
      await tester.pumpAndSettle();

      verify(
        () => followUpRepository.completeFollowUp(
          'fu-clinical-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
    });

    testWidgets('Reschedule dialog has no billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reschedule follow-up'));
      await tester.pumpAndSettle();

      expect(find.text('Save follow-up'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expect(find.textContaining('Balance due'), findsNothing);
      expectFlatSections(tester);
      verifyNever(
        () => followUpRepository.updateFollowUp(any(), any()),
      );
    });
  });

  group('Clinical Follow-ups section layout (AC5)', () {
    testWidgets('desktop Follow-ups: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );

      expectFlatSections(tester);

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Follow-ups: flat sections', (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
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
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        themeMode: ThemeMode.light,
      );
      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        themeMode: ThemeMode.dark,
      );
      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('Reschedule dialog: flat sections', (WidgetTester tester) async {
      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      await tester.tap(find.text('Follow Up Patient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reschedule follow-up'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });

  group('Clinical Follow-ups sync / UI states (AC3–AC4, AC6)', () {
    testWidgets('authorized empty state remains observable without billing UX', (
      WidgetTester tester,
    ) async {
      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[],
        ),
      );

      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('error/retry remains for authorized readers', (
      WidgetTester tester,
    ) async {
      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer(
        (_) async => const Result<List<ReceptionFollowUpEntry>>.failure(
          AppFailure.network(),
        ),
      );

      await _pumpFollowUpsTab(
        tester,
        clinicalRepository: clinicalRepository,
        opdRepository: opdRepository,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary and access gates', () {
      expect(
        ClinicalFollowUpsBillingInventory.atoms.any(
          (ClinicalFollowUpsFinancialAtom atom) =>
              atom.financialClass ==
              ClinicalFollowUpsFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        ClinicalFollowUpsAtomPermissions.tab,
        clinicalFollowUpsRequirement,
      );
      expect(
        ClinicalFollowUpsAtomPermissions.markCompleted,
        clinicalFollowUpsWriteRequirement,
      );
      expect(
        ClinicalFollowUpsAtomPermissions.reschedule,
        clinicalFollowUpsWriteRequirement,
      );
    });
  });
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockClinicalRepository clinicalRepository,
  required _MockOpdRepository opdRepository,
  required _MockIpdRepository ipdRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/clinical?section=follow-ups',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
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
        receptionFollowUpRepositoryProvider.overrideWithValue(
          followUpRepository,
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

void _stubClinical(_MockClinicalRepository repository) {
  when(() => repository.listEncounters(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<ClinicalWorklistEntry>>.success(
      AppPage<ClinicalWorklistEntry>(
        items: const <ClinicalWorklistEntry>[],
        request:
            (invocation.positionalArguments.single as ClinicalWorklistQuery)
                .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<ClinicalWorklistEntry>>.success(
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
}

void _stubOpd(_MockOpdRepository repository) {
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: const <OpdFlowSummary>[],
        request: (invocation.positionalArguments.single as OpdTriageQueueQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (Invocation invocation) async =>
        Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: (invocation.positionalArguments.single as IpdAdmissionQuery)
            .pageRequest,
        totalItemCount: 0,
      ),
    ),
  );
}

void _stubFollowUps(_MockFollowUpRepository repository) {
  when(
    () => repository.listScheduledFollowUps(
      encounterType: any(named: 'encounterType'),
    ),
  ).thenAnswer(
    (_) async => Result<List<ReceptionFollowUpEntry>>.success(
      <ReceptionFollowUpEntry>[_followUp],
    ),
  );
}
