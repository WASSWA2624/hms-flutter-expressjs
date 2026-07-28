import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../helpers/test_harness.dart';

void main() {
  const List<ClinicalActionCatalogOption> facilityDiagnoses =
      <ClinicalActionCatalogOption>[
        ClinicalActionCatalogOption(
          id: 'dx-1',
          name: 'Malaria',
          code: 'B54',
        ),
        ClinicalActionCatalogOption(
          id: 'dx-2',
          name: 'Typhoid fever',
          code: 'A01.0',
        ),
      ];

  Future<void> openDialog(
    WidgetTester tester, {
    List<ClinicalActionCatalogOption> catalog = facilityDiagnoses,
    Future<AppFailure?> Function({
      required String diagnosisType,
      required List<ClinicalActionCatalogOption> diagnoses,
    })?
    onSubmit,
    List<String>? searchedSources,
  }) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open diagnosis dialog',
            onPressed: () {
              showAppDialog<bool>(
                context: context,
                builder: (_) => ClinicalDiagnosisActionDialog(
                  onSearchClinicalTerms:
                      ({
                        required String termType,
                        String? query,
                        int? limit,
                        String source = 'ALL',
                      }) async {
                        searchedSources?.add(source);
                        return Result<
                          List<ClinicalActionCatalogOption>
                        >.success(catalog);
                      },
                  onSubmit:
                      onSubmit ??
                      ({
                        required String diagnosisType,
                        required List<ClinicalActionCatalogOption> diagnoses,
                      }) async {
                        return null;
                      },
                ),
              );
            },
          );
        },
      ),
      size: const Size(1280, 900),
    );
    await tester.tap(find.text('Open diagnosis dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('loads facility catalog and uses diagnosis type radios', (
    WidgetTester tester,
  ) async {
    final List<String> sources = <String>[];
    await openDialog(tester, searchedSources: sources);

    expect(sources, <String>['FACILITY']);
    expect(find.text('All sources'), findsNothing);
    expect(find.text('Favorites'), findsNothing);
    expect(find.text('Global catalog'), findsNothing);
    expect(find.byType(AppRadioGroup<String>), findsOneWidget);
    expect(find.text('Primary'), findsWidgets);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Differential'), findsOneWidget);
    expect(find.text('Malaria'), findsOneWidget);
    expect(find.text('Typhoid fever'), findsOneWidget);
    expect(find.text('Available diagnoses'), findsOneWidget);
    expect(find.text('Selected diagnoses'), findsOneWidget);
    expect(find.text('Deselect'), findsOneWidget);
  });

  testWidgets('transfers checked diagnoses and submits selected type', (
    WidgetTester tester,
  ) async {
    String? submittedType;
    List<ClinicalActionCatalogOption>? submitted;

    await openDialog(
      tester,
      onSubmit:
          ({
            required String diagnosisType,
            required List<ClinicalActionCatalogOption> diagnoses,
          }) async {
            submittedType = diagnosisType;
            submitted = diagnoses;
            return null;
          },
    );

    final Finder availableTable = find
        .byType(AppListTable<ClinicalActionCatalogOption>)
        .first;
    final Finder availableCheckboxes = find.descendant(
      of: availableTable,
      matching: find.byType(Checkbox),
    );

    // Index 0 is the header select-all checkbox; index 1 is the first row.
    await tester.tap(availableCheckboxes.at(1));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Malaria'), findsOneWidget);

    await tester.tap(find.text('Secondary'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Add diagnosis'));
    await tester.pumpAndSettle();

    expect(submittedType, 'SECONDARY');
    expect(submitted, isNotNull);
    expect(submitted!.single.name, 'Malaria');
  });

  testWidgets('Deselect moves checked selected diagnoses back', (
    WidgetTester tester,
  ) async {
    await openDialog(tester);

    final Finder availableTable = find
        .byType(AppListTable<ClinicalActionCatalogOption>)
        .first;
    await tester.tap(
      find.descendant(of: availableTable, matching: find.byType(Checkbox)).at(1),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);

    final Finder selectedTable = find
        .byType(AppListTable<ClinicalActionCatalogOption>)
        .last;
    await tester.tap(
      find.descendant(of: selectedTable, matching: find.byType(Checkbox)).at(1),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Deselect'));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('No diagnoses selected'), findsOneWidget);
  });
}
