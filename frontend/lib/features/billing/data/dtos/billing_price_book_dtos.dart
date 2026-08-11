import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
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

num? _num(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value.trim());
  }
  return null;
}

int? _int(Object? value) {
  final num? number = _num(value);
  return number?.toInt();
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

final class BillingPriceBookEntryPageDto {
  const BillingPriceBookEntryPageDto({required this.page});

  final AppPage<BillingPriceBookEntry> page;

  factory BillingPriceBookEntryPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<BillingPriceBookEntry> items = _list(response['data'])
        .map(BillingPriceBookEntryDto.new)
        .map((BillingPriceBookEntryDto dto) => dto.toEntity())
        .where((BillingPriceBookEntry item) => item.id.isNotEmpty)
        .toList(growable: false);

    return BillingPriceBookEntryPageDto(
      page: AppPage<BillingPriceBookEntry>(
        items: items,
        request: request,
        totalItemCount: _int(_map(response['pagination'])['total']),
      ),
    );
  }
}

final class BillingPriceBookEntryDto {
  const BillingPriceBookEntryDto(this.json);

  final _JsonMap json;

  factory BillingPriceBookEntryDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map || data == null) {
      return BillingPriceBookEntryDto(_map(data ?? response));
    }
    return BillingPriceBookEntryDto(_map(response));
  }

  BillingPriceBookEntry toEntity() {
    final _JsonMap coverage = _map(json['coverage_plan']);
    final _JsonMap company = _map(json['insurance_company']);
    return BillingPriceBookEntry(
      id: _string(json['id']) ?? '',
      displayId:
          _string(json['display_id']) ?? _string(json['human_friendly_id']),
      tenantId: _string(json['tenant_id']),
      facilityId: _string(json['facility_id']),
      catalogType: _string(json['catalog_type']) ?? '',
      catalogItemId: _string(json['catalog_item_id']) ?? '',
      paymentMode: _string(json['payment_mode']) ?? 'SELF_PAY',
      coveragePlanId: _string(json['coverage_plan_id']),
      coveragePlanName: _string(coverage['name']),
      insuranceCompanyId: _string(json['insurance_company_id']),
      insuranceCompanyName: _string(company['name']),
      billingEntity: _string(json['billing_entity']) ?? 'FACILITY',
      unitPrice: _num(json['unit_price']) ?? 0,
      currency: (_string(json['currency']) ?? 'UGX').toUpperCase(),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
      isActive: _bool(json['is_active'], fallback: true),
      notes: _string(json['notes']),
    );
  }
}
