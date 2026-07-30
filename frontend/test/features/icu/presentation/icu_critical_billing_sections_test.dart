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
import 'package:hosspi_hms/features/icu/presentation/icu_critical_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _criticalPatient = IcuPatientSummary(
  id: 'ADM-CRIT-BILL-1',
  admissionId: 'ADM-CRIT-BILL-1',
  displayId: 'ADMCRITBILL1',
  patientId: 'patient-uuid-crit-bill',
  patientDisplayName: 'Critical Billing Patient',
  icuStatus: 'ACTIVE',
  hasCriticalAlert: true,
  criticalSeverity: 'HIGH',
  bedLabel: 'ICU-2',
  encounterId: 'ENC-CRIT-BILL-1',
  sourceKind: 'EMERGENCY',
);

const IcuCriticalAlert _latestAlert = IcuCriticalAlert(
  id: 'ALERT-BILL-1',
  severity: 'HIGH',
  message: 'Hypotension',
);

const IcuPatientDetail _criticalDetail = IcuPatientDetail(
  summary: _criticalPatient,
  activeStay: IcuStaySummary(id: 'STAY-CRIT-BILL-1'),
  alerts: <IcuCriticalAlert>[_latestAlert],
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
}) {
  final bool needsClinical = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.clinicalWrite ||
        permission == AppPermissions.clinicalRead,
  );
  final bool needsEmergency = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.emergencyWrite ||
        permission == AppPermissions.emergencyRead,
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
        roles: <String>['NURSE'],
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

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_criticalPatient],
  IcuPatientDetail detail = _criticalDetail,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> filtered = items;
    if (query.scope == IcuBoardScope.critical) {
      filtered = items
          .where((IcuPatientSummary item) => item.hasCriticalAlert)
          .toList(growable: false);
    }
    return Future<Result<AppPage<IcuPatientSummary>>>.value(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: filtered,
          request: query.pageRequest,
          totalItemCount: filtered.length,
        ),
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(repository.loadBedBoard).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => Result<IcuPatientDetail>.success(detail),
  );
}

Future<void> _pumpCriticalTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_criticalPatient],
  IcuPatientDetail detail = _criticalDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=critical',
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
            body: Text('Billing workspace ${state.uri.query}'),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        icuRepositoryProvider.overrideWithValue(repository),
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
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
    registerFallbackValue(_criticalDetail);
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('ICU Critical billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(IcuCriticalBillingInventory.all, isNotEmpty);
      expect(
        IcuCriticalBillingInventory.all.map(
          (IcuCriticalFinancialAtom a) => a.id,
        ),
        containsAll(<String>[
          'tab',
          'alert_column',
          'next_action_acknowledge',
          'acknowledge_alert',
          'start_stay',
          'round_note',
          'order_lab',
          'order_imaging',
          'prescribe',
          'mark_readiness',
          'billing_deferred_badge',
          'open_billing',
          'collect_payment',
          'adjust_refund',
        ]),
      );
      expect(
        IcuCriticalBillingInventory.scopeNote,
        contains('persistIcuStayBilling'),
      );

      for (final IcuCriticalFinancialAtom atom
          in IcuCriticalBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == IcuCriticalFinancialClass.createCharge ||
            atom.financialClass == IcuCriticalFinancialClass.settle ||
            atom.financialClass == IcuCriticalFinancialClass.adjust ||
            atom.financialClass == IcuCriticalFinancialClass.reverse ||
            atom.financialClass == IcuCriticalFinancialClass.defer;
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
        IcuCriticalBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(
        IcuCriticalBillingInventory.startStay.billingPath,
        contains('persistIcuStayBilling'),
      );
      expect(
        IcuCriticalBillingInventory.acknowledgeAlert.financialClass,
        IcuCriticalFinancialClass.notBilled,
      );
      expect(
        IcuCriticalBillingInventory.nextActionAcknowledge.auditCode,
        'NOT_BILLED',
      );
    });

    test('cashier settle/adjust atoms are unmounted on Critical', () {
      expect(IcuCriticalBillingInventory.collectPayment.mounted, isFalse);
      expect(IcuCriticalBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IcuCriticalBillingInventory.isInlineCollectionForbidden(
          IcuCriticalFinancialClass.settle,
        ),
        isTrue,
      );
      expect(
        IcuCriticalAtomPermissions.openBilling,
        same(icuBillingReadRequirement),
      );
    });
  });

  group('ICU Critical billing wiring (AC2-AC4)', () {
    test('workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.icu,
        containsAll(RealtimeEventGroups.billing),
      );
      expect(
        RealtimeEventGroups.icu,
        containsAll(RealtimeEventGroups.criticalAlerts),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect — mobile dark',
      (WidgetTester tester) async {
        await _pumpCriticalTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        expect(find.text('Critical Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Critical Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsNothing);
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
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Critical Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(
          IcuCriticalAtomPermissions.openBilling.isAllowed(
            _policy(
              permissions: <AppPermission>{
                AppPermissions.clinicalRead,
                AppPermissions.billingRead,
              },
            ),
          ),
          isTrue,
        );

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id=patient-uuid-crit-bill'),
          findsOneWidget,
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
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.textContaining('Critical'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });
  });

  group('ICU Critical section layout (AC5)', () {
    testWidgets('desktop Critical: flat sibling sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
        physicalSize: const Size(1920, 1200),
      );
      expectFlatSections(tester);

      await tester.tap(find.text('Critical Billing Patient'));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
      expect(find.textContaining('Critical alerts'), findsWidgets);
    });

    testWidgets('mobile Critical: flat sections', (WidgetTester tester) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
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
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
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
            AppPermissions.clinicalRead,
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

  group('ICU Critical UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpCriticalTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        items: const <IcuPatientSummary>[],
      );

      expect(find.textContaining('Critical'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expectFlatSections(tester);
    });

    test('unauthorized billing write requirement stays on Billing workspace', () {
      final AppAccessPolicy clinicalOnly = _policy(
        permissions: <AppPermission>{
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(
        IcuCriticalAtomPermissions.openBilling.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        billingWorkspaceWriteRequirement.isAllowed(clinicalOnly),
        isFalse,
      );
      expect(
        IcuCriticalBillingInventory.collectPayment.requirement.isAllowed(
          clinicalOnly,
        ),
        isFalse,
      );
    });
  });
}
