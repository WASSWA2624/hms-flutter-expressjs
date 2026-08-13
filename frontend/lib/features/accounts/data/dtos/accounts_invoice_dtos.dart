import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef _Json = Map<String, Object?>;

String? _string(Object? value) {
  if (value == null) return null;
  final String text = value.toString().trim();
  return text.isEmpty ? null : text;
}

num? _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

DateTime? _date(Object? value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

_Json _expectMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map(
      (Object? key, Object? v) => MapEntry(key.toString(), v),
    );
  }
  return const <String, Object?>{};
}

_Json _dataMap(Object? responseData) {
  final _Json response = _expectMap(responseData);
  final Object? data = response['data'];
  if (data is Map) return _expectMap(data);
  return response;
}

List<Object?> _list(Object? value) {
  if (value is List) return value;
  return const <Object?>[];
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

final class AccountsInvoiceDto {
  const AccountsInvoiceDto(this.json);

  final _Json json;

  factory AccountsInvoiceDto.fromResponse(Object? responseData) {
    final _Json data = _dataMap(responseData);
    if (data.isNotEmpty) return AccountsInvoiceDto(data);
    return AccountsInvoiceDto(_expectMap(responseData));
  }

  AccountsInvoice toEntity() {
    final List<AccountsInvoiceLineItem> items = _list(json['items'])
        .whereType<Object?>()
        .map(_expectMap)
        .map((Object? raw) {
          final _Json row = _expectMap(raw);
          return AccountsInvoiceLineItem(
            id: _string(row['id']) ?? '',
            name: _string(row['name']) ?? '',
            description: _string(row['description']),
            quantity: _num(row['quantity']) ?? 0,
            unitPrice: _num(row['unit_price'] ?? row['unitPrice']) ?? 0,
            lineTotal: _num(row['line_total'] ?? row['lineTotal']),
          );
        })
        .where((AccountsInvoiceLineItem item) => item.name.isNotEmpty)
        .toList(growable: false);

    return AccountsInvoice(
      id: _string(json['id']) ?? '',
      displayId:
          _string(json['display_id']) ??
          _string(json['displayId']) ??
          _string(json['human_friendly_id']),
      payee: _string(json['payee']) ?? '',
      invoiceDate:
          _date(json['invoice_date']) ??
          _date(json['invoiceDate']) ??
          DateTime.now().toUtc(),
      reference: _string(json['reference']),
      notes: _string(json['notes']),
      currency: (_string(json['currency']) ?? 'UGX').toUpperCase(),
      status: (_string(json['status']) ?? 'DRAFT').toUpperCase(),
      totalAmount: _num(json['total_amount'] ?? json['totalAmount']) ?? 0,
      voidReason: _string(json['void_reason'] ?? json['voidReason']),
      voidedAt: _date(json['voided_at'] ?? json['voidedAt']),
      items: items,
    );
  }
}

final class AccountsInvoicePageDto {
  const AccountsInvoicePageDto({required this.page});

  final AppPage<AccountsInvoice> page;

  factory AccountsInvoicePageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _Json response = _expectMap(responseData);
    final Object? rawData = response['data'];
    final List<AccountsInvoice> items;
    if (rawData is List) {
      items = rawData
          .map((Object? row) => AccountsInvoiceDto(_expectMap(row)).toEntity())
          .where((AccountsInvoice item) => item.id.isNotEmpty)
          .toList(growable: false);
    } else {
      final _Json data = _dataMap(responseData);
      final Object? nestedItems = data['items'] ?? data['accountsInvoices'];
      items = _list(nestedItems)
          .map((Object? row) => AccountsInvoiceDto(_expectMap(row)).toEntity())
          .where((AccountsInvoice item) => item.id.isNotEmpty)
          .toList(growable: false);
    }

    return AccountsInvoicePageDto(
      page: AppPage<AccountsInvoice>(
        items: items,
        request: request,
        totalItemCount:
            _int(_expectMap(response['pagination'])['total']) ??
            _int(_expectMap(_dataMap(responseData)['pagination'])['total']) ??
            items.length,
      ),
    );
  }
}
