import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/features/lab/presentation/lab_status_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('partial results with abnormal flag show Partially Ready', (
    WidgetTester tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const LabOrderSummary order = LabOrderSummary(
      id: 'LAB-1',
      status: 'IN_PROCESS',
      itemCount: 3,
      inProcessItemCount: 2,
      items: <LabOrderItem>[
        LabOrderItem(
          id: 'ITEM-1',
          status: 'COMPLETED',
          resultStatus: 'ABNORMAL',
          resultValue: '12',
          resultId: 'RES-1',
        ),
        LabOrderItem(
          id: 'ITEM-2',
          status: 'COMPLETED',
          resultStatus: 'NORMAL',
          resultValue: '40',
          resultId: 'RES-2',
        ),
        LabOrderItem(id: 'ITEM-3', status: 'ORDERED'),
      ],
    );

    expect(
      labWorklistGlanceStatus(captured, order).label,
      'Partially Ready - Abnormal',
    );
  });

  testWidgets('partial results with critical flag show Partially Ready', (
    WidgetTester tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const LabOrderSummary order = LabOrderSummary(
      id: 'LAB-2',
      status: 'IN_PROCESS',
      itemCount: 2,
      items: <LabOrderItem>[
        LabOrderItem(
          id: 'ITEM-1',
          status: 'COMPLETED',
          resultStatus: 'CRITICAL',
          resultValue: '3',
          resultId: 'RES-1',
        ),
        LabOrderItem(id: 'ITEM-2', status: 'ORDERED'),
      ],
    );

    expect(
      labWorklistGlanceStatus(captured, order).label,
      'Partially Ready - Critical',
    );
  });

  testWidgets('all results entered keep Ready - Abnormal', (
    WidgetTester tester,
  ) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const LabOrderSummary order = LabOrderSummary(
      id: 'LAB-3',
      status: 'IN_PROCESS',
      itemCount: 2,
      items: <LabOrderItem>[
        LabOrderItem(
          id: 'ITEM-1',
          status: 'COMPLETED',
          resultStatus: 'ABNORMAL',
          resultValue: '12',
          resultId: 'RES-1',
        ),
        LabOrderItem(
          id: 'ITEM-2',
          status: 'COMPLETED',
          resultStatus: 'NORMAL',
          resultValue: '40',
          resultId: 'RES-2',
        ),
      ],
    );

    expect(
      labWorklistGlanceStatus(captured, order).label,
      'Ready - Abnormal',
    );
  });
}
