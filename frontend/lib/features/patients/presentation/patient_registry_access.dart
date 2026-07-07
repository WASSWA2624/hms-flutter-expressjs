import 'package:hosspi_hms/core/permissions/access_policy.dart';

bool isPharmacyRegistryReader(AppAccessPolicy policy) {
  return policy.hasRole(AppRole.pharmacist) &&
      !policy.grants(AppPermissions.patientWrite);
}
