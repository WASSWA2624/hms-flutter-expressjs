import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/pharmacy/data/dtos/pharmacy_dtos.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('PharmacyOrderDto', () {
    test('maps billing fields from order payload', () {
      final PharmacyOrder order = const PharmacyOrderDto(<String, Object?>{
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
      final PharmacyOrder order = const PharmacyOrderDto(<String, Object?>{
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

    test('maps care location and flags discharge-pending inpatient orders', () {
      final PharmacyOrder order = const PharmacyOrderDto(<String, Object?>{
        'id': 'PO-102',
        'display_id': 'PO-102',
        'status': 'PARTIALLY_DISPENSED',
        'encounter_id': 'ENC-1',
        'encounter_type': 'IPD',
        'location': 'INPATIENT',
      }).toEntity();

      expect(order.location, 'INPATIENT');
      expect(order.encounterType, 'IPD');
      expect(order.isInpatientOrder, isTrue);
      expect(order.isDischargePending, isTrue);
    });

    test('treats outpatient orders as not discharge-pending', () {
      final PharmacyOrder order = const PharmacyOrderDto(<String, Object?>{
        'id': 'PO-103',
        'display_id': 'PO-103',
        'status': 'ORDERED',
        'location': 'OUTPATIENT',
      }).toEntity();

      expect(order.isInpatientOrder, isFalse);
      expect(order.isDischargePending, isFalse);
    });
  });

  group('PharmacyOrderFilter', () {
    test('maps location filters to backend location values', () {
      expect(PharmacyOrderFilter.outpatient.backendLocation, 'OUTPATIENT');
      expect(PharmacyOrderFilter.ward.backendLocation, 'INPATIENT');
      expect(PharmacyOrderFilter.discharge.backendLocation, 'DISCHARGE');
      expect(PharmacyOrderFilter.ready.backendLocation, isNull);
      expect(PharmacyOrderFilter.discharge.isBackendBacked, isTrue);
      expect(PharmacyOrderFilter.ward.isBackendBacked, isTrue);
      expect(PharmacyOrderFilter.outpatient.isBackendBacked, isTrue);
    });
  });

  group('PharmacyWorkbenchSummaryDto', () {
    test('parses discharge pending queue count', () {
      final PharmacyWorkbenchSummary summary =
          const PharmacyWorkbenchSummaryDto(<String, Object?>{
            'total_orders': 5,
            'discharge_pending_queue': 2,
          }).toEntity();

      expect(summary.totalOrders, 5);
      expect(summary.dischargePendingQueue, 2);
    });

    test('parses location and payment queue counts', () {
      final PharmacyWorkbenchSummary summary =
          const PharmacyWorkbenchSummaryDto(<String, Object?>{
            'outpatient_queue': 4,
            'ward_queue': 3,
            'pending_payment_queue': 2,
          }).toEntity();

      expect(summary.outpatientQueue, 4);
      expect(summary.wardQueue, 3);
      expect(summary.pendingPaymentQueue, 2);
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

  group('PharmacyOrderItemDto', () {
    test('maps catalog pricing fields from workflow item payload', () {
      final PharmacyOrderItem item =
          const PharmacyOrderItemDto(<String, Object?>{
            'id': 'item-1',
            'drug_display_name': 'Artemether Tablet',
            'quantity_prescribed': 24,
            'pharmacy_unit_price': 500,
            'facility_unit_price': 450,
            'pharmacy_currency': 'TZS',
            'facility_currency': 'TZS',
            'is_offered_at_facility': true,
          }).toEntity();

      expect(item.pharmacyUnitPrice, 500);
      expect(item.facilityUnitPrice, 450);
      expect(item.isOfferedAtFacility, isTrue);
    });
  });
}
