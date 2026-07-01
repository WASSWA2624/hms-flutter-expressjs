import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('HrCompensationLineEditor renders pay type fields', (
    WidgetTester tester,
  ) async {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_MONTH',
      rateController: TextEditingController(text: '3000'),
      effectiveFrom: DateTime(2026),
    );
    addTearDown(line.rateController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: HrCompensationLineEditor(
            line: line,
            usedPayTypes: const <String>{'PER_MONTH'},
            onChanged: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3000'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  test('HrCompensationLineData serializes full compensation payload', () {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_CONSULTATION',
      rateController: TextEditingController(text: '75'),
      currency: 'USD',
      effectiveFrom: DateTime(2026),
    );

    final Map<String, Object?> payload = line.toPayload();
    expect(payload['pay_type'], 'PER_CONSULTATION');
    expect(payload['rate'], 75);
    expect(payload['currency'], 'USD');
    line.rateController.dispose();
  });
}
