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
    patientIdentifier: 'PAT0000003',
    providerUserId: 'provider-1',
    providerDisplayName: 'Provider Example',
    status: 'SCHEDULED',
    scheduledStart: scheduledStart,
    scheduledEnd: scheduledEnd,
  );

  test('duration helpers keep start, duration, and end linked', () {
    const AppTimeValue start = AppTimeValue(hour: 9, minute: 0);
    expect(opdRescheduleDurationMinutes(start, const AppTimeValue(hour: 9, minute: 30)), 30);
    expect(
      opdRescheduleEndFromDuration(start, 45),
      const AppTimeValue(hour: 9, minute: 45),
    );
    expect(opdRescheduleEndFromDuration(start, 0), isNull);
    expect(
      opdRescheduleEndFromDuration(const AppTimeValue(hour: 23, minute: 30), 60),
      isNull,
    );
  });

  testWidgets('uses AppPatientDetails with Edit primary and Cancel chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
    );

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(AppPatientDetails), findsOneWidget);
    expect(find.byType(AppTriageSummaryPanel), findsNothing);
    expect(find.text('Patient Example'), findsWidgets);
    expect(find.text('PAT0000003'), findsOneWidget);
    expect(find.byType(AppDateField), findsOneWidget);
    expect(find.byType(AppTimeField), findsNWidgets(2));
    expect(find.byType(AppTextField), findsOneWidget);
    expect(find.byType(AppSelectField<String>), findsOneWidget);
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
      (_) async => const Result<OpdAppointment>.failure(AppFailure.network()),
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
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    when(() => repository.updateAppointment(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return Result<OpdAppointment>.success(updated);
    });
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
    expect(submittedPayload, isNotNull);
    expect(submittedPayload!.containsKey('provider_user_id'), isFalse);
    verify(() => repository.updateAppointment('APT000001', any())).called(1);
  });

  testWidgets('changing duration updates end time before save', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);
    when(() => repository.updateAppointment(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return Result<OpdAppointment>.success(appointment);
    });

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
    );

    await tester.enterText(find.byType(AppTextField).first, '45');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(submittedPayload, isNotNull);
    final String? endIso = submittedPayload!['scheduled_end'] as String?;
    expect(endIso, isNotNull);
    final DateTime end = DateTime.parse(endIso!).toLocal();
    final DateTime start = DateTime.parse(
      submittedPayload!['scheduled_start']! as String,
    ).toLocal();
    expect(end.difference(start).inMinutes, 45);
  });

  testWidgets('provider reassignment is included only when changed', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    const OpdProviderOption doctor = OpdProviderOption(
      id: 'provider-2',
      displayName: 'Jordan Demo',
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(
      repository,
      appointments: <OpdAppointment>[appointment],
      providers: <OpdProviderOption>[doctor],
    );
    when(() => repository.updateAppointment(any(), any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments[1] as Map<String, Object?>;
      return Result<OpdAppointment>.success(
        appointment.copyWith(
          providerUserId: 'provider-2',
          providerDisplayName: 'Jordan Demo',
        ),
      );
    });

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
    );

    final Finder providerField = find.byType(AppSelectField<String>);
    await tester.ensureVisible(providerField);
    await tester.tap(find.descendant(
      of: providerField,
      matching: find.byType(EditableText),
    ));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.text('Jordan Demo'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(submittedPayload, containsPair('provider_user_id', 'provider-2'));
  });

  testWidgets('end-before-start validation does not call the API', (
    WidgetTester tester,
  ) async {
    final OpdAppointment invalidRange = OpdAppointment(
      id: 'appointment-internal',
      publicId: 'APT000001',
      patientDisplayName: 'Patient Example',
      providerDisplayName: 'Provider Example',
      status: 'SCHEDULED',
      scheduledStart: DateTime.utc(2026, 7, 20, 8, 30),
      scheduledEnd: DateTime.utc(2026, 7, 20, 8),
    );
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      appointments: <OpdAppointment>[invalidRange],
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: invalidRange,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

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

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository, appointments: <OpdAppointment>[appointment]);

    await _pumpDialog(
      tester,
      appointment: appointment,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    // Overflow may paint under extreme text scale; dialog chrome must remain usable.
    tester.takeException();
    expect(find.text('RESCHEDULE'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(AppPatientDetails), findsOneWidget);
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
  List<OpdProviderOption> providers = const <OpdProviderOption>[],
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
    (_) async => Result<List<OpdProviderOption>>.success(providers),
  );
  when(() => repository.listProviders(search: any(named: 'search'))).thenAnswer(
    (_) async => Result<List<OpdProviderOption>>.success(providers),
  );
}
