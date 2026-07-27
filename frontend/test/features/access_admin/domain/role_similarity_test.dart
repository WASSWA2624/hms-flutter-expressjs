import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';

void main() {
  AccessAdminItem role({
    required String id,
    required String name,
    String? displayName,
    String? description,
    String? tenantId = 'tenant-1',
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
      tenantId: tenantId,
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
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.exactNameConflict, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches, isNotEmpty);
    final RoleSimilarityMatch match = result.similarMatches.first;
    expect(match.exactNameConflict, isTrue);
    expect(match.nameScore, 100);
    expect(
      match.fieldComparisons.map((RoleFieldComparison c) => c.field),
      containsAll(<String>['name', 'display_name']),
    );
    expect(
      match.fieldComparisons
          .firstWhere((RoleFieldComparison c) => c.field == 'name')
          .status,
      RoleFieldComparisonStatus.match,
    );
  });

  test('detects compact-key and reordered identity conflicts', () {
    final RoleDuplicateCheckResult compact = checkRoleDuplicates(
      name: 'WARDCLERK',
      displayName: 'Desk Aide',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );
    final RoleDuplicateCheckResult reordered = checkRoleDuplicates(
      name: 'FRONT DESK',
      displayName: 'Clerk Ward',
      tenantId: 'tenant-1',
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
      tenantId: 'tenant-1',
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
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.overridableMatches, isNotEmpty);
    expect(result.overridableMatches.first.score, greaterThanOrEqualTo(72));
    final RoleSimilarityMatch match = result.overridableMatches.first;
    expect(match.fieldComparisons, isNotEmpty);
    expect(
      match.fieldComparisons.any(
        (RoleFieldComparison c) =>
            c.field == 'name' &&
            c.score != null &&
            c.score! >= roleReviewFieldThreshold,
      ),
      isTrue,
    );
  });

  test('flags description-led near matches with supporting identity', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD AID',
      displayName: 'Ward Aide',
      description: 'Front desk ward support',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.similarMatches, isNotEmpty);
    expect(
      result.similarMatches.first.descriptionScore,
      greaterThanOrEqualTo(85),
    );
  });

  test('surfaces cross-scope Testing peers as overridable matches', () {
    final List<AccessAdminItem> peers = <AccessAdminItem>[
      role(
        id: 'role-org',
        name: 'TESTING',
        displayName: 'Testing',
        tenantId: 'tenant-1',
        facilityId: null,
      ),
      role(
        id: 'role-fac',
        name: 'TESTING',
        displayName: 'Testing',
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
    ];

    final RoleDuplicateCheckResult platformCreate = checkRoleDuplicates(
      name: 'Testing',
      displayName: 'Testing',
      tenantId: null,
      facilityId: null,
      existing: peers,
    );

    expect(platformCreate.hasExactConflict, isFalse);
    expect(platformCreate.similarMatches.length, 2);
    expect(platformCreate.overridableMatches.length, 2);
    expect(platformCreate.similarMatches.first.score, greaterThan(0));
    expect(
      platformCreate.similarMatches.every(
        (RoleSimilarityMatch match) => match.nameScore == 100,
      ),
      isTrue,
    );
  });

  test('surfaces facility peers when creating tenant-wide role', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: <AccessAdminItem>[
        role(
          id: 'role-fac',
          name: 'WARD CLERK',
          displayName: 'Ward Clerk',
          facilityId: 'facility-1',
        ),
      ],
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isNotEmpty);
    expect(result.overridableMatches, isNotEmpty);
    expect(result.similarMatches.first.nameScore, 100);
  });

  test('still hard-blocks exact conflicts in the same scope', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches.first.exactNameConflict, isTrue);
  });

  test('surfaces other-tenant peers as overridable when present in peer set', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WARD CLERK',
      displayName: 'Ward Clerk',
      tenantId: 'tenant-2',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isNotEmpty);
    expect(result.overridableMatches, isNotEmpty);
  });

  test('expands hospital role aliases for exact conflicts', () {
    final List<AccessAdminItem> peers = <AccessAdminItem>[
      role(
        id: 'role-rn',
        name: 'REGISTERED NURSE',
        displayName: 'Registered Nurse',
      ),
    ];

    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'RN',
      displayName: 'RN',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: peers,
    );

    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches.first.nameScore, 100);
  });

  test('treats initials as exact identity conflicts', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'WC',
      displayName: 'WC',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isTrue);
  });

  test('strips filler tokens before comparing identity', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'THE WARD CLERK ROLE',
      displayName: 'The Ward Clerk Role',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.hasExactConflict, isTrue);
  });

  test('flags token-subset near matches like Senior Ward Clerk', () {
    final RoleDuplicateCheckResult result = checkRoleDuplicates(
      name: 'SENIOR WARD CLERK',
      displayName: 'Senior Ward Clerk',
      description: 'Supervises ward desk',
      tenantId: 'tenant-1',
      facilityId: null,
      existing: existing,
    );

    expect(result.similarMatches, isNotEmpty);
    expect(
      result.similarMatches.first.nameScore,
      greaterThanOrEqualTo(roleTokenSubsetThreshold),
    );
  });

  test('canonicalizes aliases and filler tokens', () {
    expect(canonicalizeRoleText('The RN Role'), 'registered nurse');
    expect(normalizeRoleCompactKey('Ward Clerk'), 'wardclerk');
    expect(roleInitialsKey('Ward Clerk'), 'wc');
  });

  test('roleScopesMatch distinguishes platform tenant and facility', () {
    expect(
      roleScopesMatch(
        leftTenantId: null,
        leftFacilityId: null,
        rightTenantId: null,
        rightFacilityId: null,
      ),
      isTrue,
    );
    expect(
      roleScopesMatch(
        leftTenantId: null,
        leftFacilityId: null,
        rightTenantId: 'tenant-1',
        rightFacilityId: null,
      ),
      isFalse,
    );
    expect(
      roleScopesMatch(
        leftTenantId: 'tenant-1',
        leftFacilityId: 'facility-1',
        rightTenantId: 'tenant-1',
        rightFacilityId: 'facility-1',
      ),
      isTrue,
    );
  });
}
