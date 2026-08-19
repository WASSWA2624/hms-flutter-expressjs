import 'package:hosspi_hms/features/accounts/domain/entities/accounts_payment_method.dart';
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

final class AccountsPaymentMethodPageDto {
  const AccountsPaymentMethodPageDto({required this.page});

  final AppPage<AccountsPaymentMethod> page;

  factory AccountsPaymentMethodPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsPaymentMethod> items = _list(response['data'])
        .map(AccountsPaymentMethodDto.new)
        .map((AccountsPaymentMethodDto dto) => dto.toEntity())
        .whereType<AccountsPaymentMethod>()
        .toList(growable: false);

    return AccountsPaymentMethodPageDto(
      page: AppPage<AccountsPaymentMethod>(
        items: items,
        request: request,
        totalItemCount: _int(_expectMap(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsPaymentMethodDto {
  const AccountsPaymentMethodDto(this.json);

  final Map<String, Object?> json;

  factory AccountsPaymentMethodDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map) {
      return AccountsPaymentMethodDto(_expectMap(data));
    }
    return AccountsPaymentMethodDto(response);
  }

  /// Returns `null` for rows missing the public reference or an unrecognised
  /// tender type so a malformed payload cannot render an unaddressable row.
  AccountsPaymentMethod? toEntity() {
    final String? humanFriendlyId = _string(json['human_friendly_id']);
    final AccountsPaymentMethodType? methodType =
        AccountsPaymentMethodType.fromWire(_string(json['method_type']));
    if (humanFriendlyId == null || methodType == null) {
      return null;
    }

    return AccountsPaymentMethod(
      humanFriendlyId: humanFriendlyId,
      methodCode: _string(json['method_code']) ?? '',
      methodName: _string(json['method_name']) ?? '',
      methodType: methodType,
      direction:
          AccountsPaymentMethodDirection.fromWire(
            _string(json['incoming_and_outgoing']),
          ) ??
          AccountsPaymentMethodDirection.incoming,
      provider: _string(json['provider']),
      settlementAccount: _string(json['settlement_account']),
      settlementAccountHumanFriendlyId: _string(
        json['settlement_account_human_friendly_id'],
      ),
      clearingAccount: _string(json['clearing_account']),
      clearingAccountHumanFriendlyId: _string(
        json['clearing_account_human_friendly_id'],
      ),
      requiresExternalReference: _bool(json['requires_external_reference']),
      requiresApproval: _bool(json['requires_approval']),
      feeRule: _string(json['fee_rule']),
      facilityScope: _string(json['facility_scope']),
      facilityHumanFriendlyId: _string(json['facility_human_friendly_id']),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
      status:
          AccountsPaymentMethodStatus.fromWire(_string(json['status'])) ??
          AccountsPaymentMethodStatus.draft,
      notes: _string(json['notes']),
      version: _int(json['version']) ?? 1,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      archivedAt: _date(json['archived_at']),
    );
  }
}
