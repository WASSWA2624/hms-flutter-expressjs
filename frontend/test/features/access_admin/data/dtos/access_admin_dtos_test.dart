import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/data/dtos/access_admin_dtos.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';

void main() {
  test('AccessAdminLookupsDto unwraps API envelope data', () {
    final AccessAdminLookups lookups = AccessAdminLookupsDto.fromResponse(
      <String, Object?>{
        'status': 200,
        'message': 'ok',
        'data': <String, Object?>{
          'permissions': <Map<String, Object?>>[
            <String, Object?>{
              'id': 'PERM-1',
              'label': 'clinical:read',
              'display_name': 'Clinical Read',
            },
          ],
        },
      },
    ).toEntity();

    expect(lookups.permissions, hasLength(1));
    expect(lookups.permissions.first.id, 'PERM-1');
    expect(lookups.permissions.first.label, 'clinical:read');
  });
}
