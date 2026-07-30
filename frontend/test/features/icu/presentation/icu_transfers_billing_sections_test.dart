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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_transfers_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _openTransferPatient = IcuPatientSummary(
  id: 'ADM-XFER-1',
  admissionId: 'ADM-XFER-1',
  displayId: 'ADMXFER1',
  patientId: 'patient-uuid-xfer',
  patientDisplayName: 'Transfer Tab Patient',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-5',
  hasActiveBed: true,
  transferStatus: 'REQUESTED',
  encounterId: 'ENC-XFER-1',
  sourceKind: 'EMERGENCY',
);

const IcuPatientDetail _openTransferDetail = IcuPatientDetail(
  summary: _openTransferPatient,
  activeStay: IcuStaySummary(id: 'STAY-XFER-1'),
  transferRequests: <IcuTransferRequest>[
    IcuTransferRequest(
      id: 'TR-1',
      status: 'REQUESTED',
      toWardName: 'Ward B',
    ),
  ],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalWrite ||
        permission == AppPermissions.clinicalRead,
  );
  final bool needsBilling = permissions.contains(AppPermissions.billingRead) ||
      permissions.contains(AppPermissions.billingWrite);
  final List<AppModuleEntitlement> resolvedModules =
      modules ??
      <AppModuleEntitlement>[
        const AppModuleEntitlement(
          code: 'icu-critical-care',
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
      ];

  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: AuthUserProfile(
        roles: roles,
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: resolvedModules,
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_openTransferPatient],
  IcuPatientDetail detail = _openTransferDetail,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(
      IcuReferenceData(
        wards: <IcuWardOption>[
          IcuWardOption(id: 'ward-icu', name: 'ICU A', wardType: 'ICU'),
          IcuWardOption(id: 'ward-b', name: 'Ward B', wardType: 'GENERAL'),
        ],
      ),
    ),
  );
  when(repository.loadBedBoard).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => Result<IcuPatientDetail>.success(detail),
  );
}

