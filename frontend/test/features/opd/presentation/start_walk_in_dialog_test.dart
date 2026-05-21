import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdQueueQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const OpdTriageQueueQuery());
  });

  testWidgets(
    'StartOpdEncounterDialog loads and submits the new patient flow',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      Map<String, Object?>? submittedPayload;

      when(() => patientRepository.listPatients(any())).thenAnswer(
        (_) async => const Result<AppPage<Patient>>.success(
          AppPage<Patient>(
            items: <Patient>[],
            request: AppPageRequest(pageSize: 50),
            totalItemCount: 0,
          ),
        ),
      );
      when(() => opdRepository.listAppointments(any())).thenAnswer(
        (_) async => const Result<AppPage<OpdAppointment>>.success(
          AppPage<OpdAppointment>(
            items: <OpdAppointment>[],
            request: AppPageRequest(pageSize: 50),
            totalItemCount: 0,
          ),
        ),
      );
      when(
        () => opdRepository.listProviders(search: any(named: 'search')),
      ).thenAnswer(
        (_) async => const Result<List<OpdProviderOption>>.success(
          <OpdProviderOption>[],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            patientRepositoryProvider.overrideWithValue(patientRepository),
            opdRepositoryProvider.overrideWithValue(opdRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: StartOpdEncounterDialog(
                providerSchedules: const <OpdProviderSchedule>[],
                appointments: const <OpdAppointment>[],
                onSubmit: (Map<String, Object?> payload) async {
                  submittedPayload = payload;
                  return null;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New patient'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('First name *'), findsOneWidget);
      expect(find.text('Last name *'), findsOneWidget);
      expect(find.text('Gender (optional)'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), 'Jane');
      await tester.enterText(find.byType(EditableText).at(1), 'Doe');
      await tester.tap(find.text('Start encounter').last);
      await tester.pumpAndSettle();

      expect(submittedPayload?['patient_registration'], <String, Object?>{
        'first_name': 'Jane',
        'last_name': 'Doe',
        'gender': null,
      });
      expect(submittedPayload?['arrival_mode'], 'WALK_IN');
      expect(submittedPayload?['require_consultation_payment'], isTrue);
      expect(submittedPayload?['create_consultation_invoice'], isTrue);
    },
  );

  testWidgets(
    'StartOpdEncounterDialog preselects existing patient when no appointment exists',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      const Patient patient = Patient(
        id: 'patient-1',
        publicId: 'PAT000001',
        firstName: 'Jane',
        lastName: 'Doe',
      );

      _stubStartDialogLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        patients: const <Patient>[patient],
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: StartOpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          onSubmit: (_) async => null,
        ),
      );

      expect(find.text('Search patient *'), findsOneWidget);
      expect(find.text('Search appointment *'), findsNothing);
    },
  );

  testWidgets(
    'StartOpdEncounterDialog preselects appointment mode for one eligible patient appointment',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      const Patient patient = Patient(
        id: 'patient-1',
        publicId: 'PAT000001',
        firstName: 'Jane',
        lastName: 'Doe',
      );
      const OpdAppointment appointment = OpdAppointment(
        id: 'appointment-1',
        publicId: 'APT000001',
        patientId: 'patient-1',
        patientDisplayName: 'Jane Doe',
        patientIdentifier: 'PAT000001',
        status: 'SCHEDULED',
      );

      _stubStartDialogLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        patients: const <Patient>[patient],
        appointments: const <OpdAppointment>[appointment],
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: StartOpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          onSubmit: (_) async => null,
        ),
      );

      expect(find.text('Search appointment *'), findsOneWidget);
      expect(
        find.text(
          'Select a scheduled appointment to check the patient into OPD.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'StartOpdEncounterDialog requires selection when patient has multiple eligible appointments',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      const Patient patient = Patient(
        id: 'patient-1',
        publicId: 'PAT000001',
        firstName: 'Jane',
        lastName: 'Doe',
      );
      const List<OpdAppointment> appointments = <OpdAppointment>[
        OpdAppointment(
          id: 'appointment-1',
          publicId: 'APT000001',
          patientId: 'patient-1',
          patientDisplayName: 'Jane Doe',
          patientIdentifier: 'PAT000001',
          status: 'SCHEDULED',
        ),
        OpdAppointment(
          id: 'appointment-2',
          publicId: 'APT000002',
          patientId: 'patient-1',
          patientDisplayName: 'Jane Doe',
          patientIdentifier: 'PAT000001',
          status: 'CONFIRMED',
        ),
      ];

      _stubStartDialogLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        patients: const <Patient>[patient],
        appointments: appointments,
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: StartOpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          onSubmit: (_) async => null,
        ),
      );

      await tester.tap(find.text('Start encounter').last);
      await tester.pumpAndSettle();

      expect(find.text('Search appointment *'), findsOneWidget);
      expect(find.text('This field is required.'), findsWidgets);
    },
  );

  testWidgets(
    'StartOpdEncounterDialog opens active encounter instead of submitting duplicate creation',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      const Patient patient = Patient(
        id: 'patient-1',
        publicId: 'PAT000001',
        firstName: 'Jane',
        lastName: 'Doe',
      );
      final OpdFlowSummary activeFlow = OpdFlowSummary(
        id: 'encounter-1',
        publicId: 'ENC000001',
        patientId: 'patient-1',
        patientIdentifier: 'PAT000001',
        patientDisplayName: 'Jane Doe',
        status: 'OPEN',
        stage: 'WAITING_VITALS',
        arrivalMode: 'WALK_IN',
        startedAt: DateTime(2026, 5, 21, 8),
      );
      Map<String, Object?>? submittedPayload;

      _stubStartDialogLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        patients: const <Patient>[patient],
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: StartOpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          activeFlows: <OpdFlowSummary>[activeFlow],
          initialPatient: patient,
          onSubmit: (Map<String, Object?> payload) async {
            submittedPayload = payload;
            return null;
          },
        ),
      );

      expect(find.text('Active OPD encounter found'), findsOneWidget);
      expect(
        find.text(
          'This patient already has an active OPD encounter. Open the active encounter instead of creating a duplicate.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Open active encounter').last);
      await tester.pumpAndSettle();

      expect(submittedPayload?['existing_encounter_id'], 'ENC000001');
      expect(submittedPayload?['patient_id'], 'PAT000001');
    },
  );

  testWidgets(
    'RecordVitalsDialog exposes triage assessment and routing fields',
    (WidgetTester tester) async {
      final _MockOpdRepository opdRepository = _MockOpdRepository();

      when(
        () => opdRepository.listProviders(search: any(named: 'search')),
      ).thenAnswer(
        (_) async => const Result<List<OpdProviderOption>>.success(
          <OpdProviderOption>[],
        ),
      );
      when(() => opdRepository.listProviders()).thenAnswer(
        (_) async => const Result<List<OpdProviderOption>>.success(
          <OpdProviderOption>[],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [opdRepositoryProvider.overrideWithValue(opdRepository)],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(
              body: RecordVitalsDialog(
                flow: OpdFlowSummary(
                  id: 'encounter-1',
                  publicId: 'ENC000001',
                  stage: 'WAITING_VITALS',
                  chiefComplaint: 'Headache',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Symptoms (optional)'), findsOneWidget);
      expect(find.text('Pain severity (optional)'), findsOneWidget);
      expect(find.text('Allergies (optional)'), findsOneWidget);
      expect(find.text('Risk flags'), findsOneWidget);
      expect(find.text('Do not route yet'), findsOneWidget);
    },
  );

  testWidgets('DoctorReviewDialog shows the triage summary notes', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    const OpdFlowSummary flow = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Jane Doe',
      patientIdentifier: 'PAT000001',
      providerUserId: 'DOC000001',
      providerDisplayName: 'Dr Able',
      stage: 'WAITING_DOCTOR_REVIEW',
      triageLevel: 'LEVEL_2',
      chiefComplaint: 'Headache',
      triageNotes: 'Symptoms: Dizziness\nRisk flags: Fall risk',
    );

    when(() => opdRepository.listAppointments(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: const <OpdAppointment>[],
          request:
              (invocation.positionalArguments.single as OpdAppointmentQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opdRepository.listVisitQueues(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdQueueEntry>>.success(
        AppPage<OpdQueueEntry>(
          items: const <OpdQueueEntry>[],
          request: (invocation.positionalArguments.single as OpdQueueQuery)
              .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opdRepository.listOpdFlows(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[flow],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
    when(() => opdRepository.listTriageQueue(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request:
              (invocation.positionalArguments.single as OpdTriageQueueQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(
      () => opdRepository.listClinicalAlertThresholds(
        vitalType: any(named: 'vitalType'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
        <OpdClinicalAlertThreshold>[],
      ),
    );
    when(() => opdRepository.listProviderSchedules()).thenAnswer(
      (_) async => const Result<List<OpdProviderSchedule>>.success(
        <OpdProviderSchedule>[],
      ),
    );
    when(
      () => opdRepository.listAvailableDrugs(search: any(named: 'search')),
    ).thenAnswer(
      (_) async => const Result<List<OpdDrugOption>>.success(<OpdDrugOption>[]),
    );
    when(() => opdRepository.listAvailableDrugs()).thenAnswer(
      (_) async => const Result<List<OpdDrugOption>>.success(<OpdDrugOption>[]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [opdRepositoryProvider.overrideWithValue(opdRepository)],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: DoctorReviewDialog(flow: flow)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Triage notes'), findsOneWidget);
    expect(find.textContaining('Dizziness'), findsOneWidget);
    expect(find.textContaining('Fall risk'), findsOneWidget);
  });

  testWidgets('OpdWorkspacePage exposes the required OPD worklist columns', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    final DateTime queuedAt = DateTime.now().subtract(
      const Duration(minutes: 18),
    );
    final OpdFlowSummary flow = OpdFlowSummary(
      id: 'encounter-1',
      publicId: 'ENC000001',
      patientDisplayName: 'Jane Doe',
      patientIdentifier: 'PAT000001',
      encounterType: 'OPD',
      status: 'OPEN',
      arrivalMode: 'WALK_IN',
      stage: 'WAITING_CONSULTATION_PAYMENT',
      nextStep: 'PAY_CONSULTATION',
      queuedAt: queuedAt,
      providerDisplayName: 'Dr Able',
      consultationPaymentRequired: true,
      consultationFee: 25000,
      consultationCurrency: 'UGX',
    );

    when(() => opdRepository.listAppointments(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdAppointment>>.success(
        AppPage<OpdAppointment>(
          items: const <OpdAppointment>[],
          request:
              (invocation.positionalArguments.single as OpdAppointmentQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opdRepository.listVisitQueues(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdQueueEntry>>.success(
        AppPage<OpdQueueEntry>(
          items: const <OpdQueueEntry>[],
          request: (invocation.positionalArguments.single as OpdQueueQuery)
              .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(() => opdRepository.listOpdFlows(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: <OpdFlowSummary>[flow],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 1,
        ),
      ),
    );
    when(() => opdRepository.listTriageQueue(any())).thenAnswer(
      (invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request:
              (invocation.positionalArguments.single as OpdTriageQueueQuery)
                  .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );
    when(
      () => opdRepository.listClinicalAlertThresholds(
        vitalType: any(named: 'vitalType'),
      ),
    ).thenAnswer(
      (_) async => const Result<List<OpdClinicalAlertThreshold>>.success(
        <OpdClinicalAlertThreshold>[],
      ),
    );
    when(() => opdRepository.listProviderSchedules()).thenAnswer(
      (_) async => const Result<List<OpdProviderSchedule>>.success(
        <OpdProviderSchedule>[],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [opdRepositoryProvider.overrideWithValue(opdRepository)],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(body: OpdWorkspacePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visit type'), findsOneWidget);
    expect(find.text('Queue / status'), findsOneWidget);
    expect(find.text('Payer / billing'), findsOneWidget);
    expect(find.text('Wait time'), findsOneWidget);
    expect(find.textContaining('Payment required'), findsWidgets);

    final Finder tableFilterButton = find.byTooltip('Filter OPD table').last;
    await tester.ensureVisible(tableFilterButton);
    await tester.tap(tableFilterButton);
    await tester.pumpAndSettle();

    expect(find.text('OPD filters'), findsOneWidget);
    expect(find.text('Search in'), findsOneWidget);
    expect(find.text('Arrival date'), findsOneWidget);
    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
    expect(find.text('Arrival range'), findsOneWidget);
    expect(find.text('Any arrival date'), findsOneWidget);
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    expect(find.text('Visit type'), findsWidgets);
    expect(find.text('All visit types'), findsOneWidget);
    expect(find.text('Queue'), findsWidgets);
    expect(find.text('All queues'), findsOneWidget);
    expect(find.text('Status'), findsWidgets);
    expect(find.text('All statuses'), findsOneWidget);
    expect(find.text('Provider'), findsWidgets);
    expect(find.text('All providers'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('All billing states'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('All next actions'), findsOneWidget);
    expect(find.text('Triage scope'), findsOneWidget);
    expect(find.text('All triage scopes'), findsOneWidget);
  });
}

void _stubStartDialogLookups({
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  List<Patient> patients = const <Patient>[],
  List<OpdAppointment> appointments = const <OpdAppointment>[],
  List<OpdFlowSummary> flows = const <OpdFlowSummary>[],
}) {
  when(() => patientRepository.listPatients(any())).thenAnswer(
    (_) async => Result<AppPage<Patient>>.success(
      AppPage<Patient>(
        items: patients,
        request: const AppPageRequest(pageSize: 50),
        totalItemCount: patients.length,
      ),
    ),
  );
  when(() => opdRepository.listAppointments(any())).thenAnswer(
    (_) async => Result<AppPage<OpdAppointment>>.success(
      AppPage<OpdAppointment>(
        items: appointments,
        request: const AppPageRequest(pageSize: 50),
        totalItemCount: appointments.length,
      ),
    ),
  );
  when(() => opdRepository.listOpdFlows(any())).thenAnswer(
    (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
      AppPage<OpdFlowSummary>(
        items: flows,
        request:
            (invocation.positionalArguments.single as OpdFlowQuery).pageRequest,
        totalItemCount: flows.length,
      ),
    ),
  );
  when(
    () => opdRepository.listProviders(search: any(named: 'search')),
  ).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}

Future<void> _pumpStartDialog(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  required StartOpdEncounterDialog dialog,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientRepositoryProvider.overrideWithValue(patientRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: dialog),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
