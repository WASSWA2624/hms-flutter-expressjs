import 'package:hosspi_hms/features/accounts/domain/entities/accounts_document_sequence.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef _JsonMap = Map<String, Object?>;

_JsonMap _expectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return <String, Object?>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        entry.key.toString(): entry.value,
    };
  }
  return const <String, Object?>{};
}

List<_JsonMap> _list(Object? value) {
  if (value is! List) {
    return const <_JsonMap>[];
  }
  return value
      .map(_expectMap)
      .where((_JsonMap item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _string(Object? value) {
  if (value == null) {
    return null;
  }
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

DateTime? _date(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

final class AccountsDocumentSequencePageDto {
  const AccountsDocumentSequencePageDto({required this.page});

  final AppPage<AccountsDocumentSequence> page;

  factory AccountsDocumentSequencePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsDocumentSequence> items = _list(response['data'])
        .map(AccountsDocumentSequenceDto.new)
        .map((AccountsDocumentSequenceDto dto) => dto.toEntity())
        .whereType<AccountsDocumentSequence>()
        .toList(growable: false);

    return AccountsDocumentSequencePageDto(
      page: AppPage<AccountsDocumentSequence>(
        items: items,
        request: request,
        totalItemCount: _int(_expectMap(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsDocumentSequenceDto {
  const AccountsDocumentSequenceDto(this.json);

  final Map<String, Object?> json;

  factory AccountsDocumentSequenceDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map) {
      return AccountsDocumentSequenceDto(_expectMap(data));
    }
    return AccountsDocumentSequenceDto(response);
  }

  /// Returns `null` for rows missing the public reference or carrying a
  /// document type this build does not know, so a malformed payload cannot
  /// render an unaddressable or mislabelled row.
  AccountsDocumentSequence? toEntity() {
    final String? humanFriendlyId = _string(json['human_friendly_id']);
    final AccountsDocumentType? documentType = AccountsDocumentType.fromWire(
      _string(json['document_type']),
    );
    if (humanFriendlyId == null || documentType == null) {
      return null;
    }

    return AccountsDocumentSequence(
      humanFriendlyId: humanFriendlyId,
      sequenceCode: _string(json['sequence_code']) ?? '',
      documentType: documentType,
      module: _string(json['module']) ?? '',
      facility: _string(json['facility']),
      facilityHumanFriendlyId: _string(json['facility_human_friendly_id']),
      prefix: _string(json['prefix']) ?? '',
      suffix: _string(json['suffix']),
      datePattern: _string(json['date_pattern']),
      nextNumber: _int(json['next_number']),
      minimumLength: _int(json['minimum_length']) ?? 1,
      resetFrequency:
          AccountsDocumentSequenceResetFrequency.fromWire(
            _string(json['reset_frequency']),
          ) ??
          AccountsDocumentSequenceResetFrequency.never,
      lastIssuedNumber: _int(json['last_issued_number']),
      lastIssuedAt: _date(json['last_issued_at']),
      gapPolicy:
          AccountsDocumentSequenceGapPolicy.fromWire(
            _string(json['gap_policy']),
          ) ??
          AccountsDocumentSequenceGapPolicy.allowGaps,
      status:
          AccountsDocumentSequenceStatus.fromWire(
            // The list row publishes the status under the documented column id.
            _string(json['sequence_status']) ?? _string(json['status']),
          ) ??
          AccountsDocumentSequenceStatus.draft,
      nextReferencePreview: _string(json['next_reference_preview']),
      notes: _string(json['notes']),
      version: _int(json['version']) ?? 1,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      archivedAt: _date(json['archived_at']),
    );
  }
}
