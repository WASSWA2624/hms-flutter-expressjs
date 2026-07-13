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
    this.priceSource,
    this.billingEntity,
    this.paymentMode,
    this.catalogType,
    this.priceBookEntryId,
    this.coveragePlanId,
    this.patientShare,
    this.insurerShare,
    this.copayAmount,
  });

  final String id;
  final String label;
  final num quantity;
  final num? unitPrice;
  final String? currency;
  final String? priceSource;
  final String? billingEntity;
  final String? paymentMode;
  final String? catalogType;
  final String? priceBookEntryId;
  final String? coveragePlanId;
  final num? patientShare;
  final num? insurerShare;
  final num? copayAmount;

  bool get hasPrice => unitPrice != null && unitPrice! > 0;

  num? get lineTotal {
    if (!hasPrice) {
      return null;
    }
    return unitPrice! * quantity;
  }

  ClinicalRequestBillingLineItem copyWith({
    String? id,
    String? label,
    num? quantity,
    num? unitPrice,
    String? currency,
    String? priceSource,
    String? billingEntity,
    String? paymentMode,
    String? catalogType,
    String? priceBookEntryId,
    String? coveragePlanId,
    num? patientShare,
    num? insurerShare,
    num? copayAmount,
  }) {
    return ClinicalRequestBillingLineItem(
      id: id ?? this.id,
      label: label ?? this.label,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      currency: currency ?? this.currency,
      priceSource: priceSource ?? this.priceSource,
      billingEntity: billingEntity ?? this.billingEntity,
      paymentMode: paymentMode ?? this.paymentMode,
      catalogType: catalogType ?? this.catalogType,
      priceBookEntryId: priceBookEntryId ?? this.priceBookEntryId,
      coveragePlanId: coveragePlanId ?? this.coveragePlanId,
      patientShare: patientShare ?? this.patientShare,
      insurerShare: insurerShare ?? this.insurerShare,
      copayAmount: copayAmount ?? this.copayAmount,
    );
  }
}

@immutable
final class ClinicalRequestPayerContext {
  const ClinicalRequestPayerContext({
    this.insured = false,
    this.insuranceCompanyId,
    this.insuranceCompanyName,
    this.coveragePlanId,
    this.coveragePlanName,
    this.insurerKey,
    this.coveragePercentage,
    this.copayType,
    this.copayValue,
    this.memberId,
  });

  final bool insured;
  final String? insuranceCompanyId;
  final String? insuranceCompanyName;
  final String? coveragePlanId;
  final String? coveragePlanName;
  final String? insurerKey;
  final num? coveragePercentage;
  final String? copayType;
  final num? copayValue;
  final String? memberId;

  String get paymentMode => insured ? 'INSURANCE' : 'SELF_PAY';

  String? get payerLabel {
    final String company = (insuranceCompanyName ?? '').trim();
    final String scheme = (coveragePlanName ?? '').trim();
    if (company.isNotEmpty && scheme.isNotEmpty) {
      return '$company · $scheme';
    }
    if (scheme.isNotEmpty) return scheme;
    if (company.isNotEmpty) return company;
    return null;
  }

