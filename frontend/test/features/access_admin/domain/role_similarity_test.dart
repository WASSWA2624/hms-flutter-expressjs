import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';

void main() {
  AccessAdminItem role({
    required String id,
    required String name,
    String? displayName,
    String? description,
    String? facilityId,
  }) {
    return AccessAdminItem(
      id: id,
      resource: AccessAdminResource.roles,
      displayId: id,
      title: displayName ?? name,
      name: name,
      displayName: displayName,
      subtitle: description,
      facilityId: facilityId,
      tenantId: 'tenant-1',
    );
  }

  test('detects exact name conflict in the same scope', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk',
      facilityId: null,
      existing: <AccessAdminItem>[
        role(
          id: 'role-1',
          name: 'WARD CLERK',
          displayName: 'Ward Clerk',
          description: 'Front desk',
        ),
      ],
    );

    expect(result.exactNameConflict, isTrue);
    expect(result.similarMatches, isNotEmpty);
  });

  test('returns overridable similar matches for near names', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLRCK',
      displayName: 'Ward Clerk',
      description: 'Front desk',
      facilityId: null,
      existing: <AccessAdminItem>[
        role(
          id: 'role-1',
          name: 'WARD CLERK',
          displayName: 'Ward Clerk',
          description: 'Front desk',
        ),
      ],
    );

    expect(result.exactNameConflict, isFalse);
    expect(result.overridableMatches, isNotEmpty);
    expect(result.overridableMatches.first.score, greaterThanOrEqualTo(80));
  });

  test('ignores peers outside facility scope', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      facilityId: 'facility-1',
      existing: <AccessAdminItem>[
        role(
          id: 'role-1',
          name: 'WARD CLERK',
          displayName: 'Ward Clerk',
        ),
      ],
    );

    expect(result.similarMatches, isEmpty);
  });
}
