import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/data/dtos/access_admin_dtos.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';

void main() {
  group('AccessAdminUserDetailDto', () {
    test('parses assignment ids and permissions grouped by role', () {
      final AccessAdminUserDetail detail =
          AccessAdminUserDetailDto.fromResponse(<String, Object?>{
            'id': 'USR0001',
            'display_id': 'USR0001',
            'email': 'nurse@hosspi.com',
            'position_title': 'Registered Nurse',
            'status': 'ACTIVE',
            'roles': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'ROL-NURSE',
                'name': 'NURSE',
                'user_role_id': 'UR-1',
                'resource_uuid': 'role-uuid',
              },
            ],
            'direct_permissions': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'PRM-1',
                'name': 'profile:read',
                'resource_uuid': 'perm-uuid',
              },
            ],
            'effective_permissions': <String>['clinical:read', 'profile:read'],
            'role_permission_preview': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'clinical:read',
                'source_role': 'NURSE',
              },
            ],
            'permissions_by_role': <Map<String, Object?>>[
              <String, Object?>{
                'role_id': 'ROL-NURSE',
                'role_name': 'NURSE',
                'user_role_id': 'UR-1',
                'resource_uuid': 'role-uuid',
                'permissions': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'clinical:read',
                    'source_role': 'NURSE',
                  },
                ],
              },
            ],
          }).toEntity();

      expect(detail.item.roles.single.userRoleId, 'UR-1');
      expect(detail.directPermissions.single.mutationId, 'perm-uuid');
      expect(detail.permissionsByRole, hasLength(1));
      expect(
        detail.resolvedRoleGroups.single.permissions.single.name,
        'clinical:read',
      );
      expect(detail.resolvedRoleGroups.single.userRoleId, 'UR-1');
    });
  });
}
