import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_time_field.dart';
import 'package:hosspi_hms/shared/components/app_time_value.dart';

import 'component_test_app.dart';

void main() {
  group('AppTimeValue', () {
    test('parse and format 24-hour times', () {
      final AppTimeValue? value = AppTimeValue.parse('08:30');
      expect(value, const AppTimeValue(hour: 8, minute: 30));
      expect(value?.format24(), '08:30');
    });

    test('parse 12-hour times with period', () {
      final AppTimeValue? pm = AppTimeValue.parse('02:15 PM');
      final AppTimeValue? am = AppTimeValue.parse('12:00 AM');
      expect(pm, const AppTimeValue(hour: 14, minute: 15));
      expect(am, const AppTimeValue(hour: 0, minute: 0));
    });

    test('compare times for ordering', () {
      const AppTimeValue earlier = AppTimeValue(hour: 8, minute: 0);
      const AppTimeValue later = AppTimeValue(hour: 9, minute: 0);
      expect(later.isAfter(earlier), isTrue);
      expect(earlier.isBefore(later), isTrue);
    });
  });

  testWidgets('AppTimeField renders segmented hour and minute inputs', (
    WidgetTester tester,
  ) async {
    AppTimeValue? selected;

    await pumpComponent(
      tester,
      AppTimeField(
        value: const AppTimeValue(hour: 9, minute: 5),
        use24HourFormat: true,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
        onChanged: (AppTimeValue? value) => selected = value,
      ),
    );

    expect(find.text('09'), findsOneWidget);
    expect(find.text('05'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();
    expect(selected, const AppTimeValue(hour: 10, minute: 5));
  });

  testWidgets('AppTimeField shows active format toggle beside the picker', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTimeField(
        value: AppTimeValue(hour: 15, minute: 0),
        use24HourFormat: true,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
        labelText: 'Start time',
      ),
    );

    expect(find.text('Start time'), findsOneWidget);
    final InputDecorator decorator = tester.widget(
      find.ancestor(
        of: find.text('Start time'),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorator.decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
    expect(decorator.decoration.label, isNotNull);
    expect(find.text('24H'), findsOneWidget);
    expect(find.text('12H'), findsNothing);
    expect(find.byTooltip('Select time'), findsOneWidget);
  });

  testWidgets('AppTimeField shows AM/PM toggle in 12-hour mode', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTimeField(
        value: AppTimeValue(hour: 15, minute: 0),
        use24HourFormat: false,
        allowFormatToggle: false,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
      ),
    );

    expect(find.text('03'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
  });

  testWidgets('AppTimeField supports optional seconds', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTimeField(
        value: AppTimeValue(hour: 1, minute: 2, second: 3),
        showSeconds: true,
        use24HourFormat: true,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
      ),
    );

    expect(find.text('03'), findsOneWidget);
  });

  testWidgets('AppTimeField rejects typed values outside active ranges', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTimeField(
        value: AppTimeValue(hour: 9, minute: 30),
        use24HourFormat: true,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '24');
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.pump();

    expect(find.text('09'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('AppTimeField rejects out-of-range hours in 12-hour mode', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppTimeField(
        value: AppTimeValue(hour: 9, minute: 15),
        use24HourFormat: false,
        allowFormatToggle: false,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), '13');
    await tester.enterText(find.byType(TextField).at(1), '60');
    await tester.pump();

    expect(find.text('09'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('format toggle preserves the represented time', (
    WidgetTester tester,
  ) async {
    AppTimeValue? selected;
    await pumpComponent(
      tester,
      AppTimeField(
        value: const AppTimeValue(hour: 15, minute: 45),
        use24HourFormat: true,
        pickerButtonLabel: 'Select time',
        invalidTimeMessage: 'Invalid time',
        onChanged: (AppTimeValue? value) => selected = value,
      ),
    );

    await tester.tap(find.text('24H'));
    await tester.pump();
    expect(find.text('12H'), findsOneWidget);
    expect(find.text('24H'), findsNothing);
    expect(find.text('03'), findsOneWidget);
    expect(find.text('PM'), findsOneWidget);
    expect(selected, const AppTimeValue(hour: 15, minute: 45));

    await tester.tap(find.text('12H'));
    await tester.pump();
    expect(find.text('24H'), findsOneWidget);
    expect(find.text('12H'), findsNothing);
    expect(find.text('15'), findsOneWidget);
    expect(selected, const AppTimeValue(hour: 15, minute: 45));
  });
}
