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

    test(
      'parses invoice work items with financials and patient demographics',
      () {
        final page = BillingWorkItemPageDto.fromResponse(<String, Object?>{
          'data': <String, Object?>{
            'queue': 'PENDING_PAYMENT',
            'items': <Object?>[
              <String, Object?>{
                'id': 'invoice-1',
                'display_id': 'INV-001',
                'tenant_id': 'tenant-1',
                'patient_display_name': 'Jane Doe',
                'patient_display_id': 'PAT-001',
                'patient_gender': 'FEMALE',
                'patient_date_of_birth': '1990-05-17T00:00:00.000Z',
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
        expect(item.patientGender, 'FEMALE');
        expect(item.patientDateOfBirth, isNotNull);
        expect(item.balanceDue, 60000);
        expect(item.clearanceState, BillingClearanceState.partiallyPaid);
      },
    );

    test('maps unpaid issued invoices to awaiting payment clearance', () {
      final BillingWorkItem item = const BillingWorkItemDto(<String, Object?>{
        'id': 'invoice-2',
        'display_id': 'INV-002',
        'billing_status': 'ISSUED',
        'status': 'SENT',
        'total_amount': '95000.00',
        'currency': 'UGX',
        'financials': <String, Object?>{
          'effective_total': '95000.00',
          'net_paid_total': '0.00',
          'balance_due': '95000.00',
        },
      }, fallbackQueue: BillingQueueType.pendingPayment).toEntity();

      expect(item.clearanceState, BillingClearanceState.awaitingPayment);
    });

    test('parses approval work items', () {
      final page = BillingWorkItemPageDto.fromResponse(<String, Object?>{
        'data': <String, Object?>{
          'queue': 'APPROVAL_REQUIRED',
          'items': <Object?>[
            <String, Object?>{
              'id': 'approval-1',
              'display_id': 'APR-001',
              'approval_type': 'REFUND',
              'status': 'PENDING',
              'reason': 'Large refund',
              'requested_by_user_display_id': 'USR-001',
              'target_display_id': 'INV-001',
            },
          ],
          'pagination': <String, Object?>{'total': 1},
        },
      }, const AppPageRequest(pageSize: 12)).page;

      final BillingWorkItem item = page.items.single;
      expect(item.kind, BillingWorkItemKind.approval);
      expect(item.canApproveOrReject, isTrue);
      expect(item.approvalType, 'REFUND');
    });

    test('parses patient ledger', () {
      final BillingPatientLedger ledger = BillingPatientLedgerDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'patient': <String, Object?>{
              'id': 'patient-1',
              'display_id': 'PAT-001',
              'display_name': 'Jane Doe',
            },
            'summary': <String, Object?>{
              'total_invoiced': '1000.00',
              'net_paid': '400.00',
              'balance_due': '600.00',
            },
            'ledger': <String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'type': 'INVOICE',
                  'display_id': 'INV-001',
                  'amount': '1000.00',
                  'timeline_at': '2026-05-17T08:00:00.000Z',
                },
              ],
              'pagination': <String, Object?>{'total': 1},
            },
          },
        },
        const AppPageRequest(),
      ).toEntity();

      expect(ledger.patientDisplayId, 'PAT-001');
      expect(ledger.summary.balanceDue, 600);
      expect(ledger.entries.single.kind, BillingWorkItemKind.invoice);
    });
  });
}
