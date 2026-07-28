import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:hosspi_hms/features/ipd/presentation/pages/ipd_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_bed_board_panel.dart';
import 'package:hosspi_hms/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIpdRepository extends Mock implements IpdRepository {}

const IpdAdmissionSummary _queueAdmission = IpdAdmissionSummary(
  id: 'adm-queue',
  displayId: 'ADM-QUEUE',
  patientId: 'pat-queue',
  patientDisplayName: 'Quinn Queue',
  stage: 'ADMITTED_PENDING_BED',
  admissionStatus: 'ADMITTED',
);

const IpdAdmissionSummary _activeAdmission = IpdAdmissionSummary(
  id: 'adm-active',
  displayId: 'ADM-ACTIVE',
  patientId: 'pat-active',
  patientDisplayName: 'Ada Active',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED',
  hasActiveBed: true,
);

const IpdAdmissionSummary _transferAdmission = IpdAdmissionSummary(
  id: 'adm-transfer',
  displayId: 'ADM-XFER',
  patientId: 'pat-xfer',
  patientDisplayName: 'Terry Transfer',
  stage: 'TRANSFER_REQUESTED',
  admissionStatus: 'ADMITTED',
);

const IpdAdmissionSummary _dischargeAdmission = IpdAdmissionSummary(
  id: 'adm-discharge',
  displayId: 'ADM-DISC',
  patientId: 'pat-disc',
  patientDisplayName: 'Dana Discharge',
  stage: 'DISCHARGE_PLANNED',
  admissionStatus: 'ADMITTED',
);

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
  occupantPatientName: 'Ada Active',
  occupantAdmissionId: 'adm-active',
  occupantAdmissionDisplayId: 'ADM-ACTIVE',
);

AppAccessPolicy _ipdWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['DOCTOR']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.operationsWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

AppAccessPolicy _ipdBedManagePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['FACILITY_ADMIN']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.operationsWrite,
        AppPermissions.facilityAdmin,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'inpatient-bed-management',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'facilities-maintenance',
          licenseStatus: 'ACTIVE',
        ),
      ],
    ),
  );
}

List<IpdAdmissionSummary> _itemsForScope(IpdQueueScope scope) {
  return switch (scope) {
    IpdQueueScope.admissionQueue => <IpdAdmissionSummary>[_queueAdmission],
    IpdQueueScope.activePatients => <IpdAdmissionSummary>[_activeAdmission],
    IpdQueueScope.transferPending => <IpdAdmissionSummary>[_transferAdmission],
    IpdQueueScope.dischargePlanned => <IpdAdmissionSummary>[
      _dischargeAdmission,
    ],
    _ => <IpdAdmissionSummary>[
      _queueAdmission,
      _activeAdmission,
      _transferAdmission,
      _dischargeAdmission,
    ],
  };
}

