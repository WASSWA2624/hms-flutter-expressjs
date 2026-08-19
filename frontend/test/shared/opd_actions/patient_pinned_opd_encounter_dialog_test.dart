import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:mocktail/mocktail.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(const PatientDuplicateQuery());
    registerFallbackValue(<String, Object?>{});
  });

  const Patient patient = Patient(
    id: 'patient-internal',
    publicId: 'PAT000001',
    firstName: 'Ada',
    lastName: 'Lovelace',
    displayName: 'Ada Lovelace',
  );

  testWidgets(
    'showPatientPinnedOpdEncounterDialog uses AppDialog and pins the patient',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
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
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: AppButton.primary(
                    label: 'Open pinned encounter',
                    leadingIcon: Icons.open_in_new,
                    onPressed: () {
                      unawaited(
                        showPatientPinnedOpdEncounterDialog(
                          context: context,
                          patient: patient,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open pinned encounter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(OpdEncounterDialog), findsOneWidget);
      expect(find.byType(PatientPinnedOpdEncounterDialog), findsOneWidget);
      expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Ada Lovelace'), findsWidgets);
      expect(find.text('Search patient *'), findsNothing);
      expect(find.text('Start encounter'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byIcon(AppActionIcons.start), findsWidgets);
      expect(
        tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
        isTrue,
      );

      final Iterable<AppButton> footerButtons = tester
          .widgetList<AppButton>(find.byType(AppButton))
          // The header's dismiss affordance is icon-only; footer actions carry
          // labels. Filtering on that keeps this about footer order.
          .where((AppButton button) => !button.iconOnly)
          .where(
            (AppButton button) =>
                button.label == 'Close' || button.label == 'Start encounter',
          );
      expect(footerButtons.map((AppButton button) => button.label).toList(), [
        'Start encounter',
        'Close',
      ]);

      final ModalRoute<Object?>? route = ModalRoute.of(
        tester.element(find.byType(AppDialog)),
      );
      expect(route?.settings.name, 'showOpdEncounterDialog');
    },
  );

  testWidgets(
    'openPatientOpdEncounterFlow opens through showOpdEncounterDialog shell',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );
      var saved = false;

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
            home: Consumer(
              builder: (BuildContext context, WidgetRef ref, _) {
                return Scaffold(
                  body: AppButton.primary(
                    label: 'Open encounter flow',
                    leadingIcon: Icons.open_in_new,
                    onPressed: () {
                      unawaited(
                        openPatientOpdEncounterFlow(
                          context,
                          ref,
                          patient,
                          onSaved: () async {
                            saved = true;
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open encounter flow'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(OpdEncounterDialog), findsOneWidget);
      expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
      expect(find.byType(PatientPinnedOpdEncounterDialog), findsNothing);

      await tester.tap(find.widgetWithText(AppButton, 'Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(saved, isFalse);
    },
  );

  testWidgets('load failure keeps the dialog open with shared failure UI', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    when(() => patientRepository.listPatients(any())).thenAnswer(
      (_) async => const Result<AppPage<Patient>>.failure(AppFailure.network()),
    );
    when(() => opdRepository.listAppointments(any())).thenAnswer(
      (_) async =>
          const Result<AppPage<OpdAppointment>>.failure(AppFailure.network()),
    );
    when(() => opdRepository.listProviders()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderOption>>.failure(AppFailure.network()),
    );
    when(() => opdRepository.listProviderSchedules()).thenAnswer(
      (_) async =>
          const Result<List<OpdProviderSchedule>>.failure(AppFailure.network()),
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
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: AppButton.primary(
                  label: 'Open pinned encounter',
                  leadingIcon: Icons.open_in_new,
                  onPressed: () {
                    unawaited(
                      showPatientPinnedOpdEncounterDialog(
                        context: context,
                        patient: patient,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open pinned encounter'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsWidgets);
    expect(find.widgetWithText(AppButton, 'Try again'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    _stubLookups(
      patientRepository: patientRepository,
      opdRepository: opdRepository,
    );
    await tester.tap(find.widgetWithText(AppButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppButton, 'Try again'), findsNothing);
    expect(find.byType(AppLoadingIndicator), findsNothing);
  });

  testWidgets(
    'pinned submit success dismisses through controller startOpdFlow',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );
      when(
        () => opdRepository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => const Result<OpdFlowDetail>.success(
          OpdFlowDetail(
            summary: OpdFlowSummary(
              id: 'encounter-1',
              publicId: 'ENC000001',
              facilityId: 'FAC000001',
              patientId: 'PAT000001',
              status: 'OPEN',
              stage: 'WAITING_VITALS',
            ),
          ),
        ),
      );

      OpdEncounterDialogResult? result;
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
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: AppButton.primary(
                    label: 'Open pinned encounter',
                    leadingIcon: Icons.open_in_new,
                    onPressed: () async {
                      result = await showPatientPinnedOpdEncounterDialog(
                        context: context,
                        patient: patient,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open pinned encounter'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(AppButton, 'Start encounter'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsNothing);
      expect(result, isNotNull);
      expect(result!.flow?.publicId, 'ENC000001');
      verify(
        () => opdRepository.startOpdFlow(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).called(1);
    },
  );

  testWidgets('pinned submit failure keeps dialog open and patches nothing', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    _stubLookups(
      patientRepository: patientRepository,
      opdRepository: opdRepository,
    );
    when(
      () => opdRepository.startOpdFlow(
        any(),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.failure(AppFailure.network()),
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
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: AppButton.primary(
                  label: 'Open pinned encounter',
                  leadingIcon: Icons.open_in_new,
                  onPressed: () {
                    unawaited(
                      showPatientPinnedOpdEncounterDialog(
                        context: context,
                        patient: patient,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open pinned encounter'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Start encounter'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(PatientPinnedOpdEncounterDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsWidgets);
    expect(find.text('Start encounter'), findsOneWidget);
  });
}

void _stubLookups({
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
}) {
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
    () => opdRepository.listProviders(search: any(named: 'search')),
  ).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => opdRepository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
  when(() => opdRepository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
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
