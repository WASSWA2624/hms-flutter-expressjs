import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';

enum ClinicalRequestPaymentMode { billLater, payNow }

enum ClinicalRequestPaymentStatus { paid, partial, unpaid, notBilled }

@immutable
final class ClinicalRequestBillingLineItem {
  const ClinicalRequestBillingLineItem({
    required this.id,
    required this.label,
    this.quantity = 1,
    this.unitPrice,
    this.currency,
  });

  final String id;
  final String label;
  final num quantity;
  final num? unitPrice;
  final String? currency;

  bool get hasPrice => unitPrice != null && unitPrice! > 0;

  num? get lineTotal {
    if (!hasPrice) {
      return null;
    }
    return unitPrice! * quantity;
  }
}

@immutable
final class ClinicalRequestBillingSubmit {
  const ClinicalRequestBillingSubmit({
    required this.mode,
    required this.totalAmount,
    required this.currency,
    required this.paymentStatus,
    this.paidAmount,
    this.paymentMethod,
    this.paymentReference,
    this.lineItems = const <ClinicalRequestBillingLineItem>[],
  });

  final ClinicalRequestPaymentMode mode;
  final num totalAmount;
  final String currency;
  final ClinicalRequestPaymentStatus paymentStatus;
  final num? paidAmount;
  final String? paymentMethod;
  final String? paymentReference;
  final List<ClinicalRequestBillingLineItem> lineItems;

