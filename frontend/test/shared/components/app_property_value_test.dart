import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_font_family.dart';
import 'package:hosspi_hms/shared/components/app_property_value.dart';

import 'component_test_app.dart';

void main() {
  TextStyle styleOf(WidgetTester tester, String text) {
    return tester.widget<Text>(find.text(text)).style!;
  }

  testWidgets('renders icon, label and value on one line', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValue(
        icon: Icons.person_outline,
        label: 'Name',
        value: 'Wasswa Wilson',
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text(': '), findsOneWidget);
    expect(find.text('Wasswa Wilson'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('label reads regular weight and value reads bold', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValue(label: 'Name', value: 'Wasswa Wilson'),
    );

    expect(styleOf(tester, 'Name').fontWeight, AppFontWeight.regular);
    expect(
      styleOf(tester, 'Wasswa Wilson').fontWeight,
      AppFontWeight.strong,
    );
  });

  testWidgets('is borderless by default and framed when bordered', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValue(label: 'Name', value: 'Wasswa Wilson'),
    );
    expect(find.byType(DecoratedBox), findsNothing);

    await pumpComponent(
      tester,
      const AppPropertyValue(
        label: 'Name',
        value: 'Wasswa Wilson',
        bordered: true,
      ),
    );
    expect(find.byType(DecoratedBox), findsOneWidget);
  });

  testWidgets('falls back to emptyValue for a blank value', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValue(label: 'Name', value: '   ', emptyValue: '—'),
    );

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('expand wraps label and value into one paragraph', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const SizedBox(
        width: 200,
        child: AppPropertyValue(
          label: 'Instructions',
          value: 'Take one tablet twice a day after meals for seven days.',
          expand: true,
        ),
      ),
    );

    expect(find.textContaining('Instructions: '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppPropertyValueList can drop pairs without a value', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValueList(
        hideEmptyValues: true,
        items: <AppPropertyValueData>[
          AppPropertyValueData(label: 'Name', value: 'Wasswa Wilson'),
          AppPropertyValueData(label: 'Phone', value: '  '),
        ],
      ),
    );

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
  });

  testWidgets('AppPropertyValueList stacks vertically on request', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AppPropertyValueList(
        direction: AppPropertyValueListDirection.vertical,
        items: <AppPropertyValueData>[
          AppPropertyValueData(label: 'Name', value: 'Wasswa Wilson'),
          AppPropertyValueData(label: 'Phone', value: '+256700000000'),
        ],
      ),
    );

    final Offset name = tester.getTopLeft(find.textContaining('Name: '));
    final Offset phone = tester.getTopLeft(find.textContaining('Phone: '));
    expect(phone.dy, greaterThan(name.dy));
    expect(phone.dx, name.dx);
  });
}