  ClinicalRequestPayerContext copyWith({
    bool? insured,
    String? insuranceCompanyId,
    String? insuranceCompanyName,
    String? coveragePlanId,
    String? coveragePlanName,
    String? insurerKey,
    num? coveragePercentage,
    String? copayType,
    num? copayValue,
    String? memberId,
  }) {
    return ClinicalRequestPayerContext(
      insured: insured ?? this.insured,
      insuranceCompanyId: insuranceCompanyId ?? this.insuranceCompanyId,
      insuranceCompanyName:
          insuranceCompanyName ?? this.insuranceCompanyName,
      coveragePlanId: coveragePlanId ?? this.coveragePlanId,
      coveragePlanName: coveragePlanName ?? this.coveragePlanName,
      insurerKey: insurerKey ?? this.insurerKey,
      coveragePercentage: coveragePercentage ?? this.coveragePercentage,
      copayType: copayType ?? this.copayType,
      copayValue: copayValue ?? this.copayValue,
      memberId: memberId ?? this.memberId,
    );
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
    this.billingEntity,
    this.paymentMode,
    this.coveragePlanId,
    this.insuranceCompanyId,
    this.coveragePercentage,
    this.copayType,
    this.copayValue,
    this.patientShare,
    this.insurerShare,
    this.copayAmount,
  });

  final ClinicalRequestPaymentMode mode;
  final num totalAmount;
  final String currency;
  final ClinicalRequestPaymentStatus paymentStatus;
  final num? paidAmount;
  final String? paymentMethod;
  final String? paymentReference;
  final List<ClinicalRequestBillingLineItem> lineItems;
  final String? billingEntity;
  final String? paymentMode;
  final String? coveragePlanId;
  final String? insuranceCompanyId;
  final num? coveragePercentage;
  final String? copayType;
  final num? copayValue;
  final num? patientShare;
  final num? insurerShare;
  final num? copayAmount;

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
      if (billingEntity != null && billingEntity!.isNotEmpty)
        'billing_entity': billingEntity,
      if (paymentMode != null && paymentMode!.isNotEmpty)
        'payment_mode': paymentMode,
      if (coveragePlanId != null && coveragePlanId!.isNotEmpty)
        'coverage_plan_id': coveragePlanId,
      if (insuranceCompanyId != null && insuranceCompanyId!.isNotEmpty)
        'insurance_company_id': insuranceCompanyId,
      if (coveragePercentage != null) 'coverage_percentage': coveragePercentage,
      if (copayType != null && copayType!.isNotEmpty) 'copay_type': copayType,
      if (copayValue != null) 'copay_value': copayValue,
      if (patientShare != null) 'patient_share': patientShare,
      if (insurerShare != null) 'insurer_share': insurerShare,
      if (copayAmount != null) 'copay_amount': copayAmount,
      'line_items': lineItems
          .map(
            (ClinicalRequestBillingLineItem item) => <String, Object?>{
              'id': item.id,
              'label': item.label,
              'quantity': item.quantity,
              if (item.unitPrice != null) 'unit_price': item.unitPrice,
              if (item.lineTotal != null) 'line_total': item.lineTotal,
              if (item.priceSource != null && item.priceSource!.isNotEmpty)
                'price_source': item.priceSource,
              if (item.billingEntity != null && item.billingEntity!.isNotEmpty)
                'billing_entity': item.billingEntity,
              if (item.paymentMode != null && item.paymentMode!.isNotEmpty)
                'payment_mode': item.paymentMode,
              if (item.catalogType != null && item.catalogType!.isNotEmpty)
                'catalog_type': item.catalogType,
              if (item.priceBookEntryId != null &&
                  item.priceBookEntryId!.isNotEmpty)
                'price_book_entry_id': item.priceBookEntryId,
              if (item.coveragePlanId != null && item.coveragePlanId!.isNotEmpty)
                'coverage_plan_id': item.coveragePlanId,
              if (item.patientShare != null) 'patient_share': item.patientShare,
              if (item.insurerShare != null) 'insurer_share': item.insurerShare,
              if (item.copayAmount != null) 'copay_amount': item.copayAmount,
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
  String? catalogType,
  String? billingEntity,
}) {
  return <ClinicalRequestBillingLineItem>[
    for (final ClinicalActionCatalogOption option in options)
      ClinicalRequestBillingLineItem(
        id: option.apiId,
        label: option.displayTitle,
        quantity: quantities?[option.apiId] ?? 1,
        unitPrice: clinicalCatalogOptionUnitPrice(option),
        currency: clinicalCatalogOptionCurrency(option) ?? currency,
        catalogType:
            catalogType ??
            clinicalCatalogOptionCatalogType(option),
        billingEntity: billingEntity,
        priceSource: billingEntity,
      ),
  ];
}

