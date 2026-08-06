import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/patient_appointment_quick_dialog.dart';
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

  const Patient patient = Patient(
    id: 'patient-internal',
    publicId: 'PAT000001',
    tenantId: 'TEN000001',
    facilityId: 'FAC000001',
    displayName: 'Ada Lovelace',
  );

  testWidgets('uses AppDialog with Schedule appointment commit chrome', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(tester, patient: patient, repository: repository);

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isTrue);
    expect(dialog.pinActionsToBottom, isTrue);
    expect(find.text('SCHEDULE APPOINTMENT'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Schedule appointment'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsNothing);
    expect(find.byType(AppDateField), findsOneWidget);
    expect(find.byType(AppTimeField), findsOneWidget);
    expect(find.byIcon(AppActionIcons.calendar), findsWidgets);
    expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
  });

  testWidgets('Close pops false without creating an appointment', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    bool? result;

    await _pumpDialog(
      tester,
      patient: patient,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    verifyNever(() => repository.createAppointment(any()));
  });

  testWidgets('failure keeps the dialog open and preserves entered reason', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);
    when(() => repository.createAppointment(any())).thenAnswer(
      (_) async => const Result<OpdAppointment>.failure(AppFailure.network()),
    );
    bool? result;

    await _pumpDialog(
      tester,
      patient: patient,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    final Finder reasonField = find.byType(AppTextField).last;
    await tester.enterText(reasonField, 'Follow-up review');
    await tester.tap(find.widgetWithText(AppButton, 'Schedule appointment'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('Follow-up review'), findsOneWidget);
    verify(() => repository.createAppointment(any())).called(1);
  });

  testWidgets('successful save pops true after persisted create', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    final DateTime scheduledStart = DateTime.utc(2026, 7, 20, 9);
    final OpdAppointment created = OpdAppointment(
      id: 'appointment-internal',
      publicId: 'APT000099',
      patientId: 'PAT000001',
      status: 'SCHEDULED',
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledStart.add(const Duration(minutes: 30)),
    );
    Map<String, Object?>? submittedPayload;
    _stubWorkspaceLoad(repository);
    when(() => repository.createAppointment(any())).thenAnswer((
      Invocation invocation,
    ) async {
      submittedPayload =
          invocation.positionalArguments.single as Map<String, Object?>;
      return Result<OpdAppointment>.success(created);
    });
    bool? result;

    await _pumpDialog(
      tester,
      patient: patient,
      repository: repository,
      onResult: (bool? value) => result = value,
    );

    await tester.tap(find.widgetWithText(AppButton, 'Schedule appointment'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AppDialog), findsNothing);
    expect(submittedPayload, containsPair('patient_id', 'PAT000001'));
    expect(submittedPayload, containsPair('facility_id', 'FAC000001'));
    expect(submittedPayload, containsPair('status', 'SCHEDULED'));
    verify(() => repository.createAppointment(any())).called(1);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    final Result<OpdWorkspaceState> workspace = container
        .read(opdWorkspaceControllerProvider)
        .requireValue;
    final OpdWorkspaceState state = workspace.when(
      success: (OpdWorkspaceState value) => value,
      failure: (AppFailure failure) => throw StateError(failure.toString()),
    );
    expect(state.appointments.items.single.publicId, 'APT000099');
  });

  testWidgets('blocks scheduling while the patient has an open encounter', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(
      repository,
      flows: const <OpdFlowSummary>[
        OpdFlowSummary(
          id: 'flow-1',
          patientId: 'PAT000001',
          appointmentId: 'APT000001',
          status: 'IN_PROGRESS',
          stage: 'WITH_DOCTOR',
        ),
      ],
      appointments: const <OpdAppointment>[
        OpdAppointment(
          id: 'appointment-1',
          publicId: 'APT000001',
          patientId: 'PAT000001',
          status: 'SCHEDULED',
        ),
      ],
    );

    await _pumpDialog(tester, patient: patient, repository: repository);

    expect(find.text('Appointment unavailable'), findsOneWidget);
    expect(
      find.textContaining('already in an active OPD encounter'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(AppButton, 'Continue encounter'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Edit encounter'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Reschedule'), findsOneWidget);
    final AppButton submit = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Schedule appointment'),
    );
    expect(submit.enabled, isFalse);
    verifyNever(() => repository.createAppointment(any()));
  });

  testWidgets('remains usable on a compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _MockOpdRepository repository = _MockOpdRepository();
    _stubWorkspaceLoad(repository);

    await _pumpDialog(
      tester,
      patient: patient,
      repository: repository,
      dark: true,
      textScaler: const TextScaler.linear(1.8),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('SCHEDULE APPOINTMENT'), findsOneWidget);
    expect(
      find.widgetWithText(AppButton, 'Schedule appointment'),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppButton, 'Close'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required Patient patient,
  OpdRepository? repository,
  ValueChanged<bool?>? onResult,
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appAccessPolicyProvider.overrideWithValue(_frontDeskPolicy()),
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
                  final bool? value = await showPatientAppointmentQuickDialog(
                    context: context,
                    patient: patient,
                    referenceData: const PatientReferenceData(),
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
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
  List<OpdAppointment> appointments = const <OpdAppointment>[],
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
    (Invocation invocation) async =>
        const Result<AppPage<OpdQueueEntry>>.success(
          AppPage<OpdQueueEntry>(
            items: <OpdQueueEntry>[],
            request: AppPageRequest(pageSize: 12),
            totalItemCount: 0,
          ),
        ),
  );
  when(() => repository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: flows,
        request: const AppPageRequest(),
        totalItemCount: flows.length,
      ),
    ),
  );
  when(() => repository.listTriageQueue(any())).thenAnswer(
    (Invocation invocation) async =>
        const Result<AppPage<OpdFlowSummary>>.success(
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

AppAccessPolicy _frontDeskPolicy() {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'access-token'),
      user: const AuthUserProfile(roles: <String>['RECEPTIONIST']),
      permissions: <AppPermission>{
        AppPermissions.patientRead,
        AppPermissions.patientWrite,
        AppPermissions.clinicalRead,
        AppPermissions.clinicalWrite,
      },
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      ],
    ),
  );
}
