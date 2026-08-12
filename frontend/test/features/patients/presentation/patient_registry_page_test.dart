import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_state.dart';
import 'package:hosspi_hms/core/security/secure_session_storage.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/domain/repositories/discharge_repository.dart';
import 'package:hosspi_hms/features/ipd/data/repositories/ipd_repository_impl.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/domain/repositories/ipd_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/domain/repositories/opd_repository.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/domain/repositories/patient_repository.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_widgets.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/test_harness.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(const PatientListQuery());
    registerFallbackValue(const PatientDuplicateQuery());
    registerFallbackValue(const OpdAppointmentQuery());
    registerFallbackValue(const OpdFlowQuery());
    registerFallbackValue(<String, Object?>{});
  });

  test('Patient Registry depends on shared OPD actions, not the OPD page', () {
    final String source = File(
      'lib/features/patients/presentation/pages/patient_registry_page.dart',
    ).readAsStringSync();

    expect(source, contains('shared/opd_actions/opd_actions.dart'));
    expect(
      source,
      isNot(
        contains('features/opd/presentation/pages/opd_workspace_page.dart'),
      ),
    );
  });

  testWidgets(
    'RegisterNewPatientDialog opens similarity dialog before saving duplicates',
    (WidgetTester tester) async {
      var lookupCount = 0;
      var submitCount = 0;

      await _pumpRegisterSimilarityHarness(
        tester,
        onLookupDuplicates: (PatientDuplicateQuery query) async {
          lookupCount += 1;
          expect(query.firstName, 'Jane');
          expect(query.lastName, 'Doe');
          expect(query.gender, 'FEMALE');
          return const Result<AppPage<PatientDuplicateCandidate>>.success(
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
          return _registeredPatientResult(payload);
        },
      );

      await tester.tap(find.text('Open register dialog'));
      await tester.pumpAndSettle();

      await _fillRegisterPatientBasics(tester);
      await tester.tap(find.text('Register patient'));
      await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

      expect(lookupCount, 1);
      expect(submitCount, 0);
      expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
      expect(find.text('Potential duplicate found'), findsOneWidget);
      expect(find.text('Register anyway'), findsOneWidget);

      await tester.tap(find.text('Register anyway'));
      await _pumpUntilGone(tester, find.text('SIMILAR PATIENTS FOUND'));

      expect(submitCount, 1);
    },
  );

  testWidgets(
    'RegisterNewPatientDialog rechecks similarity after cancel and edit',
    (WidgetTester tester) async {
      var lookupCount = 0;

      await _pumpRegisterSimilarityHarness(
        tester,
        useShowAppDialog: true,
        onLookupDuplicates: (PatientDuplicateQuery query) async {
          lookupCount += 1;
          return const Result<AppPage<PatientDuplicateCandidate>>.success(
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
          return _registeredPatientResult(payload);
        },
      );

      await tester.tap(find.text('Open register dialog'));
      await tester.pumpAndSettle();

      await _fillRegisterPatientBasics(tester);
      await tester.tap(find.text('Register patient'));
      await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

      expect(lookupCount, 1);
      expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
      expect(find.text('Register anyway'), findsOneWidget);

      await tester.tap(find.widgetWithText(AppButton, 'Close').last);
      await _pumpUntilGone(tester, find.text('SIMILAR PATIENTS FOUND'));

      expect(find.text('SIMILAR PATIENTS FOUND'), findsNothing);
      expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);

      await tester.enterText(find.byType(EditableText).at(0), 'Janet');
      await tester.pump();
      await tester.tap(find.text('Register patient'));
      await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

      expect(lookupCount, 2);
      expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
    },
  );

  testWidgets(
    'RegisterNewPatientDialog disables facility until tenant is selected',
    (WidgetTester tester) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open register dialog',
              onPressed: () {
                unawaited(
                  showAppDialog<Patient>(
                    context: context,
                    builder: (_) => RegisterNewPatientDialog(
                      referenceData: const PatientReferenceData(
                        tenants: <PatientReferenceOption>[
                          PatientReferenceOption(
                            id: 'tenant-1',
                            label: 'DemoCare Tenant',
                          ),
                          PatientReferenceOption(
                            id: 'tenant-2',
                            label: 'Other Tenant',
                          ),
                        ],
                        facilities: <PatientReferenceOption>[
                          PatientReferenceOption(
                            id: 'facility-1',
                            label: 'DemoCare General Hospital',
                            tenantId: 'tenant-1',
                          ),
                          PatientReferenceOption(
                            id: 'facility-2',
                            label: 'Other Clinic',
                            tenantId: 'tenant-2',
                          ),
                        ],
                      ),
                      registrationScope: const PatientRegistrationScope(
                        showTenantPicker: true,
                        showFacilityPicker: true,
                      ),
                      onSubmit: (_) async => _registeredPatientResult(const {}),
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(1000, 800),
      );

      await tester.tap(find.text('Open register dialog'));
      await tester.pumpAndSettle();

      final Finder facilityField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is PatientFacilitySelectField && !widget.enabled,
      );
      expect(facilityField, findsOneWidget);
      expect(find.byTooltip('Please select a tenant first.'), findsOneWidget);

      final Finder tenantSelect = find.descendant(
        of: find.byType(PatientTenantSelectField),
        matching: find.byType(EditableText),
      );
      await tester.tap(tenantSelect);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('DemoCare Tenant'),
        ),
      );
      await tester.pumpAndSettle();

      final Finder enabledFacilityField = find.byWidgetPredicate(
        (Widget widget) =>
            widget is PatientFacilitySelectField && widget.enabled,
      );
      expect(enabledFacilityField, findsOneWidget);
      expect(find.byTooltip('Please select a tenant first.'), findsNothing);

      final Finder facilitySelect = find.descendant(
        of: enabledFacilityField,
        matching: find.byType(EditableText),
      );
      await tester.tap(facilitySelect);
      await tester.pumpAndSettle();
      expect(find.text('DemoCare General Hospital'), findsWidgets);
      expect(find.text('Other Clinic'), findsNothing);
    },
  );

  testWidgets('RegisterNewPatientDialog creates a patient master record only', (
    WidgetTester tester,
  ) async {
    Map<String, Object?>? submittedPayload;

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open register dialog',
            onPressed: () {
              unawaited(
                showAppDialog<Patient>(
                  context: context,
                  builder: (_) => RegisterNewPatientDialog(
                    referenceData: const PatientReferenceData(),
                    registrationScope: const PatientRegistrationScope(
                      defaultTenantId: 'tenant-1',
                      defaultFacilityId: 'facility-1',
                    ),
                    onSubmit: (Map<String, Object?> payload) async {
                      submittedPayload = payload;
                      return _registeredPatientResult(payload);
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

    await tester.tap(find.text('Open register dialog'));
    await tester.pumpAndSettle();
    await _fillRegisterPatientBasics(
      tester,
      firstName: 'Amina',
      lastName: 'Kato',
    );
    await tester.tap(find.text('Register patient'));
    await tester.pumpAndSettle();

    expect(submittedPayload?['first_name'], 'Amina');
    expect(submittedPayload?['last_name'], 'Kato');
    expect(submittedPayload?['gender'], 'FEMALE');
    expect(submittedPayload?['tenant_id'], 'tenant-1');
    expect(submittedPayload?['facility_id'], 'facility-1');
    expect(submittedPayload?['is_active'], isTrue);
    expect(submittedPayload?.containsKey('patient_registration'), isFalse);
  });

  testWidgets(
    'RegisterNewPatientDialog shows tenant and facility pickers for multi-tenant scope',
    (WidgetTester tester) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open register dialog',
              onPressed: () {
                unawaited(
                  showAppDialog<Patient>(
                    context: context,
                    builder: (_) => RegisterNewPatientDialog(
                      referenceData: const PatientReferenceData(
                        tenants: <PatientReferenceOption>[
                          PatientReferenceOption(
                            id: 'tenant-1',
                            label: 'DemoCare Tenant',
                          ),
                        ],
                        facilities: <PatientReferenceOption>[
                          PatientReferenceOption(
                            id: 'facility-1',
                            label: 'DemoCare General Hospital',
                            tenantId: 'tenant-1',
                          ),
                        ],
                      ),
                      registrationScope: const PatientRegistrationScope(
                        showTenantPicker: true,
                        showFacilityPicker: true,
                      ),
                      onSubmit: (_) async => _registeredPatientResult(const {}),
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(1000, 800),
      );

      await tester.tap(find.text('Open register dialog'));
      await tester.pumpAndSettle();

      expect(find.byType(PatientTenantSelectField), findsOneWidget);
      expect(find.byType(PatientFacilitySelectField), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    },
  );

  testWidgets('RegisterNewPatientDialog saves without optional last name', (
    WidgetTester tester,
  ) async {
    Map<String, Object?>? submittedPayload;

    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open register dialog',
            onPressed: () {
              unawaited(
                showAppDialog<Patient>(
                  context: context,
                  builder: (_) => RegisterNewPatientDialog(
                    referenceData: const PatientReferenceData(),
                    onSubmit: (Map<String, Object?> payload) async {
                      submittedPayload = payload;
                      return _registeredPatientResult(payload);
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

    await tester.tap(find.text('Open register dialog'));
    await tester.pumpAndSettle();
    await _fillRegisterPatientBasics(tester, firstName: 'Amina', lastName: '');
    await tester.tap(find.text('Register patient'));
    await tester.pumpAndSettle();

    expect(submittedPayload?['first_name'], 'Amina');
    expect(submittedPayload?['last_name'], isNull);
    expect(submittedPayload?['gender'], 'FEMALE');
  });

  testWidgets(
    'RegisterNewPatientDialog disables identifier value until type is selected',
    (WidgetTester tester) async {
      await pumpLocalizedWidget(
        tester,
        Builder(
          builder: (BuildContext context) {
            return AppButton.primary(
              label: 'Open register dialog',
              onPressed: () {
                unawaited(
                  showAppDialog<Patient>(
                    context: context,
                    builder: (_) => RegisterNewPatientDialog(
                      referenceData: const PatientReferenceData(),
                      onSubmit: (_) async => _registeredPatientResult(const {}),
                    ),
                  ),
                );
              },
            );
          },
        ),
        size: const Size(1000, 800),
      );

      await tester.tap(find.text('Open register dialog'));
      await tester.pumpAndSettle();

      final AppTextField identifierValueField = tester.widget<AppTextField>(
        _identifierValueField(),
      );
      expect(identifierValueField.enabled, isFalse);
      expect(identifierValueField.tooltip, 'Select an identifier type first.');
      expect(
        find.byTooltip('Select an identifier type first.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('patient worklist shows registry contract columns', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      dateOfBirth: DateTime(1990),
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
      hasAllergyAlert: true,
      allergyAlertLabel: 'Penicillin - Severe',
      currentVisit: PatientVisitContext(
        kind: 'encounter',
        publicId: 'ENC-2001',
        status: 'IN_PROGRESS',
        title: 'OPD',
        occurredAt: DateTime(2026, 5, 18),
      ),
    );

    _stubPatientRegistry(patientRepository, patient);
    _stubProviderLookup(opdRepository);

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1280, 900),
    );

    expect(find.text('Patient name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Next action'), findsOneWidget);
    expect(find.text('Patient no.'), findsNothing);
    expect(find.text('Age / sex'), findsNothing);
    expect(find.text('Visit'), findsNothing);
    expect(find.text('MRN MRN-10024'), findsOneWidget);
    expect(find.text('+256700000000'), findsOneWidget);
    expect(find.text('Penicillin - Severe'), findsOneWidget);
    expect(find.text('OPD - In Progress'), findsNothing);
    // Open record is label-only (row or next-action cell opens detail).
    expect(find.text('Open record'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppButton),
        matching: find.text('Open record'),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('TABLE SETTINGS'), findsOneWidget);
  });

  testWidgets(
    'Complete record next action opens edit form without detail shell',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      const patient = Patient(
        id: 'patient-incomplete-1',
        publicId: 'PAT-INC-1',
        firstName: 'Incomplete',
        lastName: 'Patient',
        requiresCompletion: true,
      );

      _stubPatientRegistry(patientRepository, patient);
      _stubProviderLookup(opdRepository);
      when(() => patientRepository.updatePatient(patient.id, any())).thenAnswer(
        (_) async => const Result<Patient>.success(patient),
      );

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        roles: const <String>['PLATFORM_ADMIN'],
      );

      expect(find.text('Complete record'), findsOneWidget);
      await tester.tap(find.text('Complete record'));
      await tester.pumpAndSettle();

      expect(find.byType(PatientFormDialog), findsOneWidget);
      expect(find.text('EDIT PATIENT'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
    },
  );

  testWidgets(
    'Duplicate review toolbar opens when overview has candidates',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      const patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );
      const secondary = Patient(
        id: 'patient-2',
        publicId: 'PAT-1002',
        firstName: 'Amina',
        lastName: 'Kato',
      );
      const duplicate = PatientDuplicateCandidate(
        reviewId: 'dup-1',
        confidenceScore: 88,
        classification: 'STRONG',
        primaryPatient: patient,
        secondaryPatient: secondary,
        fieldComparisons: <PatientDuplicateFieldComparison>[
          PatientDuplicateFieldComparison(
            field: 'PHONE',
            inputValue: '+256700000001',
            candidateValue: '+256700000001',
            status: 'MATCH',
            contribution: 45,
            similarityPercent: 100,
          ),
        ],
      );

      _stubPatientRegistry(
        patientRepository,
        patient,
        duplicates: const <PatientDuplicateCandidate>[duplicate],
      );
      _stubProviderLookup(opdRepository);
      when(
        () => patientRepository.previewPatientMerge(
          primaryPatientId: any(named: 'primaryPatientId'),
          secondaryPatientId: any(named: 'secondaryPatientId'),
        ),
      ).thenAnswer(
        (_) async => const Result<PatientMergePreview>.success(
          PatientMergePreview(
            primaryPatient: patient,
            secondaryPatient: secondary,
            confidenceScore: 88,
            classification: 'STRONG',
            transferCounts: <String, int>{'contacts': 1},
          ),
        ),
      );

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        roles: const <String>['PLATFORM_ADMIN'],
      );

      expect(find.byTooltip('Potential matches needing review.'), findsOneWidget);
      await tester.tap(find.text('Duplicate review'));
      await tester.pumpAndSettle();

      expect(find.text('Duplicate review'), findsWidgets);
      expect(find.text('Review merge'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Review merge'));
      await tester.pumpAndSettle();

      expect(find.text('Merge preview'), findsOneWidget);
      expect(find.text('Keep left'), findsOneWidget);
      expect(find.text('Keep right'), findsOneWidget);
      expect(find.text('Auto-merge'), findsOneWidget);
      expect(find.text('Merge patients'), findsNothing);

      final Finder autoMerge = find.text('Auto-merge');
      await tester.ensureVisible(autoMerge);
      await tester.pumpAndSettle();
      await tester.tap(autoMerge);
      await tester.pumpAndSettle();
      final Finder mergePatients = find.text('Merge patients');
      await tester.ensureVisible(mergePatients);
      await tester.pumpAndSettle();
      expect(mergePatients, findsOneWidget);
    },
  );

  testWidgets(
    'unauthorized users do not see Register patient or Duplicate review',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      const patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );
      const duplicate = PatientDuplicateCandidate(
        reviewId: 'dup-1',
        confidenceScore: 88,
        classification: 'STRONG',
        primaryPatient: patient,
        secondaryPatient: Patient(
          id: 'patient-2',
          publicId: 'PAT-1002',
          firstName: 'Amina',
          lastName: 'Kato',
        ),
      );

      _stubPatientRegistry(
        patientRepository,
        patient,
        duplicates: const <PatientDuplicateCandidate>[duplicate],
      );
      _stubProviderLookup(opdRepository);

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        roles: const <String>['PHARMACIST'],
      );

      expect(find.byTooltip('Register patient'), findsNothing);
      expect(find.text('Duplicate review'), findsNothing);
    },
  );

  testWidgets(
    'RegisterNewPatientDialog opens patient detail dialog after save',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      const createdPatient = Patient(
        id: 'patient-new-1',
        firstName: 'Amina',
        lastName: 'Kato',
      );

      _stubPatientRegistry(patientRepository, createdPatient);
      _stubProviderLookup(opdRepository);
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

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1400, 900),
        roles: const <String>['PLATFORM_ADMIN'],
      );

      await tester.tap(find.text('Register patient'));
      await tester.pumpAndSettle();
      await _fillRegisterPatientBasics(
        tester,
        firstName: 'Amina',
        lastName: 'Kato',
      );
      await tester.tap(find.text('Register patient').last);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
      expect(find.text('Amina Kato'), findsWidgets);
    },
  );

  testWidgets('RegisterNewPatientDialog surfaces submit failures', (
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
                showAppDialog<Patient>(
                  context: context,
                  builder: (_) => RegisterNewPatientDialog(
                    referenceData: const PatientReferenceData(),
                    onSubmit: (_) async =>
                        const Result<Patient>.failure(AppFailure.forbidden()),
                  ),
                ),
              );
            },
          );
        },
      ),
      size: const Size(1000, 800),
    );

    await tester.tap(find.text('Open failing form'));
    await tester.pumpAndSettle();
    await _fillRegisterPatientBasics(tester, firstName: 'Amina', lastName: '');
    await tester.tap(find.text('Register patient'));
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
    await tester.tap(find.text('Schedule appointment').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Schedule appointment'), findsWidgets);

    final dateField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppDateField && widget.labelText == 'Appointment date',
    );
    final timeField = find.byWidgetPredicate(
      (Widget widget) =>
          widget is AppTimeField && widget.labelText == 'Start time',
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

    expect(dateSize.width, greaterThan(200));
    expect(timeSize.width, greaterThan(120));
    expect(durationSize.width, greaterThan(120));
    expect(dateTop, lessThan(timeTop));
    expect((timeTop - durationTop).abs(), lessThan(1));
  });

  testWidgets('OPD quick action opens the shared encounter dialog', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    const patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
    );

    _stubPatientRegistry(patientRepository, patient);
    _stubProviderLookup(opdRepository);
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
      (Invocation invocation) async => Result<AppPage<OpdFlowSummary>>.success(
        AppPage<OpdFlowSummary>(
          items: const <OpdFlowSummary>[],
          request: (invocation.positionalArguments.single as OpdFlowQuery)
              .pageRequest,
          totalItemCount: 0,
        ),
      ),
    );

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1000, 820),
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start OPD encounter').first);
    await tester.pumpAndSettle();

    expect(find.text('Existing patient'), findsNothing);
    expect(find.text('Search patient *'), findsNothing);
    expect(find.text('Start encounter'), findsOneWidget);
  });

  testWidgets('patient quick actions expose one OPD entry point', (
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
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();

    expect(find.text('Start OPD encounter'), findsOneWidget);
    expect(find.text('Continue OPD flow'), findsNothing);
    expect(find.text('Triage'), findsNothing);
    expect(find.text('Billing'), findsNothing);
    expect(find.text('Record vitals'), findsNothing);
    expect(find.text('Assign doctor'), findsNothing);
    expect(find.text('Clinical notes'), findsNothing);
    expect(find.text('Manage consultation billing'), findsNothing);
    expect(find.text('Prescribe'), findsNothing);
  });

  testWidgets('active OPD patient quick action continues the flow', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    const patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
      currentVisit: PatientVisitContext(
        kind: 'encounter',
        publicId: 'OPD-1',
        status: 'WAITING_VITALS',
        title: 'OPD encounter',
      ),
    );

    _stubPatientRegistry(patientRepository, patient);
    _stubProviderLookup(opdRepository);
    when(() => opdRepository.getOpdFlow('OPD-1')).thenAnswer(
      (_) async => const Result<OpdFlowDetail>.success(
        OpdFlowDetail(
          summary: OpdFlowSummary(
            id: 'OPD-1',
            publicId: 'OPD-1',
            patientId: 'patient-1',
            status: 'OPEN',
            stage: 'WAITING_VITALS',
            displayCode: 'VITALS_NEEDED',
          ),
        ),
      ),
    );

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1100, 960),
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();

    expect(find.text('Continue OPD flow'), findsOneWidget);
    expect(find.text('Start OPD encounter'), findsNothing);
    expect(find.text('Triage'), findsNothing);
    expect(find.text('Billing'), findsNothing);
    expect(find.text('Record vitals'), findsNothing);
    expect(find.text('Assign doctor'), findsNothing);
    expect(find.text('Clinical notes'), findsNothing);
    expect(find.text('Manage consultation billing'), findsNothing);

    await tester.tap(find.text('Continue OPD flow'));
    await tester.pumpAndSettle();

    // Stage next-action opens vitals directly — no empty Flow Actions hub.
    expect(find.text('Record vitals'), findsWidgets);
    expect(find.text('Flow actions'), findsNothing);
  });

  testWidgets('request admission quick action opens maximized dialog', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final ipdRepository = _MockIpdRepository();
    const patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
    );

    _stubPatientRegistry(patientRepository, patient);
    when(() => patientRepository.loadReferenceData()).thenAnswer(
      (_) async => const Result<PatientReferenceData>.success(
        PatientReferenceData(
          facilities: <PatientReferenceOption>[
            PatientReferenceOption(id: 'facility-1', label: 'Main hospital'),
          ],
          wards: <PatientReferenceOption>[
            PatientReferenceOption(
              id: 'ward-1',
              label: 'Medical ward',
              facilityId: 'facility-1',
            ),
          ],
          rooms: <PatientReferenceOption>[
            PatientReferenceOption(
              id: 'room-1',
              label: 'Room 101',
              wardId: 'ward-1',
              facilityId: 'facility-1',
            ),
          ],
          beds: <PatientReferenceOption>[
            PatientReferenceOption(
              id: 'bed-1',
              label: 'Bed A',
              wardId: 'ward-1',
              roomId: 'room-1',
              facilityId: 'facility-1',
              status: 'AVAILABLE',
            ),
          ],
        ),
      ),
    );
    _stubProviderLookup(opdRepository);
    when(() => ipdRepository.requestAdmission(any())).thenAnswer(
      (_) async => const Result<IpdAdmissionDetail>.success(
        IpdAdmissionDetail(
          summary: IpdAdmissionSummary(
            id: 'admission-1',
            stage: 'ADMISSION_REQUESTED',
            admissionStatus: 'REQUESTED',
          ),
        ),
      ),
    );

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      ipdRepository: ipdRepository,
      size: const Size(1100, 960),
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();

    expect(find.text('Request admission'), findsOneWidget);
    expect(find.text('Admit patient'), findsNothing);

    await tester.tap(find.text('Request admission'));
    await tester.pumpAndSettle();

    expect(find.byType(PatientAdmissionQuickDialog), findsOneWidget);
    expect(find.byType(ClinicalAdmissionActionDialog), findsOneWidget);
    expect(find.text('Request admission'), findsWidgets);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_exit), findsWidgets);
    expect(find.byIcon(AppActionIcons.bed), findsWidgets);
    expect(find.byType(PatientFacilitySelectField), findsNothing);
  });

  testWidgets('active admission quick action opens discharge dialog', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final dischargeRepository = _MockDischargeRepository();
    const patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      tenantId: 'tenant-1',
      facilityId: 'facility-1',
      firstName: 'Amina',
      lastName: 'Kato',
      gender: 'FEMALE',
      primaryPhone: '+256700000000',
      primaryIdentifierType: 'MRN',
      primaryIdentifierValue: 'MRN-10024',
      currentVisit: PatientVisitContext(
        kind: 'admission',
        publicId: 'admission-1',
        status: 'ADMITTED',
        title: 'Admission',
      ),
    );
    const detail = PatientDetail(
      patient: patient,
      workspace: PatientWorkspaceSnapshot(
        admissions: <PatientSummaryRecord>[
          PatientSummaryRecord(
            id: 'admission-1',
            kind: 'admission',
            status: 'ADMITTED',
            title: 'Medical ward',
            subtitle: 'Bed A2',
          ),
        ],
      ),
    );
    const dischargeDetail = DischargeAdmissionDetail(
      ipd: IpdAdmissionDetail(
        summary: IpdAdmissionSummary(
          id: 'admission-1',
          stage: 'DISCHARGE_PLANNED',
          admissionStatus: 'ADMITTED',
        ),
        latestDischargeSummary: IpdDischargeSummary(
          id: 'ds-1',
          status: 'PLANNED',
          summary: 'Ready for home care.',
          clearance: IpdDischargeClearance(
            summaryReady: true,
            pendingOrdersReviewed: true,
            pharmacyCleared: true,
            billingCleared: true,
            nursingCleared: true,
            documentsReady: true,
          ),
        ),
      ),
      patientId: 'patient-1',
    );

    _stubPatientRegistry(patientRepository, patient, detail: detail);
    _stubProviderLookup(opdRepository);
    when(
      () => dischargeRepository.getAdmissionDetail('admission-1'),
    ).thenAnswer(
      (_) async =>
          const Result<DischargeAdmissionDetail>.success(dischargeDetail),
    );
    when(
      () => dischargeRepository.updateDischargeClearance(any(), any()),
    ).thenAnswer((_) async => const Result<void>.success(null));
    when(
      () => dischargeRepository.finalizeDischarge('admission-1', any()),
    ).thenAnswer((_) async => const Result<void>.success(null));

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      dischargeRepository: dischargeRepository,
      size: const Size(1100, 960),
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();

    // Active work Continue is the sole discharge entry — no duplicate chip.
    expect(find.text('Manage admission'), findsNothing);
    expect(find.text('Discharge planning'), findsOneWidget);

    await tester.tap(find.text('Discharge planning'));
    await tester.pumpAndSettle();

    expect(find.text('Clearance checklist'), findsOneWidget);
    expect(
      find.text(
        'I confirm the patient has exited and documents were handed over.',
      ),
      findsNothing,
    );

    verify(
      () => dischargeRepository.getAdmissionDetail('admission-1'),
    ).called(1);
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
      roles: const <String>['PLATFORM_ADMIN'],
    );

    await tester.tap(find.text('Amina Kato').first);
    await tester.pumpAndSettle();
    expect(find.text('Patient report'), findsOneWidget);
    await tester.tap(find.text('Patient report'));
    await tester.pumpAndSettle();

    expect(find.text('PRINT PREVIEW'), findsOneWidget);
    expect(find.text('Report period'), findsWidgets);
    expect(find.text('Report sections'), findsOneWidget);
    expect(find.text('Patient information'), findsWidgets);
    expect(find.text('Hospital information'), findsWidgets);
    expect(find.text('Vital signs'), findsWidgets);
    expect(find.text('Demo General Hospital'), findsWidgets);
    expect(find.text('Amina Kato'), findsWidgets);
    // Preview Print plus toolbar Print when export is allowed.
    expect(find.text('Print'), findsWidgets);
    expect(find.textContaining(RegExp(r'1 of [2-9]')), findsWidgets);
    expect(find.textContaining(RegExp(r'2 of [2-9]')), findsWidgets);
  });

  testWidgets(
    'renders AppTabStrip with tabs, Register patient in search bar, and Filters/Settings',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      final patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );

      _stubPatientRegistry(patientRepository, patient);
      _stubProviderLookup(opdRepository);

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        useRouter: true,
      );

      expect(find.byType(AppTabStrip), findsOneWidget);
      expect(_patientTabLabel('All patients'), findsOneWidget);
      expect(_patientTabLabel('Active'), findsOneWidget);
      expect(_patientTabLabel('Admitted'), findsOneWidget);
      // Doctor role pack lacks billing:read — Balance due tab is absent.
      expect(_patientTabLabel('Balance due'), findsNothing);
      expect(find.byTooltip('Register patient'), findsOneWidget);
      expect(find.byTooltip('Refresh'), findsNothing);
      expect(find.text('Refresh'), findsNothing);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('Advanced filters'), findsNothing);
      expect(find.byTooltip('Settings'), findsOneWidget);
      // Doctor pack lacks evidence:export — Export/Print omitted.
      expect(find.byTooltip('Export'), findsNothing);
      expect(find.byTooltip('Print'), findsNothing);
      expect(find.byType(AppListTable<Patient>), findsOneWidget);
    },
  );

  testWidgets(
    'PLATFORM_ADMIN shows Export and Print; Filters dialog includes Close',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      final patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );

      _stubPatientRegistry(patientRepository, patient);
      _stubProviderLookup(opdRepository);

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        roles: const <String>['PLATFORM_ADMIN'],
        useRouter: true,
      );

      expect(find.byTooltip('Export'), findsOneWidget);
      expect(find.byTooltip('Print'), findsOneWidget);

      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(find.text('Apply filters'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('ADVANCED FILTERS'), findsNothing);
    },
  );

  testWidgets(
    'active-tab search narrows badge to filtered total; siblings stay overview',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      final patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );

      when(() => patientRepository.loadOverview()).thenAnswer(
        (_) async => const Result<PatientRegistryOverview>.success(
          PatientRegistryOverview(
            totalPatients: 12,
            activePatients: 5,
            activeAdmissions: 3,
          ),
        ),
      );
      when(() => patientRepository.loadReferenceData()).thenAnswer(
        (_) async =>
            const Result<PatientReferenceData>.success(PatientReferenceData()),
      );
      when(() => patientRepository.listPatients(any())).thenAnswer((
        Invocation invocation,
      ) async {
        final PatientListQuery query =
            invocation.positionalArguments.single as PatientListQuery;
        final bool narrowed = query.search.trim().isNotEmpty;
        return Result<AppPage<Patient>>.success(
          AppPage<Patient>(
            items: narrowed ? <Patient>[patient] : <Patient>[patient, patient],
            request: query.pageRequest,
            totalItemCount: narrowed ? 1 : 12,
          ),
        );
      });
      when(() => patientRepository.loadPatientDetail(patient.id)).thenAnswer(
        (_) async => Result<PatientDetail>.success(
          PatientDetail(
            patient: patient,
            workspace: const PatientWorkspaceSnapshot(),
          ),
        ),
      );
      _stubProviderLookup(opdRepository);

      await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        useRouter: true,
      );

      final AppTabStrip initialStrip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem allTab = initialStrip.tabs.firstWhere(
        (AppTabItem item) => item.id == 'all',
      );
      expect(allTab.count, 12);
      expect(allTab.countTone, AppTabCountTone.info);

      await tester.enterText(find.byType(TextField).first, 'Amina');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      final AppTabStrip filteredStrip = tester.widget<AppTabStrip>(
        find.byType(AppTabStrip),
      );
      final AppTabItem filteredAll = filteredStrip.tabs.firstWhere(
        (AppTabItem item) => item.id == 'all',
      );
      final AppTabItem activeSibling = filteredStrip.tabs.firstWhere(
        (AppTabItem item) => item.id == 'active',
      );
      expect(filteredAll.count, 1);
      expect(activeSibling.count, 5);
    },
  );

  testWidgets(
    'switching tabs updates section query and keeps Register patient in search bar',
    (WidgetTester tester) async {
      final patientRepository = _MockPatientRepository();
      final opdRepository = _MockOpdRepository();
      final patient = Patient(
        id: 'patient-1',
        publicId: 'PAT-1001',
        firstName: 'Amina',
        lastName: 'Kato',
      );

      _stubPatientRegistry(patientRepository, patient);
      _stubProviderLookup(opdRepository);

      final GoRouter? router = await _pumpPatientRegistry(
        tester,
        patientRepository: patientRepository,
        opdRepository: opdRepository,
        size: const Size(1280, 900),
        useRouter: true,
      );

      clearInteractions(patientRepository);
      _stubPatientRegistry(patientRepository, patient);

      await tester.tap(_patientTabLabel('Active'));
      await tester.pumpAndSettle();

      expect(router, isNotNull);
      expect(router!.state.uri.queryParameters['section'], 'active');
      expect(find.byTooltip('Register patient'), findsOneWidget);

      final List<PatientListQuery> queries = verify(
        () => patientRepository.listPatients(captureAny()),
      ).captured.cast<PatientListQuery>();
      expect(
        queries.any(
          (PatientListQuery query) =>
              query.section == PatientRegistrySection.active ||
              query.isActive == true,
        ),
        isTrue,
      );
    },
  );

  testWidgets('deep link section=admitted selects Admitted tab', (
    WidgetTester tester,
  ) async {
    final patientRepository = _MockPatientRepository();
    final opdRepository = _MockOpdRepository();
    final patient = Patient(
      id: 'patient-1',
      publicId: 'PAT-1001',
      firstName: 'Amina',
      lastName: 'Kato',
    );

    _stubPatientRegistry(patientRepository, patient);
    _stubProviderLookup(opdRepository);

    await _pumpPatientRegistry(
      tester,
      patientRepository: patientRepository,
      opdRepository: opdRepository,
      size: const Size(1280, 900),
      useRouter: true,
      initialLocation: '/patients?section=admitted',
      initialQuery: PatientListQuery.fromUri(
        Uri.parse('/patients?section=admitted'),
      ),
    );

    expect(find.byTooltip('Register patient'), findsOneWidget);
    expect(_patientTabLabel('Admitted'), findsOneWidget);

    final List<PatientListQuery> queries = verify(
      () => patientRepository.listPatients(captureAny()),
    ).captured.cast<PatientListQuery>();
    expect(
      queries.any(
        (PatientListQuery query) =>
            query.section == PatientRegistrySection.admitted ||
            query.hasActiveAdmission == true,
      ),
      isTrue,
    );
  });
}

