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
