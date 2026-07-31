import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_edit_diagnosis_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('formatClinicalDiagnosisDisplay', () {
    test('formats name, humanized type, and code', () {
      expect(
        formatClinicalDiagnosisDisplay(
          const ClinicalRelatedRecord(
            id: 'dx-1',
            kind: 'diagnosis',
            title: 'Malaria',
            diagnosisType: 'PRIMARY',
            code: 'B54',
          ),
        ),
        'Malaria - Primary | B54',
      );
    });

    test('omits code segment when empty', () {
      expect(
        formatClinicalDiagnosisDisplay(
          const ClinicalRelatedRecord(
            id: 'dx-2',
            kind: 'diagnosis',
            title: 'Sepsis',
            diagnosisType: 'SECONDARY',
          ),
        ),
        'Sepsis - Secondary',
      );
    });
  });

  group('clinicalDiagnosisDedupKey', () {
    test('uses code and description identity', () {
      expect(
        clinicalDiagnosisDedupKey(code: 'b54', description: 'Malaria'),
        'B54::MALARIA',
      );
    });
  });

  testWidgets('edit dialog submits UUID list and selected type', (
    WidgetTester tester,
  ) async {
    List<ClinicalRelatedRecord>? submittedDiagnoses;
    String? submittedType;

    setTestViewport(tester, const Size(900, 700));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return AppButton.primary(
                  label: 'Open edit diagnosis',
                  onPressed: () {
                    showAppDialog<bool>(
                      context: context,
                      builder: (_) => ClinicalEditDiagnosisActionDialog(
                        diagnoses: const <ClinicalRelatedRecord>[
                          ClinicalRelatedRecord(
                            id: '55555555-5555-4555-8555-555555555555',
                            kind: 'diagnosis',
                            title: 'Malaria',
                            diagnosisType: 'PRIMARY',
                            code: 'B54',
                          ),
                        ],
                        onSubmit:
                            ({
                              required List<ClinicalRelatedRecord> diagnoses,
                              required String diagnosisType,
                            }) async {
                              submittedDiagnoses = diagnoses;
                              submittedType = diagnosisType;
                              return null;
                            },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open edit diagnosis'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT DIAGNOSIS'), findsOneWidget);
    expect(find.text('Malaria - Primary | B54'), findsOneWidget);
    expect(find.text('Editing 1 diagnosis'), findsOneWidget);

    await tester.tap(find.text('Secondary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Save'));
    await tester.pumpAndSettle();

    expect(submittedType, 'SECONDARY');
    expect(
      submittedDiagnoses!.single.id,
      '55555555-5555-4555-8555-555555555555',
    );
  });
}
