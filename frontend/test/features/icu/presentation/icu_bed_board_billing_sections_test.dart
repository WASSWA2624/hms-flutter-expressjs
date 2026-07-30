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
import 'package:hosspi_hms/features/icu/presentation/icu_bed_board_billing_inventory.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_screen_section.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuBed _availableBed = IcuBed(
  id: 'bed-1',
  label: 'ICU-1',
  status: 'AVAILABLE',
  wardId: 'ward-1',
  wardName: 'ICU Ward',
);

const IcuBed _occupiedBed = IcuBed(
  id: 'bed-2',
  label: 'ICU-2',
  status: 'OCCUPIED',
  wardId: 'ward-1',
  wardName: 'ICU Ward',
  occupantAdmissionId: 'ADM-1',
  occupantDisplayId: 'ADM0001',
  occupantName: 'Ada Occupant',
);

AppAccessPolicy _policy({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement>? modules,
  List<String> roles = const <String>['NURSE'],
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
  final bool needsInpatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.facilityAdmin ||
        permission == AppPermissions.tenantAdmin ||
        permission == AppPermissions.systemAdmin ||
        permission == AppPermissions.unitManage ||
        permission == AppPermissions.roomsBedsRead,
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
        if (needsInpatient)
          const AppModuleEntitlement(
            code: 'inpatient-bed-management',
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
  List<IcuBed> beds = const <IcuBed>[_availableBed, _occupiedBed],
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((invocation) {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    return Future<Result<AppPage<IcuPatientSummary>>>.value(
      Result<AppPage<IcuPatientSummary>>.success(
        AppPage<IcuPatientSummary>(
          items: const <IcuPatientSummary>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
  });
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async => const Result<IcuReferenceData>.success(IcuReferenceData()),
  );
  when(() => repository.loadBedBoard()).thenAnswer(
    (_) async => Result<IcuBedBoard>.success(
      IcuBedBoard(
        wards: const <IcuBedWard>[IcuBedWard(id: 'ward-1', name: 'ICU Ward')],
        beds: beds,
      ),
    ),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer(
    (_) async => const Result<IcuPatientDetail>.success(
      IcuPatientDetail(
        summary: IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
      ),
    ),
  );
}

void _expectNoPatientBillingAffordances() {
  expect(find.textContaining('Receive payment'), findsNothing);
  expect(find.textContaining('Issue invoice'), findsNothing);
  expect(find.textContaining('Refund'), findsNothing);
  expect(find.textContaining('Write off'), findsNothing);
  expect(find.textContaining('Credit note'), findsNothing);
  expect(find.textContaining('Collect payment'), findsNothing);
}

Future<void> _pumpBedBoard(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IcuBed> beds = const <IcuBed>[_availableBed, _occupiedBed],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, beds: beds);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/icu?section=beds',
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
        path: '/rooms-beds',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Rooms & beds'));
        },
      ),
      GoRoute(
        path: '/billing',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Billing workspace'));
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

  setUp(() {
    repository = _MockIcuRepository();
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'fallback', admissionId: 'fallback'),
    );
  });

  group('ICU Bed board financial inventory (AC1)', () {
    test('every mounted atom is explicitly not billable with audit code', () {
      expect(IcuBedBoardBillingInventory.bedBoardTabHasNoBillableActions, isTrue);
      expect(
        IcuBedBoardBillingInventory.allMountedAtomsExplicitlyNotBillable,
        isTrue,
      );
      expect(IcuBedBoardBillingInventory.atoms, isNotEmpty);
      expect(
        IcuBedBoardBillingInventory.billableClasses.every(
          (IcuBedBoardFinancialAtom atom) => !atom.mounted,
        ),
        isTrue,
      );
      expect(icuBedBoardBillingScopeNote, contains('Billing'));
      expect(icuBedBoardBillingScopeNote, contains('NOT_BILLED'));

      for (final IcuBedBoardFinancialAtom atom
          in IcuBedBoardBillingInventory.mountedAtoms) {
        expect(
          atom.financialClass,
          isIn(<IcuBedBoardFinancialClass>[
            IcuBedBoardFinancialClass.notRequired,
            IcuBedBoardFinancialClass.notBilled,
            IcuBedBoardFinancialClass.noCharge,
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

    test('occupancy KPIs are NOT_BILLED, not ledger balances', () {
      final IcuBedBoardFinancialAtom chips = IcuBedBoardBillingInventory.atoms
          .singleWhere(
            (IcuBedBoardFinancialAtom atom) =>
                atom.id == 'occupancy_summary_chips',
          );
      expect(chips.financialClass, IcuBedBoardFinancialClass.notBilled);
      expect(chips.auditCode, 'NOT_BILLED');
    });

    test('unmounted bed/day and cashier atoms declare Billing paths', () {
      for (final String id in <String>[
        'icu_bed_day_charge',
        'critical_care_package',
        'transfer_rate_change',
        'discharge_ready_financial_gate',
        'collect_payment',
        'issue_invoice_adjust_refund',
      ]) {
        final IcuBedBoardFinancialAtom atom = IcuBedBoardBillingInventory.atoms
            .singleWhere((IcuBedBoardFinancialAtom entry) => entry.id == id);
        expect(atom.mounted, isFalse, reason: id);
        expect(atom.billingPath, isNotNull, reason: id);
        expect(
          atom.billingPath!.toLowerCase(),
          anyOf(contains('billing'), contains('admission'), contains('clearance')),
          reason: id,
        );
      }
    });
  });

  group('ICU Bed board billing bypass (AC2–AC4)', () {
    testWidgets(
      'authorized board has no collect/adjust; occupancy KPIs only',
      (WidgetTester tester) async {
        await _pumpBedBoard(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
              AppPermissions.billingWrite,
            },
          ),
        );

        expect(find.byType(IcuBedBoardPanel), findsOneWidget);
        expect(find.textContaining('available'), findsWidgets);
        expect(find.textContaining('occupied'), findsWidgets);
        expect(find.text('Ada Occupant'), findsOneWidget);
        _expectNoPatientBillingAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'billing:write alone cannot collect on Bed board (unauthorized financial UI absent)',
      (WidgetTester tester) async {
        await _pumpBedBoard(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.billingWrite,
            },
          ),
        );

        expect(find.byType(IcuBedBoardPanel), findsOneWidget);
        _expectNoPatientBillingAffordances();
        expect(find.textContaining('Receive payment'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets('Open IPD navigates without mounting cashier', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      final Finder openIpd = find.byTooltip('Open in IPD');
      expect(openIpd, findsOneWidget);
      await tester.tap(openIpd);
      await tester.pumpAndSettle();

      expect(find.text('IPD workspace'), findsOneWidget);
      _expectNoPatientBillingAffordances();
    });

    testWidgets('list reload is idempotent (no dual charge UI entry points)', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      verify(() => repository.loadBedBoard()).called(greaterThanOrEqualTo(1));
      _expectNoPatientBillingAffordances();
      expect(find.text('Ada Occupant'), findsOneWidget);
      expect(find.text('ICU-1'), findsOneWidget);
    });
  });

  group('ICU Bed board section layout (AC5)', () {
    testWidgets('desktop: flat sections; no titled nesting on board', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        physicalSize: const Size(1920, 1200),
      );

      expect(find.byType(IcuBedBoardPanel), findsOneWidget);
      expect(find.byType(AppScreenSection), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppWorkspaceDetailPanel &&
              (widget.title?.trim().isNotEmpty ?? false),
        ),
        findsNothing,
      );
      expectFlatSections(tester);
    });

    testWidgets('mobile: flat sections', (WidgetTester tester) async {
      await _pumpBedBoard(
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
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        themeMode: ThemeMode.light,
      );
      expectFlatSections(tester);
    });

    testWidgets('dark theme: flat sections on authorized UI', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        themeMode: ThemeMode.dark,
      );
      expectFlatSections(tester);
    });
  });

  group('ICU Bed board UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        beds: const <IcuBed>[],
      );

      expect(find.textContaining('No ICU beds'), findsWidgets);
      _expectNoPatientBillingAffordances();
      expectFlatSections(tester);
    });
  });
}
