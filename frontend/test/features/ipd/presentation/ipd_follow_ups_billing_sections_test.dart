import 'dart:async';

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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_follow_ups_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/follow_up_worklist_panel.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

class _MockFollowUpRepository extends Mock
    implements ReceptionFollowUpRepository {}

final ReceptionFollowUpEntry _followUp = ReceptionFollowUpEntry(
  id: 'fu-ipd-1',
  encounterId: 'enc-1',
  patientId: 'pat-1',
  patientIdentifier: 'PAT-FU-IPD1',
  patientDisplayName: 'Follow Up Patient',
  patientPhone: '+256700000001',
  scheduledAt: DateTime.utc(2026, 7, 29, 9, 30),
  notes: 'IPD callback',
  status: 'SCHEDULED',
);

Finder _tab(String label) =>
    find.descendant(of: find.byType(AppTabStrip), matching: find.text(label));

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
  String? tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsOperations = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.operationsRead ||
        permission == AppPermissions.operationsWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        if (needsClinical)
          const AppModuleEntitlement(
            code: 'encounters-vitals',
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
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: tenantId,
        facilityId: facilityId,
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  late _MockIpdRepository ipdRepository;
  late _MockFollowUpRepository followUpRepository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    ipdRepository = _MockIpdRepository();
    followUpRepository = _MockFollowUpRepository();
    _stubIpd(ipdRepository);
    _stubFollowUps(followUpRepository);
  });

  group('IPD Follow-ups financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(
        IpdFollowUpsBillingInventory.followUpsTabHasNoBillableActions,
        isTrue,
      );
      expect(
        IpdFollowUpsBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IpdFollowUpsBillingInventory.atoms, isNotEmpty);
      expect(
        IpdFollowUpsBillingInventory.billableAtoms.every(
          (IpdFollowUpsFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(ipdFollowUpsBillingScopeNote, contains('NOT_BILLED'));
      expect(ipdFollowUpsBillingScopeNote, contains('Billing'));
      expect(IpdFollowUpsBillingInventory.summary(), contains('NOT_BILLED'));

      for (final IpdFollowUpsFinancialAtom atom
          in IpdFollowUpsBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IpdFollowUpsFinancialClass>[
            IpdFollowUpsFinancialClass.notRequired,
            IpdFollowUpsFinancialClass.notBilled,
            IpdFollowUpsFinancialClass.noCharge,
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
        IpdFollowUpsBillingInventory.markCompleted.financialClass,
        IpdFollowUpsFinancialClass.notBilled,
      );
      expect(
        IpdFollowUpsBillingInventory.markCompleted.auditCode,
        'NOT_BILLED',
      );
      expect(
        IpdFollowUpsBillingInventory.reschedule.financialClass,
        IpdFollowUpsFinancialClass.notBilled,
      );
      expect(
        IpdFollowUpsBillingInventory.saveFollowUp.financialClass,
        IpdFollowUpsFinancialClass.notBilled,
      );
    });

    test('unmounted billable atoms document Billing system of record', () {
      expect(IpdFollowUpsBillingInventory.openBilling.mounted, isFalse);
      expect(
        IpdFollowUpsBillingInventory.openBilling.billingPath,
        contains('Billing'),
      );
      expect(
        IpdFollowUpsBillingInventory.followUpVisitCharge.mounted,
        isFalse,
      );
      expect(IpdFollowUpsBillingInventory.admissionDeposit.mounted, isFalse);
      expect(
        IpdFollowUpsBillingInventory.admissionDeposit.billingPath,
        contains('receive-payment'),
      );
      expect(IpdFollowUpsBillingInventory.bedDayCharge.mounted, isFalse);
      expect(IpdFollowUpsBillingInventory.transferRateChange.mounted, isFalse);
      expect(IpdFollowUpsBillingInventory.consumables.mounted, isFalse);
      expect(
        IpdFollowUpsBillingInventory.dischargeFinancialClearance.mounted,
        isFalse,
      );
      expect(
        IpdFollowUpsBillingInventory.dischargeFinancialClearance.billingPath,
        contains('isBillingSettledForPatient'),
      );
      expect(IpdFollowUpsBillingInventory.collectPayment.mounted, isFalse);
      expect(
        IpdFollowUpsBillingInventory.issueInvoiceAdjustRefund.mounted,
        isFalse,
      );
      expect(
        IpdFollowUpsBillingInventory.isInlineCollectionForbidden(
          IpdFollowUpsFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('inventory reuses IPD Follow-ups access gates', () {
      expect(
        IpdFollowUpsBillingInventory.tab.requirement,
        same(IpdFollowUpsAtomPermissions.tab),
      );
      expect(
        IpdFollowUpsBillingInventory.markCompleted.requirement,
        same(IpdFollowUpsAtomPermissions.markCompleted),
      );
      expect(
        IpdFollowUpsBillingInventory.reschedule.requirement,
        same(IpdFollowUpsAtomPermissions.reschedule),
      );
    });
  });

  group('IPD Follow-ups billing bypass (AC2–AC4)', () {
    testWidgets('worklist has no payment/issue/collect affordances', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
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
      expect(find.textContaining('Waive'), findsNothing);
      expect(find.textContaining('Refund'), findsNothing);
      expect(find.text('Start admission'), findsNothing);
      expect(find.text('Follow Up Patient'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('detail dialog: no financial controls; flat sibling sections', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
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
      expect(find.textContaining('Open billing'), findsNothing);
      expect(find.text('Mark completed'), findsOneWidget);
      expect(find.text('Reschedule follow-up'), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('unauthorized reader cannot collect, adjust, or mutate', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
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
          'fu-ipd-1',
          notes: any(named: 'notes'),
        ),
      ).called(1);
      verify(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: 'IPD',
        ),
      ).called(greaterThan(0));
      expect(find.text('No scheduled follow-ups'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Invoice'), findsNothing);
    });

    testWidgets('Reschedule dialog has no billing affordances', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
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

  group('IPD Follow-ups section layout (AC5)', () {
    testWidgets('desktop Follow-ups: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpFollowUpsTab(
        tester,
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

  group('IPD Follow-ups sync / UI states (AC3–AC4, AC6)', () {
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
          NetworkFailure(),
        ),
      );

      await _pumpFollowUpsTab(
        tester,
        ipdRepository: ipdRepository,
        followUpRepository: followUpRepository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    testWidgets('authorized loading chrome remains without financial controls', (
      WidgetTester tester,
    ) async {
      final Completer<Result<List<ReceptionFollowUpEntry>>> listCompleter =
          Completer<Result<List<ReceptionFollowUpEntry>>>();
      when(
        () => followUpRepository.listScheduledFollowUps(
          encounterType: any(named: 'encounterType'),
        ),
      ).thenAnswer((_) => listCompleter.future);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final GoRouter router = GoRouter(
        initialLocation: '/ipd?section=follow-ups',
        routes: <RouteBase>[
          GoRoute(
            path: '/ipd',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: IpdWorkspacePage(
                  initialQuery: IpdAdmissionQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ipdRepositoryProvider.overrideWithValue(ipdRepository),
            receptionFollowUpRepositoryProvider.overrideWithValue(
              followUpRepository,
            ),
            sharedPreferencesProvider.overrideWithValue(preferences),
            initialSessionStateProvider.overrideWithValue(
              const SessionState.ready(),
            ),
            appAccessPolicyProvider.overrideWithValue(
              _policy(
                permissions: <AppPermission>{AppPermissions.clinicalRead},
              ),
            ),
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
      await tester.pump();

      expect(_tab('Follow-ups'), findsOneWidget);
      expect(find.byType(FollowUpWorklistPanel), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);

      listCompleter.complete(
        Result<List<ReceptionFollowUpEntry>>.success(
          <ReceptionFollowUpEntry>[_followUp],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Follow Up Patient'), findsOneWidget);
    });
  });
}

Future<void> _pumpFollowUpsTab(
  WidgetTester tester, {
  required _MockIpdRepository ipdRepository,
  required _MockFollowUpRepository followUpRepository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  String initialLocation = '/ipd?section=follow-ups',
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
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IpdWorkspacePage(
              initialQuery: IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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

void _stubIpd(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer(
    (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: const <IpdAdmissionSummary>[],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[]),
  );
  when(
    () => repository.listBeds(
      search: any(named: 'search'),
      status: any(named: 'status'),
      wardId: any(named: 'wardId'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<IpdBedOption>>.success(<IpdBedOption>[]),
  );
  when(
    () => repository.listBedBoard(
      wardId: any(named: 'wardId'),
      status: any(named: 'status'),
      statusAny: any(named: 'statusAny'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async =>
        const Result<List<IpdBedBoardEntry>>.success(<IpdBedBoardEntry>[]),
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
