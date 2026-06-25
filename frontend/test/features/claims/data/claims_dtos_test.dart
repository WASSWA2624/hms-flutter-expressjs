import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/claims/data/dtos/claims_dtos.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('claims DTOs', () {
    test('decodes authorization page with encounter and amount fields', () {
      const AppPageRequest request = AppPageRequest(pageIndex: 1);
      final PreAuthorizationPageDto dto = PreAuthorizationPageDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'auth-1',
              'display_id': 'AUTH-001',
              'coverage_plan_id': 'plan-1',
              'coverage_plan_display_id': 'COV-001',
              'patient_display_id': 'PAT-001',
              'admission_display_id': 'ADM-001',
              'status': 'APPROVED',
              'approved_amount': '500000',
              'consumed_amount': '125000',
              'requested_at': '2026-05-17T08:00:00.000Z',
            },
          ],
          'pagination': <String, Object?>{'total': 4},
        },
        request,
      );

      final PreAuthorizationRecord record = dto.page.items.single;
      expect(record.displayId, 'AUTH-001');
      expect(record.patientDisplayId, 'PAT-001');
      expect(record.admissionDisplayId, 'ADM-001');
      expect(record.approvedAmount, 500000);
      expect(record.consumedAmount, 125000);
      expect(record.remainingAmount, 375000);
    });

    test('decodes insurance claim page with invoice and patient context', () {
      const AppPageRequest request = AppPageRequest();
      final InsuranceClaimPageDto dto = InsuranceClaimPageDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'claim-1',
              'display_id': 'CLM-001',
              'coverage_plan_id': 'plan-1',
              'coverage_plan_display_id': 'COV-001',
              'invoice_id': 'invoice-1',
              'invoice_display_id': 'INV-001',
              'patient_display_id': 'PAT-001',
              'status': 'PAID',
              'settlement_amount': '90000',
              'payer_reference': 'PAY-REF-1',
              'submitted_at': '2026-05-17T09:00:00.000Z',
            },
          ],
          'pagination': <String, Object?>{'total': 1},
        },
        request,
      );

      final claim = dto.page.items.single;
      expect(claim.displayId, 'CLM-001');
      expect(claim.invoiceDisplayId, 'INV-001');
      expect(claim.patientDisplayId, 'PAT-001');
      expect(claim.settlementAmount, 90000);
      expect(claim.payerReference, 'PAY-REF-1');
      expect(claim.submittedAt, isA<DateTime>());
    });

    test('decodes merged work items by type from the aggregator', () {
      const AppPageRequest request = AppPageRequest();
      final ClaimsWorkItemsPageDto dto = ClaimsWorkItemsPageDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'type': 'CLAIM',
              'id': 'claim-1',
              'display_id': 'CLM-001',
              'coverage_plan_display_id': 'COV-001',
              'invoice_display_id': 'INV-001',
              'patient_display_id': 'PAT-001',
              'status': 'SUBMITTED',
              'submitted_at': '2026-05-18T09:00:00.000Z',
            },
            <String, Object?>{
              'type': 'PRE_AUTH',
              'id': 'auth-1',
              'display_id': 'AUTH-001',
              'coverage_plan_display_id': 'COV-001',
              'status': 'PENDING',
              'approved_amount': '500000.00',
              'consumed_amount': '125000.00',
              'requested_at': '2026-05-17T08:00:00.000Z',
            },
          ],
          'pagination': <String, Object?>{'total': 2},
        },
        request,
      );

      expect(dto.page.items, hasLength(2));
      expect(dto.page.items.first.isClaim, isTrue);
      expect(dto.page.items.first.displayId, 'CLM-001');
      expect(dto.page.items.last.isAuthorization, isTrue);
      expect(dto.page.items.last.authorization?.remainingAmount, 375000);
      expect(dto.page.totalItemCount, 2);
    });

    test('decodes workspace summary counts from the aggregator', () {
      final ClaimsWorkspaceSummary summary =
          ClaimsWorkspaceSummaryDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'summary': <String, Object?>{
                'authorization_pending': 3,
                'authorization_approved': 2,
                'claims_submitted': 4,
                'claims_approved': 1,
                'denied_resubmission': 5,
                'paid_closed': 6,
                'workload': 11,
              },
            },
          }).summary;

      expect(summary.authorizationPendingCount, 3);
      expect(summary.submittedClaimsCount, 4);
      expect(summary.rejectedResubmissionCount, 5);
      expect(summary.paidClosedCount, 6);
      expect(summary.workloadCount, 11);
    });

    test('decodes lookups reference data from the aggregator', () {
      final ClaimsReferenceData reference = ClaimsLookupsDto.fromResponse(
        <String, Object?>{
          'data': <String, Object?>{
            'coverage_plans': <Object?>[
              <String, Object?>{
                'id': 'plan-1',
                'display_id': 'COV-001',
                'name': 'Corporate Plan',
                'coverage_percentage': 80,
              },
            ],
            'invoices': <Object?>[
              <String, Object?>{
                'id': 'invoice-1',
                'display_id': 'INV-001',
                'total_amount': '125000',
                'currency': 'UGX',
              },
            ],
          },
        },
      ).referenceData;

      expect(reference.coveragePlans, hasLength(1));
      expect(reference.coveragePlans.single.title, 'Corporate Plan');
      expect(reference.invoices, hasLength(1));
      expect(reference.invoices.single.totalAmount, 125000);
    });

    test('decodes coverage and invoice reference records', () {
      final coverage = CoveragePlanDto.fromResponse(<String, Object?>{
        'data': <String, Object?>{
          'id': 'plan-1',
          'display_id': 'COV-001',
          'name': 'Corporate Plan',
          'provider_name': 'Acme Insurance',
          'coverage_percentage': 80,
        },
      }).toEntity();
      final invoice = ClaimInvoiceDto.fromResponse(<String, Object?>{
        'data': <String, Object?>{
          'id': 'invoice-1',
          'display_id': 'INV-001',
          'patient_display_id': 'PAT-001',
          'billing_status': 'ISSUED',
          'total_amount': '125000',
          'currency': 'UGX',
        },
      }).toEntity();

      expect(coverage.title, 'Corporate Plan');
      expect(coverage.providerName, 'Acme Insurance');
      expect(coverage.coveragePercentage, 80);
      expect(invoice.patientDisplayId, 'PAT-001');
      expect(invoice.totalAmount, 125000);
    });
  });
}
