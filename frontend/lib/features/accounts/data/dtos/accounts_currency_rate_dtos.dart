import 'package:hosspi_hms/features/accounts/domain/entities/accounts_currency_rate.dart';
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

double? _double(Object? value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
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

final class AccountsCurrencyRatePageDto {
  const AccountsCurrencyRatePageDto({required this.page});

  final AppPage<AccountsCurrencyRate> page;

  factory AccountsCurrencyRatePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsCurrencyRate> items = _list(response['data'])
        .map(AccountsCurrencyRateDto.new)
        .map((AccountsCurrencyRateDto dto) => dto.toEntity())
        .whereType<AccountsCurrencyRate>()
        .toList(growable: false);

    return AccountsCurrencyRatePageDto(
      page: AppPage<AccountsCurrencyRate>(
        items: items,
        request: request,
        totalItemCount: _int(_expectMap(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsCurrencyRateDto {
  const AccountsCurrencyRateDto(this.json);

  final Map<String, Object?> json;

  factory AccountsCurrencyRateDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map) {
      return AccountsCurrencyRateDto(_expectMap(data));
    }
    return AccountsCurrencyRateDto(response);
  }

  /// Returns `null` for rows missing the public reference, code, rate, or
  /// effective date so a malformed payload cannot render an unusable row.
  AccountsCurrencyRate? toEntity() {
    final String? humanFriendlyId = _string(json['human_friendly_id']);
    final String? currencyCode = _string(json['currency_code']);
    final double? exchangeRate = _double(json['exchange_rate']);
    final DateTime? effectiveDate = _date(json['effective_date']);
    if (humanFriendlyId == null ||
        currencyCode == null ||
        exchangeRate == null ||
        effectiveDate == null) {
      return null;
    }

    return AccountsCurrencyRate(
      humanFriendlyId: humanFriendlyId,
      currencyCode: currencyCode.toUpperCase(),
      currencyName: _string(json['currency_name']) ?? '',
      symbol: _string(json['symbol']) ?? '',
      decimalPlaces: _int(json['decimal_places']) ?? 2,
      baseCurrency: _bool(json['base_currency']),
      rateType:
          AccountsCurrencyRateType.fromWire(_string(json['rate_type'])) ??
          AccountsCurrencyRateType.spot,
      exchangeRate: exchangeRate,
      effectiveDate: effectiveDate,
      source: _string(json['source']),
      buyRate: _double(json['buy_rate']),
      sellRate: _double(json['sell_rate']),
      lastUpdatedAt: _date(json['last_updated_at']),
      updatedBy: _string(json['updated_by']),
      status:
          AccountsCurrencyStatus.fromWire(_string(json['currency_status'])) ??
          AccountsCurrencyStatus.draft,
      entityAndFacility: _string(json['entity_and_facility']),
      facilityHumanFriendlyId: _string(json['facility_human_friendly_id']),
      notes: _string(json['notes']),
      version: _int(json['version']) ?? 1,
      createdAt: _date(json['created_at']),
      archivedAt: _date(json['archived_at']),
    );
  }
}
