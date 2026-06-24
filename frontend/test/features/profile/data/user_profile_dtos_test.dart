import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/profile/data/dtos/user_profile_dtos.dart';
import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';

void main() {
  group('UserProfileRecordDto', () {
    test('parses profile records from paginated response', () {
      final UserProfileListDto dto = UserProfileListDto.fromResponse(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'profile-1',
              'user_id': 'user-1',
              'first_name': 'Jane',
              'last_name': 'Doe',
              'gender': 'FEMALE',
            },
          ],
        },
      );

      expect(dto.records, hasLength(1));
      expect(dto.records.first.fullName, 'Jane Doe');
    });

    test('builds update payload from draft', () {
      final Map<String, Object?> payload = UserProfileRecordDto.toUpdatePayload(
        const UserProfileDraft(
          firstName: 'Jane',
          lastName: 'Doe',
          gender: 'female',
        ),
      );

      expect(payload['first_name'], 'Jane');
      expect(payload['last_name'], 'Doe');
      expect(payload['gender'], 'FEMALE');
    });
  });
}
