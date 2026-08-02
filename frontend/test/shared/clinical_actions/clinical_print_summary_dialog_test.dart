import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_print_summary_dialog.dart';
import 'package:hosspi_hms/shared/reporting/report_section_selection.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  ClinicalEncounterBundle bundle({
    List<ClinicalRelatedRecord> notes = const <ClinicalRelatedRecord>[],
    List<ClinicalRelatedRecord> labs = const <ClinicalRelatedRecord>[],
    List<ClinicalRelatedRecord> pharmacy = const <ClinicalRelatedRecord>[],
    List<ClinicalVitalSummary> vitals = const <ClinicalVitalSummary>[],
  }) {
    return ClinicalEncounterBundle(
      entry: const ClinicalWorklistEntry(
        id: 'e1',
        sourceQueue: 'OPD',
        encounterId: 'enc-1',
        patientDisplayName: 'John Doe',
      ),
      triageHandoff: ClinicalTriageHandoff(vitalSigns: vitals),
      clinicalNotes: notes,
      labOrders: labs,
      pharmacyOrders: pharmacy,
    );
  }

  test('section availabilities enable only sections with data', () {
    final List<ReportSectionAvailability> sections =
        buildClinicalPrintSectionAvailabilities(
          bundle: bundle(
            notes: const <ClinicalRelatedRecord>[
              ClinicalRelatedRecord(
                id: 'n1',
                kind: 'clinical_note',
                title: 'Cough for 3 days',
              ),
            ],
            labs: const <ClinicalRelatedRecord>[
              ClinicalRelatedRecord(
                id: 'l1',
                kind: 'lab_order',
                title: 'CBC',
                labOrderItems: <ClinicalLabOrderItem>[
                  ClinicalLabOrderItem(
                    id: 'i1',
                    testDisplayName: 'Hemoglobin',
                    resultValue: '12.5',
                    resultUnit: 'g/dL',
                    referenceRangeSummary: '12.0-15.0',
                    resultFlag: 'NORMAL',
                  ),
                ],
              ),
            ],
            vitals: const <ClinicalVitalSummary>[
              ClinicalVitalSummary(
                id: 'v1',
                vitalType: 'BP',
                displayValue: '120/80',
              ),
            ],
          ),
        );

    bool enabled(ClinicalPrintSection id) => sections
        .firstWhere((ReportSectionAvailability s) => s.id == id)
        .enabled;

    expect(enabled(ClinicalPrintSection.notes), isTrue);
    expect(enabled(ClinicalPrintSection.labResults), isTrue);
    expect(enabled(ClinicalPrintSection.vitals), isTrue);
    expect(enabled(ClinicalPrintSection.prescriptions), isFalse);
    expect(enabled(ClinicalPrintSection.followUps), isFalse);
  });

  test('lab result print line includes value and reference range', () {
    const ClinicalLabOrderItem item = ClinicalLabOrderItem(
      id: 'i1',
      testDisplayName: 'Hemoglobin',
      resultValue: '12.5',
      resultUnit: 'g/dL',
      referenceRangeSummary: '12.0-15.0',
      resultFlag: 'NORMAL',
    );

    final String line = clinicalLabResultPrintLine(
      l10n,
      item,
      pendingLabel: l10n.labStatusPending,
    );

    expect(line, contains('Hemoglobin: 12.5 g/dL'));
    expect(line, contains('12.0-15.0'));
    expect(line.toLowerCase(), contains('normal'));
  });

  testWidgets('summary html renders lab results table not bare order title', (
    WidgetTester tester,
  ) async {
    late String html;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            html = buildClinicalPrintSummaryHtml(
              context: context,
              bundle: bundle(
                labs: const <ClinicalRelatedRecord>[
                  ClinicalRelatedRecord(
                    id: 'l1',
                    kind: 'lab_order',
                    title: 'CBC order title only',
                    labOrderItems: <ClinicalLabOrderItem>[
                      ClinicalLabOrderItem(
                        id: 'i1',
                        testDisplayName: 'Hemoglobin',
                        resultValue: '12.5',
                        resultUnit: 'g/dL',
                        referenceRangeSummary: '12.0-15.0',
                        resultFlag: 'NORMAL',
                      ),
                    ],
                  ),
                ],
              ),
              selectedSections: <Object>{ClinicalPrintSection.labResults},
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(html, contains('Hemoglobin'));
    expect(html, contains('12.5 g/dL'));
    expect(html, contains('12.0-15.0'));
    expect(html, isNot(contains('CBC order title only')));
  });
}
