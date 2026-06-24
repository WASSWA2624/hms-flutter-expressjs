import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
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
