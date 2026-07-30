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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_discharge_ready_billing_inventory.dart';
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

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _pendingReadiness = IcuPatientSummary(
  id: 'ADM-DR-B1',
  admissionId: 'ADM-DR-B1',
  displayId: 'ADM-DRB1',
  patientId: 'patient-uuid-dr',
  patientDisplayName: 'Dana Discharge Billing',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-3',
  hasActiveBed: true,
  encounterId: 'ENC-DR-B1',
  sourceKind: 'EMERGENCY',
);

const IcuPatientSummary _plannedClearance = IcuPatientSummary(
  id: 'ADM-DR-B2',
  admissionId: 'ADM-DR-B2',
  displayId: 'ADM-DRB2',
  patientId: 'patient-uuid-dr-2',
  patientDisplayName: 'Pat Planned Billing',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-4',
  hasActiveBed: true,
  dischargeStatus: 'PLANNED',
  encounterId: 'ENC-DR-B2',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(
        roles: <String>['DOCTOR'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements:
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
          ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[_pendingReadiness],
  IcuPatientDetail? detailOverride,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((_) async {
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: board,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: board.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    if (detailOverride != null) {
      return Result<IcuPatientDetail>.success(detailOverride);
    }
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: summary,
        activeStay: const IcuStaySummary(id: 'stay-dr-1'),
      ),
    );
  });
}

Future<void> _pumpDischargeReady(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  List<IcuPatientSummary>? items,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(
    repository,
    board: items ?? <IcuPatientSummary>[_pendingReadiness],
  );

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=discharge',
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
          return Scaffold(
            body: Text('IPD panel=${state.uri.queryParameters['panel'] ?? ''}'),
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
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
    );
    registerFallbackValue(
      const IcuPatientDetail(
        summary: IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
      ),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('ICU Discharge ready billing inventory (AC1)', () {
    test('every financially relevant atom is inventoried and classified', () {
      expect(IcuDischargeReadyBillingInventory.all, isNotEmpty);
      expect(
        IcuDischargeReadyBillingInventory.all.map(
          (IcuDischargeReadyFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'next_action_mark_readiness',
          'next_action_open_clearance',
          'mark_readiness',
          'start_stay',
          'round_note',
          'order_lab',
          'open_billing',
          'open_discharge_clearance',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final IcuDischargeReadyFinancialAtom atom
          in IcuDischargeReadyBillingInventory.all) {
        final bool notBillable =
            atom.financialClass ==
                IcuDischargeReadyFinancialClass.notBilled ||
            atom.financialClass ==
                IcuDischargeReadyFinancialClass.notRequired ||
            atom.financialClass == IcuDischargeReadyFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(
        IcuDischargeReadyBillingInventory.markReadiness.financialClass,
        IcuDischargeReadyFinancialClass.defer,
      );
      expect(
        IcuDischargeReadyBillingInventory.printSummary.auditCode,
        'NO_CHARGE',
      );
      expect(
        IcuDischargeReadyBillingInventory.summary(),
        contains('clinical-request-billing'),
      );
    });

    test('billable mounted atoms wire through shared Billing (no bypass)', () {
      expect(
        IcuDischargeReadyBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      for (final IcuDischargeReadyFinancialAtom atom
          in IcuDischargeReadyBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('clinical-request'),
            contains('plan-discharge'),
            contains('ipd'),
            contains('clearance'),
            contains('approutes.billing'),
          ),
          reason: atom.id,
        );
      }
      expect(
        IcuDischargeReadyBillingInventory.startStay.billingPath,
        contains('persistIcuStayBilling'),
      );
      expect(
        IcuDischargeReadyBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
    });

    test('cashier settle/adjust atoms are unmounted on Discharge ready', () {
      expect(
        IcuDischargeReadyBillingInventory.collectPayment.mounted,
        isFalse,
      );
      expect(IcuDischargeReadyBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IcuDischargeReadyBillingInventory.forbidsInlineCashier(
          IcuDischargeReadyFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        IcuDischargeReadyAtomPermissions.openBilling,
        same(icuBillingReadRequirement),
      );
      expect(
        IcuDischargeReadyAtomPermissions.openBilling.allPermissions,
        billingReadRequirement.allPermissions,
      );
    });
  });

  group('ICU Discharge ready billing wiring (AC2–AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.icu,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'Open billing navigates with patient_id; deferred badge; no cashier',
      (WidgetTester tester) async {
        await _pumpDischargeReady(
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

        expect(find.text('Dana Discharge Billing'), findsOneWidget);
        await tester.tap(find.text('Dana Discharge Billing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=patient-uuid-dr'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Open discharge clearance hands off to IPD panel; no inline settle',
      (WidgetTester tester) async {
        await _pumpDischargeReady(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
          items: const <IcuPatientSummary>[_plannedClearance],
        );

        expect(find.text('Open discharge clearance'), findsWidgets);
        await tester.tap(find.text('Open discharge clearance').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('IPD panel=discharge'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
      },
    );

    testWidgets(
      'unauthorized cannot Open billing or collect — clinical-only reader',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(
          IcuDischargeReadyAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );
        expect(
          billingWorkspaceWriteRequirement.isAllowed(reader),
          isFalse,
        );

        await _pumpDischargeReady(
          tester,
          repository: repository,
          accessPolicy: reader,
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('Dana Discharge Billing'));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
      },
    );
  });

  group('ICU Discharge ready flat sections (AC5)', () {
    testWidgets('desktop light: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpDischargeReady(
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

      expectFlatSections(tester);

      await tester.tap(find.text('Dana Discharge Billing'));
      await tester.pumpAndSettle();

      expect(find.byType(AppWorkspaceDetailPanel), findsWidgets);
      expect(find.byType(AppQuickActions), findsOneWidget);
      expectFlatSections(tester);
    });

    testWidgets('mobile dark: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpDischargeReady(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
        physicalSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      await tester.tap(find.text('Dana Discharge Billing'));
      await tester.pumpAndSettle();

      expectFlatSections(tester);
    });
  });
}
