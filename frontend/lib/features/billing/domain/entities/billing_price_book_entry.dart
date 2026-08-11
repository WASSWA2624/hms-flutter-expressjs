import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

/// Facility / pharmacy tariff row used when charging (price book).
@immutable
final class BillingPriceBookEntry {
  const BillingPriceBookEntry({
    required this.id,
    required this.catalogType,
    required this.catalogItemId,
    required this.paymentMode,
    required this.unitPrice,
    required this.currency,
    required this.billingEntity,
    required this.isActive,
    this.displayId,
    this.tenantId,
    this.facilityId,
    this.coveragePlanId,
    this.coveragePlanName,
    this.insuranceCompanyId,
    this.insuranceCompanyName,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
  });

  final String id;
  final String? displayId;
  final String? tenantId;
  final String? facilityId;
  final String catalogType;
  final String catalogItemId;
  final String paymentMode;
  final String? coveragePlanId;
  final String? coveragePlanName;
  final String? insuranceCompanyId;
  final String? insuranceCompanyName;
  final String billingEntity;
  final num unitPrice;
  final String currency;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final bool isActive;
  final String? notes;

  String get effectiveId {
    final String? display = displayId?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    return id;
  }

  String get itemLabel {
    final String type = catalogType.trim();
    final String item = catalogItemId.trim();
    if (type.isEmpty) {
      return item;
    }
    if (item.isEmpty) {
      return type;
    }
    return '$type · $item';
  }

  String get schemeLabel {
    final String? name = coveragePlanName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    final String? planId = coveragePlanId?.trim();
    if (planId != null && planId.isNotEmpty) {
      return planId;
    }
    return '';
  }
}

@immutable
final class BillingPriceBookQuery {
  const BillingPriceBookQuery({
    this.search = '',
    this.catalogType = '',
    this.paymentMode = '',
    this.billingEntity = '',
    this.coveragePlanId = '',
    this.isActive,
    this.pageRequest = const AppPageRequest(pageSize: AppPageRequest.maxPageSize),
  });

  final String search;
  final String catalogType;
  final String paymentMode;
  final String billingEntity;
  final String coveragePlanId;
  final bool? isActive;
  final AppPageRequest pageRequest;

  BillingPriceBookQuery copyWith({
    String? search,
    String? catalogType,
    String? paymentMode,
    String? billingEntity,
    String? coveragePlanId,
    bool? isActive,
    AppPageRequest? pageRequest,
    bool clearIsActive = false,
  }) {
    return BillingPriceBookQuery(
      search: search ?? this.search,
      catalogType: catalogType ?? this.catalogType,
      paymentMode: paymentMode ?? this.paymentMode,
      billingEntity: billingEntity ?? this.billingEntity,
      coveragePlanId: coveragePlanId ?? this.coveragePlanId,
      isActive: clearIsActive ? null : isActive ?? this.isActive,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }
}
