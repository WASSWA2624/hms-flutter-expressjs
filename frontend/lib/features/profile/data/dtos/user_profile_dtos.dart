import 'package:hosspi_hms/features/profile/domain/entities/user_profile_entities.dart';

typedef UserProfileJsonMap = Map<String, Object?>;

final class UserProfileRecordDto {
  const UserProfileRecordDto({required this.record});

  final UserProfileRecord record;

  factory UserProfileRecordDto.fromJson(UserProfileJsonMap json) {
    return UserProfileRecordDto(
      record: UserProfileRecord(
        id: _requiredString(json, 'id'),
        userId: _requiredString(json, 'user_id'),
        facilityId: _optionalString(json, 'facility_id'),
        firstName: _optionalString(json, 'first_name'),
        middleName: _optionalString(json, 'middle_name'),
        lastName: _optionalString(json, 'last_name'),
        gender: _optionalString(json, 'gender'),
        dateOfBirth: _optionalDateTime(json['date_of_birth']),
      ),
    );
  }

  UserProfileRecord toEntity() => record;

  static UserProfileJsonMap toUpdatePayload(UserProfileDraft draft) {
    return <String, Object?>{
      if (_hasText(draft.firstName)) 'first_name': draft.firstName!.trim(),
      if (draft.middleName != null)
        'middle_name': draft.middleName!.trim().isEmpty
            ? null
            : draft.middleName!.trim(),
      if (draft.lastName != null)
        'last_name': draft.lastName!.trim().isEmpty
            ? null
            : draft.lastName!.trim(),
      if (draft.gender != null && draft.gender!.trim().isNotEmpty)
        'gender': draft.gender!.trim().toUpperCase(),
    };
  }
}

final class UserProfileListDto {
  const UserProfileListDto({required this.records});

  final List<UserProfileRecord> records;

  factory UserProfileListDto.fromResponse(Object? responseData) {
    if (responseData is List<Object?>) {
      return UserProfileListDto(
        records: responseData
            .whereType<UserProfileJsonMap>()
            .map(UserProfileRecordDto.fromJson)
            .map((UserProfileRecordDto dto) => dto.record)
            .toList(growable: false),
      );
    }

    if (responseData is UserProfileJsonMap) {
      final Object? data = responseData['data'];
      if (data is List<Object?>) {
        return UserProfileListDto(
          records: data
              .whereType<UserProfileJsonMap>()
              .map(UserProfileRecordDto.fromJson)
              .map((UserProfileRecordDto dto) => dto.record)
              .toList(growable: false),
        );
      }
    }

    return const UserProfileListDto(records: <UserProfileRecord>[]);
  }
}

String _requiredString(UserProfileJsonMap json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing user profile field: $key');
  }

  return value.trim();
}

String? _optionalString(UserProfileJsonMap json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    return null;
  }

  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _optionalDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value.trim());
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}