Future<void> _pumpTransfersTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary>? items,
  IcuPatientDetail? detail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(
    repository,
    items: items ?? <IcuPatientSummary>[_openTransferPatient],
    detail: detail ?? _openTransferDetail,
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=transfers',
    routes: <RouteBase>[
      GoRoute(
        path: '/icu',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IcuWorkspacePage(
              initialQuery: IcuBoardQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: Text('ipd-workspace')),
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          final String? patientId = state.uri.queryParameters['patient_id'];
          return Scaffold(
            body: Text(
              patientId == null
                  ? 'billing-workspace'
                  : 'Billing workspace patient=$patientId',
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('ICU Transfers billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(IcuTransfersBillingInventory.all, isNotEmpty);
      expect(
        IcuTransfersBillingInventory.all.map(
          (IcuTransfersFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'next_action_manage_transfer',
          'next_action_request_transfer',
          'request_transfer',
          'manage_transfer',
          'start_stay',
          'round_note',
          'order_lab',
          'mark_readiness',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final IcuTransfersFinancialAtom atom
          in IcuTransfersBillingInventory.all) {
        final bool notBillable =
            atom.financialClass == IcuTransfersFinancialClass.notBilled ||
            atom.financialClass == IcuTransfersFinancialClass.notRequired ||
            atom.financialClass == IcuTransfersFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(icuTransfersBillingScopeNote, contains('clinical-request-billing'));
      expect(
        IcuTransfersBillingInventory.requestTransfer.financialClass,
        IcuTransfersFinancialClass.notRequired,
      );
      expect(
        IcuTransfersBillingInventory.manageTransfer.auditCode,
        'NOT_REQUIRED',
      );
      expect(
        IcuTransfersBillingInventory.printSummary.auditCode,
        'NO_CHARGE',
      );
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        IcuTransfersBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final IcuTransfersFinancialAtom atom
          in IcuTransfersBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('plan-discharge'),
            contains('clinical'),
            contains('approutes'),
            contains('ipd'),
          ),
          reason: atom.id,
        );
      }
      expect(
        IcuTransfersBillingInventory.startStay.billingPath,
        contains('persistIcuStayBilling'),
      );
      expect(
        IcuTransfersBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Transfers', () {
      expect(IcuTransfersBillingInventory.collectPayment.mounted, isFalse);
      expect(IcuTransfersBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IcuTransfersBillingInventory.forbidsInlineCashier(
          IcuTransfersFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        IcuTransfersAtomPermissions.openBilling,
        same(icuBillingReadRequirement),
      );
    });
  });

  group('ICU Transfers billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.icu,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'Open billing navigates with patient_id; no cashier — desktop light',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        expect(find.text('Transfer Tab Patient'), findsOneWidget);
        expect(find.text('Manage transfer'), findsWidgets);

        await tester.tap(find.text('Transfer Tab Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=patient-uuid-xfer'),
          findsOneWidget,
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          IcuTransfersAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: reader,
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Transfer Tab Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        expect(find.text('Print summary'), findsOneWidget);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Manage transfer mounts without collect; transfer stays NOT_REQUIRED',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
          ),
        );

        expect(find.text('Manage transfer'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);

        await tester.tap(find.text('Manage transfer').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
      },
    );
  });

  group('ICU Transfers flat sections (AC5)', () {
    testWidgets(
      'detail panels are siblings — desktop light',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Transfer Tab Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(AppCollapsibleSection), findsWidgets);
        expectFlatSections(tester);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'Transfers detail desktop light',
        );
      },
    );

    testWidgets(
      'detail panels are siblings — mobile dark',
      (WidgetTester tester) async {
        await _pumpTransfersTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Transfer Tab Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(AppCollapsibleSection), findsWidgets);
        expectFlatSections(tester);
        expectFlatTitledSectionLayout(
          tester,
          contextLabel: 'Transfers detail mobile dark',
        );
      },
    );
  });

  group('ICU Transfers sync / UI states (AC3, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      when(() => repository.listIcuBoard(any())).thenAnswer((invocation) async {
        final IcuBoardQuery query =
            invocation.positionalArguments.single as IcuBoardQuery;
        return Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: const <IcuPatientSummary>[],
            request: query.pageRequest,
            totalItemCount: 0,
          ),
        );
      });
      when(repository.loadReferenceData).thenAnswer(
        (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
      );
      when(repository.loadBedBoard).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
      );

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final GoRouter router = GoRouter(
        initialLocation: '/icu?section=transfers',
        routes: <RouteBase>[
          GoRoute(
            path: '/icu',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: IcuWorkspacePage(
                  initialQuery: IcuBoardQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            icuRepositoryProvider.overrideWithValue(repository),
            followUpTabCountProvider.overrideWith(
              (Ref ref, FollowUpWorklistScope scope) => null,
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
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppWorkspaceStatePanel), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('authorized error/retry remains observable', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      when(() => repository.listIcuBoard(any())).thenAnswer(
        (_) async => const Result<AppPage<IcuPatientSummary>>.failure(
          AppFailure.network(),
        ),
      );
      when(repository.loadReferenceData).thenAnswer(
        (_) async =>
            const Result<IcuReferenceData>.success(IcuReferenceData()),
      );
      when(repository.loadBedBoard).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
      );

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final GoRouter router = GoRouter(
        initialLocation: '/icu?section=transfers',
        routes: <RouteBase>[
          GoRoute(
            path: '/icu',
            builder: (BuildContext context, GoRouterState state) {
              return Scaffold(
                body: IcuWorkspacePage(
                  initialQuery: IcuBoardQuery.fromUri(state.uri),
                ),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            icuRepositoryProvider.overrideWithValue(repository),
            followUpTabCountProvider.overrideWith(
              (Ref ref, FollowUpWorklistScope scope) => null,
            ),
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
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('no access'), findsNothing);
    });
  });
}
