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
import 'package:hosspi_hms/features/nursing/data/repositories/nursing_repository_impl.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/repositories/nursing_repository.dart';
import 'package:hosspi_hms/features/nursing/presentation/pages/nursing_workspace_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNursingRepository extends Mock implements NursingRepository {}

const NursingPatientSummary _routinePatient = NursingPatientSummary(
  id: 'adm-routine',
  admissionId: 'adm-routine',
  displayId: 'ADM-ROUTINE',
  patientDisplayId: 'PT-ROUTINE',
  patientDisplayName: 'Routine Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward A',
  bedDisplayLabel: 'Bed 1',
  hasActiveBed: true,
);

const NursingPatientSummary _medDuePatient = NursingPatientSummary(
  id: 'adm-med',
  admissionId: 'adm-med',
  displayId: 'ADM-MED',
  patientDisplayId: 'PT-MED',
  patientDisplayName: 'Med Due Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward B',
  bedDisplayLabel: 'Bed 2',
  hasActiveBed: true,
  medicationDueCount: 2,
);

const NursingPatientSummary _urgentPatient = NursingPatientSummary(
  id: 'adm-urgent',
  admissionId: 'adm-urgent',
  displayId: 'ADM-URGENT',
  patientDisplayId: 'PT-URGENT',
  patientDisplayName: 'Urgent Patient',
  stage: 'ADMITTED_IN_BED',
  admissionStatus: 'ADMITTED_IN_BED',
  wardDisplayName: 'Ward C',
  bedDisplayLabel: 'Bed 3',
  hasActiveBed: true,
  hasCriticalAlert: true,
  criticalSeverity: 'CRITICAL',
);

const List<NursingPatientSummary> _allPatients = <NursingPatientSummary>[
  _routinePatient,
  _medDuePatient,
  _urgentPatient,
];

AppAccessPolicy _nursingWritePolicy() {
  // Entitlements must cover both the nursing route module and the permission
  // domain modules (clinical → encounters-vitals, patient → patient-registry)
  // or fromSession strips write rights and AppAccessActionGate hides CTAs.
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['NURSE']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
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
        AppModuleEntitlement(code: 'patient-registry', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}

List<NursingPatientSummary> _itemsForQuery(NursingWorklistQuery query) {
  List<NursingPatientSummary> items = List<NursingPatientSummary>.of(
    _allPatients,
  );
  items = items
      .where((NursingPatientSummary item) => item.matchesScope(query.scope))
      .toList(growable: false);
  final String search = query.search.trim().toLowerCase();
  if (search.isNotEmpty) {
    items = items
        .where((NursingPatientSummary item) => item.matchesSearch(search))
        .toList(growable: false);
  }
  return items;
}

void _stubNursingRepository(_MockNursingRepository repository) {
  when(() => repository.listWardPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingWorklistQuery query =
        invocation.positionalArguments.single as NursingWorklistQuery;
    final List<NursingPatientSummary> items = _itemsForQuery(query);
    return Result<AppPage<NursingPatientSummary>>.success(
      AppPage<NursingPatientSummary>(
        items: items,
        request: query.pageRequest,
        totalItemCount: items.length,
      ),
    );
  });
  when(() => repository.listPendingHandovers()).thenAnswer(
    (_) async =>
        const Result<List<NursingHandover>>.success(<NursingHandover>[]),
  );
  when(() => repository.listCurrentRosters()).thenAnswer(
    (_) async => const Result<List<NursingRosterAssignment>>.success(
      <NursingRosterAssignment>[],
    ),
  );
  when(() => repository.loadPatientDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final NursingPatientSummary summary =
        invocation.positionalArguments.single as NursingPatientSummary;
    return Result<NursingPatientDetail>.success(
      NursingPatientDetail(summary: summary),
    );
  });
}

class _Harness {
  const _Harness({required this.repository, required this.router});

  final _MockNursingRepository repository;
  final GoRouter router;
}

