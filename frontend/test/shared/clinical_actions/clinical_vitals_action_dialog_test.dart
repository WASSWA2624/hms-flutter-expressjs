import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_vitals_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester, {
    OpdFlowDetail? detail,
    bool editing = false,
    Future<AppFailure?> Function(List<Map<String, Object?>> vitals)? onSubmit,
  }) async {
    await pumpLocalizedWidget(
      tester,
      Builder(
        builder: (BuildContext context) {
          return AppButton.primary(
            label: 'Open vitals dialog',
            onPressed: () {
              showAppDialog<bool>(
                context: context,
                builder: (_) => ClinicalVitalsActionDialog(
                  detail: detail,
                  editing: editing,
                  onSubmit:
                      onSubmit ??
                      (List<Map<String, Object?>> vitals) async => null,
                ),
              );
            },
          );
        },
      ),
      size: const Size(1280, 900),
    );
    await tester.tap(find.text('Open vitals dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Record vitals title for new set', (WidgetTester tester) async {
    await openDialog(tester);

    expect(find.text('Record vitals'), findsWidgets);
    expect(find.text('Edit vitals'), findsNothing);
    expect(find.text('Vital signs'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Heart rate'), findsOneWidget);
  });

  testWidgets('shows Edit vitals title when editing', (
    WidgetTester tester,
  ) async {
    await openDialog(
      tester,
      editing: true,
      detail: const OpdFlowDetail(
        summary: OpdFlowSummary(id: 'flow-1'),
        vitalMeasurements: <OpdVitalSign>[
          OpdVitalSign(
            id: 'v-temp',
            vitalType: 'TEMPERATURE',
            value: '37',
            unit: 'C',
          ),
          OpdVitalSign(
            id: 'v-hr',
            vitalType: 'HEART_RATE',
            value: '88',
            unit: 'bpm',
          ),
        ],
      ),
    );

    expect(find.text('Edit vitals'), findsWidgets);
    expect(find.text('Vital signs'), findsOneWidget);
    expect(find.byType(AppRecordVitalsDialog), findsOneWidget);
  });
}
