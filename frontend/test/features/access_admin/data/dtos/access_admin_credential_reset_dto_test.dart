import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/data/dtos/access_admin_dtos.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';

void main() {
  group('AccessAdminCredentialResetResultDto', () {
    test('maps the API envelope to a reset result', () {
      final AccessAdminCredentialResetResult result =
          AccessAdminCredentialResetResultDto.fromResponse(<String, Object?>{
            'data': <String, Object?>{
              'user_id': 'USR-0042',
              'masked_email': 'gr***@e***.com',
              'delivery_status': 'SENT',
              'expires_at': '2026-09-13T13:00:00.000Z',
            },
          }).toEntity();

      expect(result.delivery, AccessAdminCredentialDelivery.sent);
      expect(result.maskedEmail, 'gr***@e***.com');
      expect(result.expiresAt, DateTime.utc(2026, 9, 13, 13));
    });

    test('reports PENDING as pending', () {
      final AccessAdminCredentialResetResult result =
          AccessAdminCredentialResetResultDto.fromResponse(<String, Object?>{
            'delivery_status': 'pending',
          }).toEntity();

      expect(result.delivery, AccessAdminCredentialDelivery.pending);
    });

    test('never reports an unknown or missing status as delivered', () {
      for (final Object? status in <Object?>['FAILED', 'QUEUED', null]) {
        final AccessAdminCredentialResetResult result =
            AccessAdminCredentialResetResultDto.fromResponse(<String, Object?>{
              'delivery_status': status,
            }).toEntity();

        expect(result.delivery, AccessAdminCredentialDelivery.failed);
      }
    });
  });
}
