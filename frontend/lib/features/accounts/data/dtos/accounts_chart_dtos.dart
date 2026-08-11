import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
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

_JsonMap _map(Object? value) => _expectMap(value);

List<_JsonMap> _list(Object? value) {
  if (value is! List) {
    return const <_JsonMap>[];
  }
  return value
      .map(_map)
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

final class AccountsChartAccountPageDto {
  const AccountsChartAccountPageDto({required this.page});

  final AppPage<AccountsChartAccount> page;

  factory AccountsChartAccountPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsChartAccount> items = _list(response['data'])
        .map(AccountsChartAccountDto.new)
        .map((AccountsChartAccountDto dto) => dto.toEntity())
        .where((AccountsChartAccount item) => item.id.isNotEmpty)
        .toList(growable: false);

    return AccountsChartAccountPageDto(
      page: AppPage<AccountsChartAccount>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsChartAccountDto {
  const AccountsChartAccountDto(this.json);

  final _JsonMap json;

  factory AccountsChartAccountDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map || data == null) {
      return AccountsChartAccountDto(_map(data ?? response));
    }
    return AccountsChartAccountDto(_map(response));
  }

  AccountsChartAccount toEntity() {
    final _JsonMap parent = _map(json['parent']);
    return AccountsChartAccount(
      id: _string(json['id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      code: _string(json['code']) ?? '',
      name: _string(json['name']) ?? '',
      accountType: _string(json['account_type']) ?? '',
      parentId: _string(json['parent_id']) ?? _string(parent['id']),
      parentCode: _string(parent['code']),
      parentName: _string(parent['name']),
      currency: (_string(json['currency']) ?? 'UGX').toUpperCase(),
      effectiveFrom: _date(json['effective_from']),
      isActive: _bool(json['is_active'], fallback: true),
      notes: _string(json['notes']),
    );
  }
}
