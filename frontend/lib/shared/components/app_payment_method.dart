import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';

/// Canonical payment-method codes used across billing, OPD, and clinical flows.
const List<String> appPaymentMethodCodes = <String>[
  'CASH',
  'CREDIT_CARD',
  'DEBIT_CARD',
  'CARD',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
];

/// Resolves a leading icon for a payment-method API code.
IconData appPaymentMethodIcon(String method) {
  return switch (method.trim().toUpperCase()) {
    'CASH' => Icons.payments_outlined,
    'CREDIT_CARD' || 'PREPAID_CARD' => Icons.credit_card_outlined,
    'DEBIT_CARD' => Icons.payment_outlined,
    'CARD' => Icons.credit_card_outlined,
    'MOBILE_MONEY' => Icons.phone_android_outlined,
    'BANK_TRANSFER' || 'BANK_CHECK' => Icons.account_balance_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    'VOUCHER' || 'GIFT_CARD' => Icons.confirmation_number_outlined,
    _ => Icons.more_horiz_outlined,
  };
}

/// Builds select options with a consistent leading icon per payment method.
List<AppSelectOption<String>> buildAppPaymentMethodSelectOptions({
  List<String> methods = appPaymentMethodCodes,
  String Function(String method)? labelOf,
}) {
  final String Function(String method) resolveLabel =
      labelOf ?? AppDisplay.apiLabel;
  return <AppSelectOption<String>>[
    for (final String method in methods)
      AppSelectOption<String>(
        value: method,
        label: resolveLabel(method),
        leadingIcon: Icon(appPaymentMethodIcon(method)),
      ),
  ];
}