Future<_Harness> _pumpNursingWorkspace(
  WidgetTester tester, {
  required _MockNursingRepository repository,
  NursingWorkspaceQuery? initialQuery,
  String initialLocation = '/nursing',
  Size physicalSize = const Size(1440, 900),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  _stubNursingRepository(repository);

  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/nursing',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: NursingWorkspacePage(
              initialQuery:
                  initialQuery ?? NursingWorkspaceQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nursingRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        appAccessPolicyProvider.overrideWithValue(_nursingWritePolicy()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // Adaptive polling keeps timers alive, so avoid pumpAndSettle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
  return _Harness(repository: repository, router: router);
}

Future<void> _pumpAfterAction(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late _MockNursingRepository repository;

  setUpAll(() {
    registerFallbackValue(const NursingWorklistQuery());
    registerFallbackValue(_routinePatient);
  });

  setUp(() {
    repository = _MockNursingRepository();
  });

  testWidgets('renders table search chrome with Filters and Settings', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    expect(find.text(l10n.nursingAdvancedFiltersLabel), findsOneWidget);
    expect(find.text(l10n.commonTableSettingsActionLabel), findsOneWidget);
    expect(find.text(l10n.nursingNextActionColumnLabel), findsWidgets);
    expect(find.byTooltip(l10n.nursingActionRecordVitals), findsWidgets);
  });

  testWidgets('renders tab strip and default primary action', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppWorkspaceToolbar), findsNothing);
    expect(find.textContaining('All'), findsWidgets);
    expect(find.textContaining('Urgent'), findsWidgets);
    expect(find.textContaining('Medication due'), findsWidgets);
    expect(find.byTooltip('Record vitals'), findsWidgets);
    expect(find.byTooltip('Shift context'), findsOneWidget);
    expect(find.byTooltip('Add note'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.text('Routine Patient'), findsOneWidget);
    expect(find.text('Med Due Patient'), findsOneWidget);
  });

  testWidgets('does not paint a dedicated nursing title header', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(tester, repository: repository);
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(AppTabStrip)),
    );

    expect(find.text(l10n.nursingTitle), findsNothing);
    expect(find.byType(AppWorkspaceHeader), findsNothing);
  });

  testWidgets('switching tabs updates scope query parameter', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNursingWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Urgent').first);
    await _pumpAfterAction(tester);

    expect(harness.router.state.uri.queryParameters['scope'], 'urgent');
    expect(find.byTooltip('Record vitals'), findsWidgets);
    expect(find.text('Urgent Patient'), findsOneWidget);
    expect(find.text('Routine Patient'), findsNothing);
  });

  testWidgets('medication due tab updates primary action and columns', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNursingWorkspace(
      tester,
      repository: repository,
    );

    await tester.tap(find.textContaining('Medication due').first);
    await _pumpAfterAction(tester);

    expect(harness.router.state.uri.queryParameters['scope'], 'medication-due');
    expect(find.byTooltip('Administer medication'), findsWidgets);
    expect(find.text('Med Due Patient'), findsOneWidget);
    expect(find.text('Routine Patient'), findsNothing);
  });

  testWidgets('deep link scope=urgent selects urgent tab', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNursingWorkspace(
      tester,
      repository: repository,
      initialLocation: '/nursing?scope=urgent',
      initialQuery: NursingWorkspaceQuery.fromUri(
        Uri.parse('/nursing?scope=urgent'),
      ),
    );

    expect(harness.router.state.uri.queryParameters['scope'], 'urgent');
    expect(find.text('Urgent Patient'), findsOneWidget);
    expect(find.text('Routine Patient'), findsNothing);
  });

  testWidgets('default route lands on All without scope param', (
    WidgetTester tester,
  ) async {
    final _Harness harness = await _pumpNursingWorkspace(
      tester,
      repository: repository,
    );

    expect(
      harness.router.state.uri.queryParameters.containsKey('scope'),
      isFalse,
    );
    expect(find.byTooltip('Record vitals'), findsWidgets);
  });

  testWidgets('tab switch applies scope via repository', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(tester, repository: repository);

    clearInteractions(repository);
    _stubNursingRepository(repository);

    await tester.tap(find.textContaining('Medication due').first);
    await _pumpAfterAction(tester);

    final List<NursingWorklistQuery> queries = verify(
      () => repository.listWardPatients(captureAny()),
    ).captured.cast<NursingWorklistQuery>();
    expect(
      queries.any(
        (NursingWorklistQuery query) =>
            query.scope == NursingQueueScope.medicationDue,
      ),
      isTrue,
    );
  });

  testWidgets('mobile breakpoint uses list tiles instead of data table', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(
      tester,
      repository: repository,
      physicalSize: const Size(390, 844),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.text('Routine Patient'), findsOneWidget);
  });

  testWidgets('tapping a row opens the nursing detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpNursingWorkspace(tester, repository: repository);

    await tester.tap(find.text('Routine Patient'));
    await _pumpAfterAction(tester);

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    verify(
      () => repository.loadPatientDetail(any()),
    ).called(greaterThanOrEqualTo(1));
  });
}
