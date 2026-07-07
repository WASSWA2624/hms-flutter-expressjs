import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';

List<ClinicalRequestBillingLineItem> pharmacyOrderBillingLineItems(
  PharmacyOrder order,
) {
  final List<ClinicalRequestBillingLineItem> fromBilling =
      _lineItemsFromBillingMap(order.billing);
  if (fromBilling.isNotEmpty) {
    return fromBilling;
  }

  return order.items
      .map(
        (PharmacyOrderItem item) => ClinicalRequestBillingLineItem(
          id: item.id,
          label: item.medicationLabel,
          quantity: item.quantityPrescribed > 0
              ? item.quantityPrescribed
              : item.quantity,
          unitPrice: item.pharmacyUnitPrice ?? item.facilityUnitPrice,
          currency: item.pharmacyCurrency ?? item.facilityCurrency,
          priceSource: pharmacyItemPriceSourceValue(
            resolvePharmacyItemPriceSource(order: order, item: item),
          ),
        ),
      )
      .where((ClinicalRequestBillingLineItem item) => item.label.isNotEmpty)
      .toList(growable: false);
}

List<ClinicalRequestBillingLineItem> _lineItemsFromBillingMap(
  Map<String, Object?> billing,
) {
  final Object? raw = billing['line_items'];
  if (raw is! List) {
    return const <ClinicalRequestBillingLineItem>[];
  }

  return raw
      .whereType<Map<String, Object?>>()
      .map(
        (Map<String, Object?> entry) => ClinicalRequestBillingLineItem(
          id: entry['id']?.toString() ?? entry['label']?.toString() ?? '',
          label: entry['label']?.toString() ?? '',
          quantity: _asNum(entry['quantity']) ?? 1,
          unitPrice: _asNum(entry['unit_price']),
          currency: entry['currency']?.toString(),
          priceSource: entry['price_source']?.toString(),
        ),
      )
      .where((ClinicalRequestBillingLineItem item) => item.label.isNotEmpty)
      .toList(growable: false);
}

num? _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}

Map<String, Object?>? buildPharmacyOrderBillingWithItemPriceSource({
  required PharmacyOrder order,
  required String itemId,
  required PharmacyItemPriceSource priceSource,
}) {
  final List<ClinicalRequestBillingLineItem> current =
      pharmacyOrderBillingLineItems(order);
  if (current.isEmpty) {
    return null;
  }

  final List<ClinicalRequestBillingLineItem> next = current
      .map((ClinicalRequestBillingLineItem line) {
        if (line.id != itemId) {
          return line;
        }
        final PharmacyOrderItem? item = order.items
            .where((PharmacyOrderItem entry) => entry.id == itemId)
            .firstOrNull;
        if (item == null) {
          return line;
        }
        final num? unitPrice = pharmacyItemUnitPriceForSource(
          item,
          priceSource,
        );
        final String? currency =
            pharmacyItemCurrencyForSource(item, priceSource) ??
            order.billingCurrency;
        return ClinicalRequestBillingLineItem(
          id: line.id,
          label: line.label,
          quantity: line.quantity,
          unitPrice: unitPrice,
          currency: currency,
          priceSource: pharmacyItemPriceSourceValue(priceSource),
        );
      })
      .toList(growable: false);

  final num total = next.fold<num>(
    0,
    (num sum, ClinicalRequestBillingLineItem line) =>
        sum + (line.lineTotal ?? 0),
  );
  final String paymentStatus =
      (order.effectivePaymentStatus ?? '').trim().isNotEmpty
      ? order.effectivePaymentStatus!
      : 'NOT_BILLED';

  return <String, Object?>{
    'payment_status': paymentStatus,
    'currency': order.billingCurrency,
    'total_amount': total,
    if (order.billing['paid_amount'] != null)
      'paid_amount': order.billing['paid_amount'],
    'line_items': next
        .map(
          (ClinicalRequestBillingLineItem line) => <String, Object?>{
            'id': line.id,
            'label': line.label,
            'quantity': line.quantity,
            if (line.unitPrice != null) 'unit_price': line.unitPrice,
            if (line.lineTotal != null) 'line_total': line.lineTotal,
            if (line.priceSource != null) 'price_source': line.priceSource,
            if (line.currency != null) 'currency': line.currency,
          },
        )
        .toList(growable: false),
  };
}
