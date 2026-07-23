import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/components/app_currency.dart';

@immutable
final class FacilityCatalogScope {
  const FacilityCatalogScope({this.tenantId, this.facilityId});

  final String? tenantId;
  final String? facilityId;

  bool get isReady {
    final String? tenant = tenantId?.trim();
    final String? facility = facilityId?.trim();
    return tenant != null &&
        tenant.isNotEmpty &&
        facility != null &&
        facility.isNotEmpty;
  }

  Map<String, Object?> get apiParams {
    final Map<String, Object?> params = <String, Object?>{};
    final String? tenant = tenantId?.trim();
    final String? facility = facilityId?.trim();
    if (tenant != null && tenant.isNotEmpty) {
      params['tenant_id'] = tenant;
    }
    if (facility != null && facility.isNotEmpty) {
      params['facility_id'] = facility;
    }
    return params;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FacilityCatalogScope &&
            tenantId == other.tenantId &&
            facilityId == other.facilityId;
  }

  @override
  int get hashCode => Object.hash(tenantId, facilityId);
}

/// Scope pick result including currencies for price defaults.
@immutable
final class FacilityCatalogScopePick {
  const FacilityCatalogScopePick({
    required this.scope,
    this.tenantCurrency,
    this.facilityCurrency,
  });

  final FacilityCatalogScope scope;
  final String? tenantCurrency;
  final String? facilityCurrency;

  String? get tenantId => scope.tenantId;
  String? get facilityId => scope.facilityId;
  bool get isReady => scope.isReady;

  /// Facility currency wins when set; otherwise tenant; otherwise app default.
  String get defaultCurrency => resolveDefaultCurrency(
        facilityCurrency: facilityCurrency,
        tenantCurrency: tenantCurrency,
      );
}
