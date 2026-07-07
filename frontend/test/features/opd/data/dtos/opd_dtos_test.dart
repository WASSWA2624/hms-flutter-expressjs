import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/opd/data/dtos/opd_dtos.dart';

void main() {
  test('OpdFlowDetailDto decodes backend consultation gate flags', () {
    final OpdFlowDetailDto dto = OpdFlowDetailDto.fromResponse(
      <String, Object?>{
        'data': <String, Object?>{
          'encounter': <String, Object?>{
            'id': 'enc-1',
            'human_friendly_id': 'ENC0001',
            'encounter_type': 'OPD',
            'status': 'OPEN',
          },
          'flow': <String, Object?>{
            'arrival_mode': 'EMERGENCY',
            'queued_at': '2026-05-17T07:45:00.000Z',
            'stage': 'WAITING_VITALS',
            'next_step': 'RECORD_VITALS',
            'emergency_indicator': true,
            'consultation': <String, Object?>{
              'require_payment': true,
              'is_paid': true,
              'consultation_fee': '25000',
              'currency': 'UGX',
              'invoice_id': 'INV0001',
              'payment_id': 'PAY0001',
              'payment_status': 'COMPLETED',
            },
            'timeline': <Object?>[],
          },
        },
      },
    );

    final detail = dto.toEntity();

    expect(detail.consultationPaymentRequired, isTrue);
    expect(detail.consultationPaid, isTrue);
    expect(detail.consultationInvoiceId, 'INV0001');
    expect(detail.consultationPaymentId, 'PAY0001');
    expect(detail.consultationPaymentStatus, 'COMPLETED');
    expect(detail.summary.queuedAt, DateTime.parse('2026-05-17T07:45:00.000Z'));
    expect(detail.summary.arrivalMode, 'EMERGENCY');
    expect(detail.summary.emergencyIndicator, isTrue);
    expect(detail.summary.consultationPaymentRequired, isTrue);
    expect(detail.summary.consultationPaid, isTrue);
    expect(detail.summary.consultationFee, 25000);
    expect(detail.summary.consultationCurrency, 'UGX');
    expect(detail.summary.consultationPaymentStatus, 'COMPLETED');
  });

  test('OpdFlowSummaryDto maps patient display id from human-friendly id', () {
    final OpdFlowSummaryDto dto = OpdFlowSummaryDto.fromDetail(
      <String, Object?>{
        'encounter': <String, Object?>{
          'id': 'enc-1',
          'human_friendly_id': 'ENC0000003',
          'patient_id': '4e73222f-7b32-4a31-a1c1-9c1b59889479',
          'patient': <String, Object?>{
            'human_friendly_id': 'PAT0000001',
            'first_name': 'Amina',
            'last_name': 'Demo-Alpha',
          },
        },
        'flow': <String, Object?>{
          'stage': 'IN_LAB',
        },
      },
    );

    final summary = dto.toEntity();

    expect(summary.patientId, '4e73222f-7b32-4a31-a1c1-9c1b59889479');
    expect(summary.patientIdentifier, 'PAT0000001');
    expect(summary.patientDisplayId, 'PAT0000001');
    expect(summary.publicId, 'ENC0000003');
  });
}