String? clinicalCatalogOptionCatalogType(ClinicalActionCatalogOption option) {
  final Object? raw =
      option.metadata['catalog_type'] ??
      option.metadata['catalogType'] ??
      option.metadata['term_type'] ??
      option.metadata['termType'];
  if (raw == null) return null;
  final String token = raw.toString().trim().toUpperCase();
  if (token.isEmpty) return null;
  if (token.contains('LAB_PANEL') || token == 'PANEL') return 'LAB_PANEL';
  if (token.contains('LAB')) return 'LAB_TEST';
  if (token.contains('RAD')) return 'RADIOLOGY_TEST';
  if (token.contains('DRUG') || token.contains('PHARM')) return 'DRUG';
  if (token.contains('CONSULT')) return 'CONSULTATION';
  if (token.contains('SERVICE') || token.contains('PROC')) return 'SERVICE';
  return token;
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

({num patientShare, num insurerShare, num copayAmount})
clinicalRequestCoverageShares({
  required num lineTotal,
  ClinicalRequestPayerContext? payerContext,
}) {
  final ClinicalRequestPayerContext context =
      payerContext ?? const ClinicalRequestPayerContext();
  if (!context.insured || lineTotal <= 0) {
    return (patientShare: lineTotal, insurerShare: 0, copayAmount: 0);
  }

  final num coveragePct = (context.coveragePercentage ?? 0).clamp(0, 100);
  final num coveredBase = lineTotal * coveragePct / 100;
  final num uncovered = lineTotal - coveredBase;
  final String copayType = (context.copayType ?? 'NONE').trim().toUpperCase();
  final num copayValue = context.copayValue ?? 0;
  num copayAmount = 0;
  if (copayType == 'FIXED') {
    copayAmount = copayValue.clamp(0, coveredBase);
  } else if (copayType == 'PERCENT') {
    copayAmount = coveredBase * copayValue.clamp(0, 100) / 100;
  }
  final num insurerShare = (coveredBase - copayAmount).clamp(0, lineTotal);
  final num patientShare = uncovered + copayAmount;
  return (
    patientShare: patientShare,
    insurerShare: insurerShare,
    copayAmount: copayAmount,
  );
}

List<ClinicalRequestBillingLineItem> applyClinicalRequestPayerContext(
  List<ClinicalRequestBillingLineItem> lineItems, {
  ClinicalRequestPayerContext? payerContext,
  String? billingEntity,
}) {
  final ClinicalRequestPayerContext context =
      payerContext ?? const ClinicalRequestPayerContext();
  return <ClinicalRequestBillingLineItem>[
    for (final ClinicalRequestBillingLineItem item in lineItems)
      () {
        final num total = item.lineTotal ?? 0;
        final shares = clinicalRequestCoverageShares(
          lineTotal: total,
          payerContext: context,
        );
        return item.copyWith(
          billingEntity: item.billingEntity ?? billingEntity ?? item.priceSource,
          paymentMode: context.paymentMode,
          coveragePlanId: item.coveragePlanId ?? context.coveragePlanId,
          patientShare: shares.patientShare,
          insurerShare: shares.insurerShare,
          copayAmount: shares.copayAmount,
        );
      }(),
  ];
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

ClinicalRequestBillingSubmit buildPendingClinicalRequestBillingSubmit({
  required List<ClinicalActionCatalogOption> options,
  String? facilityCurrency,
  String? tenantCurrency,
}) {
  final List<ClinicalRequestBillingLineItem> lineItems =
      clinicalRequestBillingLineItems(options: options);
  final num total = clinicalRequestBillingTotal(lineItems);
  return ClinicalRequestBillingSubmit(
    mode: ClinicalRequestPaymentMode.billLater,
    totalAmount: total,
    currency: resolveClinicalRequestBillingCurrency(
      lineItems,
      facilityCurrency: facilityCurrency,
      tenantCurrency: tenantCurrency,
    ),
    paymentStatus: ClinicalRequestPaymentStatus.unpaid,
    lineItems: lineItems,
  );
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
  List<ClinicalRequestBillingLineItem> lineItems, {
  String? facilityCurrency,
  String? tenantCurrency,
}) {
  for (final ClinicalRequestBillingLineItem item in lineItems) {
    final String? currency = item.currency?.trim().toUpperCase();
    if (currency != null && currency.isNotEmpty) {
      return currency;
    }
  }
  return resolveDefaultCurrency(
    facilityCurrency: facilityCurrency,
    tenantCurrency: tenantCurrency,
  );
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
