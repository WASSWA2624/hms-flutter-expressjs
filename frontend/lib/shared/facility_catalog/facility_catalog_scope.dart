import 'package:flutter/foundation.dart';

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
