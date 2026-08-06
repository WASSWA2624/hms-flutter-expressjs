import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/reception/presentation/widgets/reception_patient_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:mocktail/mocktail.dart';

class _MockPatientRepository extends Mock implements PatientRepository {}

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
    expect(find.widgetWithText(AppButton, 'Register patient'), findsOneWidget);
    expect(find.byType(AppDialog), findsOneWidget);
  });

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
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
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

    await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
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

    await tester.tap(find.widgetWithText(AppButton, 'Select'));
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
    expect(find.widgetWithText(AppButton, 'Select'), findsOneWidget);
    final AppButton selectButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Select'),
    );
    expect(selectButton.enabled, isFalse);
  });
}

Future<void> _pumpOpenScheduler(
  WidgetTester tester, {
  required _MockPatientRepository repository,
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
