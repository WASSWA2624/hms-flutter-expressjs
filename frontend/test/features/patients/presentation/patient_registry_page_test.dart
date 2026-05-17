import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
  });

  testWidgets('PatientFormDialog warns before saving duplicate candidates', (
    WidgetTester tester,
  ) async {
    var lookupCount = 0;
    var submitCount = 0;

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open patient form',
            onPressed: () {
              unawaited(
                showAppDialog<bool>(
                  context: context,
                  builder: (_) => PatientFormDialog(
                    referenceData: const PatientReferenceData(),
                    onLookupDuplicates: (PatientDuplicateQuery query) async {
                      lookupCount += 1;
                      expect(query.firstName, 'Jane');
                      expect(query.lastName, 'Doe');
                      return const Result<
                        AppPage<PatientDuplicateCandidate>
                      >.success(
                        AppPage<PatientDuplicateCandidate>(
                          items: <PatientDuplicateCandidate>[
                            PatientDuplicateCandidate(
                              reviewId: 'review-1',
                              confidenceScore: 92,
                              classification: 'STRONG_MATCH',
                              matchReasons: <String>['name', 'phone'],
                              candidatePatient: Patient(
                                id: 'patient-1',
                                displayName: 'Jane Doe',
                                primaryPhone: '+256700000000',
                              ),
                            ),
                          ],
                          request: AppPageRequest(pageSize: 8),
                          totalItemCount: 1,
                        ),
                      );
                    },
                    onSubmit: (Map<String, Object?> payload) async {
                      submitCount += 1;
                      return null;
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      size: const Size(1000, 800),
    );

    await tester.tap(find.text('Open patient form'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText).at(0), 'Jane');
    await tester.enterText(find.byType(EditableText).at(1), 'Doe');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(lookupCount, 1);
    expect(submitCount, 0);
    expect(find.text('Potential duplicate found'), findsOneWidget);
    expect(find.text('Save anyway'), findsOneWidget);

    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();

    expect(submitCount, 1);
  });

  testWidgets(
    'EmergencyPatientFormDialog submits an incomplete patient record',
    (WidgetTester tester) async {
      Map<String, Object?>? submittedPayload;

      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open emergency form',
              onPressed: () {
                unawaited(
                  showAppDialog<bool>(
                    context: context,
                    builder: (_) => EmergencyPatientFormDialog(
                      onSubmit: (Map<String, Object?> payload) async {
                        submittedPayload = payload;
                        return null;
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(900, 700),
      );

      await tester.tap(find.text('Open emergency form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register emergency patient'));
      await tester.pumpAndSettle();

      expect(submittedPayload?['first_name'], 'Emergency');
      expect(submittedPayload?['gender'], 'UNKNOWN');
      expect(submittedPayload?['is_active'], isTrue);

      final extensionJson =
          submittedPayload?['extension_json'] as Map<String, Object?>?;
      final registration =
          extensionJson?['registration'] as Map<String, Object?>?;
      expect(registration?['source'], 'EMERGENCY');
      expect(registration?['status'], 'INCOMPLETE');
      expect(registration?['requires_completion'], isTrue);
    },
  );

  testWidgets('EmergencyPatientFormDialog surfaces submit failures', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open failing form',
            onPressed: () {
              unawaited(
                showAppDialog<bool>(
                  context: context,
                  builder: (_) => EmergencyPatientFormDialog(
                    onSubmit: (_) async => const AppFailure.forbidden(),
                  ),
                ),
              );
            },
          );
        },
      ),
      size: const Size(900, 700),
    );

    await tester.tap(find.text('Open failing form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register emergency patient'));
    await tester.pumpAndSettle();

    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('appointment quick action keeps schedule fields balanced', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    const patient = Patient(
      id: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
    );

    when(() => patientRepository.loadOverview()).thenAnswer(
      (_) async => const Result<PatientRegistryOverview>.success(
        PatientRegistryOverview(totalPatients: 1, activePatients: 1),
      ),
    );
    when(() => patientRepository.loadReferenceData()).thenAnswer(
      (_) async =>
          const Result<PatientReferenceData>.success(PatientReferenceData()),
    );
    when(() => patientRepository.listPatients(any())).thenAnswer(
      (_) async => const Result<AppPage<Patient>>.success(
        AppPage<Patient>(
          items: <Patient>[patient],
          request: AppPageRequest(),
          totalItemCount: 1,
        ),
      ),
    );
    when(() => patientRepository.loadPatientDetail(patient.id)).thenAnswer(
      (_) async => const Result<PatientDetail>.success(
        PatientDetail(patient: patient, workspace: PatientWorkspaceSnapshot()),
      ),
    );
    _stubProviderLookup(opdRepository);

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1000, 820),
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule appointment'), findsOneWidget);

    final dateField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppDateField && widget.labelText == 'Appointment date',
    );
    final timeField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppTextField && widget.labelText == 'Start time',
    );
    final durationField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppTextField && widget.labelText == 'Duration minutes',
    );

    final Size dateSize = tester.getSize(dateField);
    final Size timeSize = tester.getSize(timeField);
    final Size durationSize = tester.getSize(durationField);
    final double dateTop = tester.getTopLeft(dateField).dy;
    final double timeTop = tester.getTopLeft(timeField).dy;
    final double durationTop = tester.getTopLeft(durationField).dy;

    expect(dateSize.width, greaterThan(timeSize.width * 2));
    expect(timeSize.width, lessThanOrEqualTo(150));
    expect(durationSize.width, lessThanOrEqualTo(180));
    expect((dateTop - timeTop).abs(), lessThan(1));
    expect((dateTop - durationTop).abs(), lessThan(1));
  });

  testWidgets('triage quick action shows vital units and range status', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final patient = Patient(
      id: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      dateOfBirth: DateTime(1990),
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
    );

    _stubPatientRegistry(patientRepository, patient);
    _stubProviderLookup(opdRepository);

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1000, 920),
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triage'));
    await tester.pumpAndSettle();

    expect(find.text('Triage intake'), findsOneWidget);
    expect(find.text('Blood pressure'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppSelectField<String> && widget.labelText == 'Unit',
      ),
      findsNWidgets(2),
    );
    expect(find.text('mmHg'), findsOneWidget);
    expect(find.text('\u00B0C'), findsOneWidget);
    expect(find.text('\u00B0F'), findsNothing);
    expect(find.text('beats per minute'), findsOneWidget);
    expect(find.text('breaths per minute'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(find.text('cm'), findsOneWidget);
    expect(find.textContaining('Expected for Adult Female'), findsWidgets);

    final Finder systolicInput = find.descendant(
      of: find.byWidgetPredicate(
        (Widget widget) =>
            widget is AppTextField && widget.labelText == 'Systolic',
      ),
      matching: find.byType(EditableText),
    );

    await tester.enterText(systolicInput, '500');
    await tester.pumpAndSettle();
    expect(find.text('Enter a value between 30-300 mmHg.'), findsOneWidget);

    await tester.enterText(systolicInput, '125');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Abnormal - Expected for Adult Female: 90-120 mmHg'),
      findsOneWidget,
    );

    await tester.enterText(systolicInput, '110');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Normal - Expected for Adult Female: 90-120 mmHg'),
      findsOneWidget,
    );
  });

  testWidgets('patient report opens configurable paginated print preview', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final DateTime occurredAt = DateTime(2026, 5, 16, 7, 45);
    final patient = Patient(
      id: 'patient-1',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      dateOfBirth: DateTime(1990),
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryEmail: 'amina@example.com',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
      tenantLabel: 'HOSSPI Health',
      facilityLabel: 'Demo General Hospital',
    );
    final PatientDetail detail = PatientDetail(
      patient: patient,
      workspace: PatientWorkspaceSnapshot(
        appointments: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'appointment-1',
            kind: 'appointment',
            status: 'scheduled',
            title: 'Dental review',
            subtitle: 'Clinic room 2',
            occurredAt: occurredAt,
          ),
        ],
        encounters: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'encounter-1',
            kind: 'encounter',
            status: 'open',
            title: 'OPD encounter',
            subtitle: 'General consultation',
            occurredAt: occurredAt,
          ),
        ],
        admissions: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'admission-1',
            kind: 'admission',
            status: 'active',
            title: 'Medical ward',
            subtitle: 'Bed A2',
            occurredAt: occurredAt,
          ),
        ],
        invoices: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'invoice-1',
            kind: 'invoice',
            status: 'sent',
            title: 'Consultation invoice',
            amount: 120000,
            currency: 'UGX',
            occurredAt: occurredAt,
          ),
        ],
        payments: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'payment-1',
            kind: 'payment',
            status: 'posted',
            title: 'Mobile money payment',
            amount: 50000,
            currency: 'UGX',
            occurredAt: occurredAt,
          ),
        ],
      ),
      identifiers: const <PatientIdentifier>[
        PatientIdentifier(
          id: 'identifier-1',
          tenantId: 'tenant-1',
          patientId: 'patient-1',
          type: 'MRN',
          value: 'MRN-10024',
          isPrimary: true,
        ),
      ],
      contacts: const <PatientContact>[
        PatientContact(
          id: 'contact-1',
          tenantId: 'tenant-1',
          patientId: 'patient-1',
          type: 'phone',
          value: '+256700000000',
          isPrimary: true,
        ),
      ],
      medicalHistories: <PatientMedicalHistory>[
        PatientMedicalHistory(
          id: 'history-1',
          tenantId: 'tenant-1',
          patientId: 'patient-1',
          condition: 'Hypertension',
          diagnosisDate: DateTime(2022, 3),
          notes: 'Managed with medication.',
        ),
      ],
      timeline: <PatientTimelineItem>[
        for (var index = 0; index < 22; index++)
          PatientTimelineItem(
            id: 'timeline-$index',
            resource: index.isEven ? 'encounter' : 'vital_sign',
            title: index.isEven
                ? 'Encounter note ${index + 1}'
                : 'Vital signs ${index + 1}',
            subtitle: index.isEven ? 'Clinical update' : 'BP 110/70 mmHg',
            occurredAt: occurredAt.subtract(Duration(days: index)),
          ),
      ],
    );

    _stubPatientRegistry(patientRepository, patient, detail: detail);
    _stubProviderLookup(opdRepository);

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1200, 960),
      roles: const <String>['SUPER_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patient report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Print report'));
    await tester.pumpAndSettle();

    expect(find.text('Print preview'), findsOneWidget);
    expect(find.text('Report period'), findsWidgets);
    expect(find.text('Report sections'), findsOneWidget);
    expect(find.text('Patient information'), findsWidgets);
    expect(find.text('Hospital information'), findsWidgets);
    expect(find.text('Vital signs'), findsWidgets);
    expect(find.text('Demo General Hospital'), findsWidgets);
    expect(find.text('Amina Kato'), findsWidgets);
    expect(find.text('Print'), findsOneWidget);
    expect(find.textContaining(RegExp(r'1 of [2-9]')), findsOneWidget);
    expect(find.textContaining(RegExp(r'2 of [2-9]')), findsWidgets);
  });
}

