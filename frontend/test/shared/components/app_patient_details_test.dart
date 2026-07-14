import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_patient_details.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('compact mode hides expanded fields until Show more', (
    WidgetTester tester,
  ) async {
    await pumpLocalizedWidget(
      tester,
      ProviderScope(
        child: AppPatientDetails(
          patientName: 'Ada Lovelace',
          patientNumber: 'MRN-100',
          patientNumberLabel: 'MRN',
          ageLabel: '37y',
          genderLabel: 'Female',
          persistExpandPreference: false,
          expandedFields: const <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: 'Phone',
              value: '+256700000000',
            ),
          ],
        ),
      ),
    );

    expect(find.text('MRN-100'), findsOneWidget);
    expect(find.text('37y'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.textContaining('Phone'), findsNothing);
    expect(find.text('+256700000000'), findsNothing);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.textContaining('Phone'), findsOneWidget);
    expect(find.text('+256700000000'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
  });
}
