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
import 'package:hosspi_hms/features/icu/presentation/icu_all_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/follow_up/scoped_follow_up_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _boardPatient = IcuPatientSummary(
  id: 'ADM-ALL-BILL-1',
  admissionId: 'ADM-ALL-BILL-1',
  displayId: 'ADM-ALL-BILL-1',
  patientId: 'patient-all-bill-1',
  patientDisplayName: 'All ICU Billing Patient',
  icuStatus: 'ACTIVE',
  hasActiveBed: true,
  encounterId: 'ENC-ALL-BILL-1',
  sourceKind: 'EMERGENCY',
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
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_boardPatient],
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
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
        activeStay: const IcuStaySummary(id: 'stay-all-bill-1'),
      ),
    );
  });
}

Future<void> _pumpAllTab(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuPatientSummary> items = const <IcuPatientSummary>[_boardPatient],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubBoard(repository, items: items);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  String? navigatedLocation;
  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=all',
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
          navigatedLocation = state.uri.toString();
          return Scaffold(
            body: Text('Billing workspace ${state.uri.query}'),
          );
        },
      ),
      GoRoute(
        path: '/ipd',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('IPD'));
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

  addTearDown(() {
    expect(
      navigatedLocation,
      anyOf(isNull, contains('/billing')),
      reason: 'navigation should only go to Billing when Open billing tapped',
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
    registerFallbackValue(
      const IcuPatientDetail(
        summary: IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
      ),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
  });

  group('ICU All billing inventory (AC1)', () {
    test('every atom is classified billable or explicit not-billable', () {
      expect(IcuAllBillingInventory.atoms, isNotEmpty);
      for (final IcuAllFinancialAtom atom in IcuAllBillingInventory.atoms) {
        expect(atom.id, isNotEmpty);
        expect(atom.label, isNotEmpty);
        if (atom.financialClass == IcuAllFinancialClass.notBilled ||
            atom.financialClass == IcuAllFinancialClass.notRequired ||
            atom.financialClass == IcuAllFinancialClass.noCharge) {
          expect(atom.auditCode, isNotNull);
        }
      }
    });

    test('billable mounted atoms reuse shared Billing paths', () {
      for (final IcuAllFinancialAtom atom
          in IcuAllBillingInventory.billableMounted) {
        expect(atom.billingPath, isNotNull);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(
            contains('billing'),
            contains('persist'),
            contains('lab'),
            contains('pharmacy'),
            contains('icu'),
            contains('discharge'),
            contains('admission'),
          ),
        );
      }
      expect(
        IcuAllBillingInventory.startStay.billingPath,
        contains('persistIcuStayBilling'),
      );
      expect(
        IcuAllBillingInventory.roundNote.billingPath,
        contains('persistWardRoundBilling'),
      );
    });

    test('settle/adjust never use inline collection on this tab', () {
      expect(
        IcuAllBillingInventory.forbidsInlineCashier(
          IcuAllFinancialClass.settle,
        ),
        isTrue,
      );
      expect(IcuAllBillingInventory.collectPayment.mounted, isFalse);
      expect(IcuAllBillingInventory.adjustRefund.mounted, isFalse);
      expect(
        IcuAllAtomPermissions.openBilling,
        same(icuBillingReadRequirement),
      );
      expect(
        IcuAllAtomPermissions.billingPanel,
        same(icuBillingPanelReadRequirement),
      );
    });
  });

  group('ICU All billing wiring (AC2-AC4)', () {
    test('ICU workspace realtime includes billing for status parity', () {
      expect(
        RealtimeEventGroups.icu,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'unauthorized cannot Open billing or collect (no bypass)',
      (WidgetTester tester) async {
        await _pumpAllTab(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{AppPermissions.clinicalRead},
          ),
          physicalSize: const Size(390, 844),
          themeMode: ThemeMode.dark,
        );

        await tester.tap(find.text('All ICU Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.text('Open billing'), findsNothing);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Refund'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Open billing navigates to Billing with patient_id — desktop light',
      (WidgetTester tester) async {
        await _pumpAllTab(
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

        await tester.tap(find.text('All ICU Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing deferred'), findsWidgets);
        expect(find.text('Open billing'), findsWidgets);
        expect(find.textContaining('Receive payment'), findsNothing);

        await tester.tap(find.text('Open billing').first);
        await tester.pumpAndSettle();

        expect(find.textContaining('Billing workspace'), findsOneWidget);
        expect(
          find.textContaining('patient_id='),
          findsOneWidget,
          reason: 'Open billing must deep-link patient into Billing workspace',
        );
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'list chrome has no cashier entry points — mobile dark',
      (WidgetTester tester) async {
        await _pumpAllTab(
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

        expect(find.text('All ICU Billing Patient'), findsOneWidget);
        expect(find.textContaining('Receive payment'), findsNothing);
        expect(find.textContaining('Issue invoice'), findsNothing);
        expectFlatSections(tester);
      },
    );
  });

  group('ICU All flat sections (AC5)', () {
    testWidgets(
      'detail panels are siblings — no section-in-section',
      (WidgetTester tester) async {
        await _pumpAllTab(
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

        await tester.tap(find.text('All ICU Billing Patient'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Critical'), findsWidgets);
        expectFlatSections(tester);
      },
    );
  });
}
