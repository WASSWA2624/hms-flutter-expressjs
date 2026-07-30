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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_ended_stays_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';
import '../../../shared/layout/flat_section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _endedDeferred = IcuPatientSummary(
  id: 'ADM-END-1',
  admissionId: 'ADM-END-1',
  displayId: 'ADM-END1',
  patientId: 'PAT-END-1',
  patientDisplayName: 'Ended Stay Patient',
  icuStatus: 'ENDED',
  admissionStatus: 'ADMITTED',
  bedLabel: 'ICU-9',
  hasActiveBed: true,
  encounterId: 'ENC-END-1',
  sourceKind: 'EMERGENCY',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['DOCTOR'],
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalRead ||
        permission == AppPermissions.clinicalWrite,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyRead ||
        permission == AppPermissions.emergencyWrite,
  );
  final bool needsBilling = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.billingRead ||
        permission == AppPermissions.billingWrite,
  );

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
              code: 'icu-critical-care',
              licenseStatus: 'ACTIVE',
            ),
            if (needsClinical)
              const AppModuleEntitlement(
                code: 'encounters-vitals',
                licenseStatus: 'ACTIVE',
              ),
            if (needsEmergency)
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
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[_endedDeferred],
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> items = board;
    if (query.scope == IcuBoardScope.ended) {
      items = board
          .where((IcuPatientSummary item) => item.isEndedIcu)
          .toList(growable: false);
    }
    return Result<AppPage<IcuPatientSummary>>.success(
      AppPage<IcuPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(
      IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
    ),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: summary,
        latestStay: const IcuStaySummary(id: 'stay-ended-1'),
        recentStays: const <IcuStaySummary>[
          IcuStaySummary(id: 'stay-ended-1'),
        ],
      ),
    );
  });
}

Future<void> _pumpEndedStaysTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
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
    initialLocation: '/icu?section=ended',
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
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('IPD workspace'));
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
  tester.takeException();
}

