import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_access.dart';
import 'package:hosspi_hms/features/icu/presentation/icu_active_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _activePatient = IcuPatientSummary(
  id: 'ADM-ACTIVE-BILL-1',
  admissionId: 'ADM-ACTIVE-BILL-1',
  displayId: 'ADM-AB1',
  patientId: 'PAT-ACTIVE-BILL-1',
  patientDisplayName: 'Active Billing Patient',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-1',
  hasActiveBed: true,
  encounterId: 'ENC-ACTIVE-BILL-1',
  sourceKind: 'EMERGENCY',
);

const IcuPatientDetail _activeDetail = IcuPatientDetail(
  summary: _activePatient,
  activeStay: IcuStaySummary(id: 'stay-active-1'),
);

const IcuPatientSummary _needsStay = IcuPatientSummary(
  id: 'ADM-NEEDS-STAY-1',
  admissionId: 'ADM-NEEDS-STAY-1',
  displayId: 'ADM-NS1',
  patientId: 'PAT-NEEDS-STAY-1',
  patientDisplayName: 'Needs Stay Patient',
  icuStatus: 'NONE',
  hasActiveBed: true,
  encounterId: 'ENC-NEEDS-STAY-1',
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
  final bool needsBilling = permissions.contains(AppPermissions.billingRead);
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

void _stubRepository(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_activePatient],
  IcuPatientDetail detail = _activeDetail,
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    return Future<Result<AppPage<IcuPatientSummary>>>.value(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: items,
          request: query.pageRequest,
          totalItemCount: items.length,
        ),
      ),
    );
  });
  when(repository.loadReferenceData).thenAnswer(
    (_) async =>
        const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(repository.loadBedBoard).thenAnswer(
    (_) async => const Result<IcuBedBoard>.success(IcuBedBoard()),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => Result<IcuPatientDetail>.success(detail),
  );
}

Future<void> _pumpActiveTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_activePatient],
  IcuPatientDetail detail = _activeDetail,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, items: items, detail: detail);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu',
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
          final String? patientId =
              state.uri.queryParameters['patient_id'];
          return Scaffold(
            body: Text(
              patientId == null || patientId.isEmpty
                  ? 'Billing workspace'
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
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
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

  group('ICU Active billing inventory (AC1)', () {
    test('classifies every financially relevant atom', () {
      expect(IcuActiveBillingInventory.all, isNotEmpty);
      for (final IcuActiveFinancialAtom atom
          in IcuActiveBillingInventory.all) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        final bool billable =
            atom.financialClass == IcuActiveFinancialClass.createCharge ||
            atom.financialClass == IcuActiveFinancialClass.settle ||
            atom.financialClass == IcuActiveFinancialClass.adjust ||
            atom.financialClass == IcuActiveFinancialClass.reverse ||
            atom.financialClass == IcuActiveFinancialClass.defer;
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

    test('billable mounted atoms reuse shared Billing paths', () {
      for (final IcuActiveFinancialAtom atom
          in IcuActiveBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotEmpty);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(<Matcher>[
            contains('billing'),
            contains('persist'),
            contains('lab'),
            contains('radiology'),
            contains('pharmacy'),
            contains('ward-round'),
            contains('icu'),
            contains('discharge'),
            contains('admission'),
          ]),
        );
      }
    });

    test('inline cashier settle/adjust atoms are not mounted', () {
      expect(IcuActiveBillingInventory.collectPayment.mounted, isFalse);
      expect(IcuActiveBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IcuActiveBillingInventory.forbidsInlineCashier(
          IcuActiveFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('Open billing gate requires billing:read', () {
      expect(
        identical(
          IcuActiveIcuAtomPermissions.openBilling,
          icuBillingReadRequirement,
        ),
        isTrue,
      );
    });
  });

  group('ICU Active billing UX (AC2-AC4)', () {
    testWidgets(
      'authorized reader has no collect/adjust; Open billing requires billing:read',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
        );

        expect(find.text('Active Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expect(find.text('Open billing'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Active Billing Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:read shows Open billing (patient-scoped) without cashier',
      (WidgetTester tester) async {
        await _pumpActiveTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingRead,
            },
          ),
        );

        await tester.tap(find.text('Active Billing Patient'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);

        await tester.tap(find.text('Open billing'));
        await tester.pumpAndSettle();
        expect(
          find.text('Billing workspace patient=PAT-ACTIVE-BILL-1'),
          findsOneWidget,
        );
      },
    );

    testWidgets('list chrome has no redundant cashier entry points', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
          },
        ),
      );

      expect(find.textContaining('Active ICU'), findsWidgets);
      expect(find.textContaining('Receive payment'), findsNothing);
      expect(find.textContaining('Issue invoice'), findsNothing);
      expectFlatSections(tester);
    });

    testWidgets('start stay dialog shows ICU package/bed-day billing lines', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{
            AppPermissions.clinicalRead,
            AppPermissions.clinicalWrite,
            AppPermissions.billingRead,
          },
        ),
        items: const <IcuPatientSummary>[_needsStay],
        detail: const IcuPatientDetail(summary: _needsStay),
      );

      await tester.tap(find.text('Needs Stay Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Start ICU stay'), findsWidgets);
      await tester.tap(find.text('Start ICU stay').first);
      await tester.pumpAndSettle();

      expect(find.text('ICU critical-care package'), findsOneWidget);
      expect(find.text('ICU bed / day'), findsOneWidget);
      expectFlatSections(tester);
    });
  });

  group('ICU Active section layout (AC5)', () {
    testWidgets('desktop Active: flat sections on list + detail', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
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

      await tester.tap(find.text('Active Billing Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('mobile Active: flat sections', (WidgetTester tester) async {
      await _pumpActiveTab(
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
      await _pumpActiveTab(
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
      await tester.tap(find.text('Active Billing Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpActiveTab(
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
      await tester.tap(find.text('Active Billing Patient'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expectFlatSections(tester);
    });
  });
}
