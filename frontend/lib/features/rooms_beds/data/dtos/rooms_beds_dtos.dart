import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';

typedef RoomsBedsJsonMap = Map<String, Object?>;

final class BedAssignmentRecordDto {
  const BedAssignmentRecordDto(this.json);

  final RoomsBedsJsonMap json;

  BedAssignmentRecord toEntity() {
    return BedAssignmentRecord(
      id: _string(json['id']) ?? '',
      admissionId: _string(json['admission_id']) ?? '',
      bedId: _string(json['bed_id']) ?? '',
      assignedAt: _date(json['assigned_at']),
      releasedAt: _date(json['released_at']),
    );
  }
}

List<BedAssignmentRecord> decodeBedAssignmentRecords(Object? responseData) {
  final RoomsBedsJsonMap response = _expectMap(responseData);
  return _list(response['data'])
      .map(BedAssignmentRecordDto.new)
      .map((BedAssignmentRecordDto dto) => dto.toEntity())
      .where((BedAssignmentRecord item) {
        return item.id.isNotEmpty &&
            item.bedId.isNotEmpty &&
            item.admissionId.isNotEmpty;
      })
      .toList(growable: false);
}

void decodeSuccessfulVoid(Object? responseData) {
  _expectMap(responseData);
}

RoomsBedsJsonMap _expectMap(Object? value) {
  if (value is RoomsBedsJsonMap) {
    return value;
  }

  throw const FormatException('Expected response object.');
}

List<RoomsBedsJsonMap> _list(Object? value) {
  if (value is! List) {
    return const <RoomsBedsJsonMap>[];
  }

  return value.whereType<RoomsBedsJsonMap>().toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }

  final String normalized = value.toString().trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) {
  final String? normalized = _string(value);
  if (normalized == null) {
    return null;
  }

  return DateTime.tryParse(normalized);
}
