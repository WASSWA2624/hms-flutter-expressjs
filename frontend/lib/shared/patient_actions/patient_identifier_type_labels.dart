import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

const List<String> patientIdentifierTypes = <String>[
  'MRN',
  'NATIONAL_ID',
  'PASSPORT',
  'INSURANCE',
  'DRIVER_LICENSE',
  'BIRTH_CERTIFICATE',
  'OTHER',
];

String patientIdentifierTypeLabel(AppLocalizations l10n, String value) {
  return switch (value.trim().toUpperCase()) {
    'MRN' => l10n.patientsIdentifierTypeMrnLabel,
    'NATIONAL_ID' => l10n.patientsIdentifierTypeNationalIdLabel,
    'PASSPORT' => l10n.patientsIdentifierTypePassportLabel,
    'INSURANCE' => l10n.patientsIdentifierTypeInsuranceLabel,
    'DRIVER_LICENSE' => l10n.patientsIdentifierTypeDriverLicenseLabel,
    'BIRTH_CERTIFICATE' => l10n.patientsIdentifierTypeBirthCertificateLabel,
    'OTHER' => l10n.patientsIdentifierTypeOtherLabel,
    _ => AppDisplay.apiLabel(value),
  };
}

List<String> patientIdentifierTypeOptions(String currentValue) {
  final String normalized = currentValue.trim().toUpperCase();
  if (normalized.isEmpty || patientIdentifierTypes.contains(normalized)) {
    return patientIdentifierTypes;
  }

  return <String>[normalized, ...patientIdentifierTypes];
}
