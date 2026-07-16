import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_reschedule_appointment_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
  });

  final DateTime scheduledStart = DateTime.utc(2026, 7, 20, 8);
  final DateTime scheduledEnd = DateTime.utc(2026, 7, 20, 8, 30);
  final OpdAppointment appointment = OpdAppointment(
    id: 'appointment-internal',
    publicId: 'APT000001',
    patientDisplayName: 'Patient Example',
    providerDisplayName: 'Provider Example',
    status: 'SCHEDULED',
    scheduledStart: scheduledStart,
    scheduledEnd: scheduledEnd,
  );

  testWidgets('uses AppDialog with Edit primary and Cancel chrome', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, appointment: appointment);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Patient Example'), findsOneWidget);
    expect(find.byType(AppDateField), findsOneWidget);
    expect(find.byType(AppTimeField), findsNWidgets(2));
    expect(find.byIcon(AppActionIcons.reschedule), findsWidgets);
    expect(find.byIcon(AppActionIcons.edit), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
  });

  testWidgets('Cancel pops false without mutating the schedule', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    bool? result;

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.updateAppointment(any(), any()));
  });

  testWidgets('failure keeps the dialog open and preserves entered times', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    when(() => repository.updateAppointment(any(), any())).thenAnswer(
      (_) async => Result<OpdAppointment>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byType(AppDateField), findsOneWidget);
    verify(() => repository.updateAppointment('APT000001', any())).called(1);
  });

  testWidgets('successful edit pops true after persisted schedule update', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final DateTime updatedStart = DateTime.utc(2026, 7, 21, 10);
    final DateTime updatedEnd = DateTime.utc(2026, 7, 21, 10, 30);
    final OpdAppointment updated = appointment.copyWith(
      scheduledStart: updatedStart,
      scheduledEnd: updatedEnd,
    );
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    when(() => repository.updateAppointment(any(), any())).thenAnswer(
      (_) async => Result<OpdAppointment>.success(updated),
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    verify(() => repository.updateAppointment('APT000001', any())).called(1);
  });

  testWidgets('end-before-start validation does not call the API', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    bool? result;

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final Finder endTimeField = find.byType(AppTimeField).last;
    await tester.enterText(
      find.descendant(of: endTimeField, matching: find.byType(TextFormField)).first,
      '07',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('End time must be after start time.'), findsWidgets);
    verifyNever(() => repository.updateAppointment(any(), any()));
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      appointment: appointment,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdAppointment appointment,
  OpdRepository? repository,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (repository != null) ...[
          initialSessionStateProvider.overrideWithValue(
            const SessionState.ready(),
          ),
          opdRepositoryProvider.overrideWithValue(repository),
        ],
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
              return AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  final bool? value = await showOpdRescheduleAppointmentDialog(
                    context: context,
                    appointment: appointment,
                  );
                  onResult?.call(value);
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (repository != null) {
    // Warm the workspace controller so mutate helpers see loaded state.
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(opdWorkspaceControllerProvider.future);
  }

  await tester.tap(find.widgetWithText(AppButton, 'Open'));
  await tester.pumpAndSettle();
}

void _stubWorkspaceLoad(
  _MockOpdRepository repository, {
  required List<OpdAppointment> appointments,
}) {
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: appointments,
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: appointments.length,
      ),
    ),
  );
  when(() => repository.listVisitQueues(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.getOpdSummaryCounts()).thenAnswer(
    (_) async =>
        const Result<OpdFlowAggregateCounts>.success(OpdFlowAggregateCounts()),
  );
  when(
    () => repository.listClinicalAlertThresholds(
      vitalType: any(named: 'vitalType'),
    ),
  ).thenAnswer(
    (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
      <OpdClinicalAlertThreshold>[],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderSchedule>>.success(<OpdProviderSchedule>[]),
  );
  when(() => repository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}
