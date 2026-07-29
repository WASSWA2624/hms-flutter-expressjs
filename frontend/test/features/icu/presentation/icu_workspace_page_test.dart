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
import 'package:hosspi_hms/features/icu/data/repositories/icu_repository_impl.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/domain/repositories/icu_repository.dart';
import 'package:hosspi_hms/features/icu/presentation/pages/icu_workspace_page.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_bed_board_panel.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_board_panel.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockIcuRepository extends Mock implements IcuRepository {}

const IcuPatientSummary _activePatient = IcuPatientSummary(
  id: 'ADM-1',
  admissionId: 'ADM-1',
  displayId: 'ADM0001',
  patientDisplayName: 'Ada Active',
  icuStatus: 'ACTIVE',
  bedLabel: 'ICU-1',
);

const IcuPatientSummary _criticalPatient = IcuPatientSummary(
  id: 'ADM-2',
  admissionId: 'ADM-2',
  displayId: 'ADM0002',
  patientDisplayName: 'Chris Critical',
  icuStatus: 'ACTIVE',
  hasCriticalAlert: true,
  criticalSeverity: 'HIGH',
  bedLabel: 'ICU-2',
);

AppAccessPolicy _icuWritePolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['DOCTOR']),
      permissions: <AppPermission>{
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
        AppPermissions.emergencyRead,
        AppPermissions.emergencyWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'icu-critical-care',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(
          code: 'encounters-vitals',
          licenseStatus: 'ACTIVE',
        ),
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void _stubBoard(
  _MockIcuRepository repository, {
  List<IcuPatientSummary> board = const <IcuPatientSummary>[
    _activePatient,
    _criticalPatient,
  ],
}) {
  when(() => repository.listIcuBoard(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IcuBoardQuery query =
        invocation.positionalArguments.single as IcuBoardQuery;
    List<IcuPatientSummary> items = board;
    if (query.scope == IcuBoardScope.critical) {
      items = board
          .where((IcuPatientSummary item) => item.hasCriticalAlert)
          .toList(growable: false);
    }
    if (query.search.trim().isNotEmpty) {
      final String needle = query.search.trim().toLowerCase();
      items = items
          .where((IcuPatientSummary item) => item.matchesSearch(needle))
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
      IcuBedBoard(
        wards: <IcuBedWard>[IcuBedWard(id: 'ward-1', name: 'ICU Ward')],
        beds: <IcuBed>[
          IcuBed(
            id: 'bed-1',
            label: 'ICU-1',
            status: 'AVAILABLE',
            wardId: 'ward-1',
            wardName: 'ICU Ward',
          ),
        ],
      ),
    ),
  );
  when(() => repository.loadIcuDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final IcuPatientSummary summary =
        invocation.positionalArguments.single as IcuPatientSummary;
    return Result<IcuPatientDetail>.success(IcuPatientDetail(summary: summary));
  });
}

Future<void> _pumpIcuWorkspace(
  WidgetTester tester, {
  required _MockIcuRepository repository,
  IcuBoardQuery? initialQuery,
  String initialLocation = '/icu',
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences preferences = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/icu',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: IcuWorkspacePage(
              initialQuery: initialQuery ?? IcuBoardQuery.fromUri(state.uri),
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
        appAccessPolicyProvider.overrideWithValue(_icuWritePolicy()),
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
}

AppListTable<IcuPatientSummary> _table(WidgetTester tester) {
  return tester.widget<AppListTable<IcuPatientSummary>>(
    find.byType(AppListTable<IcuPatientSummary>),
  );
}

void main() {
  late _MockIcuRepository repository;

  setUpAll(() {
    registerFallbackValue(const IcuBoardQuery());
    registerFallbackValue(
      const IcuPatientSummary(id: 'ADM-1', admissionId: 'ADM-1'),
    );
  });

  setUp(() {
    repository = _MockIcuRepository();
    _stubBoard(repository);
  });

  testWidgets('renders tab strip with section counts and patient table', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.byType(AppListTable<IcuPatientSummary>), findsOneWidget);
    expect(find.byType(IcuBoardPanel), findsOneWidget);
    expect(find.textContaining('Active ICU'), findsWidgets);
    expect(find.textContaining('Critical alerts'), findsWidgets);
    expect(find.textContaining('Transfers'), findsWidgets);
    expect(find.textContaining('Discharge ready'), findsWidgets);
    expect(find.textContaining('Ended stays'), findsWidgets);
    expect(find.textContaining('All ICU'), findsWidgets);
    expect(find.text('Ada Active'), findsOneWidget);
    expect(find.text('Chris Critical'), findsOneWidget);
    expect(find.byTooltip('Start ICU stay'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Assign ICU bed'), findsWidgets);
    expect(find.text('Acknowledge alert'), findsWidgets);
    expect(_table(tester).columnVisibilityLabel, 'Settings');
    expect(_table(tester).search?.advancedFilterButtonLabel, 'Filters');
    expect(_table(tester).columns.length, lessThanOrEqualTo(5));
  });

  testWidgets('deep link section=critical selects Critical tab', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(
      tester,
      repository: repository,
      initialLocation: '/icu?section=critical',
      initialQuery: IcuBoardQuery.fromUri(Uri.parse('/icu?section=critical')),
    );

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.critical),
      isTrue,
    );
    expect(find.text('Chris Critical'), findsOneWidget);
    expect(find.text('Ada Active'), findsNothing);
    expect(find.text('Alert'), findsWidgets);
    expect(find.byTooltip('Start ICU stay'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    expect(find.text('Acknowledge alert'), findsWidgets);
  });

  testWidgets('deep link section=beds shows bed board without toolbar actions', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(
      tester,
      repository: repository,
      initialLocation: '/icu?section=beds',
      initialQuery: IcuBoardQuery.fromUri(Uri.parse('/icu?section=beds')),
    );

    expect(find.byType(IcuBedBoardPanel), findsOneWidget);
    expect(find.byType(AppListTable<IcuPatientSummary>), findsNothing);
    expect(find.byType(IcuBoardPanel), findsNothing);
    expect(find.byTooltip('Start ICU stay'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
    verify(() => repository.loadBedBoard()).called(greaterThanOrEqualTo(1));
  });

  testWidgets('switching tabs calls applyScope with the correct scope', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubBoard(repository);

    await tester.tap(find.textContaining('Critical alerts').first);
    await tester.pumpAndSettle();

    final List<IcuBoardQuery> scopes = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(
      scopes.any((IcuBoardQuery q) => q.scope == IcuBoardScope.critical),
      isTrue,
    );
  });

  testWidgets('selecting Bed board tab renders IcuBedBoardPanel', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);

    await _selectOverflowTab(tester, 'Bed board');

    expect(find.byType(IcuBedBoardPanel), findsOneWidget);
    expect(find.byType(AppListTable<IcuPatientSummary>), findsNothing);
    expect(find.byTooltip('Start ICU stay'), findsNothing);
    expect(find.byTooltip('Refresh'), findsNothing);
  });

  testWidgets('search submits call applySearch via repository refresh', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);
    clearInteractions(repository);
    _stubBoard(repository);

    await tester.enterText(find.byType(TextField).first, 'Ada');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final List<IcuBoardQuery> queries = verify(
      () => repository.listIcuBoard(captureAny()),
    ).captured.cast<IcuBoardQuery>();
    expect(queries.any((IcuBoardQuery q) => q.search == 'Ada'), isTrue);
    expect(find.text('Ada Active'), findsOneWidget);
    expect(find.text('Chris Critical'), findsNothing);
  });

  testWidgets('row tap opens ICU detail dialog without next-action duplicate', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);

    await tester.tap(find.text('Ada Active'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsAtLeastNWidgets(1));
    expect(find.text('ICU STAY'), findsOneWidget);
    // Assign bed is the board next-action for Ada; detail must omit it.
    expect(
      find.descendant(
        of: find.byType(AppDialog),
        matching: find.text('Assign ICU bed'),
      ),
      findsNothing,
    );
    verify(
      () => repository.loadIcuDetail(any()),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('panel deep link opens vitals dialog without stay detail shell', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(
      tester,
      repository: repository,
      initialLocation: '/icu?id=ADM0001&panel=vitals',
      initialQuery: IcuBoardQuery.fromUri(
        Uri.parse('/icu?id=ADM0001&panel=vitals'),
      ),
    );

    expect(find.text('UPDATE VITALS'), findsOneWidget);
    expect(find.text('ICU STAY'), findsNothing);
    verify(
      () => repository.loadIcuDetail(any()),
    ).called(greaterThanOrEqualTo(1));
  });

  testWidgets('id deep link opens stay detail dialog', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(
      tester,
      repository: repository,
      initialLocation: '/icu?id=ADM0001',
      initialQuery: IcuBoardQuery.fromUri(Uri.parse('/icu?id=ADM0001')),
    );

    expect(find.text('ICU STAY'), findsOneWidget);
    expect(find.text('UPDATE VITALS'), findsNothing);
  });

  testWidgets('AppListTable uses icu_board column visibility storage key', (
    WidgetTester tester,
  ) async {
    await _pumpIcuWorkspace(tester, repository: repository);

    final AppListTable<IcuPatientSummary> table = _table(tester);
    expect(table.columnVisibilityStorageKey, 'icu_board');
    expect(table.columnWidthStorageKey, 'icu_cw_board');
    expect(table.columnVisibilityController, isNotNull);
    expect(table.columnVisibilityTitle, 'Table Settings');
    expect(table.search?.matcher(_activePatient, 'Ada'), isTrue);
    expect(table.search?.matcher(_criticalPatient, 'zzz'), isFalse);
  });
}

Future<void> _selectOverflowTab(WidgetTester tester, String label) async {
  final Finder direct = find.textContaining(label);
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct.first);
    await tester.pumpAndSettle();
    return;
  }
  await tester.tap(find.byTooltip('More tabs'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining(label).last);
  await tester.pumpAndSettle();
}