final class _MockPatientRepository extends Mock implements PatientRepository {}

final class _MockOpdRepository extends Mock implements OpdRepository {}

void _stubPatientRegistry(
  _MockPatientRepository patientRepository,
  Patient patient, {
  PatientDetail? detail,
}) {
  when(() => patientRepository.loadOverview()).thenAnswer(
    (_) async => const Result<PatientRegistryOverview>.success(
      PatientRegistryOverview(totalPatients: 1, activePatients: 1),
    ),
  );
  when(() => patientRepository.loadReferenceData()).thenAnswer(
    (_) async =>
        const Result<PatientReferenceData>.success(PatientReferenceData()),
  );
  when(() => patientRepository.listPatients(any())).thenAnswer(
    (_) async => Result<AppPage<Patient>>.success(
      AppPage<Patient>(
        items: <Patient>[patient],
        request: const AppPageRequest(),
        totalItemCount: 1,
      ),
    ),
  );
  when(() => patientRepository.loadPatientDetail(patient.id)).thenAnswer(
    (_) async => Result<PatientDetail>.success(
      detail ??
          PatientDetail(
            patient: patient,
            workspace: const PatientWorkspaceSnapshot(),
          ),
    ),
  );
}

void _stubProviderLookup(_MockOpdRepository opdRepository) {
  when(() => opdRepository.listProviders()).thenAnswer(
    (_) async =>
        const Result<List<OpdProviderOption>>.success(<OpdProviderOption>[]),
  );
}

Future<void> _pumpPatientRegistry(
  WidgetTester tester, {
  required PatientRepository patientRepository,
  required OpdRepository opdRepository,
  required Size size,
  List<String> roles = const <String>['DOCTOR'],
}) async {
  setTestViewport(tester, size);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSessionStateProvider.overrideWithValue(
          SessionState.authenticated(
            session: AuthSession(
              tokens: SessionTokens(accessToken: 'test-access-token'),
              subject: 'doctor@example.com',
              user: AuthUserProfile(
                id: 'user-1',
                email: 'doctor@example.com',
                roles: roles,
              ),
            ),
          ),
        ),
        patientRepositoryProvider.overrideWithValue(patientRepository),
        opdRepositoryProvider.overrideWithValue(opdRepository),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const Scaffold(body: PatientRegistryPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
