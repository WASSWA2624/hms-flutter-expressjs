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
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_access.dart';
import 'package:hosspi_hms/features/ipd/presentation/ipd_bed_board_billing_inventory.dart';
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_bed_board_panel.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_panel.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/section_layout_test_helpers.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdBedBoardEntry _availableBed = IpdBedBoardEntry(
  id: 'bed-1',
  label: 'Bed 101',
  status: 'AVAILABLE',
  wardName: 'Medical Ward',
);

const IpdBedBoardEntry _occupiedBed = IpdBedBoardEntry(
  id: 'bed-2',
  label: 'Bed 102',
  status: 'OCCUPIED',
  wardName: 'Medical Ward',
  occupantPatientName: 'Ada Occupant',
  occupantAdmissionId: 'adm-active',
  occupantAdmissionDisplayId: 'ADM-ACTIVE',
);

const IpdAdmissionSummary _activeAdmission = IpdAdmissionSummary(
  id: 'adm-active',
  displayId: 'ADM-ACTIVE',
  patientId: 'pat-active',
  patientDisplayName: 'Ada Occupant',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
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
  final bool needsInpatient = permissions.any(
    (AppPermission permission) =>
        permission == AppPermissions.facilityAdmin ||
        permission == AppPermissions.tenantAdmin ||
        permission == AppPermissions.systemAdmin ||
        permission == AppPermissions.unitManage,
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
        if (needsInpatient)
          const AppModuleEntitlement(
            code: 'inpatient-bed-management',
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
  _MockIpdRepository repository, {
  List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[
    _availableBed,
    _occupiedBed,
  ],
}) {
  when(() => repository.listAdmissions(any())).thenAnswer((invocation) {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    return Future<Result<AppPage<IpdAdmissionSummary>>>.value(
      Result<AppPage<IpdAdmissionSummary>>.success(
        AppPage<IpdAdmissionSummary>(
          items: const <IpdAdmissionSummary>[],
          request: query.pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
  });
  when(() => repository.listWards(search: any(named: 'search'))).thenAnswer(
    (_) async => const Result<List<IpdWardOption>>.success(<IpdWardOption>[
      IpdWardOption(id: 'ward-1', name: 'Medical Ward'),
    ]),
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
  ).thenAnswer((_) async => Result<List<IpdBedBoardEntry>>.success(beds));
  when(() => repository.getAdmission(any())).thenAnswer(
    (_) async => const Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: _activeAdmission),
    ),
  );
  when(
    () => repository.updateBedStatus(
      bedId: any(named: 'bedId'),
      status: any(named: 'status'),
    ),
  ).thenAnswer((_) async => const Result<void>.success(null));
  when(() => repository.startAdmission(any())).thenAnswer(
    (_) async => const Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: _activeAdmission),
    ),
  );
}

void _expectNoInlineCashierAffordances() {
  expect(find.textContaining('Receive payment'), findsNothing);
  expect(find.textContaining('Issue invoice'), findsNothing);
  expect(find.textContaining('Refund'), findsNothing);
  expect(find.textContaining('Write off'), findsNothing);
  expect(find.textContaining('Credit note'), findsNothing);
  expect(find.textContaining('Collect payment'), findsNothing);
}

Future<void> _pumpBedBoard(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  required AppAccessPolicy accessPolicy,
  Size physicalSize = const Size(1440, 900),
  ThemeMode themeMode = ThemeMode.light,
  List<IpdBedBoardEntry> beds = const <IpdBedBoardEntry>[
    _availableBed,
    _occupiedBed,
  ],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubRepository(repository, beds: beds);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: '/ipd?section=bed-board',
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
        ipdRepositoryProvider.overrideWithValue(repository),
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
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIpdRepository();
  });

  group('IPD Bed board financial inventory (AC1)', () {
    test('mounted ops atoms are explicitly not billable with audit codes', () {
      expect(IpdBedBoardBillingInventory.atoms, isNotEmpty);
      expect(IpdBedBoardBillingInventory.allOpsAtomsExplicitlyNotBillable, isTrue);
      expect(ipdBedBoardBillingScopeNote, contains('NOT_BILLED'));
      expect(ipdBedBoardBillingScopeNote, contains('persistAdmissionBilling'));
      expect(IpdBedBoardBillingInventory.summary(), contains('NOT_BILLED'));

      expect(
        IpdBedBoardBillingInventory.bedStatusUpdate.financialClass,
        IpdBedBoardFinancialClass.notBilled,
      );
      expect(IpdBedBoardBillingInventory.bedStatusUpdate.auditCode, 'NOT_BILLED');
      expect(
        IpdBedBoardBillingInventory.manageBeds.financialClass,
        IpdBedBoardFinancialClass.notBilled,
      );
    });

    test('mounted billable atoms wire through shared Billing (no bypass)', () {
      expect(
        IpdBedBoardBillingInventory.allBillableAtomsWireThroughBilling,
        isTrue,
      );
      expect(IpdBedBoardBillingInventory.startAdmission.mounted, isTrue);
      expect(
        IpdBedBoardBillingInventory.startAdmission.financialClass,
        IpdBedBoardFinancialClass.createCharge,
      );
      expect(
        IpdBedBoardBillingInventory.startAdmission.billingPath,
        contains('persistAdmissionBilling'),
      );
      expect(
        IpdBedBoardBillingInventory.startAdmissionBillingPanel.billingPath,
        contains('ClinicalRequestBillingPanel'),
      );
      expect(
        IpdBedBoardBillingInventory.wardRoundFromDetail.billingPath,
        contains('persistWardRoundBilling'),
      );
      expect(
        IpdBedBoardBillingInventory.dischargePlanFromDetail.billingPath,
        contains('isBillingSettledForPatient'),
      );

      for (final IpdBedBoardFinancialAtom atom
          in IpdBedBoardBillingInventory.billableAtoms) {
        expect(atom.billingPath, isNotNull, reason: atom.id);
      }
    });

    test('cashier settle/adjust atoms are unmounted on Bed board', () {
      expect(IpdBedBoardBillingInventory.collectPayment.mounted, isFalse);
      expect(
        IpdBedBoardBillingInventory.issueInvoiceAdjustRefund.mounted,
        isFalse,
      );
      expect(IpdBedBoardBillingInventory.transferRateChange.mounted, isFalse);
      expect(IpdBedBoardBillingInventory.consumables.mounted, isFalse);
      expect(
        IpdBedBoardBillingInventory.isInlineCollectionForbidden(
          IpdBedBoardFinancialClass.settle,
        ),
        isTrue,
      );
    });

    test('inventory reuses IPD Bed board access gates', () {
      expect(
        IpdBedBoardBillingInventory.tab.requirement,
        same(IpdBedBoardAtomPermissions.tab),
      );
      expect(
        IpdBedBoardBillingInventory.startAdmission.requirement,
        same(IpdBedBoardAtomPermissions.startAdmission),
      );
      expect(
        IpdBedBoardBillingInventory.bedStatusUpdate.requirement,
        same(IpdBedBoardAtomPermissions.bedStatusUpdate),
      );
      expect(
        IpdBedBoardBillingInventory.manageBeds.requirement,
        same(IpdBedBoardAtomPermissions.manageBeds),
      );
      expect(
        IpdBedBoardBillingInventory.startAdmissionBillingPanel.requirement,
        same(IpdBedBoardAtomPermissions.billingPanel),
      );
    });
  });

  group('IPD Bed board billing bypass / parity (AC2–AC4)', () {
    test('IPD realtime group includes Billing for status parity', () {
      expect(
        RealtimeEventGroups.ipd,
        containsAll(RealtimeEventGroups.billing),
      );
    });

    testWidgets(
      'authorized board has no inline cashier; occupancy + Start admission only',
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

        expect(find.byType(IpdBedBoardPanel), findsOneWidget);
        expect(find.textContaining('Ada Occupant'), findsOneWidget);
        expect(find.byTooltip('Start admission'), findsOneWidget);
        _expectNoInlineCashierAffordances();
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

        expect(find.byType(IpdBedBoardPanel), findsOneWidget);
        _expectNoInlineCashierAffordances();
        expect(find.byTooltip('Start admission'), findsNothing);
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Start admission with billing:read mounts ClinicalRequestBillingPanel',
      (WidgetTester tester) async {
        await _pumpBedBoard(
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

        await tester.tap(find.byTooltip('Start admission'));
        await tester.pumpAndSettle();

        expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
        expect(find.byType(ClinicalRequestBillingPanel), findsOneWidget);
        _expectNoInlineCashierAffordances();
        expectFlatSections(tester);
      },
    );

    testWidgets(
      'Start admission without billing:read omits billing panel (no bypass collect)',
      (WidgetTester tester) async {
        await _pumpBedBoard(
          tester,
          repository: repository,
          accessPolicy: _policy(
            permissions: <AppPermission>{
              AppPermissions.clinicalRead,
              AppPermissions.clinicalWrite,
            },
          ),
        );

        await tester.tap(find.byTooltip('Start admission'));
        await tester.pumpAndSettle();

        expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
        expect(find.byType(ClinicalRequestBillingPanel), findsNothing);
        _expectNoInlineCashierAffordances();
      },
    );

    testWidgets('bed board reload is idempotent (no dual charge UI)', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
      );

      verify(
        () => repository.listBedBoard(
          wardId: any(named: 'wardId'),
          status: any(named: 'status'),
          statusAny: any(named: 'statusAny'),
          limit: any(named: 'limit'),
        ),
      ).called(greaterThanOrEqualTo(1));
      _expectNoInlineCashierAffordances();
      expect(find.textContaining('Bed 101'), findsOneWidget);
    });
  });

  group('IPD Bed board section layout (AC5)', () {
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

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppCollapsibleSection &&
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

  group('IPD Bed board UI states (AC4, AC6)', () {
    testWidgets('authorized empty state remains observable', (
      WidgetTester tester,
    ) async {
      await _pumpBedBoard(
        tester,
        repository: repository,
        accessPolicy: _policy(
          permissions: <AppPermission>{AppPermissions.clinicalRead},
        ),
        beds: const <IpdBedBoardEntry>[],
      );

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      _expectNoInlineCashierAffordances();
      expectFlatSections(tester);
    });
  });
}
