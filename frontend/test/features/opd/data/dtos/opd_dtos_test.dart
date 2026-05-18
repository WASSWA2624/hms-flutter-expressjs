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
    expect(detail.summary.queuedAt, DateTime.parse('2026-05-17T07:45:00.000Z'));
    expect(detail.summary.arrivalMode, 'EMERGENCY');
    expect(detail.summary.emergencyIndicator, isTrue);
    expect(detail.summary.consultationPaymentRequired, isTrue);
    expect(detail.summary.consultationPaid, isTrue);
    expect(detail.summary.consultationFee, 25000);
    expect(detail.summary.consultationCurrency, 'UGX');
  });
}
