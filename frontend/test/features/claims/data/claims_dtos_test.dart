import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/claims/data/dtos/claims_dtos.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('claims DTOs', () {
    test('decodes authorization page with display identifiers', () {
      const AppPageRequest request = AppPageRequest(pageIndex: 1);
      final PreAuthorizationPageDto dto = PreAuthorizationPageDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'auth-1',
              'display_id': 'AUTH-001',
              'coverage_plan_id': 'plan-1',
              'coverage_plan_display_id': 'COV-001',
              'status': 'PENDING',
              'requested_at': '2026-05-17T08:00:00.000Z',
            },
          ],
          'pagination': <String, Object?>{'total': 4},
        },
        request,
      );

      expect(dto.page.request, request);
      expect(dto.page.totalItemCount, 4);
      expect(dto.page.items.single.displayId, 'AUTH-001');
      expect(dto.page.items.single.coveragePlanDisplayId, 'COV-001');
      expect(dto.page.items.single.requestedAt, isA<DateTime>());
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
              'status': 'SUBMITTED',
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
