import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/pages/patient_registry_page.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

import '../../../helpers/test_harness.dart';

void main() {
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
}
