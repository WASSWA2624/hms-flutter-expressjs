import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
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

  Finder hostSelect() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppSelectField<String> && widget.labelText == 'Hosting staff',
  );
  Finder endTimeField() => find.byWidgetPredicate(
    (Widget widget) => widget is AppTimeField && widget.labelText == 'End time',
  );
  Finder durationField() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField && widget.labelText == 'Duration minutes',
  );
  Finder phoneInput() => find.descendant(
    of: find.byType(AppPhoneField),
    matching: find.byType(TextField),
  );
  Finder submitButton() => find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppButton && widget.label == 'Schedule appointment',
  );

  testWidgets('hosting staff accepts typed search text and filters hosts', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubHosts(repository);

    await _pumpDialog(tester, repository: repository);

    final AppSelectField<String> host = tester.widget<AppSelectField<String>>(
      hostSelect(),
    );
    expect(host.searchable, isTrue);
    expect(host.options, hasLength(2));

    final Finder hostInput = find.descendant(
      of: hostSelect(),
      matching: find.byType(TextField),
    );
    await tester.enterText(hostInput, 'Nurse');
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(hostInput).controller?.text, 'Nurse');
    expect(find.text('Dr Host'), findsNothing);
    expect(find.textContaining('Nurse Grace'), findsWidgets);
  });

  testWidgets('visitor phone is required before the meeting can be booked', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubHosts(repository);

    await _pumpDialog(tester, repository: repository);

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppTextField && widget.labelText == 'Visitor name',
      ),
      'Grace Hopper',
    );
    tester.widget<AppSelectField<String>>(hostSelect()).onChanged!('host-1');
    await tester.pumpAndSettle();

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsWidgets);
    verifyNever(() => repository.createAppointment(any()));
  });

  testWidgets('end time and duration fill each other in', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubHosts(repository);

    await _pumpDialog(tester, repository: repository);

    expect(
      tester.widget<AppTimeField>(endTimeField()).value,
      const AppTimeValue(hour: 9, minute: 30),
    );

    await tester.enterText(durationField(), '90');
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppTimeField>(endTimeField()).value,
      const AppTimeValue(hour: 10, minute: 30),
    );

    tester.widget<AppTimeField>(endTimeField()).onChanged!(
      const AppTimeValue(hour: 9, minute: 20),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AppTextField>(durationField()).controller?.text, '20');
  });

  testWidgets('books the visitor window and sends the phone through', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubHosts(repository);
    Map<String, Object?>? payload;
    when(() => repository.createAppointment(any())).thenAnswer((
      Invocation invocation,
    ) async {
      payload = invocation.positionalArguments.single as Map<String, Object?>;
      return const Result<OpdAppointment>.success(
        OpdAppointment(id: 'appointment-1', status: 'SCHEDULED'),
      );
    });

    await _pumpDialog(tester, repository: repository);

    await tester.enterText(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppTextField && widget.labelText == 'Visitor name',
      ),
      'Grace Hopper',
    );
    await tester.enterText(phoneInput(), '700000123');
    tester.widget<AppSelectField<String>>(hostSelect()).onChanged!('host-1');
    await tester.pumpAndSettle();

    tester.widget<AppTimeField>(endTimeField()).onChanged!(
      const AppTimeValue(hour: 10, minute: 45),
    );
    await tester.pumpAndSettle();

    await tester.tap(submitButton());
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload, containsPair('subject_type', 'VISITOR'));
    expect(payload, containsPair('visitor_phone', '+256700000123'));
    expect(payload, containsPair('provider_user_id', 'host-1'));
    final DateTime start = DateTime.parse(
      payload!['scheduled_start']! as String,
    );
    final DateTime end = DateTime.parse(payload!['scheduled_end']! as String);
    expect(end.difference(start), const Duration(minutes: 105));
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required OpdRepository repository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        opdRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // onSaved keeps a successful create from popping the host route.
          body: ReceptionVisitorAppointmentDialog(onSaved: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _stubHosts(_MockOpdRepository repository) {
  when(
    () => repository.listMeetingHosts(search: any(named: 'search')),
  ).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[
          OpdProviderOption(id: 'host-1', displayName: 'Dr Host'),
          OpdProviderOption(id: 'host-2', displayName: 'Nurse Grace'),
        ]),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
  when(() => repository.listAppointments(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: const <OpdAppointment>[],
        request: (invocation.positionalArguments.single as OpdAppointmentQuery)
            .pageRequest,
        totalItemCount: 0,
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
}
