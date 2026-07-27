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

  final List<AccessAdminItem> existing = <AccessAdminItem>[
    role(
      id: 'role-1',
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk ward support',
    ),
  ];

  test('detects exact name conflict in the same scope', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      description: 'Front desk',
      facilityId: null,
      existing: existing,
    );

    expect(result.exactNameConflict, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches, isNotEmpty);
  });

  test('detects compact-key and reordered identity conflicts', () {
    final RoleDuplicateCheckResult compact = checkRoleDuplicates(
      name: 'WARDCLERK',
      displayName: 'Desk Aide',
      facilityId: null,
      existing: existing,
    );
    final RoleDuplicateCheckResult reordered = checkRoleDuplicates(
      name: 'FRONT DESK',
      displayName: 'Clerk Ward',
      facilityId: null,
      existing: existing,
    );

    expect(compact.hasExactConflict, isTrue);
    expect(reordered.hasExactConflict, isTrue);
  });

  test('detects cross-field identity matches', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'Ward Clerk',
      displayName: 'Desk Support',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches.first.crossIdentityScore, 100);
  });

  test('returns overridable similar matches for near names', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLRCK',
      displayName: 'Ward Clerck',
      description: 'Front desk ward suport',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.overridableMatches, isNotEmpty);
    expect(result.overridableMatches.first.score, greaterThanOrEqualTo(72));
  });

  test('flags description-led near matches with supporting identity', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD AID',
      displayName: 'Ward Aide',
      description: 'Front desk ward support',
      facilityId: null,
      existing: existing,
    );

    expect(result.similarMatches, isNotEmpty);
    expect(
      result.similarMatches.first.descriptionScore,
      greaterThanOrEqualTo(85),
    );
  });

  test('ignores peers outside facility scope', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      facilityId: 'facility-1',
      existing: existing,
    );

    expect(result.similarMatches, isEmpty);
  });
}
