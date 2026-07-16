import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/discharge/presentation/pages/discharge_workspace_page.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDischargeRepository extends Mock implements DischargeRepository {}

const IpdAdmissionSummary _planned = IpdAdmissionSummary(
  id: 'adm-planned',
  displayId: 'ADM-P1',
  patientDisplayName: 'Alice Planned',
  stage: 'DISCHARGE_PLANNED',
  dischargeStatus: 'PLANNED',
  wardDisplayName: 'Ward A',
  clearancePhase: 'MEDICATION_PENDING',
);

const IpdAdmissionSummary _pending = IpdAdmissionSummary(
  id: 'adm-pending',
  displayId: 'ADM-S1',
  patientDisplayName: 'Bob Pending',
  stage: 'ADMITTED',
  dischargeStatus: 'SUMMARY_PENDING',
  wardDisplayName: 'Ward B',
);

const IpdAdmissionSummary _completed = IpdAdmissionSummary(
  id: 'adm-done',
  displayId: 'ADM-C1',
  patientDisplayName: 'Carol Completed',
  stage: 'DISCHARGED',
  dischargeStatus: 'COMPLETED',
  wardDisplayName: 'Ward C',
);

void _stubQueue(
  _MockDischargeRepository repository, {
  List<IpdAdmissionSummary> items = const <IpdAdmissionSummary>[
    _planned,
    _pending,
    _completed,
  ],
}) {
  when(() => repository.listQueue(any())).thenAnswer(
    (_) async => Result<AppPage<IpdAdmissionSummary>>.success(
      AppPage<IpdAdmissionSummary>(
        items: items,
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: items.length,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<DischargeReferenceData>.success(DischargeReferenceData()),
  );
  when(() => repository.getAdmissionDetail(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final String id = invocation.positionalArguments.first as String;
    final IpdAdmissionSummary summary = items.firstWhere(
      (IpdAdmissionSummary item) =>
          item.id == id || item.displayId == id || item.apiId == id,
      orElse: () => items.first,
    );
    return Result<DischargeAdmissionDetail>.success(
      DischargeAdmissionDetail(ipd: IpdAdmissionDetail(summary: summary)),
    );
  });
}

Future<void> _pumpDischargeWorkspace(
  WidgetTester tester, {
  required _MockDischargeRepository repository,
  DischargeWorklistQuery? initialQuery,
  String initialLocation = '/discharge',
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
        path: '/discharge',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: DischargeWorkspacePage(
              initialQuery:
                  initialQuery ?? DischargeWorklistQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dischargeRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(preferences),
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
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
}

void main() {
  late _MockDischargeRepository repository;

  setUpAll(() {
    registerFallbackValue(const DischargeWorklistQuery());
  });

  setUp(() {
    repository = _MockDischargeRepository();
    _stubQueue(repository);
  });

  testWidgets('renders tab strip with section counts and all patients', (
    WidgetTester tester,
  ) async {
    await _pumpDischargeWorkspace(tester, repository: repository);

    expect(find.byType(AppTabStrip), findsOneWidget);
    expect(find.textContaining('All patients'), findsWidgets);
    expect(find.textContaining('Planned'), findsWidgets);
    expect(find.textContaining('Pending clearance'), findsWidgets);
    expect(find.textContaining('Completed'), findsWidgets);
    expect(find.text('Alice Planned'), findsOneWidget);
    expect(find.text('Bob Pending'), findsOneWidget);
    expect(find.text('Carol Completed'), findsOneWidget);
    expect(find.textContaining('Start discharge plan'), findsOneWidget);
  });

  testWidgets('deep link section=planned selects Planned tab', (
    WidgetTester tester,
  ) async {
    await _pumpDischargeWorkspace(
      tester,
      repository: repository,
      initialLocation: '/discharge?section=planned',
      initialQuery: DischargeWorklistQuery.fromUri(
        Uri.parse('/discharge?section=planned'),
      ),
    );

    expect(find.text('Alice Planned'), findsOneWidget);
    expect(find.text('Bob Pending'), findsNothing);
    expect(find.text('Carol Completed'), findsNothing);
    expect(find.textContaining('Manage clearance'), findsOneWidget);
  });

  testWidgets('switching tabs filters rows and updates primary action', (
    WidgetTester tester,
  ) async {
    await _pumpDischargeWorkspace(tester, repository: repository);

    await tester.tap(find.textContaining('Completed').first);
    await tester.pumpAndSettle();

    expect(find.text('Carol Completed'), findsOneWidget);
    expect(find.text('Alice Planned'), findsNothing);
    expect(find.text('Bob Pending'), findsNothing);
    expect(find.textContaining('Print discharge summary'), findsOneWidget);

    await tester.tap(find.textContaining('Pending clearance').first);
    await tester.pumpAndSettle();

    expect(find.text('Bob Pending'), findsOneWidget);
    expect(find.text('Alice Planned'), findsNothing);
    expect(find.textContaining('Manage clearance'), findsOneWidget);
  });

  testWidgets('search matcher filters visible rows client-side', (
    WidgetTester tester,
  ) async {
    await _pumpDischargeWorkspace(tester, repository: repository);

    await tester.enterText(find.byType(TextField).first, 'Bob');
    await tester.pumpAndSettle();

    expect(find.text('Bob Pending'), findsOneWidget);
    expect(find.text('Alice Planned'), findsNothing);
    expect(find.text('Carol Completed'), findsNothing);
  });

  testWidgets('opens detail dialog when row is selected', (
    WidgetTester tester,
  ) async {
    await _pumpDischargeWorkspace(tester, repository: repository);

    await tester.tap(find.text('Alice Planned'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    verify(() => repository.getAdmissionDetail('adm-planned')).called(1);
  });

  testWidgets('switches to mobile list layout at small breakpoints', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences preferences = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/discharge',
      routes: <RouteBase>[
        GoRoute(
          path: '/discharge',
          builder: (BuildContext context, GoRouterState state) {
            return const Scaffold(body: DischargeWorkspacePage());
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dischargeRepositoryProvider.overrideWithValue(repository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
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

    expect(find.text('Alice Planned'), findsOneWidget);
    expect(find.byType(AppTabStrip), findsOneWidget);
  });
}