  Map<String, Object?> toPayloadMap() {
    return <String, Object?>{
      'payment_status': clinicalRequestPaymentStatusValue(paymentStatus),
      'currency': currency,
      'total_amount': totalAmount,
      if (paidAmount != null && paidAmount! > 0) 'paid_amount': paidAmount,
      if (paymentMethod != null && paymentMethod!.trim().isNotEmpty)
        'payment_method': paymentMethod,
      if (paymentReference != null && paymentReference!.trim().isNotEmpty)
        'payment_reference': paymentReference,
      'line_items': lineItems
          .map(
            (ClinicalRequestBillingLineItem item) => <String, Object?>{
              'id': item.id,
              'label': item.label,
              'quantity': item.quantity,
              if (item.unitPrice != null) 'unit_price': item.unitPrice,
              if (item.lineTotal != null) 'line_total': item.lineTotal,
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, Object?> toRequestDetailsBilling({num? lineAmount}) {
    return <String, Object?>{...toPayloadMap(), 'line_amount': ?lineAmount};
  }
}

List<ClinicalRequestBillingLineItem> clinicalRequestBillingLineItems({
  required List<ClinicalActionCatalogOption> options,
  Map<String, num>? quantities,
  String? currency,
}) {
  return <ClinicalRequestBillingLineItem>[
    for (final ClinicalActionCatalogOption option in options)
      ClinicalRequestBillingLineItem(
        id: option.apiId,
        label: option.displayTitle,
        quantity: quantities?[option.apiId] ?? 1,
        unitPrice: clinicalCatalogOptionUnitPrice(option),
        currency: clinicalCatalogOptionCurrency(option) ?? currency,
      ),
  ];
}

num? clinicalCatalogOptionUnitPrice(ClinicalActionCatalogOption option) {
  if (option.unitPrice != null && option.unitPrice! > 0) {
    return option.unitPrice;
  }
  final Object? raw = option.metadata['unit_price'] ?? option.metadata['price'];
  if (raw is num) {
    return raw;
  }
  if (raw is String) {
    return num.tryParse(raw.trim());
  }
  return null;
}

String? clinicalCatalogOptionCurrency(ClinicalActionCatalogOption option) {
  final String? direct = option.currency?.trim();
  if (direct != null && direct.isNotEmpty) {
    return direct.toUpperCase();
  }
  final Object? raw = option.metadata['currency'];
  if (raw == null) {
    return null;
  }
  final String normalized = raw.toString().trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

String clinicalRequestPriceLabel(
  BuildContext context,
  num? amount,
  String? currency,
) {
  if (amount == null || amount <= 0) {
    return AppLocalizations.of(context).clinicalRequestPriceNotSetLabel;
  }
  return opdMoneyLabel(context, amount, currency) ?? amount.toString();
}

num clinicalRequestBillingTotal(
  List<ClinicalRequestBillingLineItem> lineItems,
) {
  var total = 0.0;
  for (final ClinicalRequestBillingLineItem item in lineItems) {
    total += (item.lineTotal ?? 0).toDouble();
  }
  return total;
}

bool clinicalRequestBillingHasMissingPrices(
  List<ClinicalRequestBillingLineItem> lineItems,
) {
  return lineItems.any((ClinicalRequestBillingLineItem item) => !item.hasPrice);
}

String clinicalRequestPaymentStatusValue(ClinicalRequestPaymentStatus status) {
  return switch (status) {
    ClinicalRequestPaymentStatus.paid => 'PAID',
    ClinicalRequestPaymentStatus.partial => 'PARTIAL',
    ClinicalRequestPaymentStatus.unpaid => 'PENDING',
    ClinicalRequestPaymentStatus.notBilled => 'NOT_BILLED',
  };
}

ClinicalRequestPaymentStatus clinicalRequestPaymentStatusFromValue(
  String? value,
) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'PAID' ||
    'COMPLETED' ||
    'CLEARED' ||
    'SUCCESS' ||
    'SUCCESSFUL' ||
    'APPROVED' => ClinicalRequestPaymentStatus.paid,
    'PARTIAL' => ClinicalRequestPaymentStatus.partial,
    'NOT_BILLED' ||
    'NOT_REQUIRED' ||
    'NO_CHARGE' => ClinicalRequestPaymentStatus.notBilled,
    'PENDING' ||
    'PENDING_PAYMENT' ||
    'ISSUED' ||
    'INVOICE_CREATED' ||
    'UNPAID' => ClinicalRequestPaymentStatus.unpaid,
    _ => ClinicalRequestPaymentStatus.notBilled,
  };
}

String clinicalRequestPaymentStatusLabel(
  AppLocalizations l10n,
  ClinicalRequestPaymentStatus status,
) {
  return switch (status) {
    ClinicalRequestPaymentStatus.paid => l10n.clinicalRequestPaymentPaidLabel,
    ClinicalRequestPaymentStatus.partial =>
      l10n.clinicalRequestPaymentPartialLabel,
    ClinicalRequestPaymentStatus.unpaid =>
      l10n.clinicalRequestPaymentUnpaidLabel,
    ClinicalRequestPaymentStatus.notBilled =>
      l10n.clinicalRequestPaymentNotBilledLabel,
  };
}

String clinicalRequestPaymentStatusDisplayLabel(
  AppLocalizations l10n,
  String? rawStatus,
) {
  final String normalized = (rawStatus ?? '').trim();
  if (normalized.isEmpty) {
    return l10n.clinicalRequestPaymentNotBilledLabel;
  }
  final ClinicalRequestPaymentStatus status =
      clinicalRequestPaymentStatusFromValue(normalized);
  if (status == ClinicalRequestPaymentStatus.notBilled &&
      normalized != 'NOT_BILLED' &&
      normalized != 'NOT_REQUIRED' &&
      normalized != 'NO_CHARGE') {
    return AppDisplay.apiLabel(normalized);
  }
  return clinicalRequestPaymentStatusLabel(l10n, status);
}

Map<String, Object?> mergeClinicalRequestBilling(
  Map<String, Object?> payload,
  ClinicalRequestBillingSubmit? billing,
) {
  if (billing == null) {
    return payload;
  }
  return <String, Object?>{...payload, 'billing': billing.toPayloadMap()};
}

Map<String, Object?> mergeClinicalRequestBillingIntoRequestDetails(
  Map<String, Object?> requestDetails,
  ClinicalRequestBillingSubmit? billing, {
  num? lineAmount,
}) {
  if (billing == null) {
    return requestDetails;
  }
  return <String, Object?>{
    ...requestDetails,
    'billing': billing.toRequestDetailsBilling(lineAmount: lineAmount),
  };
}

num? clinicalRequestBillingLineAmount(
  ClinicalRequestBillingSubmit? billing,
  String catalogItemId,
) {
  if (billing == null) {
    return null;
  }
  for (final ClinicalRequestBillingLineItem item in billing.lineItems) {
    if (item.id == catalogItemId) {
      return item.lineTotal;
    }
  }
  return null;
}

String resolveClinicalRequestBillingCurrency(
  List<ClinicalRequestBillingLineItem> lineItems,
) {
  for (final ClinicalRequestBillingLineItem item in lineItems) {
    final String? currency = item.currency?.trim().toUpperCase();
    if (currency != null && currency.isNotEmpty) {
      return currency;
    }
  }
  return appDefaultCurrencyCode;
}

const List<String> clinicalRequestPaymentMethods = <String>[
  'CASH',
  'CARD',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'INSURANCE',
  'OTHER',
];

IconData clinicalRequestPaymentMethodIcon(String method) {
  return switch (method.trim().toUpperCase()) {
    'CASH' => Icons.payments_outlined,
    'CARD' => Icons.credit_card_outlined,
    'MOBILE_MONEY' => Icons.phone_android_outlined,
    'BANK_TRANSFER' => Icons.account_balance_outlined,
    'INSURANCE' => Icons.health_and_safety_outlined,
    _ => Icons.more_horiz_outlined,
  };
}

List<AppSelectOption<String>> clinicalRequestPaymentMethodOptions() {
  return clinicalRequestPaymentMethods
      .map(
        (String method) => AppSelectOption<String>(
          value: method,
          label: AppDisplay.apiLabel(method),
          leadingIcon: Icon(clinicalRequestPaymentMethodIcon(method)),
        ),
      )
      .toList(growable: false);
}
