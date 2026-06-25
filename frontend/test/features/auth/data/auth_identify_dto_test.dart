import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/auth/data/dtos/auth_identify_dto.dart';

void main() {
  group('AuthIdentifyDto', () {
    test('parses tenant options from identify response', () {
      final result = AuthIdentifyDto.fromResponseData(<String, Object?>{
        'users': <Object?>[
          <String, Object?>{
            'tenant_id': 'tenant-1',
            'tenant_name': 'City Hospital',
            'tenant_slug': 'city-hospital',
            'status': 'ACTIVE',
          },
          <String, Object?>{
            'tenantId': 'tenant-2',
            'tenantName': 'Rural Clinic',
            'status': 'PENDING',
          },
        ],
      }).toEntity();

      expect(result.tenants, hasLength(2));
      expect(result.tenants.first.tenantId, 'tenant-1');
      expect(result.tenants.first.tenantName, 'City Hospital');
      expect(result.tenants.first.isActive, isTrue);
      expect(result.tenants.last.tenantId, 'tenant-2');
      expect(result.tenants.last.isActive, isFalse);
    });

    test('returns empty tenants for invalid payload', () {
      expect(
        AuthIdentifyDto.fromResponseData(null).toEntity().tenants,
        isEmpty,
      );
      expect(
        AuthIdentifyDto.fromResponseData(
          <String, Object?>{},
        ).toEntity().tenants,
        isEmpty,
      );
    });
  });
}
