import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';

/// Resolves whether the registration form should show tenant/facility pickers and
/// which values to submit when fields are hidden.
@immutable
final class PatientRegistrationScope {
  const PatientRegistrationScope({
    this.defaultTenantId,
    this.defaultFacilityId,
    this.showTenantPicker = false,
    this.showFacilityPicker = false,
  });

  final String? defaultTenantId;
  final String? defaultFacilityId;
  final bool showTenantPicker;
  final bool showFacilityPicker;

  factory PatientRegistrationScope.resolve({
    required PatientReferenceData referenceData,
    required AppAccessPolicy accessPolicy,
  }) {
    final List<PatientReferenceOption> tenants = referenceData.tenants;
    final List<PatientReferenceOption> facilities = referenceData.facilities;
    final String? sessionTenantId = accessPolicy.tenantId;
    final String? sessionFacilityId = accessPolicy.facilityId;

    final bool showTenantPicker =
        accessPolicy.canManageTenant() &&
        (sessionTenantId == null || tenants.length > 1);

    final String? defaultTenantId = showTenantPicker
        ? null
        : (sessionTenantId ?? tenants.firstOrNull?.id);

    final List<PatientReferenceOption> scopedFacilities = facilitiesForTenant(
      facilities,
      defaultTenantId,
    );

    final bool showFacilityPicker =
        showTenantPicker || scopedFacilities.length > 1;

    if (!showFacilityPicker) {
      return PatientRegistrationScope(
        defaultTenantId: defaultTenantId,
        defaultFacilityId: scopedFacilities.isEmpty
            ? sessionFacilityId
            : scopedFacilities.first.id,
      );
    }

    return PatientRegistrationScope(
      defaultTenantId: defaultTenantId,
      defaultFacilityId: showTenantPicker ? null : sessionFacilityId,
      showTenantPicker: showTenantPicker,
      showFacilityPicker: true,
    );
  }

  static List<PatientReferenceOption> facilitiesForTenant(
    List<PatientReferenceOption> facilities,
    String? tenantId,
  ) {
    if (tenantId == null || tenantId.isEmpty) {
      return facilities;
    }

    return facilities
        .where(
          (PatientReferenceOption facility) =>
              facility.tenantId == null || facility.tenantId == tenantId,
        )
        .toList(growable: false);
  }
}