Future<void> _pumpRegisterSimilarityHarness(
  WidgetTester tester, {
  required Future<Result<AppPage<PatientDuplicateCandidate>>> Function(
    PatientDuplicateQuery query,
  )
  onLookupDuplicates,
  required Future<Result<Patient>> Function(Map<String, Object?> payload)
  onSubmit,
  bool useShowAppDialog = false,
}) async {
  setTestViewport(tester, const Size(1200, 900));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConnectivityStatusProvider.overrideWith(
          (Ref ref) => Stream<AppConnectivityStatus>.value(
            AppConnectivityStatus.online,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: AppButton.primary(
                  label: 'Open register dialog',
                  onPressed: () {
                    if (useShowAppDialog) {
                      unawaited(
                        showAppDialog<Patient>(
                          context: context,
                          builder: (_) => RegisterNewPatientDialog(
                            referenceData: const PatientReferenceData(),
                            onLookupDuplicates: onLookupDuplicates,
                            onSubmit: onSubmit,
                          ),
                        ),
                      );
                      return;
                    }
                    unawaited(
                      showRegisterNewPatientDialog(
                        context: context,
                        referenceData: const PatientReferenceData(),
                        onLookupDuplicates: onLookupDuplicates,
                        onSubmit: onSubmit,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
}) async {
  for (int i = 0; i < maxFrames; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
}) async {
  for (int i = 0; i < maxFrames; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) {
      return;
    }
  }
  fail('Timed out waiting for $finder to disappear');
}

Future<void> _fillRegisterPatientBasics(
  WidgetTester tester, {
  String firstName = 'Jane',
  String lastName = 'Doe',
  String genderLabel = 'Female',
}) async {
  await tester.enterText(find.byType(EditableText).at(0), firstName);
  if (lastName.isNotEmpty) {
    await tester.enterText(find.byType(EditableText).at(1), lastName);
  }
  await tester.tap(find.byType(AppGenderField));
  await tester.pumpAndSettle();
  await tester.tap(find.text(genderLabel).last);
  await tester.pumpAndSettle();
}

Finder _identifierValueField() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is AppTextField &&
        (widget.labelText?.contains('Identifier value') ?? false),
  );
}

final class _MockPatientRepository extends Mock implements PatientRepository {}

final class _MockOpdRepository extends Mock implements OpdRepository {}

final class _MockIpdRepository extends Mock implements IpdRepository {}

final class _MockDischargeRepository extends Mock
    implements DischargeRepository {}

final class _TestSecureSessionStorage implements SecureSessionStorage {
  @override
  Future<SessionTokens?> readTokens() async =>
      SessionTokens(accessToken: 'test-access-token');

  @override
  Future<void> writeTokens(SessionTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

final class _TestAppPreferencesStore implements AppPreferencesStore {
  final Map<String, Object> _data = <String, Object>{};

  @override
  String? getString(String key) => _data[key] as String?;
  @override
  bool? getBool(String key) => _data[key] as bool?;
  @override
  int? getInt(String key) => _data[key] as int?;
  @override
  Future<bool> setString(String key, String value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }
}

void _stubPatientRegistry(
  _MockPatientRepository patientRepository,
  Patient patient, {
  PatientDetail? detail,
  List<PatientDuplicateCandidate> duplicates =
      const <PatientDuplicateCandidate>[],
}) {
  when(() => patientRepository.loadOverview()).thenAnswer(
    (_) async => Result<PatientRegistryOverview>.success(
      PatientRegistryOverview(
        totalPatients: 1,
        activePatients: 1,
        duplicates: duplicates,
      ),
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
  when(
    () => opdRepository.getBillingDefaults(
      facilityId: any(named: 'facilityId'),
      tenantId: any(named: 'tenantId'),
    ),
  ).thenAnswer(
    (_) async => const Result<OpdBillingDefaults>.success(OpdBillingDefaults()),
  );
  when(() => opdRepository.listProviderSchedules()).thenAnswer(
    (_) async => const Result<List<OpdProviderSchedule>>.success(
      <OpdProviderSchedule>[],
    ),
  );
}

Future<GoRouter?> _pumpPatientRegistry(
  WidgetTester tester, {
  required PatientRepository patientRepository,
  required OpdRepository opdRepository,
  IpdRepository? ipdRepository,
  DischargeRepository? dischargeRepository,
  required Size size,
  List<String> roles = const <String>['DOCTOR'],
  bool useRouter = false,
  String initialLocation = '/patients',
  PatientListQuery? initialQuery,
}) async {
  setTestViewport(tester, size);

  final overrides = [
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
    secureSessionStorageProvider.overrideWithValue(_TestSecureSessionStorage()),
    appPreferencesStoreProvider.overrideWithValue(_TestAppPreferencesStore()),
    patientRepositoryProvider.overrideWithValue(patientRepository),
    opdRepositoryProvider.overrideWithValue(opdRepository),
    if (ipdRepository != null)
      ipdRepositoryProvider.overrideWithValue(ipdRepository),
    if (dischargeRepository != null)
      dischargeRepositoryProvider.overrideWithValue(dischargeRepository),
  ];

  if (!useRouter) {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: PatientRegistryPage(initialQuery: initialQuery)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return null;
  }

  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/patients',
        builder: (BuildContext context, GoRouterState state) {
          return Scaffold(
            body: PatientRegistryPage(
              initialQuery: initialQuery ?? PatientListQuery.fromUri(state.uri),
            ),
          );
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  return router;
}

Finder _patientTabLabel(String label) {
  return find.descendant(
    of: find.byType(AppTabStrip),
    matching: find.text(label),
  );
}

Result<Patient> _registeredPatientResult(Map<String, Object?> payload) {
  return Result<Patient>.success(
    Patient(
      id: 'patient-new-1',
      firstName: payload['first_name'] as String? ?? 'Patient',
      lastName: payload['last_name'] as String?,
    ),
  );
}
