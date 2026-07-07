import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_billing_helpers.dart';
import 'package:hosspi_hms/features/pharmacy/presentation/pharmacy_order_item_pricing_helpers.dart';

void main() {
  group('pharmacy order item pricing helpers', () {
    const PharmacyOrderItem item = PharmacyOrderItem(
      id: 'item-1',
      drugDisplayName: 'Artemether Tablet',
      quantityPrescribed: 24,
      pharmacyUnitPrice: 500,
      facilityUnitPrice: 450,
      pharmacyCurrency: 'TZS',
      facilityCurrency: 'TZS',
      isOfferedAtFacility: true,
    );

    test('defaults clinical orders to facility price when offered', () {
      const PharmacyOrder order = PharmacyOrder(
        id: 'order-1',
        orderSource: 'CLINICAL',
        encounterId: 'ENC-1',
        items: <PharmacyOrderItem>[item],
      );

      expect(
        resolvePharmacyItemPriceSource(order: order, item: item),
        PharmacyItemPriceSource.facility,
      );
      expect(resolvePharmacyItemUnitPrice(order: order, item: item), 450);
    });

    test('defaults walk-in orders to pharmacy price', () {
      const PharmacyOrder order = PharmacyOrder(
        id: 'order-2',
        orderSource: 'PHARMACY',
        items: <PharmacyOrderItem>[item],
      );

      expect(
        resolvePharmacyItemPriceSource(order: order, item: item),
        PharmacyItemPriceSource.pharmacy,
      );
      expect(resolvePharmacyItemUnitPrice(order: order, item: item), 500);
    });

    test('persists selected price source from billing line items', () {
      const PharmacyOrder order = PharmacyOrder(
        id: 'order-3',
        orderSource: 'CLINICAL',
        encounterId: 'ENC-1',
        billing: <String, Object?>{
          'line_items': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'item-1',
              'label': 'Artemether Tablet',
              'quantity': 24,
              'unit_price': 500,
              'price_source': 'PHARMACY',
            },
          ],
        },
        items: <PharmacyOrderItem>[item],
      );

      expect(
        resolvePharmacyItemPriceSource(order: order, item: item),
        PharmacyItemPriceSource.pharmacy,
      );
      expect(resolvePharmacyItemUnitPrice(order: order, item: item), 500);
    });

    test('builds billing payload when switching price source', () {
      const PharmacyOrder order = PharmacyOrder(
        id: 'order-4',
        orderSource: 'CLINICAL',
        encounterId: 'ENC-1',
        billing: <String, Object?>{
          'currency': 'TZS',
          'payment_status': 'NOT_BILLED',
          'line_items': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'item-1',
              'label': 'Artemether Tablet',
              'quantity': 24,
              'unit_price': 450,
              'price_source': 'FACILITY',
            },
          ],
        },
        items: <PharmacyOrderItem>[item],
      );

      final Map<String, Object?>? billing =
          buildPharmacyOrderBillingWithItemPriceSource(
            order: order,
            itemId: 'item-1',
            priceSource: PharmacyItemPriceSource.pharmacy,
          );

      expect(billing, isNotNull);
      final List<Object?> lineItems = billing!['line_items']! as List<Object?>;
      final Map<String, Object?> line =
          lineItems.first! as Map<String, Object?>;
      expect(line['unit_price'], 500);
      expect(line['price_source'], 'PHARMACY');
      expect(line['line_total'], 12000);
    });
  });
}
