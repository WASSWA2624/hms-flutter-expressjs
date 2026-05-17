import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/billing/data/dtos/billing_dtos.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('Billing DTOs', () {
    test('parses workspace summary and queues', () {
      final BillingWorkspaceOverview overview =
          BillingWorkspaceOverviewDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'summary': <String, Object?>{
                'needs_issue': 2,
                'pending_payment': 4,
                'claims_pending': 1,
                'approval_required': 3,
                'overdue': 5,
                'payments_today_total': '120000.00',
                'refunds_today_total': '10000.00',
              },
              'queues': <Object?>[
                <String, Object?>{
                  'queue': 'PENDING_PAYMENT',
                  'label': 'Pending payment',
                  'count': 4,
                },
              ],
              'timeline': <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'type': 'PAYMENT',
                    'display_id': 'PAY-1',
                    'status': 'COMPLETED',
                    'amount': '50000.00',
                    'timeline_at': '2026-05-17T08:00:00.000Z',
                  },
                ],
              },
            },
          }).toEntity();

      expect(overview.summary.pendingPayment, 4);
      expect(overview.summary.paymentsTodayTotal, 120000);
      expect(overview.queues.single.queue, BillingQueueType.pendingPayment);
      expect(overview.timeline.single.kind, BillingWorkItemKind.payment);
    });

    test('parses invoice work items with financials', () {
      final page = BillingWorkItemPageDto.fromResponse(<String, Object?>{
        'data': <String, Object?>{
          'queue': 'PENDING_PAYMENT',
          'items': <Object?>[
            <String, Object?>{
              'id': 'invoice-1',
              'display_id': 'INV-001',
              'tenant_id': 'tenant-1',
              'patient_display_name': 'Jane Doe',
              'billing_status': 'PARTIAL',
              'total_amount': '100000.00',
              'currency': 'UGX',
              'financials': <String, Object?>{
                'effective_total': '100000.00',
                'net_paid_total': '40000.00',
                'balance_due': '60000.00',
              },
              'items': <Object?>[
                <String, Object?>{
                  'id': 'item-1',
                  'description': 'Consultation',
                  'quantity': 1,
                  'unit_price': '100000.00',
                  'total_price': '100000.00',
                },
              ],
              'payments': <Object?>[
                <String, Object?>{
                  'id': 'payment-1',
                  'status': 'COMPLETED',
                  'method': 'CASH',
                  'amount': '40000.00',
                },
              ],
            },
          ],
          'pagination': <String, Object?>{'total': 1},
        },
      }, const AppPageRequest(pageSize: 12)).page;

      final BillingWorkItem item = page.items.single;
      expect(item.isInvoice, isTrue);
      expect(item.effectiveDisplayId, 'INV-001');
      expect(item.balanceDue, 60000);
      expect(item.clearanceState, BillingClearanceState.partiallyPaid);
      expect(item.items.single.description, 'Consultation');
      expect(item.firstRefundablePayment?.id, 'payment-1');
    });
  });
}
