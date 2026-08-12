import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/network/app_connectivity_status.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_gender_field.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_registration_scope.dart';
import 'package:hosspi_hms/shared/patient_actions/register_new_patient_dialog.dart';

void main() {
  testWidgets(
    'uses AppDialog with Cancel, Register patient, and AppActionIcons.personAdd',
    (WidgetTester tester) async {
      await _pumpDialog(tester);

      expect(find.byType(RegisterNewPatientDialog), findsOneWidget);
      expect(find.byType(AppDialog), findsOneWidget);
      expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Register patient'), findsOneWidget);
      expect(find.byIcon(AppActionIcons.personAdd), findsWidgets);
      expect(find.byIcon(AppActionIcons.cancel), findsWidgets);

      final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
      expect(dialog.closeEnabled, isTrue);
      expect(dialog.pinActionsToBottom, isTrue);
    },
  );

  testWidgets('title is role-based and never a patient name', (
    WidgetTester tester,
  ) async {
    await _pumpDialog(tester);

    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Kato'), findsNothing);
    expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);
  });

  testWidgets('Close pops null without calling onSubmit', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    Patient? result;

    await _pumpDialog(
      tester,
      onResult: (Patient? value) => result = value,
      onSubmit: (Map<String, Object?> payload) async {
        submitCount += 1;
        return _registeredPatientResult(payload);
      },
    );

    await tester.tap(find.widgetWithText(AppButton, 'Close'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(submitCount, 0);
    expect(find.byType(RegisterNewPatientDialog), findsNothing);
  });

  testWidgets('failure keeps dialog open and does not pop a patient', (
    WidgetTester tester,
  ) async {
    Patient? result;

    await _pumpDialog(
      tester,
      onResult: (Patient? value) => result = value,
      onSubmit: (_) async =>
          const Result<Patient>.failure(AppFailure.forbidden()),
    );

    await _fillRegisterPatientBasics(tester, firstName: 'Amina', lastName: '');
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(AppDialog), findsOneWidget);
    expect(find.byType(RegisterNewPatientDialog), findsOneWidget);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets(
    'success submits snake_case payload and pops the created patient',
    (WidgetTester tester) async {
      Map<String, Object?>? payload;
      Patient? result;

      await _pumpDialog(
        tester,
        registrationScope: const PatientRegistrationScope(
          defaultTenantId: 'tenant-1',
          defaultFacilityId: 'facility-1',
        ),
        onResult: (Patient? value) => result = value,
        onSubmit: (Map<String, Object?> submitted) async {
          payload = submitted;
          return _registeredPatientResult(submitted);
        },
      );

      await _fillRegisterPatientBasics(
        tester,
        firstName: 'Amina',
        lastName: 'Kato',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
      await tester.pumpAndSettle();

      expect(result?.firstName, 'Amina');
      expect(result?.lastName, 'Kato');
      expect(find.byType(RegisterNewPatientDialog), findsNothing);
      expect(payload?['first_name'], 'Amina');
      expect(payload?['last_name'], 'Kato');
      expect(payload?['gender'], 'FEMALE');
      expect(payload?['tenant_id'], 'tenant-1');
      expect(payload?['facility_id'], 'facility-1');
      expect(payload?['is_active'], isTrue);
    },
  );

  testWidgets('duplicate review can use existing or register anyway', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;

    await _pumpDialog(
      tester,
      registrationScope: const PatientRegistrationScope(
        defaultTenantId: 'tenant-1',
        defaultFacilityId: 'facility-1',
      ),
      onLookupDuplicates: (PatientDuplicateQuery query) async {
        expect(query.tenantId, 'tenant-1');
        expect(query.facilityId, 'facility-1');
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
                  tenantId: 'tenant-1',
                  facilityId: 'facility-1',
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

    await _fillRegisterPatientBasics(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(submitCount, 0);
    expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
    expect(find.text('Potential duplicate found'), findsOneWidget);
    expect(find.text('Register anyway'), findsOneWidget);
    expect(find.text('Use existing patient'), findsOneWidget);
    // Registration form stays underneath; no inline warning panel.
    expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);

    await tester.tap(find.widgetWithText(AppButton, 'Register anyway'));
    await _pumpUntilGone(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(submitCount, 1);
  });

  testWidgets('cross-scope exact identity still allows register anyway', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;

    await _pumpDialog(
      tester,
      registrationScope: const PatientRegistrationScope(
        defaultTenantId: 'tenant-1',
        defaultFacilityId: 'facility-1',
      ),
      onLookupDuplicates: (_) async {
        return const Result<AppPage<PatientDuplicateCandidate>>.success(
          AppPage<PatientDuplicateCandidate>(
            items: <PatientDuplicateCandidate>[
              PatientDuplicateCandidate(
                reviewId: 'review-cross',
                confidenceScore: 100,
                classification: 'STRONG_MATCH',
                fieldComparisons: <PatientDuplicateFieldComparison>[
                  PatientDuplicateFieldComparison(
                    field: 'NAME',
                    inputValue: 'Jane Doe',
                    candidateValue: 'Jane Doe',
                    status: 'MATCH',
                  ),
                  PatientDuplicateFieldComparison(
                    field: 'PHONE',
                    inputValue: '+256700000000',
                    candidateValue: '+256700000000',
                    status: 'MATCH',
                  ),
                ],
                candidatePatient: Patient(
                  id: 'patient-other-facility',
                  displayName: 'Jane Doe',
                  primaryPhone: '+256700000000',
                  tenantId: 'tenant-1',
                  facilityId: 'facility-2',
                  facilityLabel: 'Other Clinic',
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

    await _fillRegisterPatientBasics(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(find.text('Register anyway'), findsOneWidget);
    expect(find.text('Other Clinic'), findsWidgets);
    expect(find.text('Facility'), findsWidgets);

    await tester.tap(find.widgetWithText(AppButton, 'Register anyway'));
    await _pumpUntilGone(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(submitCount, 1);
  });

  testWidgets('Use existing patient returns candidate without creating', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;
    Patient? result;
    await _pumpDialog(
      tester,
      onResult: (Patient? value) => result = value,
      onLookupDuplicates: (_) async {
        return const Result<AppPage<PatientDuplicateCandidate>>.success(
          AppPage<PatientDuplicateCandidate>(
            items: <PatientDuplicateCandidate>[
              PatientDuplicateCandidate(
                reviewId: 'review-1',
                confidenceScore: 88,
                classification: 'STRONG',
                matchReasons: <String>['PHONE_MATCH'],
                fieldComparisons: <PatientDuplicateFieldComparison>[
                  PatientDuplicateFieldComparison(
                    field: 'PHONE',
                    inputValue: '+256700000000',
                    candidateValue: '+256700000000',
                    status: 'MATCH',
                    contribution: 45,
                  ),
                ],
                candidatePatient: Patient(
                  id: 'patient-existing',
                  displayName: 'Jane Doe',
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

    await _fillRegisterPatientBasics(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
    expect(find.text('Phone'), findsWidgets);
    expect(find.text('+256700000000'), findsWidgets);
    expect(find.text('88%'), findsWidgets);
    await tester.tap(find.widgetWithText(AppButton, 'Use existing patient'));
    await _pumpUntilGone(tester, find.byType(RegisterNewPatientDialog));
    expect(result?.id, 'patient-existing');
    expect(submitCount, 0);
    expect(find.byType(RegisterNewPatientDialog), findsNothing);
  });

  testWidgets('canceling similarity review keeps registration form open', (
    WidgetTester tester,
  ) async {
    var submitCount = 0;

    await _pumpDialog(
      tester,
      onLookupDuplicates: (_) async {
        return const Result<AppPage<PatientDuplicateCandidate>>.success(
          AppPage<PatientDuplicateCandidate>(
            items: <PatientDuplicateCandidate>[
              PatientDuplicateCandidate(
                reviewId: 'review-1',
                confidenceScore: 80,
                classification: 'POSSIBLE',
                candidatePatient: Patient(
                  id: 'patient-1',
                  displayName: 'Jane Doe',
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

    await _fillRegisterPatientBasics(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await _pumpUntilFound(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(find.text('SIMILAR PATIENTS FOUND'), findsOneWidget);
    await tester.tap(find.widgetWithText(AppButton, 'Close').last);
    await _pumpUntilGone(tester, find.text('SIMILAR PATIENTS FOUND'));

    expect(submitCount, 0);
    expect(find.byType(RegisterNewPatientDialog), findsOneWidget);
    expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
  });

  testWidgets('locks dismiss while submitting', (WidgetTester tester) async {
    final Completer<Result<Patient>> completer = Completer<Result<Patient>>();

    await _pumpDialog(tester, onSubmit: (_) => completer.future);

    await _fillRegisterPatientBasics(tester, firstName: 'Amina', lastName: '');
    await tester.tap(find.widgetWithText(AppButton, 'Register patient'));
    await tester.pump();

    final AppDialog dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.closeEnabled, isFalse);

    final AppButton cancel = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Close'),
    );
    expect(cancel.enabled, isFalse);

    completer.complete(
      _registeredPatientResult(const <String, Object?>{'first_name': 'Amina'}),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('remains usable on compact dark high-text-scale surface', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      dark: true,
      textScaler: const TextScaler.linear(1.3),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(RegisterNewPatientDialog), findsOneWidget);
    expect(find.text('REGISTER NEW PATIENT'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Register patient'), findsOneWidget);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  ValueChanged<Patient?>? onResult,
  RegisterNewPatientSubmit? onSubmit,
  RegisterNewPatientDuplicateLookup? onLookupDuplicates,
  PatientRegistrationScope registrationScope = const PatientRegistrationScope(),
  bool dark = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          );
        },
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: AppButton.primary(
                  label: 'Open register',
                  leadingIcon: AppActionIcons.personAdd,
                  onPressed: () async {
                    final PatientRegistrationResult? value =
                        await showRegisterNewPatientDialog(
                          context: context,
                          referenceData: const PatientReferenceData(),
                          registrationScope: registrationScope,
                          onLookupDuplicates: onLookupDuplicates,
                          onSubmit:
                              onSubmit ??
                              (Map<String, Object?> payload) async =>
                                  _registeredPatientResult(payload),
                        );
                    onResult?.call(value?.patient);
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
  await tester.tap(find.widgetWithText(AppButton, 'Open register'));
  await tester.pumpAndSettle();
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

Result<Patient> _registeredPatientResult(Map<String, Object?> payload) {
  return Result<Patient>.success(
    Patient(
      id: 'PAT-NEW-1',
      publicId: 'PAT-NEW-1',
      firstName: payload['first_name'] as String? ?? 'Patient',
      lastName: payload['last_name'] as String?,
    ),
  );
}
