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
            'stage': 'WAITING_VITALS',
            'next_step': 'RECORD_VITALS',
            'consultation': <String, Object?>{
              'require_payment': true,
              'is_paid': true,
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
  });
}
