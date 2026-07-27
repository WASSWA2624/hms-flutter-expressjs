import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';

AccessAdminItem _user({
  required String id,
  required String email,
  String? phone,
  String? positionTitle,
  String tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
}) {
  return AccessAdminItem(
    id: id,
    resource: AccessAdminResource.users,
    displayId: id,
    title: email,
    email: email,
    phone: phone,
    positionTitle: positionTitle,
    tenantId: tenantId,
    facilityId: facilityId,
  );
}

void main() {
  final List<AccessAdminItem> existing = <AccessAdminItem>[
    _user(
      id: 'user-1',
      email: 'alice@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
    ),
  ];

  test('weights email above phone above position title', () {
    expect(userEmailWeight, greaterThan(userPhoneWeight));
    expect(userPhoneWeight, greaterThan(userPositionTitleWeight));
    final int emailHeavy = compositeUserSimilarityScore(
      emailScore: 100,
      positionScore: 0,
    );
    final int positionHeavy = compositeUserSimilarityScore(
      emailScore: 0,
      positionScore: 100,
    );
    expect(emailHeavy, greaterThan(positionHeavy));
  });

  test('normalizes email, phone digits and position title', () {
    expect(normalizeUserEmail('  Alice@Example.COM '), 'alice@example.com');
    expect(normalizeUserPhoneDigits('+256 700-111-222'), '256700111222');
    expect(canonicalizeUserPositionTitle('Registered  Nurse!'), 'registered nurse');
  });

  test('flags an exact email conflict as non-overridable', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'ALICE@example.com',
      phone: '+256999000111',
      positionTitle: 'Lab Tech',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.exactEmailConflict, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.similarMatches.first.exactEmailConflict, isTrue);
    expect(result.overridableMatches, isEmpty);
  });

  test('flags an exact phone conflict regardless of formatting', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'brandnew@example.com',
      phone: '256-700-111-222',
      positionTitle: 'Lab Tech',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.exactPhoneConflict, isTrue);
    expect(result.hasExactConflict, isTrue);
    expect(result.overridableMatches, isEmpty);
  });

  test('surfaces a near position match as an overridable soft conflict', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'brandnew@example.com',
      phone: '+256999000111',
      positionTitle: 'Registered Nurses',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isNotEmpty);
    expect(result.overridableMatches, isNotEmpty);
    final UserSimilarityMatch match = result.similarMatches.first;
    expect(match.isExact, isFalse);
    expect(match.positionScore, isNotNull);
    expect(match.positionScore! >= userReviewFieldThreshold, isTrue);
    expect(match.reasons, contains('position_title'));
  });

  test('returns no matches for an unrelated user', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'unrelated@other.com',
      phone: '+1555000999',
      positionTitle: 'Pharmacist',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isEmpty);
  });

  test('excludes the edited user from its own conflict set', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'alice@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      tenantId: 'tenant-1',
      existing: existing,
      excludeUserId: 'user-1',
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isEmpty);
  });

  test('hydrates review rows from backend conflict entries', () {
    final List<UserSimilarityMatch> matches =
        userSimilarityMatchesFromConflictEntries(<Map<String, Object?>>[
      <String, Object?>{
        'id': 'user-9',
        'display_id': 'USR9',
        'email': 'dup@example.com',
        'phone': '256700111222',
        'position_title': 'Registered Nurse',
        'score': 100,
        'exactEmailConflict': true,
        'reasons': <String>['email'],
        'field_comparisons': <Map<String, Object?>>[
          <String, Object?>{
            'field': 'email',
            'input_value': 'dup@example.com',
            'candidate_value': 'dup@example.com',
            'score': 100,
            'status': 'MATCH',
          },
        ],
      },
    ]);

    expect(matches, hasLength(1));
    expect(matches.first.exactEmailConflict, isTrue);
    expect(matches.first.isExact, isTrue);
    expect(matches.first.user.email, 'dup@example.com');
    expect(matches.first.fieldComparisons, isNotEmpty);
  });
}
