import 'package:hosspi_hms/features/accounts/domain/entities/accounts_fiscal_period.dart';
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

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final String normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

final class AccountsFiscalPeriodPageDto {
  const AccountsFiscalPeriodPageDto({required this.page});

  final AppPage<AccountsFiscalPeriod> page;

  factory AccountsFiscalPeriodPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsFiscalPeriod> items = _list(response['data'])
        .map(AccountsFiscalPeriodDto.new)
        .map((AccountsFiscalPeriodDto dto) => dto.toEntity())
        .whereType<AccountsFiscalPeriod>()
        .toList(growable: false);

    return AccountsFiscalPeriodPageDto(
      page: AppPage<AccountsFiscalPeriod>(
        items: items,
        request: request,
        totalItemCount: _int(_expectMap(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsFiscalPeriodDto {
  const AccountsFiscalPeriodDto(this.json);

  final Map<String, Object?> json;

  factory AccountsFiscalPeriodDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map) {
      return AccountsFiscalPeriodDto(_expectMap(data));
    }
    return AccountsFiscalPeriodDto(response);
  }

  /// Returns `null` for rows missing the public reference or required dates so
  /// a malformed payload cannot render an unaddressable row.
  AccountsFiscalPeriod? toEntity() {
    final String? humanFriendlyId = _string(json['human_friendly_id']);
    final DateTime? startDate = _date(json['start_date']);
    final DateTime? endDate = _date(json['end_date']);
    if (humanFriendlyId == null || startDate == null || endDate == null) {
      return null;
    }

    return AccountsFiscalPeriod(
      humanFriendlyId: humanFriendlyId,
      fiscalYear: _string(json['fiscal_year']) ?? '',
      periodNo: _int(json['period_no']) ?? 0,
      periodName: _string(json['period_name']) ?? '',
      startDate: startDate,
      endDate: endDate,
      entityAndFacility: _string(json['entity_and_facility']),
      module: _string(json['module']),
      openDate: _date(json['open_date']),
      softCloseDate: _date(json['soft_close_date']),
      closeDate: _date(json['close_date']),
      lockDate: _date(json['lock_date']),
      reopenedAt: _date(json['reopened_at']),
      reopenedBy: _string(json['reopened_by']),
      status:
          AccountsFiscalPeriodStatus.fromWire(_string(json['period_status'])) ??
          AccountsFiscalPeriodStatus.draft,
      facilityHumanFriendlyId: _string(json['facility_human_friendly_id']),
      notes: _string(json['notes']),
      isLocked: _bool(json['is_locked']),
      version: _int(json['version']) ?? 1,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      archivedAt: _date(json['archived_at']),
    );
  }
}
