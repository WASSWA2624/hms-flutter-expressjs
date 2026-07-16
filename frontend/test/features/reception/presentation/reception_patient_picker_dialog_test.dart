import 'dart:async';

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

  testWidgets(
    'showReceptionPatientPickerDialog uses AppDialog shell and shared select field',
    (WidgetTester tester) async {
      final _MockPatientRepository repository = _MockPatientRepository();
      _stubPatientLookups(repository, patients: const <Patient>[_patient]);

      await _pumpOpenPicker(tester, repository: repository);

      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.byType(AppSelectField<String>), findsOneWidget);
      expect(find.byType(AppFormShell), findsOneWidget);
      expect(find.text('SELECT PATIENT'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Select'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.person), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widgetList<ModalBarrier>(find.byType(ModalBarrier))
            .any((ModalBarrier barrier) => barrier.dismissible),
        isFalse,
      );

      final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
        find.byType(AppSelectField<String>),
      );
      expect(
        field.options.map((AppSelectOption<String> option) => option.value),
        contains('PAT000001'),
      );
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

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('PAT000001');
    await tester.pump();

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

    final AppSelectField<String> field = tester.widget<AppSelectField<String>>(
      find.byType(AppSelectField<String>),
    );
    field.onChanged?.call('PAT000001');
    await tester.pump();
    field.onSearchTextChanged?.call('missing');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(AppFormInformationBanner), findsOneWidget);
    final AppSelectField<String> updated = tester
        .widget<AppSelectField<String>>(find.byType(AppSelectField<String>));
    expect(updated.value, isNull);
    expect(find.widgetWithText(AppButton, 'Select'), findsOneWidget);
    final AppButton selectButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Select'),
    );
    expect(selectButton.enabled, isFalse);
  });
}

Future<void> _pumpOpenPicker(
  WidgetTester tester, {
  required _MockPatientRepository repository,
  void Function(Patient? selected)? onSelected,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        initialSessionStateProvider.overrideWithValue(
          const SessionState.ready(),
        ),
        patientRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: AppButton.primary(
                  label: 'Open picker',
                  leadingIcon: AppActionIcons.person,
                  onPressed: () async {
                    final Patient? selected =
                        await showReceptionPatientPickerDialog(
                          context: context,
                        );
                    onSelected?.call(selected);
                  },
                ),
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
