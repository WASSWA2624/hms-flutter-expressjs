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
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_appointment_actions_dialog.dart';
import 'package:mocktail/mocktail.dart';

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
    registerFallbackValue(<String, Object?>{});
  });

  final OpdAppointment visitorMeeting = OpdAppointment(
    id: 'appointment-internal',
    publicId: 'APT000001',
    subjectType: 'VISITOR',
    visitorName: 'Jane Visitor',
    providerDisplayName: 'Provider Example',
    status: 'SCHEDULED',
    scheduledStart: DateTime.utc(2026, 7, 20, 8),
    scheduledEnd: DateTime.utc(2026, 7, 20, 8, 30),
  );

  testWidgets('confirms before closing the booking out', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester, appointment: visitorMeeting);

    expect(find.byType(OpdCompleteAppointmentDialog), findsOneWidget);
    expect(find.byType(AppConfirmActionDialog), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Mark complete'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
    expect(find.text('Jane Visitor'), findsOneWidget);
  });

  testWidgets('Close pops false without mutating the appointment', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      appointments: <OpdAppointment>[visitorMeeting],
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: visitorMeeting,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.updateAppointment(any(), any()));
  });

  testWidgets('successful completion pops true and sends COMPLETED', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      appointments: <OpdAppointment>[visitorMeeting],
    );
    when(() => repository.updateAppointment(any(), any())).thenAnswer(
      (_) async => Result<OpdAppointment>.success(
        visitorMeeting.copyWith(status: 'COMPLETED'),
      ),
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: visitorMeeting,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Mark complete'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    verify(
      () => repository.updateAppointment('APT000001', <String, Object?>{
        'status': 'COMPLETED',
      }),
    ).called(1);
  });

  testWidgets('failure keeps the dialog open', (WidgetTester tester) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      appointments: <OpdAppointment>[visitorMeeting],
    );
    when(() => repository.updateAppointment(any(), any())).thenAnswer(
      (_) async => Result<OpdAppointment>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      appointment: visitorMeeting,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Mark complete'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppConfirmActionDialog), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdAppointment appointment,
  OpdRepository? repository,
  ValueChanged<bool?>? onResult,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return AppButton.primary(
                label: 'Open',
                onPressed: () async {
                  final bool? value = await showOpdCompleteAppointmentDialog(
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
    (_) async => const Result<AppPage<OpdQueueEntry>>.success(
      AppPage<OpdQueueEntry>(
        items: <OpdQueueEntry>[],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: <OpdFlowSummary>[],
        request: AppPageRequest(),
        totalItemCount: 0,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (_) async => const Result<AppPage<OpdFlowSummary>>.success(
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
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
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
