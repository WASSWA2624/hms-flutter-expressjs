import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/access_admin_entities.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';

AccessAdminItem _user({
  required String id,
  required String email,
  String? phone,
  String? positionTitle,
  String? firstName,
  String? lastName,
  String tenantId = 'tenant-1',
  String? facilityId = 'facility-1',
  String? facilityName = 'Main Facility',
}) {
  return AccessAdminItem(
    id: id,
    resource: AccessAdminResource.users,
    displayId: id.startsWith('USR') ? id : 'USR-$id',
    title: email,
    email: email,
    phone: phone,
    positionTitle: positionTitle,
    firstName: firstName,
    lastName: lastName,
    profileName: <String?>[firstName, lastName]
        .whereType<String>()
        .join(' ')
        .trim(),
    tenantId: tenantId,
    facilityId: facilityId,
    facilityName: facilityName,
  );
}

void main() {
  final List<AccessAdminItem> existing = <AccessAdminItem>[
    _user(
      id: 'user-1',
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
    ),
  ];

  test('weights email and name above position and facility', () {
    expect(userEmailWeight, greaterThan(userFullNameWeight));
    expect(userFullNameWeight, greaterThan(userPhoneWeight));
    expect(userPhoneWeight, greaterThan(userPositionTitleWeight));
    expect(userPositionTitleWeight, greaterThan(userFacilityWeight));
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

  test('normalizes email, phone, names and position aliases', () {
    expect(normalizeUserEmail('  Alice@Example.COM '), 'alice@example.com');
    expect(normalizeUserPhoneDigits('+256 700-111-222'), '256700111222');
    expect(canonicalizePersonName('Dr. Alice  Smith'), 'alice smith');
    expect(canonicalizeUserPositionTitle('RN'), 'registered nurse');
  });

  test('treats national phone suffixes as strong matches', () {
    expect(scorePhonePair('256700111222', '700111222'), 100);
    expect(scorePhonePair('256700111222', '256788888888'), lessThan(userPhoneCompositeMin));
  });

  test('flags an exact email conflict as non-overridable', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'ALICE.SMITH@example.com',
      phone: '+256999000111',
      positionTitle: 'Lab Tech',
      firstName: 'Alice',
      lastName: 'Smith',
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
      firstName: 'Bob',
      lastName: 'Jones',
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
      firstName: 'Carol',
      lastName: 'Nguyen',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.exactEmailConflict, isFalse);
    expect(result.exactPhoneConflict, isFalse);
    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isNotEmpty);
    expect(result.overridableMatches, isNotEmpty);
    final UserSimilarityMatch match = result.similarMatches.first;
    expect(match.isExact, isFalse);
    expect(match.positionScore, greaterThanOrEqualTo(75));
    expect(match.reasons, contains('position_title'));
  });

  test('surfaces swapped first/last names as a strong name match', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'brandnew@example.com',
      phone: '+256999000111',
      positionTitle: 'Pharmacist',
      firstName: 'Smith',
      lastName: 'Alice',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isNotEmpty);
    final UserSimilarityMatch match = result.similarMatches.first;
    expect(match.fullNameScore, greaterThanOrEqualTo(88));
    expect(match.reasons, containsAll(<String>['full_name', 'facility']));
  });

  test('does not dilute composite score with weak unrelated phone similarity', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'alice.smith@example.com',
      phone: '+256788888888',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      facilityId: 'facility-1',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.exactEmailConflict, isTrue);
    final UserSimilarityMatch match = result.similarMatches.first;
    expect(match.score, greaterThanOrEqualTo(95));
    final UserFieldComparison phoneComparison = match.fieldComparisons
        .firstWhere((UserFieldComparison entry) => entry.field == 'phone');
    expect(phoneComparison.status, UserFieldComparisonStatus.different);
  });

  test('returns no matches for an unrelated user', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'unrelated@other.com',
      phone: '+1555000999',
      positionTitle: 'Pharmacist',
      firstName: 'Zed',
      lastName: 'Quark',
      tenantId: 'tenant-1',
      existing: existing,
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isEmpty);
  });

  test('excludes the user being edited from its own conflict set', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      tenantId: 'tenant-1',
      existing: existing,
      excludeUserId: 'user-1',
    );

    expect(result.hasExactConflict, isFalse);
    expect(result.similarMatches, isEmpty);
  });

  test('emits field comparisons including name and facility', () {
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      facilityId: 'facility-1',
      facilityName: 'Main Facility',
      tenantId: 'tenant-1',
      existing: existing,
    );

    final UserSimilarityMatch match = result.similarMatches.first;
    final Set<String> fields = match.fieldComparisons
        .map((UserFieldComparison entry) => entry.field)
        .toSet();
    expect(
      fields,
      containsAll(<String>[
        'first_name',
        'last_name',
        'full_name',
        'email',
        'phone',
        'position_title',
        'facility',
      ]),
    );
    final UserFieldComparison facilityComparison = match.fieldComparisons
        .firstWhere((UserFieldComparison entry) => entry.field == 'facility');
    expect(facilityComparison.inputValue, 'Main Facility');
    expect(facilityComparison.candidateValue, 'Main Facility');
  });

  test('never surfaces raw UUIDs in facility comparisons', () {
    const String facilityUuid = 'fbb67a68-8fea-4eed-a072-4869585d8466';
    final UserDuplicateCheckResult result = checkUserDuplicates(
      email: 'alice.smith@example.com',
      phone: '+256700111222',
      positionTitle: 'Registered Nurse',
      firstName: 'Alice',
      lastName: 'Smith',
      facilityId: facilityUuid,
      facilityName: 'DemoCare General Hospital',
      tenantId: 'tenant-1',
      existing: <AccessAdminItem>[
        _user(
          id: 'USR0001',
          email: 'alice.smith@example.com',
          phone: '+256700111222',
          positionTitle: 'Registered Nurse',
          firstName: 'Alice',
          lastName: 'Smith',
          facilityId: facilityUuid,
          facilityName: 'DemoCare General Hospital',
        ),
      ],
    );

    final UserFieldComparison facilityComparison = result
        .similarMatches
        .first
        .fieldComparisons
        .firstWhere((UserFieldComparison entry) => entry.field == 'facility');
    expect(facilityComparison.inputValue, 'DemoCare General Hospital');
    expect(facilityComparison.candidateValue, 'DemoCare General Hospital');
    expect(publicUserLabel(facilityUuid), isNull);
  });
}