void _stubRepository(_MockIpdRepository repository) {
  when(() => repository.listAdmissions(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IpdAdmissionQuery query =
        invocation.positionalArguments.single as IpdAdmissionQuery;
    List<IpdAdmissionSummary> items = _itemsForScope(query.scope);
    final String search = query.search.trim().toLowerCase();
    if (search.isNotEmpty) {
      items = items
          .where((IpdAdmissionSummary item) {
            final String name = (item.patientDisplayName ?? '').toLowerCase();
            final String id = (item.displayId ?? item.id).toLowerCase();
            return name.contains(search) || id.contains(search);
          })
          .toList(growable: false);
    }
    if (query.wardId != null) {
      items = items
          .where(
            (IpdAdmissionSummary item) => item.wardDisplayName == query.wardId,
          )
          .toList(growable: false);
    }
    return Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
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
  ).thenAnswer(
    (_) async => const Result<List<IpdBedBoardEntry>>.success(
      <IpdBedBoardEntry>[_availableBed, _occupiedBed],
    ),
  );
  when(() => repository.getAdmission(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.single as String;
    final IpdAdmissionSummary summary =
        <IpdAdmissionSummary>[
          _queueAdmission,
          _activeAdmission,
          _transferAdmission,
          _dischargeAdmission,
        ].firstWhere(
          (IpdAdmissionSummary item) => item.id == id || item.displayId == id,
          orElse: () => _queueAdmission,
        );
    return Result<IpdAdmissionDetail>.success(
      IpdAdmissionDetail(summary: summary),
    );
  });
}

Future<GoRouter> _pumpIpdWorkspace(
  WidgetTester tester, {
  required _MockIpdRepository repository,
  IpdAdmissionQuery? initialQuery,
  String initialLocation = '/ipd',
  Size viewport = const Size(1440, 900),
  AppAccessPolicy? accessPolicy,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = viewport;
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
              initialQuery:
                  initialQuery ?? IpdAdmissionQuery.fromUri(state.uri),
            ),
          );
        },
      ),
      GoRoute(
        path: '/rooms-beds',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(body: Text('Rooms & Beds'));
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
        appAccessPolicyProvider.overrideWithValue(
          accessPolicy ?? _ipdWritePolicy(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  late _MockIpdRepository repository;

  setUpAll(() {
    registerFallbackValue(const IpdAdmissionQuery());
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    repository = _MockIpdRepository();
    _stubRepository(repository);
  });

  testWidgets('renders tab strip with counts, table, and Start admission', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsOneWidget);
    expect(find.textContaining('Admission Queue'), findsWidgets);
    expect(find.textContaining('Active Patients'), findsWidgets);
    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.textContaining('Discharge'), findsWidgets);
    expect(find.textContaining('Bed board'), findsWidgets);
    expect(find.text('Quinn Queue'), findsOneWidget);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('switching tabs applies scope filters and updates URL', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpIpdWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubRepository(repository);

    await tester.tap(find.textContaining('Active Patients').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'active');
    List<IpdAdmissionQuery> queries = verify(
      () => repository.listAdmissions(captureAny()),
    ).captured.cast<IpdAdmissionQuery>();
    expect(
      queries.any(
        (IpdAdmissionQuery q) => q.scope == IpdQueueScope.activePatients,
      ),
      isTrue,
    );
    expect(find.text('Ada Active'), findsOneWidget);
    expect(find.text('Quinn Queue'), findsNothing);

    clearInteractions(repository);
    _stubRepository(repository);

    await tester.tap(find.textContaining('Transfers').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'transfers');
    queries = verify(
      () => repository.listAdmissions(captureAny()),
    ).captured.cast<IpdAdmissionQuery>();
    expect(
      queries.any(
        (IpdAdmissionQuery q) => q.scope == IpdQueueScope.transferPending,
      ),
      isTrue,
    );
    expect(find.text('Terry Transfer'), findsOneWidget);

    clearInteractions(repository);
    _stubRepository(repository);

    await tester.tap(find.textContaining('Discharge').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'discharge');
    expect(find.text('Dana Discharge'), findsOneWidget);
  });

  testWidgets('deep link section=active selects Active Patients tab', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      initialLocation: '/ipd?section=active',
      initialQuery: IpdAdmissionQuery.fromUri(Uri.parse('/ipd?section=active')),
    );

    final List<IpdAdmissionQuery> queries = verify(
      () => repository.listAdmissions(captureAny()),
    ).captured.cast<IpdAdmissionQuery>();
    expect(
      queries.any(
        (IpdAdmissionQuery q) => q.scope == IpdQueueScope.activePatients,
      ),
      isTrue,
    );
    expect(find.text('Ada Active'), findsOneWidget);
    expect(find.text('Quinn Queue'), findsNothing);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('deep link section=bed-board renders Bed Board panel', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      initialLocation: '/ipd?section=bed-board',
      initialQuery: IpdAdmissionQuery.fromUri(
        Uri.parse('/ipd?section=bed-board'),
      ),
    );

    expect(find.byType(IpdBedBoardPanel), findsOneWidget);
    expect(find.byType(AppListTable<IpdAdmissionSummary>), findsNothing);
    expect(find.byType(AppListTable<IpdBedBoardEntry>), findsOneWidget);
    verify(
      () => repository.listBedBoard(
        wardId: any(named: 'wardId'),
        status: any(named: 'status'),
        statusAny: any(named: 'statusAny'),
        limit: any(named: 'limit'),
      ),
    ).called(greaterThanOrEqualTo(1));
    // Doctor policy: Manage beds denied → Start admission remains primary.
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Live ward bed occupancy and operations.'), findsNothing);
  });

  testWidgets('Bed Board tab loads bed board and updates URL', (
    WidgetTester tester,
  ) async {
    final GoRouter router = await _pumpIpdWorkspace(
      tester,
      repository: repository,
    );
    clearInteractions(repository);
    _stubRepository(repository);

    await tester.tap(find.textContaining('Bed board').first);
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'bed-board');
    expect(find.byType(IpdBedBoardPanel), findsOneWidget);
    verify(
      () => repository.listBedBoard(
        wardId: any(named: 'wardId'),
        status: any(named: 'status'),
        statusAny: any(named: 'statusAny'),
        limit: any(named: 'limit'),
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets(
    'Bed board toolbar shows Manage beds for admins and hides panel header',
    (WidgetTester tester) async {
      await _pumpIpdWorkspace(
        tester,
        repository: repository,
        accessPolicy: _ipdBedManagePolicy(),
        initialLocation: '/ipd?section=bed-board',
        initialQuery: IpdAdmissionQuery.fromUri(
          Uri.parse('/ipd?section=bed-board'),
        ),
      );

      expect(find.byType(IpdBedBoardPanel), findsOneWidget);
      expect(find.byTooltip('Manage beds'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.byTooltip('Start admission'), findsOneWidget);
      expect(
        find.text('Live ward bed occupancy and operations.'),
        findsNothing,
      );
    },
  );

  testWidgets('switching to Bed board changes toolbar primary action', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      accessPolicy: _ipdBedManagePolicy(),
    );

    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.byTooltip('Manage beds'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);

    await tester.tap(find.textContaining('Bed board').first);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Manage beds'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Start admission'), findsOneWidget);
  });

  testWidgets('queue tabs do not expose Refresh in the tab toolbar', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.byTooltip('Start admission'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('admission worklist shows five default column headers', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    for (final String label in <String>[
      'Patient name',
      'Ward and bed',
      'Admitted',
      'Status',
      'Next action',
    ]) {
      expect(
        find.descendant(of: find.byType(DataTable), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('Role')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('Length of stay'),
      ),
      findsNothing,
    );
  });

  testWidgets('admission row tap opens detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    await tester.tap(find.text('Quinn Queue'));
    await tester.pumpAndSettle();

    expect(find.text('Admission detail'), findsOneWidget);
    verify(() => repository.getAdmission('adm-queue')).called(1);
  });

  testWidgets('bed board shows five default column headers', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      initialLocation: '/ipd?section=bed-board',
      initialQuery: IpdAdmissionQuery.fromUri(
        Uri.parse('/ipd?section=bed-board'),
      ),
    );

    for (final String label in <String>[
      'Bed',
      'Ward',
      'Current patient',
      'Status',
      'Next action',
    ]) {
      expect(
        find.descendant(of: find.byType(DataTable), matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text('Room')),
      findsNothing,
    );
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('occupied bed board row tap opens admission detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      initialLocation: '/ipd?section=bed-board',
      initialQuery: IpdAdmissionQuery.fromUri(
        Uri.parse('/ipd?section=bed-board'),
      ),
    );

    await tester.tap(find.text('Ada Active'));
    await tester.pumpAndSettle();

    expect(find.text('Admission detail'), findsOneWidget);
    verify(() => repository.getAdmission('adm-active')).called(1);
  });

  testWidgets('search filters table rows via applySearch', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubRepository(repository);

    await tester.enterText(find.byType(TextField).first, 'Quinn');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final List<IpdAdmissionQuery> queries = verify(
      () => repository.listAdmissions(captureAny()),
    ).captured.cast<IpdAdmissionQuery>();
    expect(queries.any((IpdAdmissionQuery q) => q.search == 'Quinn'), isTrue);
  });

  testWidgets('Start admission opens the admission dialog', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    await tester.tap(find.byTooltip('Start admission'));
    await tester.pumpAndSettle();

    expect(find.byType(IpdStartAdmissionDialog), findsOneWidget);
  });

  testWidgets('tab labels include counts when count is greater than zero', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(tester, repository: repository);

    expect(find.text('Admission Queue'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('AppTabStrip renders on narrow mobile viewport', (
    WidgetTester tester,
  ) async {
    await _pumpIpdWorkspace(
      tester,
      repository: repository,
      viewport: const Size(390, 844),
    );

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('Admission Queue'), findsWidgets);
    expect(find.textContaining('Bed board'), findsWidgets);
  });
}
