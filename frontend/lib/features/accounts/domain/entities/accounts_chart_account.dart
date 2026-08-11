import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Chart of accounts row (`accounts.md` §4.6 / §8.9).
@immutable
final class AccountsChartAccount {
  const AccountsChartAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.accountType,
    required this.currency,
    required this.isActive,
    this.displayId,
    this.tenantId,
    this.facilityId,
    this.parentId,
    this.parentCode,
    this.parentName,
    this.effectiveFrom,
    this.notes,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? facilityId;
  final String code;
  final String name;
  final String accountType;
  final String? parentId;
  final String? parentCode;
  final String? parentName;
  final String currency;
  final DateTime? effectiveFrom;
  final bool isActive;
  final String? notes;

  String get effectiveId {
    final String? display = displayId?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    return id;
  }

  String get accountLabel {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return code.trim();
    }
    return trimmedName;
  }

  String get parentLabel {
    final String? parentNameValue = parentName?.trim();
    if (parentNameValue != null && parentNameValue.isNotEmpty) {
      return parentNameValue;
    }
    final String? parentCodeValue = parentCode?.trim();
    if (parentCodeValue != null && parentCodeValue.isNotEmpty) {
      return parentCodeValue;
    }
    return '';
  }
}

@immutable
final class AccountsChartQuery {
  const AccountsChartQuery({
    this.search = '',
    this.accountType = '',
    this.parentId = '',
    this.currency = '',
    this.isActive,
    this.pageRequest = const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
  });

  final String search;
  final String accountType;
  final String parentId;
  final String currency;
  final bool? isActive;
  final AppPageRequest pageRequest;

  AccountsChartQuery copyWith({
    String? search,
    String? accountType,
    String? parentId,
    String? currency,
    bool? isActive,
    AppPageRequest? pageRequest,
    bool clearIsActive = false,
  }) {
    return AccountsChartQuery(
      search: search ?? this.search,
      accountType: accountType ?? this.accountType,
      parentId: parentId ?? this.parentId,
      currency: currency ?? this.currency,
      isActive: clearIsActive ? null : isActive ?? this.isActive,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
