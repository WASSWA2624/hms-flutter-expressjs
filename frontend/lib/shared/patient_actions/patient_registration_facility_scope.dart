import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';

/// Resolves whether the registration form should show a facility picker and which
/// facility to submit when the field is hidden.
@immutable
final class PatientRegistrationFacilityScope {
  const PatientRegistrationFacilityScope({
    this.defaultFacilityId,
    this.showFacilityPicker = false,
  });

  final String? defaultFacilityId;
  final bool showFacilityPicker;

  factory PatientRegistrationFacilityScope.resolve({
    required PatientReferenceData referenceData,
    required AppAccessPolicy accessPolicy,
  }) {
    final List<PatientReferenceOption> facilities = referenceData.facilities;
    if (facilities.length <= 1) {
      return PatientRegistrationFacilityScope(
        defaultFacilityId: facilities.isEmpty
            ? accessPolicy.facilityId
            : facilities.first.id,
      );
    }

    final bool showFacilityPicker = accessPolicy.canManageTenant();
    return PatientRegistrationFacilityScope(
      defaultFacilityId: showFacilityPicker ? null : accessPolicy.facilityId,
      showFacilityPicker: showFacilityPicker,
    );
  }
}
