import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/components/components.dart';

String clinicalActionApiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split(RegExp(r'[_\s-]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

String clinicalActionJoinDisplay(
  Iterable<String?> values, {
  String separator = ' | ',
}) {
  return values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(separator);
}

String? clinicalActionTrimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? clinicalActionNonEmpty(String value) {
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool clinicalActionHasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String clinicalActionNormalizedCatalogToken(String value) {
  return value.trim().toUpperCase();
}

List<AppSelectOption<String>> clinicalActionStatusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
      ),
  ];
}

ClinicalActionCatalogOption? clinicalActionCatalogOptionById(
  List<ClinicalActionCatalogOption> options,
  String? id,
) {
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  for (final ClinicalActionCatalogOption option in options) {
    if (clinicalActionCatalogIdMatches(option, id)) {
      return option;
    }
  }
  return null;
}

bool clinicalActionCatalogIdMatches(
  ClinicalActionCatalogOption option,
  String id,
) {
  final String normalized = id.trim();
  return option.id == normalized ||
      option.publicId == normalized ||
      option.apiId == normalized;
}

String? clinicalActionCatalogDisplayLabelById(
  List<ClinicalActionCatalogOption> options,
  String? apiId, {
  String separator = ' | ',
}) {
  final ClinicalActionCatalogOption? option = clinicalActionCatalogOptionById(
    options,
    apiId,
  );
  if (option == null) {
    return null;
  }
  return clinicalActionJoinDisplay(<String?>[
    option.displayTitle,
    option.displaySubtitle,
  ], separator: separator);
}

List<ClinicalActionCatalogOption> clinicalActionMergeCatalogOption(
  List<ClinicalActionCatalogOption> options,
  ClinicalActionCatalogOption option,
) {
  if (options.any(
    (ClinicalActionCatalogOption item) => item.apiId == option.apiId,
  )) {
    return options;
  }
  return <ClinicalActionCatalogOption>[option, ...options];
}
