import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';

import 'component_test_app.dart';

void main() {
  testWidgets('AppCurrencyAmountField formats and validates amounts', (
    WidgetTester tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: Column(
          children: <Widget>[
            AppCurrencyAmountField(
              amountController: controller,
              currency: 'UGX',
              amountLabelText: 'Amount',
              currencyLabelText: 'Currency',
              isRequired: true,
              onCurrencyChanged: (_) {},
            ),
            AppButton.primary(
              label: 'Submit',
              onPressed: () {
                formKey.currentState!.validate();
              },
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('This field is required.'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '1234567.89');
    await tester.pump();

    expect(controller.text, '1,234,567.89');

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('This field is required.'), findsNothing);
  });

  testWidgets('AppCurrencyAmountField picker searches currencies with flags', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var currency = 'UGX';

    await pumpComponent(
      tester,
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AppCurrencyAmountField(
            amountController: controller,
            currency: currency,
            amountLabelText: 'Amount',
            currencyLabelText: 'Currency',
            currencySearchLabelText: 'Search currency',
            currencyOptions: const <AppCurrencyOption>[
              AppCurrencyOption(
                code: 'UGX',
                name: 'Uganda Shilling',
                country: 'Uganda',
              ),
              AppCurrencyOption(
                code: 'EUR',
                name: 'Euro',
                country: 'European Union',
              ),
              AppCurrencyOption(
                code: 'USD',
                name: 'US Dollar',
                country: 'United States',
              ),
            ],
            onCurrencyChanged: (String? value) {
              setState(() {
                currency = value ?? 'UGX';
              });
            },
          );
        },
      ),
    );

    expect(find.text('UGX'), findsOneWidget);
    expect(find.text(_flagEmoji('UG')), findsOneWidget);

    await tester.tap(find.text('UGX'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'euro');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'EUR - Euro'), findsOneWidget);
    expect(find.text('USD - US Dollar'), findsNothing);

    await tester.tap(find.widgetWithText(ListTile, 'EUR - Euro'));
    await tester.pumpAndSettle();

    expect(currency, 'EUR');
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text(_flagEmoji('EU')), findsOneWidget);
  });

  testWidgets('AppCurrencyAmountField fits compact widths', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComponent(
      tester,
      AppCurrencyAmountField(
        amountController: controller,
        currency: 'EUR',
        amountLabelText: 'Amount',
        amountHintText: '0.00',
        currencyLabelText: 'Currency',
        onCurrencyChanged: (_) {},
      ),
      size: const Size(220, 320),
    );

    await tester.enterText(find.byType(EditableText), '99.95');
    await tester.pump();

    expect(controller.text, '99.95');
    expect(tester.takeException(), isNull);
  });
}

String _flagEmoji(String regionCode) {
  return String.fromCharCodes(
    regionCode.codeUnits.map((int unit) => 0x1F1E6 + unit - 0x41),
  );
}
