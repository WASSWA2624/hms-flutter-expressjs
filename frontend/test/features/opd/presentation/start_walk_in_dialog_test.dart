import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/opd/presentation/pages/opd_workspace_page.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_actions.dart';
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
    registerFallbackValue(const PatientDuplicateQuery());
  });

  testWidgets('OpdEncounterDialog loads and submits the new patient flow', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    Map<String, Object?>? submittedPayload;
    const Patient createdPatient = Patient(
      id: 'patient-new',
      publicId: 'PAT000099',
      firstName: 'Jane',
      lastName: 'Doe',
    );

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
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
    );
    when(() => opdRepository.listProviders()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
    );
    when(() => opdRepository.listOpdFlows(any())).thenAnswer(
      (_) async => const Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: <OpdFlowSummary>[],
          request: AppPageRequest(),
          totalItemCount: 0,
        ),
      ),
    );
    when(
      () => opdRepository.getBillingDefaults(
        facilityId: any(named: 'facilityId'),
        tenantId: any(named: 'tenantId'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
    );
    when(() => patientRepository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<PatientReferenceData>.success(PatientReferenceData()),
    );
    when(() => patientRepository.listDuplicateCandidates(any())).thenAnswer(
      (_) async => const Result<AppPage<PatientDuplicateCandidate>>.success(
        AppPage<PatientDuplicateCandidate>(
          items: <PatientDuplicateCandidate>[],
          request: AppPageRequest(pageSize: 8),
          totalItemCount: 0,
        ),
      ),
    );
    when(
      () => patientRepository.createPatient(any()),
    ).thenAnswer((_) async => const Result<Patient>.success(createdPatient));

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
            body: OpdEncounterDialog(
              providerSchedules: const <OpdProviderSchedule>[],
              appointments: const <OpdAppointment>[],
              onSubmit: (Map<String, Object?> payload) async {
                submittedPayload = payload;
                return _successfulOpdSubmit(patientId: createdPatient.id);
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
    expect(find.textContaining('Last name'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'Jane');
    await tester.enterText(find.byType(EditableText).at(1), 'Doe');
    await tester.tap(find.text('Create patient').last);
    await tester.pumpAndSettle();

    expect(find.text('Existing patient'), findsOneWidget);
    expect(find.text('Start encounter').last, findsOneWidget);
    expect(submittedPayload, isNull);

    await tester.tap(find.text('Start encounter').last);
    await tester.pumpAndSettle();

    expect(submittedPayload?['patient_id'], 'PAT000099');
    expect(submittedPayload?['patient_registration'], isNull);
    expect(submittedPayload?['arrival_mode'], 'WALK_IN');
  });

  testWidgets('OpdEncounterDialog submits pay-now payload during OPD start', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    const Patient patient = Patient(
      id: 'patient-1',
      publicId: 'PAT000001',
      firstName: 'Jane',
      lastName: 'Doe',
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
      dialog: OpdEncounterDialog(
        providerSchedules: const <OpdProviderSchedule>[],
        appointments: const <OpdAppointment>[],
        initialPatient: patient,
        onSubmit: (Map<String, Object?> payload) async {
          submittedPayload = payload;
          return _successfulOpdSubmit(patientId: patient.id);
        },
      ),
    );

    final Finder amountInput = find.descendant(
      of: find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppCurrencyAmountField &&
            widget.amountLabelText == 'Consultation fee (optional)',
      ),
      matching: find.byType(EditableText),
    );

    await tester.enterText(amountInput, '25000');
    await tester.ensureVisible(find.text('Payment received'));
    await tester.tap(find.text('Payment received'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'MM-10001');
    await tester.ensureVisible(find.text('Start encounter').last);
    await tester.tap(find.text('Start encounter').last);
    await tester.pumpAndSettle();

    expect(submittedPayload?['require_consultation_payment'], isTrue);
    expect(submittedPayload?['create_consultation_invoice'], isTrue);
    expect(submittedPayload?['consultation_fee'], '25000');
    final Map<String, Object?> payNow =
        submittedPayload!['pay_now']! as Map<String, Object?>;
    expect(payNow, containsPair('method', 'CASH'));
    expect(payNow, containsPair('amount', '25000'));
    expect(payNow, containsPair('status', 'COMPLETED'));
    expect(payNow, containsPair('transaction_ref', 'MM-10001'));
    expect(payNow['paid_at'], isA<String>());
  });

  testWidgets(
    'OpdEncounterDialog hides patient picker for pinned existing patient',
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
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          source: 'patient_registry',
          onSubmit: (_) async => _successfulOpdSubmit(),
        ),
        size: const Size(1000, 820),
      );

      expect(find.text('Existing patient'), findsNothing);
      expect(find.text('Search patient *'), findsNothing);
      expect(find.text('Arrival mode *'), findsOneWidget);
      expect(find.text('Start encounter'), findsOneWidget);
    },
  );

  testWidgets(
    'OpdEncounterDialog hides appointment picker for pinned appointment',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
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
        appointments: const <OpdAppointment>[appointment],
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialAppointment: appointment,
          initialAppointmentId: appointment.publicId,
          source: 'opd_workspace',
          onSubmit: (_) async => _successfulOpdSubmit(),
        ),
        size: const Size(1000, 820),
      );

      expect(find.text('Search appointment *'), findsNothing);
      expect(find.text('Arrival mode *'), findsNothing);
      expect(find.text('Search doctor (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'OpdEncounterDialog shows patient mode selector in generic workspace context',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();

      _stubStartDialogLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      await _pumpStartDialog(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          source: 'opd_workspace',
          onSubmit: (_) async => _successfulOpdSubmit(),
        ),
      );

      expect(find.text('Existing patient'), findsOneWidget);
      expect(find.text('Appointment patient'), findsOneWidget);
      expect(find.text('New patient'), findsOneWidget);
      expect(find.text('Search patient *'), findsOneWidget);
    },
  );

  testWidgets('OpdEncounterDialog opens maximized by default on desktop', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();

    _stubStartDialogLookups(
      patientRepository: patientRepository,
      opdRepository: opdRepository,
    );

    await _pumpStartDialog(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      dialog: OpdEncounterDialog(
        providerSchedules: const <OpdProviderSchedule>[],
        appointments: const <OpdAppointment>[],
        onSubmit: (_) async => _successfulOpdSubmit(),
      ),
      size: const Size(1000, 820),
    );

    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
  });

  testWidgets(
    'OpdEncounterDialog opens active encounter instead of submitting duplicate creation',
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
        nextStep: 'RECORD_VITALS',
        displayNextStep: 'RECORD_VITALS',
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
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          activeFlows: <OpdFlowSummary>[activeFlow],
          initialPatient: patient,
          onSubmit: (Map<String, Object?> payload) async {
            submittedPayload = payload;
            return _successfulOpdSubmit(patientId: patient.id);
          },
        ),
      );

      expect(find.text('Active OPD encounter found'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Continue encounter'), findsOneWidget);
      expect(find.byType(AppCopyableIdentifier), findsWidgets);

      await tester.tap(find.text('Update encounter').last);
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

  testWidgets('RecordVitalsDialog explains empty vital submission', (
    WidgetTester tester,
  ) async {
    final _MockOpdRepository opdRepository = _MockOpdRepository();

    when(() => opdRepository.listProviders()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
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
          home: const Scaffold(
            body: RecordVitalsDialog(
              flow: OpdFlowSummary(
                id: 'encounter-1',
                publicId: 'ENC000001',
                stage: 'WAITING_VITALS',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(
        AppFormInformationBanner,
        'Enter at least one vital sign.',
      ),
      findsNothing,
    );

    await tester.tap(find.text('Record vitals').last);
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(
        AppFormInformationBanner,
        'Enter at least one vital sign.',
      ),
      findsOneWidget,
    );
    verifyNever(() => opdRepository.recordTriageVitals(any(), any()));
  });

  testWidgets(
    'FlowActionsDialog doctor review shows the triage summary notes',
    (WidgetTester tester) async {
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
        (_) async =>
            const Result<List<OpdDrugOption>>.success(<OpdDrugOption>[]),
      );
      when(() => opdRepository.listAvailableDrugs()).thenAnswer(
        (_) async =>
            const Result<List<OpdDrugOption>>.success(<OpdDrugOption>[]),
      );
      when(() => opdRepository.getOpdFlow(any())).thenAnswer(
        (_) async =>
            const Result<OpdFlowDetail>.success(OpdFlowDetail(summary: flow)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialSessionStateProvider.overrideWithValue(
              SessionState.authenticated(
                session: AuthSession(
                  tokens: SessionTokens(accessToken: 'test-access-token'),
                  subject: 'doctor@example.com',
                  user: const AuthUserProfile(
                    id: 'doctor-1',
                    email: 'doctor@example.com',
                    roles: <String>['DOCTOR'],
                  ),
                  moduleEntitlements: const <AppModuleEntitlement>[
                    AppModuleEntitlement(code: 'scheduling-queue'),
                  ],
                ),
              ),
            ),
            opdRepositoryProvider.overrideWithValue(opdRepository),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold(body: FlowActionsDialog(flow: flow)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final Finder doctorReviewAction = find.widgetWithText(
        AppButton,
        'Doctor review',
      );
      await tester.ensureVisible(doctorReviewAction);
      await tester.pumpAndSettle();
      await tester.tap(doctorReviewAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Triage notes'), findsOneWidget);
      expect(find.textContaining('Dizziness'), findsOneWidget);
      expect(find.textContaining('Fall risk'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(AppButton, 'Doctor review').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Doctor review').last);
      await tester.pump();

      expect(
        find.widgetWithText(AppFormInformationBanner, 'Check the details'),
        findsNothing,
      );
      expect(find.text('This field is required.'), findsOneWidget);
    },
  );

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
    final OpdFlowSummary paidFlow = OpdFlowSummary(
      id: 'encounter-2',
      publicId: 'ENC000002',
      patientDisplayName: 'Grace Nanyonga',
      patientIdentifier: 'PAT000002',
      encounterType: 'OPD',
      status: 'OPEN',
      arrivalMode: 'WALK_IN',
      stage: 'WAITING_DOCTOR_REVIEW',
      nextStep: 'DOCTOR_REVIEW',
      queuedAt: queuedAt.subtract(const Duration(minutes: 4)),
      providerDisplayName: 'Dr Baker',
      consultationPaid: true,
      consultationFee: 20000,
      consultationPaidAmount: 20000,
      consultationCurrency: 'UGX',
      consultationPaymentStatus: 'PAID',
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
          items: <OpdFlowSummary>[flow, paidFlow],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 2,
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
    when(() => opdRepository.getOpdSummaryCounts()).thenAnswer(
      (_) async => const Result<OpdFlowAggregateCounts>.success(
        OpdFlowAggregateCounts.empty,
      ),
    );
    when(
      () => opdRepository.listProviders(search: any(named: 'search')),
    ).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
    );
    when(() => opdRepository.listProviders()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
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
    await _pumpUntilFound(tester, find.text('Patient name'));

    expect(find.text('Patient name'), findsOneWidget);
    expect(find.text('Queue status'), findsOneWidget);
    expect(find.text('Next step'), findsOneWidget);
    expect(find.textContaining('Payment required'), findsWidgets);
    expect(find.textContaining('Paid'), findsWidgets);
    expect(find.textContaining('UGX'), findsWidgets);
    expect(find.textContaining('25,000'), findsWidgets);
    expect(find.textContaining('20,000'), findsWidgets);

    final Finder tableFilterButton = find.byTooltip('Filters').last;
    await tester.ensureVisible(tableFilterButton);
    await tester.tap(tableFilterButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Filters'), findsWidgets);
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
  }, skip: true);
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxAttempts = 100,
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
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
  when(() => opdRepository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(
    () => opdRepository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
  when(() => patientRepository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<PatientReferenceData>.success(PatientReferenceData()),
  );
  when(() => patientRepository.listDuplicateCandidates(any())).thenAnswer(
    (_) async => const Result<AppPage<PatientDuplicateCandidate>>.success(
      AppPage<PatientDuplicateCandidate>(
        items: <PatientDuplicateCandidate>[],
        request: AppPageRequest(pageSize: 8),
        totalItemCount: 0,
      ),
    ),
  );
}

Future<void> _pumpStartDialog(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  required OpdEncounterDialog dialog,
  Size size = const Size(800, 720),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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

Result<OpdFlowDetail> _successfulOpdSubmit({String? patientId}) {
  return Result<OpdFlowDetail>.success(
    OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'flow-1',
        patientId: patientId ?? 'patient-new-1',
      ),
    ),
  );
}
