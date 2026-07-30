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
import 'package:hosspi_hms/features/lab/data/repositories/lab_repository_impl.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/domain/repositories/lab_repository.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_access.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_follow_ups_billing_inventory.dart';
import 'package:hosspi_hms/features/lab/presentation/pages/lab_workspace_page.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockLabRepository extends Mock implements LabRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-lab-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-LAB1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'Lab callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: labWorkflowsModule, licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['LAB_TECH'],
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
  late _MockLabRepository labRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const LabWorkbenchQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    labRepository = _MockLabRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubLab(labRepository);
    _stubFollowUps(followUpRepository);
  });

  group('Lab Follow-ups financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        LabFollowUpsBillingInventory.followUpsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        LabFollowUpsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(LabFollowUpsBillingInventory.atoms, isNotEmpty);
      expect(
        LabFollowUpsBillingInventory.billableAtoms.every(
          (LabFollowUpsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(labFollowUpsBillingScopeNote, contains('NOT_BILLED'));

      for (final LabFollowUpsFinancialAtom atom
          in LabFollowUpsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<LabFollowUpsFinancialClass>[
            LabFollowUpsFinancialClass.notRequired,
            LabFollowUpsFinancialClass.notBilled,
            LabFollowUpsFinancialClass.noCharge,
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
      expect(
        LabFollowUpsBillingInventory.markCompleted.financialClass,
        LabFollowUpsFinancialClass.notBilled,
      );
      expect(LabFollowUpsBillingInventory.markCompleted.auditCode, 'NOT_BILLED');
      expect(LabFollowUpsBillingInventory.markCompleted.mounted, isTrue);

      expect(
        LabFollowUpsBillingInventory.reschedule.financialClass,
        LabFollowUpsFinancialClass.notBilled,
      );
      expect(LabFollowUpsBillingInventory.reschedule.auditCode, 'NOT_BILLED');

      expect(
        LabFollowUpsBillingInventory.saveFollowUp.financialClass,
        LabFollowUpsFinancialClass.notBilled,
      );
      expect(LabFollowUpsBillingInventory.saveFollowUp.auditCode, 'NOT_BILLED');
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(LabFollowUpsBillingInventory.followUpVisitCharge.mounted, isFalse);
      expect(LabFollowUpsBillingInventory.createLabOrderCharge.mounted, isFalse);
      expect(
        LabFollowUpsBillingInventory.resultEntrySave.mounted,
        isFalse,
      );
      expect(LabFollowUpsBillingInventory.collectPayment.mounted, isFalse);
      expect(
        LabFollowUpsBillingInventory.issueInvoiceAdjustRefund.mounted,
        isFalse,
      );
      expect(
        LabFollowUpsBillingInventory.createLabOrderCharge.billingPath,
        contains('clinical-request-billing'),
      );
      expect(
        LabFollowUpsBillingInventory.collectPayment.billingPath,
        contains('receive-payment'),
      );
      expect(labFollowUpsBillingScopeNote, contains('Billing'));
    });
  });

  group('Lab Follow-ups billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
          'fu-lab-1',
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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

    testWidgets('Create Order primary absent on Follow-ups strip', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
          },
        ),
      );

      expect(find.textContaining('Create Lab Order'), findsNothing);
      expect(find.textContaining('Create order'), findsNothing);
      expect(LabFollowUpsBillingInventory.createLabOrderCharge.mounted, isFalse);
    });
  });

  group('Lab Follow-ups section layout (AC5)', () {
    testWidgets('desktop Follow-ups: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.labRead,
            AppPermissions.labWrite,
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

  group('Lab Follow-ups sync / UI states (AC3–AC4, AC6)', () {
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
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
        labRepository: labRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.labRead},
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('inventory reuses shared financial class vocabulary and access gates', () {
      expect(
        LabFollowUpsBillingInventory.atoms.any(
          (LabFollowUpsFinancialAtom atom) =>
              atom.financialClass == LabFollowUpsFinancialClass.createCharge,
        ),
        isTrue,
      );
      expect(
        LabFollowUpsBillingInventory.isInlineCollectionForbidden(
          LabFollowUpsFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        LabFollowUpsAtomPermissions.tab,
        labFollowUpsRequirement,
      );
      expect(
        LabFollowUpsAtomPermissions.markCompleted,
        labFollowUpsWriteRequirement,
      );
      expect(
        LabFollowUpsAtomPermissions.reschedule,
        labFollowUpsWriteRequirement,
      );
    });
  });
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockLabRepository labRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/lab?section=follow-ups',
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
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: LabWorkspacePage(
              initialQuery: LabWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        labRepositoryProvider.overrideWithValue(labRepository),
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

void _stubLab(_MockLabRepository repository) {
  when(() => repository.loadWorkbench(any())).thenAnswer(
    (_) async => Result<LabWorkbenchBundle>.success(
      LabWorkbenchBundle(
        summary: const LabWorkbenchSummary(
          totalOrders: 0,
          collectionQueue: 0,
          completedOrders: 0,
          totalPatients: 0,
          collectionPatients: 0,
          completedPatients: 0,
        ),
        worklist: AppPage<LabOrderSummary>(
          items: const <LabOrderSummary>[],
          request: const AppPageRequest(pageSize: 12),
          totalItemCount: 0,
        ),
      ),
    ),
  );
  when(
    () => repository.listQcLogs(search: any(named: 'search')),
  ).thenAnswer((_) async => const Result<List<LabQcLog>>.success(<LabQcLog>[]));
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
