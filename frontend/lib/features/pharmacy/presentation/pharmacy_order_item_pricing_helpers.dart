import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';

enum PharmacyItemPriceSource { pharmacy, facility }

const Set<String> _clinicalOrderSources = <String>{
  'CLINICAL',
  'OPD',
  'IPD',
  'EMERGENCY',
  'ICU',
  'THEATER',
};

PharmacyItemPriceSource pharmacyDefaultPriceSource(PharmacyOrder order) {
  final String source = (order.orderSource ?? '').trim().toUpperCase();
  if (_clinicalOrderSources.contains(source) ||
      (order.encounterId ?? '').trim().isNotEmpty) {
    return PharmacyItemPriceSource.facility;
  }
  return PharmacyItemPriceSource.pharmacy;
}

PharmacyItemPriceSource? pharmacyItemPriceSourceFromValue(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'PHARMACY' => PharmacyItemPriceSource.pharmacy,
    'FACILITY' => PharmacyItemPriceSource.facility,
    _ => null,
  };
}

String pharmacyItemPriceSourceValue(PharmacyItemPriceSource source) {
  return switch (source) {
    PharmacyItemPriceSource.pharmacy => 'PHARMACY',
    PharmacyItemPriceSource.facility => 'FACILITY',
  };
}

ClinicalRequestBillingLineItem? pharmacyBillingLineItemForOrderItem(
  PharmacyOrder order,
  PharmacyOrderItem item,
) {
  final Object? raw = order.billing['line_items'];
  if (raw is! List) {
    return null;
  }

  final Set<String> itemKeys = <String>{
    item.id,
    if ((item.displayId ?? '').trim().isNotEmpty) item.displayId!.trim(),
    if ((item.drugId ?? '').trim().isNotEmpty) item.drugId!.trim(),
  };

  for (final Object? entry in raw) {
    if (entry is! Map) {
      continue;
    }
    final Map<String, Object?> normalized = <String, Object?>{
      for (final MapEntry<Object?, Object?> pair in entry.entries)
        if (pair.key != null) pair.key.toString(): pair.value,
    };
    final String? id = normalized['id']?.toString().trim();
    if (id == null || id.isEmpty || !itemKeys.contains(id)) {
      continue;
    }
    return ClinicalRequestBillingLineItem(
      id: id,
      label: normalized['label']?.toString() ?? item.medicationLabel,
      quantity: _asNum(normalized['quantity']) ?? item.quantityPrescribed,
      unitPrice: _asNum(normalized['unit_price']),
      currency: normalized['currency']?.toString(),
      priceSource: normalized['price_source']?.toString(),
    );
  }
  return null;
}

PharmacyItemPriceSource resolvePharmacyItemPriceSource({
  required PharmacyOrder order,
  required PharmacyOrderItem item,
}) {
  final ClinicalRequestBillingLineItem? billingLine =
      pharmacyBillingLineItemForOrderItem(order, item);
  final PharmacyItemPriceSource? stored = pharmacyItemPriceSourceFromValue(
    billingLine?.priceSource,
  );
  if (stored != null) {
    return stored;
  }

  final PharmacyItemPriceSource fallback = pharmacyDefaultPriceSource(order);
  if (fallback == PharmacyItemPriceSource.facility &&
      !_itemHasFacilityPrice(item)) {
    return PharmacyItemPriceSource.pharmacy;
  }
  return fallback;
}

num? pharmacyItemUnitPriceForSource(
  PharmacyOrderItem item,
  PharmacyItemPriceSource source,
) {
  return switch (source) {
    PharmacyItemPriceSource.pharmacy => item.pharmacyUnitPrice,
    PharmacyItemPriceSource.facility => item.facilityUnitPrice,
  };
}

String? pharmacyItemCurrencyForSource(
  PharmacyOrderItem item,
  PharmacyItemPriceSource source,
) {
  return switch (source) {
    PharmacyItemPriceSource.pharmacy => item.pharmacyCurrency,
    PharmacyItemPriceSource.facility => item.facilityCurrency,
  };
}

num resolvePharmacyItemQuantity(PharmacyOrderItem item) {
  if (item.quantityPrescribed > 0) {
    return item.quantityPrescribed;
  }
  if (item.quantity > 0) {
    return item.quantity;
  }
  return 1;
}

/// Quantity used for billing/print amounts: prefer snapshot qty, then net
/// dispensed for partial/full fills, otherwise prescribed.
num resolvePharmacyItemBillableQuantity({
  required PharmacyOrder order,
  required PharmacyOrderItem item,
}) {
  final ClinicalRequestBillingLineItem? billingLine =
      pharmacyBillingLineItemForOrderItem(order, item);
  final num? billingQuantity = billingLine?.quantity;
  if (billingQuantity != null && billingQuantity > 0) {
    return billingQuantity;
  }
  if (item.quantityDispensed > 0) {
    return item.quantityDispensed;
  }
  return resolvePharmacyItemQuantity(item);
}

num? resolvePharmacyItemUnitPrice({
  required PharmacyOrder order,
  required PharmacyOrderItem item,
}) {
  final ClinicalRequestBillingLineItem? billingLine =
      pharmacyBillingLineItemForOrderItem(order, item);
  if (billingLine?.unitPrice != null && billingLine!.unitPrice! > 0) {
    return billingLine.unitPrice;
  }

  final PharmacyItemPriceSource source = resolvePharmacyItemPriceSource(
    order: order,
    item: item,
  );
  return pharmacyItemUnitPriceForSource(item, source);
}

String? resolvePharmacyItemCurrency({
  required PharmacyOrder order,
  required PharmacyOrderItem item,
}) {
  final ClinicalRequestBillingLineItem? billingLine =
      pharmacyBillingLineItemForOrderItem(order, item);
  if ((billingLine?.currency ?? '').trim().isNotEmpty) {
    return billingLine!.currency;
  }

  final PharmacyItemPriceSource source = resolvePharmacyItemPriceSource(
    order: order,
    item: item,
  );
  return pharmacyItemCurrencyForSource(item, source) ??
      order.billingCurrency ??
      'USD';
}

num? resolvePharmacyItemLineTotal({
  required PharmacyOrder order,
  required PharmacyOrderItem item,
}) {
  final num? unitPrice = resolvePharmacyItemUnitPrice(order: order, item: item);
  if (unitPrice == null || unitPrice <= 0) {
    return null;
  }
  return unitPrice * resolvePharmacyItemBillableQuantity(order: order, item: item);
}

bool pharmacyItemHasSelectablePrices(PharmacyOrderItem item) {
  return _itemHasPharmacyPrice(item) && _itemHasFacilityPrice(item);
}

bool pharmacyItemNeedsStockMapping(PharmacyOrderItem item) {
  return item.defaultStockMapping == null && item.stockMappings.isEmpty;
}

bool pharmacyItemIsCancelled(PharmacyOrderItem item) {
  return (item.status ?? '').trim().toUpperCase() == 'CANCELLED';
}

bool _itemHasPharmacyPrice(PharmacyOrderItem item) {
  return item.pharmacyUnitPrice != null && item.pharmacyUnitPrice! > 0;
}

bool _itemHasFacilityPrice(PharmacyOrderItem item) {
  return item.isOfferedAtFacility &&
      item.facilityUnitPrice != null &&
      item.facilityUnitPrice! > 0;
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
