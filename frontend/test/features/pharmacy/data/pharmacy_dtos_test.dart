import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/data/dtos/pharmacy_dtos.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('PharmacyOrderDto', () {
    test('maps billing fields from order payload', () {
      final PharmacyOrder order = PharmacyOrderDto(<String, Object?>{
        'id': 'PO-100',
        'display_id': 'PO-100',
        'status': 'ORDERED',
        'payment_status': 'UNPAID',
        'billing': <String, Object?>{
          'payment_status': 'UNPAID',
          'total_amount': 42.5,
          'currency': 'USD',
          'line_items': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'line-1',
              'label': 'Amoxicillin',
              'quantity': 2,
              'unit_price': 21.25,
            },
          ],
        },
      }).toEntity();

      expect(order.paymentStatus, 'UNPAID');
      expect(order.effectivePaymentStatus, 'UNPAID');
      expect(order.hasBillingGate, isTrue);
      expect(order.requiresPaymentBeforeDispense, isTrue);
      expect(order.billingTotalAmount, 42.5);
      expect(order.billingCurrency, 'USD');
    });

    test('treats paid orders as payment satisfied', () {
      final PharmacyOrder order = PharmacyOrderDto(<String, Object?>{
        'id': 'PO-101',
        'display_id': 'PO-101',
        'status': 'ORDERED',
        'payment_status': 'PAID',
        'billing': <String, Object?>{
          'payment_status': 'PAID',
          'total_amount': 10,
        },
      }).toEntity();

      expect(order.isPaymentSatisfied, isTrue);
      expect(order.requiresPaymentBeforeDispense, isFalse);
    });
  });

  group('PharmacyInventoryWorkbenchDto', () {
    test('maps inventory stock page', () {
      const AppPageRequest request = AppPageRequest(pageSize: 10);
      final PharmacyInventoryWorkbench workbench =
          PharmacyInventoryWorkbenchDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'summary': <String, Object?>{
                'total_stock_rows': 3,
                'low_stock_rows': 1,
              },
              'stocks': <Map<String, Object?>>[
                <String, Object?>{
                  'id': 'STK-1',
                  'display_id': 'STK-1',
                  'quantity': 12,
                  'stock_status': 'IN_STOCK',
                  'inventory_item': <String, Object?>{
                    'id': 'INV-1',
                    'name': 'Gloves',
                  },
                },
              ],
              'pagination': <String, Object?>{'total': 1},
            },
          }, request).workbench;

      expect(workbench.summary.totalStockRows, 3);
      expect(workbench.summary.lowStockRows, 1);
      expect(workbench.stocks.items, hasLength(1));
      expect(workbench.stocks.items.single.quantity, 12);
    });
  });
}
