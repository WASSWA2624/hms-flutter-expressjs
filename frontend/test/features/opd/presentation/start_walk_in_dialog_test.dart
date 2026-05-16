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
  });

  testWidgets('StartWalkInDialog loads and submits the new patient flow', (
    WidgetTester tester,
  ) async {
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
      (_) async =>
          const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
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
            body: StartWalkInDialog(
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
    await tester.tap(find.text('Start walk-in').last);
    await tester.pumpAndSettle();

    expect(submittedPayload?['patient_registration'], <String, Object?>{
      'first_name': 'Jane',
      'last_name': 'Doe',
      'gender': null,
    });
  });
}
