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
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

class _MockOpdRepository extends Mock implements OpdRepository {}

const Patient _patient = Patient(
  id: 'patient-1',
  publicId: 'PAT000001',
  firstName: 'Ada',
  lastName: 'Lovelace',
  displayName: 'Ada Lovelace',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
  });

  testWidgets('scheduler opens one dialog with Existing patient selected', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository repository = _MockPatientRepository();
    _stubPatientLookups(repository, patients: const <Patient>[_patient]);

    await _pumpOpenScheduler(tester, repository: repository);

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.text('SCHEDULE APPOINTMENT'), findsOneWidget);
    expect(find.text('Existing patient'), findsOneWidget);
    expect(find.text('New patient'), findsOneWidget);
    final AppTabStrip tabs = tester.widget<AppTabStrip>(
      find.byType(AppTabStrip),
    );
    expect(tabs.selectedId, 'existing');
    expect(find.byType(AppListTable<Patient>), findsOneWidget);
    expect(find.text('SELECT PATIENT'), findsNothing);

    await tester.tap(find.text('New patient'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterNewPatientForm), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppButton && widget.label == 'Register patient',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppDialog), findsOneWidget);
  });

  testWidgets(
    'visitor tab keeps shared tab strip and pinned footer Schedule/Close',
    (WidgetTester tester) async {
      final _MockPatientRepository patientRepository = _MockPatientRepository();
      final _MockOpdRepository opdRepository = _MockOpdRepository();
      _stubPatientLookups(patientRepository, patients: const <Patient>[_patient]);
      _stubVisitorHosts(opdRepository);

      await _pumpOpenScheduler(
        tester,
        repository: patientRepository,
        opdRepository: opdRepository,
      );

      await tester.tap(find.text('Visitor / staff meeting'));
      await tester.pumpAndSettle();

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(find.text('Existing patient'), findsOneWidget);
      expect(find.text('New patient'), findsOneWidget);
      expect(find.text('Visitor / staff meeting'), findsOneWidget);
      final AppTabStrip tabs = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      expect(tabs.selectedId, 'visitor');
      expect(find.byType(ReceptionVisitorAppointmentDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppTextField && widget.labelText == 'Visitor name',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppSelectField<String> &&
              widget.labelText == 'Hosting staff',
        ),
        findsOneWidget,
      );
      expect(find.text('Non-patient meeting'), findsOneWidget);
      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.pinActionsToBottom, isTrue);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppButton && widget.label == 'Schedule appointment',
        ),
        findsOneWidget,
      );
      // Header chrome and footer both expose a Close control.
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is AppButton && widget.label == 'Close',
        ),
        findsAtLeastNWidgets(1),
      );
      expect(dialog.actions, hasLength(2));
      expect(
        dialog.actions.whereType<AppButton>().map((AppButton b) => b.label),
        containsAll(<String>['Close', 'Schedule appointment']),
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppButton && widget.label == 'Register patient',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Existing patient'));
      await tester.pumpAndSettle();
      expect(find.byType(AppListTable<Patient>), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppButton && widget.label == 'Schedule appointment',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'showReceptionPatientPickerDialog uses table with filters and settings',
    (WidgetTester tester) async {
      final _MockPatientRepository repository = _MockPatientRepository();
      _stubPatientLookups(repository, patients: const <Patient>[_patient]);

      await _pumpOpenPicker(tester, repository: repository);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);
      expect(find.byType(AppListTable<Patient>), findsOneWidget);
      expect(find.byType(AppSelectField<String>), findsNothing);
      expect(find.text('SELECT PATIENT'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is AppButton &&
              widget.label == 'Close' &&
              !widget.iconOnly,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is AppButton && widget.label == 'Select',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.filter_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.text('Export'), findsNothing);
      expect(find.byIcon(AppActionIcons.person), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );

      final AppListTable<Patient> table = tester.widget<AppListTable<Patient>>(
        find.byType(AppListTable<Patient>),
      );
      expect(table.enableExport, isFalse);
    },
  );

  testWidgets('Cancel dismisses without returning a patient', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository repository = _MockPatientRepository();
    _stubPatientLookups(repository, patients: const <Patient>[_patient]);

    Patient? selected;
    await _pumpOpenPicker(
      tester,
      repository: repository,
      onSelected: (Patient? value) => selected = value,
    );

    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppButton && widget.label == 'Close' && !widget.iconOnly,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(selected, isNull);
    verify(() => repository.listPatients(any())).called(greaterThan(0));
  });

  testWidgets('Select returns the chosen patient without mutating', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository repository = _MockPatientRepository();
    _stubPatientLookups(repository, patients: const <Patient>[_patient]);

    Patient? selected;
    await _pumpOpenPicker(
      tester,
      repository: repository,
      onSelected: (Patient? value) => selected = value,
    );

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (Widget widget) => widget is AppButton && widget.label == 'Select',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsNothing);
    expect(selected?.publicId, 'PAT000001');
    expect(selected?.effectiveDisplayName, 'Ada Lovelace');
  });

  testWidgets('search failure keeps dialog open and clears selection', (
    WidgetTester tester,
  ) async {
    final _MockPatientRepository repository = _MockPatientRepository();
    when(() => repository.loadOverview()).thenAnswer(
      (_) async => const Result<PatientRegistryOverview>.success(
        PatientRegistryOverview(totalPatients: 1, activePatients: 1),
      ),
    );
    when(() => repository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<PatientReferenceData>.success(PatientReferenceData()),
    );
    when(() => repository.listPatients(any())).thenAnswer((
      Invocation invocation,
    ) async {
      final PatientListQuery query =
          invocation.positionalArguments.single as PatientListQuery;
      final String search = query.search.trim();
      if (search == 'missing') {
        return const Result<AppPage<Patient>>.failure(AppFailure.network());
      }
      return Result<AppPage<Patient>>.success(
        AppPage<Patient>(
          items: const <Patient>[_patient],
          request: query.pageRequest,
          totalItemCount: 1,
        ),
      );
    });

    await _pumpOpenPicker(tester, repository: repository);

    await tester.tap(find.text('Ada Lovelace'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'missing');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsOneWidget);
    final Finder selectFinder = find.byWidgetPredicate(
      (Widget widget) => widget is AppButton && widget.label == 'Select',
    );
    expect(selectFinder, findsOneWidget);
    final AppButton selectButton = tester.widget<AppButton>(selectFinder);
    expect(selectButton.enabled, isFalse);
  });
}

