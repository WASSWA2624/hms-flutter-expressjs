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
    final AppRadioGroup<String> typeGroup = tester.widget(
      find.byType(AppRadioGroup<String>),
    );
    expect(typeGroup.presentation, AppRadioGroupPresentation.borderless);
    expect(typeGroup.dense, isTrue);
    expect(typeGroup.labelText, isNull);
    expect(typeGroup.semanticLabel, 'Diagnosis type');
    expect(find.text('Diagnosis type'), findsNothing);
    expect(find.text('Primary'), findsWidgets);
    expect(find.text('Secondary'), findsOneWidget);
    expect(find.text('Differential'), findsOneWidget);
    expect(find.text('Malaria'), findsOneWidget);
    expect(find.text('Typhoid fever'), findsOneWidget);
    expect(find.text('Available diagnoses'), findsNothing);
    expect(find.textContaining('matches'), findsNothing);
    expect(find.text('Selected diagnoses'), findsNothing);
    expect(find.text('0 selected'), findsNothing);
    expect(find.text('Deselect'), findsNothing);
    expect(find.text('Add selections'), findsNothing);
    expect(find.text('Add selected diagnosis'), findsOneWidget);
    expect(find.text('Remove selected diagnosis'), findsOneWidget);
    expect(find.text('Search selected diagnosis'), findsOneWidget);
    expect(find.text('#'), findsNothing);
    expect(find.byIcon(Icons.swap_vert), findsNothing);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);

    final Finder tables = find.byType(AppListTable<ClinicalActionCatalogOption>);
    expect(tables, findsNWidgets(2));
    final AppListTable<ClinicalActionCatalogOption> availableTable = tester
        .widget(tables.first);
    expect(availableTable.showRowNumbers, isFalse);
    expect(availableTable.forceCompact, isTrue);
    expect(availableTable.columns.first.fixedWidth, 32);
    expect(availableTable.columns.last.isSortable, isFalse);
  });

  testWidgets('row click toggles selection and transfers diagnoses', (
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

    await tester.tap(find.text('Malaria'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Add selected diagnosis'));
    await tester.pumpAndSettle();

    expect(find.text('Malaria'), findsOneWidget);
    expect(find.text('No diagnoses selected'), findsNothing);

    await tester.tap(find.text('Secondary'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Add diagnosis'));
    await tester.pumpAndSettle();

    expect(submittedType, 'SECONDARY');
    expect(submitted, isNotNull);
    expect(submitted!.single.name, 'Malaria');
  });

  testWidgets('Remove selected diagnosis moves checked rows back', (
    WidgetTester tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('Malaria'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Add selected diagnosis'));
    await tester.pumpAndSettle();

    final Finder selectedTable = find
        .byType(AppListTable<ClinicalActionCatalogOption>)
        .last;
    await tester.tap(find.descendant(of: selectedTable, matching: find.text('Malaria')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(AppButton, 'Remove selected diagnosis'),
    );
    await tester.pumpAndSettle();

    expect(find.text('No diagnoses selected'), findsOneWidget);
  });
}