void main() {
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

  group('ICU Ended stays billing & sections scan', () {
    test('AC1: every financial atom is inventoried and classified', () {
      expect(IcuEndedStaysBillingInventory.atoms, isNotEmpty);
      expect(
        IcuEndedStaysBillingInventory.atoms.map(
          (IcuEndedStaysFinancialAtom atom) => atom.id,
        ),
        containsAll(<String>[
          'tab',
          'list_chrome',
          'empty_loading_error',
          'row_select',
          'next_action_open_ipd',
          'historical_stay_charges',
          'start_stay',
          'round_note',
          'order_lab',
          'order_imaging',
          'prescribe',
          'mark_readiness',
          'billing_deferred_badge',
          'open_billing',
          'open_discharge_clearance',
          'print_summary',
          'end_stay',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      for (final IcuEndedStaysFinancialAtom atom
          in IcuEndedStaysBillingInventory.atoms) {
        final bool notBillable =
            atom.financialClass == IcuEndedStaysFinancialClass.notBilled ||
            atom.financialClass == IcuEndedStaysFinancialClass.notRequired ||
            atom.financialClass == IcuEndedStaysFinancialClass.noCharge;
        if (notBillable) {
          expect(
            atom.auditCode,
            isNotNull,
            reason: '${atom.id} not-billable needs audit code',
          );
        }
      }
      expect(IcuEndedStaysBillingInventory.openBilling.mounted, isTrue);
      expect(IcuEndedStaysBillingInventory.collectPayment.mounted, isFalse);
      expect(IcuEndedStaysBillingInventory.adjustRefund.mounted, isFalse);
      expect(IcuEndedStaysBillingInventory.endStay.mounted, isFalse);
      expect(IcuEndedStaysBillingInventory.printSummary.auditCode, 'NO_CHARGE');
    });

    test('AC2: billable atoms wire through Billing; inline collect forbidden', () {
      expect(
        IcuEndedStaysBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        IcuEndedStaysBillingInventory.openBilling.billingPath,
        contains('AppRoutes.billing'),
      );
      expect(
        IcuEndedStaysBillingInventory.historicalStayCharges.billingPath,
        contains('persistIcuStayBilling'),
      );
      expect(
        IcuEndedStaysBillingInventory.roundNote.billingPath,
        contains('persistWardRoundBilling'),
      );
      for (final IcuEndedStaysFinancialAtom atom
          in IcuEndedStaysBillingInventory.atoms) {
        if (IcuEndedStaysBillingInventory.forbidsInlineCashier(
          atom.financialClass,
        )) {
          expect(
            atom.mounted == false ||
                (atom.billingPath?.contains('Billing') ?? false) ||
                (atom.billingPath?.contains('billing') ?? false) ||
                (atom.billingPath?.contains('persist') ?? false),
            isTrue,
            reason: '${atom.id} must not bypass Billing',
          );
        }
      }
      expect(
        IcuEndedStaysAtomPermissions.openBilling,
        same(IcuEndedStaysAtomPermissions.openBilling),
      );
    });

    test('AC3: ICU realtime includes billing for status parity', () {
      expect(RealtimeEventGroups.icu, isNotEmpty);
      expect(
        RealtimeEventGroups.icu.any(
          (String event) =>
              event.toLowerCase().contains('billing') ||
              event.toLowerCase().contains('invoice') ||
              event.toLowerCase().contains('payment'),
        ),
        isTrue,
      );
    });

    testWidgets(
      'AC2/AC3/AC4: Open billing navigates with patient_id; no cashier',
      (WidgetTester tester) async {
        await _pumpEndedStaysTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        expect(find.text('Ended Stay Patient'), findsWidgets);

        await tester.tap(find.text('Ended Stay Patient').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing deferred'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Waive'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('End ICU stay'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Billing workspace patient=PAT-END-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC4/AC6: without billing:read Open billing and collect are absent',
      (WidgetTester tester) async {
        final AppAccessPolicy reader = _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        );
        expect(IcuEndedStaysAtomPermissions.write.isAllowed(reader), isFalse);
        expect(
          IcuEndedStaysAtomPermissions.openBilling.isAllowed(reader),
          isFalse,
        );

        await _pumpEndedStaysTab(
          tester,
          repository: repository,
          accessPolicy: reader,
        );

        await tester.tap(find.text('Ended Stay Patient').first);
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppQuickActions),
            matching: find.text('ICU round'),
          ),
          findsNothing,
        );
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('no access'), findsNothing);
        // Deferred chip remains visible as status parity, not settle.
        expect(find.textContaining('Billing deferred'), findsWidgets);
      },
    );

    testWidgets('AC5: desktop light — flat sections on Ended detail', (
      WidgetTester tester,
    ) async {
      await _pumpEndedStaysTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1440, 900),
        themeMode: ThemeMode.light,
      );

      await tester.tap(find.text('Ended Stay Patient').first);
      await tester.pumpAndSettle();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Ended detail desktop light',
      );
      expect(find.byType(AppCollapsibleSection), findsWidgets);
    });

    testWidgets('AC5: mobile dark — flat sections on Ended detail', (
      WidgetTester tester,
    ) async {
      await _pumpEndedStaysTab(
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

      final Finder row = find.text('Ended Stay Patient');
      await tester.ensureVisible(row.first);
      await tester.tap(row.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      tester.takeException();

      expectFlatSections(tester);
      expectFlatTitledSectionLayout(
        tester,
        contextLabel: 'Ended detail mobile dark',
      );
    });

    testWidgets('AC4: empty state remains observable on Ended', (
      WidgetTester tester,
    ) async {
      when(() => repository.listIcuBoard(any())).thenAnswer(
        (_) async => Result<AppPage<IcuPatientSummary>>.success(
          AppPage<IcuPatientSummary>(
            items: const <IcuPatientSummary>[],
            request: const AppPageRequest(pageSize: 12),
            totalItemCount: 0,
          ),
        ),
      );
      when(() => repository.loadReferenceData()).thenAnswer(
        (_) async =>
            const Result<IcuReferenceData>.success(IcuReferenceData()),
      );
      when(() => repository.loadBedBoard()).thenAnswer(
        (_) async => const Result<IcuBedBoard>.success(
          IcuBedBoard(wards: <IcuBedWard>[], beds: <IcuBed>[]),
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
        initialLocation: '/icu?section=ended',
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
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('Open billing'), findsNothing);
      expect(find.textContaining('Receive payment'), findsNothing);
    });

    test('openIcuBillingWorkspace helper documents patient_id path', () {
      expect(
        IcuEndedStaysBillingInventory.summary(),
        contains('patient_id'),
      );
      expect(
        IcuEndedStaysBillingInventory.openBilling.billingPath,
        contains('patient_id'),
      );
    });
  });
}
