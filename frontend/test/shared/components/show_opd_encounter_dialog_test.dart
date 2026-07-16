import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
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
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
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
  });

  const Patient patient = Patient(
    id: 'patient-internal',
    publicId: 'PAT000001',
    firstName: 'Ada',
    lastName: 'Lovelace',
    displayName: 'Ada Lovelace',
  );

  testWidgets(
    'showOpdEncounterDialog uses AppDialog, route name, and blocks barrier dismiss',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      await _pumpOpener(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          onSubmit: (_) async => _successfulSubmit(),
        ),
      );

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(OpdEncounterDialog), findsOneWidget);
      expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
      expect(find.textContaining('Ada Lovelace'), findsNothing);
      expect(find.byIcon(opdEncounterIcon), findsWidgets);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );

      final ModalRoute<Object?>? route = ModalRoute.of(
        tester.element(find.byType(AppDialog)),
      );
      expect(route?.settings.name, 'showOpdEncounterDialog');

      await tester.tapAt(Offset.zero);
      await tester.pump();
      expect(find.byType(AppDialog), findsOneWidget);
    },
  );

  testWidgets(
    'showOpdEncounterDialog preserves pinned patient IDs and role-based title',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );

      await _pumpOpener(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          initialPatient: patient,
          initialPatientId: patient.publicId,
          onSubmit: (_) async => _successfulSubmit(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
      expect(find.textContaining('Ada Lovelace'), findsWidgets);
      expect(find.textContaining('PAT000001'), findsWidgets);
      expect(find.text('Search patient *'), findsNothing);
      expect(find.text('Start encounter'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'showOpdEncounterDialog locks close/Cancel while loading with shared spinner',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      final Completer<Result<AppPage<Patient>>> patientLoad =
          Completer<Result<AppPage<Patient>>>();

      _stubLookups(
        patientRepository: patientRepository,
        opdRepository: opdRepository,
      );
      when(
        () => patientRepository.listPatients(any()),
      ).thenAnswer((_) => patientLoad.future);

      await _pumpOpener(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        settle: false,
        dialog: OpdEncounterDialog(
          providerSchedules: const <OpdProviderSchedule>[],
          appointments: const <OpdAppointment>[],
          onSubmit: (_) async => _successfulSubmit(),
        ),
      );
      await tester.pump();

      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
        isFalse,
      );
      expect(
        tester
            .widget<AppButton>(find.widgetWithText(AppButton, 'Cancel'))
            .enabled,
        isFalse,
      );

      patientLoad.complete(
        const Result<AppPage<Patient>>.success(
          AppPage<Patient>(
            items: <Patient>[],
            request: AppPageRequest(pageSize: 50),
            totalItemCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(
        tester.widget<AppDialog>(find.byType(AppDialog)).closeEnabled,
        isTrue,
      );
    },
  );

  testWidgets('Cancel dismisses without submit and without patching', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    var submitCount = 0;
    OpdEncounterDialogResult? result;

    _stubLookups(
      patientRepository: patientRepository,
      opdRepository: opdRepository,
    );

    await _pumpOpener(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      onResult: (OpdEncounterDialogResult? value) => result = value,
      dialog: OpdEncounterDialog(
        providerSchedules: const <OpdProviderSchedule>[],
        appointments: const <OpdAppointment>[],
        initialPatient: patient,
        initialPatientId: patient.publicId,
        onSubmit: (_) async {
          submitCount += 1;
          return _successfulSubmit();
        },
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(result, isNull);
    expect(submitCount, 0);
  });

  testWidgets(
    'showPatientPinnedOpdEncounterDialog routes through showOpdEncounterDialog',
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
                    label: 'Open pinned',
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

      await tester.tap(find.text('Open pinned'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(PatientPinnedOpdEncounterDialog), findsOneWidget);
      expect(find.byType(OpdEncounterDialog), findsOneWidget);
      expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
      final ModalRoute<Object?>? route = ModalRoute.of(
        tester.element(find.byType(AppDialog)),
      );
      expect(route?.settings.name, 'showOpdEncounterDialog');
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );
    },
  );

  testWidgets('dark mode and text scaling keep opener chrome usable', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository patientRepository = _MockPatientRepository();
    final _MockOpdRepository opdRepository = _MockOpdRepository();
    _stubLookups(
      patientRepository: patientRepository,
      opdRepository: opdRepository,
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
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
          themeMode: ThemeMode.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            );
          },
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: AppButton.primary(
                  label: 'Open encounter',
                  leadingIcon: Icons.open_in_new,
                  onPressed: () {
                    unawaited(
                      showOpdEncounterDialog(
                        context: context,
                        dialog: OpdEncounterDialog(
                          providerSchedules: const <OpdProviderSchedule>[],
                          appointments: const <OpdAppointment>[],
                          initialPatient: patient,
                          initialPatientId: patient.publicId,
                          onSubmit: (_) async => _successfulSubmit(),
                        ),
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

    await tester.tap(find.text('Open encounter'));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('START OPD ENCOUNTER'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Start encounter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpOpener(
  WidgetTester tester, {
  required _MockPatientRepository patientRepository,
  required _MockOpdRepository opdRepository,
  required Widget dialog,
  ValueChanged<OpdEncounterDialogResult?>? onResult,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1100, 900));
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
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: AppButton.primary(
                label: 'Open encounter',
                leadingIcon: Icons.open_in_new,
                onPressed: () {
                  unawaited(() async {
                    final OpdEncounterDialogResult? result =
                        await showOpdEncounterDialog(
                          context: context,
                          dialog: dialog,
                        );
                    onResult?.call(result);
                  }());
                },
              ),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open encounter'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Result<OpdFlowDetail> _successfulSubmit() {
  return const Result<OpdFlowDetail>.success(
    OpdFlowDetail(
      summary: OpdFlowSummary(
        id: 'flow-1',
        publicId: 'OPD000001',
        patientId: 'PAT000001',
        status: 'WAITING_VITALS',
        stage: 'WAITING_VITALS',
      ),
    ),
  );
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
