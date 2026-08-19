import 'package:hosspi_hms/features/accounts/domain/entities/accounts_department.dart';
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

final class AccountsDepartmentPageDto {
  const AccountsDepartmentPageDto({required this.page});

  final AppPage<AccountsDepartment> page;

  factory AccountsDepartmentPageDto.fromResponse(
    Object? responseData,
    AppPageRequest request,
  ) {
    final _JsonMap response = _expectMap(responseData);
    final List<AccountsDepartment> items = _list(response['data'])
        .map(AccountsDepartmentDto.new)
        .map((AccountsDepartmentDto dto) => dto.toEntity())
        .whereType<AccountsDepartment>()
        .toList(growable: false);

    return AccountsDepartmentPageDto(
      page: AppPage<AccountsDepartment>(
        items: items,
        request: request,
        totalItemCount: _int(_expectMap(response['pagination'])['total']),
      ),
    );
  }
}

final class AccountsDepartmentDto {
  const AccountsDepartmentDto(this.json);

  final Map<String, Object?> json;

  factory AccountsDepartmentDto.fromResponse(Object? responseData) {
    final _JsonMap response = _expectMap(responseData);
    final Object? data = response['data'];
    if (data is Map) {
      return AccountsDepartmentDto(_expectMap(data));
    }
    return AccountsDepartmentDto(response);
  }

  /// Returns `null` for rows missing the public reference so a malformed
  /// payload cannot render an unaddressable row.
  AccountsDepartment? toEntity() {
    final String? humanFriendlyId = _string(json['human_friendly_id']);
    if (humanFriendlyId == null) {
      return null;
    }

    return AccountsDepartment(
      humanFriendlyId: humanFriendlyId,
      departmentCode: _string(json['department_code']) ?? '',
      departmentName: _string(json['department_name']) ?? '',
      costCentreCode: _string(json['cost_centre_code']) ?? '',
      costCentreName: _string(json['cost_centre_name']) ?? '',
      parent: _string(json['parent']),
      parentHumanFriendlyId: _string(json['parent_human_friendly_id']),
      facility: _string(json['facility']),
      facilityHumanFriendlyId: _string(json['facility_human_friendly_id']),
      manager: _string(json['manager']),
      managerHumanFriendlyId: _string(json['manager_human_friendly_id']),
      defaultRevenueAccount: _string(json['default_revenue_account']),
      defaultRevenueAccountHumanFriendlyId: _string(
        json['default_revenue_account_human_friendly_id'],
      ),
      defaultExpenseAccount: _string(json['default_expense_account']),
      defaultExpenseAccountHumanFriendlyId: _string(
        json['default_expense_account_human_friendly_id'],
      ),
      budgetOwner: _string(json['budget_owner']),
      budgetOwnerHumanFriendlyId: _string(
        json['budget_owner_human_friendly_id'],
      ),
      effectiveFrom: _date(json['effective_from']),
      effectiveTo: _date(json['effective_to']),
      status:
          AccountsDepartmentStatus.fromWire(_string(json['status'])) ??
          AccountsDepartmentStatus.draft,
      version: _int(json['version']) ?? 1,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      archivedAt: _date(json['archived_at']),
    );
  }
}
