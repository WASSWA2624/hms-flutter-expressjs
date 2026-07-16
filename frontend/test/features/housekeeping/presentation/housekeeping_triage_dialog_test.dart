import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/housekeeping/data/repositories/housekeeping_repository_impl.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';
import 'package:hosspi_hms/features/housekeeping/domain/repositories/housekeeping_repository.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/controllers/housekeeping_workspace_controller.dart';
import 'package:hosspi_hms/features/housekeeping/presentation/widgets/housekeeping_triage_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockHousekeepingRepository extends Mock
    implements HousekeepingRepository {}

const HousekeepingWorkItem _openRequest = HousekeepingWorkItem(
  id: 'MR-001',
  displayId: 'MR-001',
  resource: HousekeepingResource.maintenanceRequests,
  title: 'Fix leaking tap',
  status: 'OPEN',
  facilityLabel: 'Main Campus',
  assetLabel: 'Tap-12',
  roomLabel: 'Room 3A',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const HousekeepingWorkspaceQuery());
    registerFallbackValue(
      const HousekeepingMaintenanceTriageDraft(status: 'IN_PROGRESS'),
    );
  });

  testWidgets('uses AppDialog with triage commit and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository);

    await _pumpDialog(tester, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.text('TRIAGE MAINTENANCE HANDOFF'), findsOneWidget);
    expect(find.text('Triage maintenance request'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(HousekeepingTriageForm), findsOneWidget);
    expect(find.byIcon(AppActionIcons.triage), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
  });

  testWidgets('Cancel pops without mutating triage', (WidgetTester tester) async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository);

    await _pumpDialog(tester, repository: repository);

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    verifyNever(() => repository.triageMaintenanceRequest(any(), any()));
  });

  testWidgets('failure keeps the dialog open and preserves the triage note', (
    WidgetTester tester,
  ) async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository);
    when(() => repository.triageMaintenanceRequest(any(), any())).thenAnswer(
      (_) async => const Result<HousekeepingWorkItem>.failure(
        AppFailure.network(),
      ),
    );

    await _pumpDialog(tester, repository: repository);

    await tester.enterText(
      find.byType(AppTextField).first,
      'Keep this triage note',
    );
    await tester.tap(
      find.widgetWithText(AppButton, 'Triage maintenance request'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Triage maintenance request'), findsOneWidget);
    expect(find.text('Keep this triage note'), findsOneWidget);
    verify(() => repository.triageMaintenanceRequest('MR-001', any())).called(1);
  });

  testWidgets('successful triage closes after persisted save', (
    WidgetTester tester,
  ) async {
    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository);
    when(() => repository.triageMaintenanceRequest(any(), any())).thenAnswer(
      (_) async => Result<HousekeepingWorkItem>.success(
        _openRequest.copyWith(
          status: 'IN_PROGRESS',
          subtitle: '[TRIAGE] triage_summary=Leak confirmed',
        ),
      ),
    );

    await _pumpDialog(tester, repository: repository);

    await tester.tap(
      find.widgetWithText(AppButton, 'Triage maintenance request'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    verify(() => repository.triageMaintenanceRequest('MR-001', any())).called(1);
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockHousekeepingRepository repository = _MockHousekeepingRepository();
    _stubWorkspace(repository);

    await _pumpDialog(
      tester,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('TRIAGE MAINTENANCE HANDOFF'), findsOneWidget);
    expect(find.text('Triage maintenance request'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required HousekeepingRepository repository,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        housekeepingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Consumer(
                builder: (BuildContext context, WidgetRef ref, _) {
                  return AppButton.primary(
                    label: 'Open',
                    onPressed: () async {
                      await showHousekeepingTriageDialog(
                        context,
                        ref,
                        _openRequest,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold)),
  );
  await container.read(housekeepingWorkspaceControllerProvider.future);

  await tester.tap(find.widgetWithText(AppButton, 'Open'));
  await tester.pumpAndSettle();
}

void _stubWorkspace(_MockHousekeepingRepository repository) {
  when(() => repository.getWorkspace(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final HousekeepingWorkspaceQuery query =
        invocation.positionalArguments.single as HousekeepingWorkspaceQuery;
    return Result<HousekeepingWorkspaceLoad>.success(
      HousekeepingWorkspaceLoad(
        overview: const HousekeepingWorkspaceOverview(),
        items: AppPage<HousekeepingWorkItem>(
          items: const <HousekeepingWorkItem>[_openRequest],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
  });
}
