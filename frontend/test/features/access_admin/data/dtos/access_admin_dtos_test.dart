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

  test('maps create-role Prisma payload to friendly display id', () {
    final AccessAdminItem role = AccessAdminItemDto.fromJson(
      <String, dynamic>{
        'id': 'a84038ca-ed05-4a8b-9cde-a276de4e725f',
        'human_friendly_id': 'ROL0000009',
        'name': 'TESTING',
        'display_name': 'testing',
        'description': 'TESTING',
        'tenant_id': 'tenant-uuid',
        'facility_id': null,
      },
      AccessAdminResource.roles,
    ).toEntity();

    expect(role.id, 'ROL0000009');
    expect(role.effectiveDisplayId, 'ROL0000009');
    expect(role.mutationId, 'a84038ca-ed05-4a8b-9cde-a276de4e725f');
    expect(role.resourceUuid, 'a84038ca-ed05-4a8b-9cde-a276de4e725f');
    expect(role.isTenantScopedRole, isTrue);
  });

  test('maps permission lookup description into meta', () {
    final AccessAdminLookupOption option = AccessAdminLookupOptionDto.fromJson(
      <String, dynamic>{
        'id': 'PRM0001',
        'label': 'clinical:read',
        'description': 'Read clinical records',
      },
    ).toEntity();

    expect(option.id, 'PRM0001');
    expect(option.meta, 'Read clinical records');
  });
}
