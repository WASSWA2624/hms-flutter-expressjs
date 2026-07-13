import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/app_payment_method.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

void main() {
  test('appPaymentMethodIcon maps known payment methods', () {
    expect(appPaymentMethodIcon('CASH'), Icons.payments_outlined);
    expect(appPaymentMethodIcon('CREDIT_CARD'), Icons.credit_card_outlined);
    expect(appPaymentMethodIcon('DEBIT_CARD'), Icons.payment_outlined);
    expect(appPaymentMethodIcon('MOBILE_MONEY'), Icons.phone_android_outlined);
    expect(
      appPaymentMethodIcon('BANK_TRANSFER'),
      Icons.account_balance_outlined,
    );
    expect(appPaymentMethodIcon('INSURANCE'), Icons.health_and_safety_outlined);
    expect(appPaymentMethodIcon('OTHER'), Icons.more_horiz_outlined);
  });

  test('buildAppPaymentMethodSelectOptions includes leading icons', () {
    final List<AppSelectOption<String>> options =
        buildAppPaymentMethodSelectOptions(
          methods: const <String>['CASH', 'MOBILE_MONEY'],
        );

    expect(options, hasLength(2));
    expect(options.first.leadingIcon, isA<Icon>());
    expect((options.first.leadingIcon! as Icon).icon, Icons.payments_outlined);
    expect(
      (options.last.leadingIcon! as Icon).icon,
      Icons.phone_android_outlined,
    );
  });
}
