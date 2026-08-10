import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_compensation_line_editor.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  testWidgets('HrCompensationLineEditor renders rate, type, frequency, and zone', (
    WidgetTester tester,
  ) async {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_MONTH',
      rateController: TextEditingController(text: '3000'),
      effectiveFrom: DateTime(2026),
    );
    addTearDown(line.rateController.dispose);

    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HrCompensationLineEditor(
                line: line,
                usedPayTypes: const <String>{'PER_MONTH'},
                onChanged: () {},
                onRemove: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3000'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.textContaining('Pay zone'), findsWidgets);
    expect(find.textContaining('Base rate'), findsWidgets);
    expect(find.textContaining('Pay frequency'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('HrCompensationLineData serializes payroll metadata', () {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_CONSULTATION',
      rateController: TextEditingController(text: '75'),
      currency: 'USD',
      payZone: 'Zone A',
      effectiveFrom: DateTime(2026),
    );

    final Map<String, Object?> payload = line.toPayload();
    expect(payload['pay_type'], 'PER_CONSULTATION');
    expect(payload['rate'], 75);
    expect(payload['currency'], 'USD');
    final Map<String, Object?> metadata =
        payload['metadata_json']! as Map<String, Object?>;
    expect(metadata['pay_frequency'], 'PER_SERVICE');
    expect(metadata['pay_zone'], 'Zone A');
    line.rateController.dispose();
  });

  test('HrCompensationLineData parses thousand-separated amounts', () {
    final HrCompensationLineData line = HrCompensationLineData(
      payType: 'PER_CONSULTATION',
      rateController: TextEditingController(text: '50,000'),
      currency: 'UGX',
      effectiveFrom: DateTime(2026, 8, 10),
    );

    final Map<String, Object?> payload = line.toPayload();
    expect(payload['rate'], 50000);
    line.rateController.dispose();
  });

  test('used pay types are excluded from select options', () {
    final List<String> available = kHrCompensationPayTypeCodes
        .where(
          (String code) =>
              code == 'PER_HOUR' || !const <String>{'PER_MONTH', 'PER_CONSULTATION'}.contains(code),
        )
        .toList(growable: false);
    expect(available, isNot(contains('PER_MONTH')));
    expect(available, isNot(contains('PER_CONSULTATION')));
    expect(available, contains('PER_HOUR'));
  });
}