Future<void> _pumpOpenScheduler(
  WidgetTester tester, {
  required _MockPatientRepository repository,
  OpdRepository? opdRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        patientRepositoryProvider.overrideWithValue(repository),
        if (opdRepository != null)
          opdRepositoryProvider.overrideWithValue(opdRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return AppButton.primary(
                label: 'Open scheduler',
                onPressed: () => openReceptionScheduleAppointment(
                  context: context,
                  ref: ref,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AppButton, 'Open scheduler'));
  await tester.pumpAndSettle();
}

void _stubVisitorHosts(_MockOpdRepository repository) {
  when(
    () => repository.listMeetingHosts(search: any(named: 'search')),
  ).thenAnswer(
    (_) async => const Result<List<OpdProviderOption>>.success(
      <OpdProviderOption>[
        OpdProviderOption(id: 'host-1', displayName: 'Dr Host'),
      ],
    ),
  );
  when(() => repository.listProviderSchedules()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderSchedule>>.success(<OpdProviderSchedule>[]),
  );
}

Future<void> _pumpOpenPicker(
  WidgetTester tester, {
  required _MockPatientRepository repository,
  ValueChanged<Patient?>? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        patientRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              return AppButton.primary(
                label: 'Open picker',
                onPressed: () async {
                  final Patient? patient = await showReceptionPatientPickerDialog(
                    context: context,
                  );
                  onSelected?.call(patient);
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(AppButton, 'Open picker'));
  await tester.pumpAndSettle();
}

void _stubPatientLookups(
  _MockPatientRepository repository, {
  required List<Patient> patients,
}) {
  when(() => repository.loadOverview()).thenAnswer(
    (_) async => Result<PatientRegistryOverview>.success(
      PatientRegistryOverview(
        totalPatients: patients.length,
        activePatients: patients.length,
      ),
    ),
  );
  when(() => repository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<PatientReferenceData>.success(PatientReferenceData()),
  );
  when(() => repository.listPatients(any())).thenAnswer((
    Invocation invocation,
  ) async {
    final PatientListQuery query =
        invocation.positionalArguments.single as PatientListQuery;
    return Result<AppPage<Patient>>.success(
      AppPage<Patient>(
        items: patients,
        request: query.pageRequest,
        totalItemCount: patients.length,
      ),
    );
  });
}
