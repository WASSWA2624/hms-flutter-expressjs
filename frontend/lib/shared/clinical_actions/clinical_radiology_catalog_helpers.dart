import 'package:flutter/material.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_catalog_select_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/components/components.dart';

const List<String> clinicalRadiologyLateralityValues = <String>[
  'LEFT',
  'RIGHT',
  'BILATERAL',
  'OBLIQUE',
];

List<AppSelectOption<String>> clinicalRadiologyLateralityOptions(
  AppLocalizations l10n,
) {
  return <AppSelectOption<String>>[
    AppSelectOption<String>(
      value: 'LEFT',
      label: l10n.radiologyLateralityLeft,
      leadingIcon: const Icon(Icons.turn_left_outlined),
    ),
    AppSelectOption<String>(
      value: 'RIGHT',
      label: l10n.radiologyLateralityRight,
      leadingIcon: const Icon(Icons.turn_right_outlined),
    ),
    AppSelectOption<String>(
      value: 'BILATERAL',
      label: l10n.radiologyLateralityBilateral,
      leadingIcon: const Icon(Icons.compare_arrows_outlined),
    ),
    AppSelectOption<String>(
      value: 'OBLIQUE',
      label: l10n.radiologyLateralityOblique,
      leadingIcon: const Icon(Icons.change_circle_outlined),
    ),
  ];
}

String? clinicalRadiologyLateralityLabel(AppLocalizations l10n, String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'LEFT' => l10n.radiologyLateralityLeft,
    'RIGHT' => l10n.radiologyLateralityRight,
    'BILATERAL' => l10n.radiologyLateralityBilateral,
    'OBLIQUE' => l10n.radiologyLateralityOblique,
    '' => null,
    _ => value,
  };
}

IconData clinicalRadiologyModalityIcon(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'XRAY' || 'X_RAY' || 'X-RAY' => Icons.photo_camera_outlined,
    'CT' => Icons.donut_large_outlined,
    'MRI' => Icons.all_out_outlined,
    'ULTRASOUND' || 'US' => Icons.graphic_eq_outlined,
    'FLUOROSCOPY' => Icons.video_camera_back_outlined,
    'MAMMOGRAPHY' => Icons.image_search_outlined,
    'PET' => Icons.blur_on_outlined,
    'NUCLEAR_MEDICINE' || 'NUCLEAR MEDICINE' => Icons.radio_button_checked,
    'INTERVENTIONAL_RADIOLOGY' ||
    'INTERVENTIONAL RADIOLOGY' => Icons.medical_services_outlined,
    'ECG' => Icons.monitor_heart_outlined,
    'ECHO' => Icons.favorite_border,
    'ENDO' || 'GASTRO' => Icons.biotech_outlined,
    'OTHER' => Icons.image_search_outlined,
    _ => Icons.image_search_outlined,
  };
}

String clinicalRadiologyModalityDisplayLabel(
  AppLocalizations l10n,
  String? value,
) {
  final String normalized = (value ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return '';
  }
  return switch (normalized) {
    'XRAY' || 'X_RAY' || 'X-RAY' => l10n.radiologyModalityXray,
    'CT' => l10n.radiologyModalityCt,
    'MRI' => l10n.radiologyModalityMri,
    'ULTRASOUND' || 'US' => l10n.radiologyModalityUltrasound,
    'FLUOROSCOPY' => l10n.radiologyModalityFluoroscopy,
    'MAMMOGRAPHY' => l10n.radiologyModalityMammography,
    'PET' => l10n.radiologyModalityPet,
    'NUCLEAR_MEDICINE' ||
    'NUCLEAR MEDICINE' => l10n.radiologyModalityNuclearMedicine,
    'INTERVENTIONAL_RADIOLOGY' ||
    'INTERVENTIONAL RADIOLOGY' => l10n.radiologyModalityInterventionalRadiology,
    'ECG' => l10n.radiologyModalityEcg,
    'ECHO' => l10n.radiologyModalityEcho,
    'ENDO' => l10n.radiologyModalityEndo,
    'GASTRO' => l10n.radiologyModalityGastro,
    'OTHER' => l10n.radiologyModalityOther,
    _ => normalized.replaceAll('_', ' '),
  };
}

IconData clinicalRadiologyBodyRegionIcon(String value) {
  final String normalized = value.trim().toUpperCase();
  if (_containsAny(normalized, <String>['HEAD', 'BRAIN', 'SKULL', 'CRAN'])) {
    return Icons.psychology_alt_outlined;
  }
  if (_containsAny(normalized, <String>['ORBIT', 'EYE', 'OCULAR'])) {
    return Icons.remove_red_eye_outlined;
  }
  if (_containsAny(normalized, <String>['SINUS', 'NASAL', 'NOSE'])) {
    return Icons.air_outlined;
  }
  if (_containsAny(normalized, <String>['MANDIBLE', 'JAW', 'MAXILL'])) {
    return Icons.face_retouching_natural_outlined;
  }
  if (_containsAny(normalized, <String>['NECK', 'CERVICAL'])) {
    return Icons.record_voice_over_outlined;
  }
  if (_containsAny(normalized, <String>['CHEST', 'THORAX', 'LUNG', 'RIB'])) {
    return Icons.air_outlined;
  }
  if (_containsAny(normalized, <String>['BREAST', 'MAMMO'])) {
    return Icons.favorite_border;
  }
  if (_containsAny(normalized, <String>[
    'ABDOM',
    'LIVER',
    'SPLEEN',
    'KIDNEY',
  ])) {
    return Icons.circle_outlined;
  }
  if (_containsAny(normalized, <String>['PELV', 'UTER', 'OVAR', 'PROSTAT'])) {
    return Icons.wc_outlined;
  }
  if (_containsAny(normalized, <String>['SPINE', 'VERTEB', 'LUMBAR', 'SACR'])) {
    return Icons.align_vertical_center_outlined;
  }
  if (_containsAny(normalized, <String>['SHOULDER', 'CLAVIC'])) {
    return Icons.sports_martial_arts_outlined;
  }
  if (_containsAny(normalized, <String>['ARM', 'ELBOW', 'FOREARM', 'HUMER'])) {
    return Icons.back_hand_outlined;
  }
  if (_containsAny(normalized, <String>['WRIST', 'HAND', 'FINGER', 'PALM'])) {
    return Icons.pan_tool_outlined;
  }
  if (_containsAny(normalized, <String>['HIP', 'ACETAB', 'PELVIS'])) {
    return Icons.accessibility_new_outlined;
  }
  if (_containsAny(normalized, <String>['KNEE', 'PATELL'])) {
    return Icons.directions_walk_outlined;
  }
  if (_containsAny(normalized, <String>['LEG', 'THIGH', 'FEMUR', 'TIBIA'])) {
    return Icons.directions_walk_outlined;
  }
  if (_containsAny(normalized, <String>['ANKLE', 'FOOT', 'TOE', 'HEEL'])) {
    return Icons.directions_run_outlined;
  }
  return Icons.accessibility_new_outlined;
}

String? clinicalRadiologyOptionModality(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(
        clinicalRadiologyMetadataText(option, 'modality'),
      ) ??
      clinicalActionTrimmedOrNull(option.category);
}

String? clinicalRadiologyOptionBodyRegion(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(
        clinicalRadiologyMetadataText(option, 'body_region'),
      ) ??
      clinicalActionTrimmedOrNull(
        clinicalRadiologyMetadataText(option, 'bodyRegion'),
      ) ??
      clinicalRadiologySecondaryFragment(
        option,
        exclude: <String?>[
          clinicalRadiologyOptionModality(option),
          clinicalRadiologyOptionLaterality(option),
          option.status,
        ],
      );
}

String? clinicalRadiologyOptionLaterality(ClinicalActionCatalogOption option) {
  final String? metadataValue = clinicalActionTrimmedOrNull(
    clinicalRadiologyMetadataText(option, 'laterality'),
  );
  if (metadataValue != null) {
    return metadataValue;
  }
  final String haystack = clinicalActionJoinDisplay(<String?>[
    option.secondaryText,
    option.searchText,
    option.name,
  ]).toUpperCase();
  for (final String value in clinicalRadiologyLateralityValues) {
    if (haystack.contains(value)) {
      return value;
    }
  }
  return null;
}

String? clinicalRadiologyOptionPriority(ClinicalActionCatalogOption option) {
  return clinicalActionTrimmedOrNull(
        clinicalRadiologyMetadataText(option, 'priority'),
      ) ??
      clinicalActionTrimmedOrNull(
        clinicalRadiologyMetadataText(option, 'urgency'),
      );
}

String? clinicalRadiologyMetadataText(
  ClinicalActionCatalogOption option,
  String key,
) {
  final Object? value = option.metadata[key];
  return clinicalActionTrimmedOrNull(value?.toString());
}

String? clinicalRadiologySecondaryFragment(
  ClinicalActionCatalogOption option, {
  required Iterable<String?> exclude,
}) {
  final Set<String> excluded = exclude
      .whereType<String>()
      .map(clinicalActionNormalizedCatalogToken)
      .where((String value) => value.isNotEmpty)
      .toSet();
  final List<String> fragments = <String>[
    ...?clinicalActionTrimmedOrNull(
      option.secondaryText,
    )?.split(RegExp(r'[|,;/]+')),
  ];
  for (final String fragment in fragments) {
    final String? normalized = clinicalActionTrimmedOrNull(fragment);
    if (normalized == null) {
      continue;
    }
    final String token = clinicalActionNormalizedCatalogToken(normalized);
    if (excluded.contains(token) ||
        clinicalRadiologyLateralityValues.contains(token)) {
      continue;
    }
    return normalized;
  }
  return null;
}

List<String> clinicalRadiologySortedValues(Iterable<String?> values) {
  final Set<String> seen = <String>{};
  final List<String> unique = <String>[];
  for (final String? value in values) {
    final String? normalized = clinicalActionTrimmedOrNull(value);
    if (normalized == null) {
      continue;
    }
    final String key = clinicalActionNormalizedCatalogToken(normalized);
    if (seen.add(key)) {
      unique.add(normalized);
    }
  }
  unique.sort(
    (String left, String right) =>
        clinicalActionApiLabel(left).compareTo(clinicalActionApiLabel(right)),
  );
  return unique;
}

List<AppSelectOption<String>> clinicalRadiologyModalityOptions(
  AppLocalizations l10n,
  List<ClinicalActionCatalogOption> catalog,
) {
  final List<String> values = clinicalRadiologySortedValues(
    catalog.map(clinicalRadiologyOptionModality),
  );
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: clinicalRadiologyModalityDisplayLabel(l10n, value),
        leadingIcon: Icon(clinicalRadiologyModalityIcon(value)),
      ),
  ];
}

List<AppSelectOption<String>> clinicalRadiologyBodyRegionOptions(
  List<ClinicalActionCatalogOption> catalog, {
  String? modality,
  String? laterality,
  String? priority,
}) {
  final String? selectedModality = clinicalActionTrimmedOrNull(modality);
  final String? selectedLaterality = clinicalActionTrimmedOrNull(laterality);
  final String? selectedPriority = clinicalActionTrimmedOrNull(priority);
  final Iterable<ClinicalActionCatalogOption> filtered = catalog.where((
    ClinicalActionCatalogOption option,
  ) {
    if (selectedModality != null &&
        clinicalActionNormalizedCatalogToken(
              clinicalRadiologyOptionModality(option) ?? '',
            ) !=
            clinicalActionNormalizedCatalogToken(selectedModality)) {
      return false;
    }
    if (selectedLaterality != null &&
        clinicalActionNormalizedCatalogToken(
              clinicalRadiologyOptionLaterality(option) ?? '',
            ) !=
            clinicalActionNormalizedCatalogToken(selectedLaterality)) {
      return false;
    }
    final String? optionPriority = clinicalRadiologyOptionPriority(option);
    if (selectedPriority != null &&
        optionPriority != null &&
        clinicalActionNormalizedCatalogToken(optionPriority) !=
            clinicalActionNormalizedCatalogToken(selectedPriority)) {
      return false;
    }
    return true;
  });
  final List<String> values = clinicalRadiologySortedValues(
    filtered.map(clinicalRadiologyOptionBodyRegion),
  );
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(
        value: value,
        label: clinicalActionApiLabel(value),
        leadingIcon: Icon(clinicalRadiologyBodyRegionIcon(value)),
      ),
  ];
}

IconData clinicalRadiologyCatalogIcon(ClinicalActionCatalogOption option) {
  return clinicalRadiologyModalityIcon(
    clinicalRadiologyOptionModality(option) ?? option.category,
  );
}

bool _containsAny(String haystack, Iterable<String> needles) {
  for (final String needle in needles) {
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

List<AppSelectOption<String>> clinicalRadiologyCatalogSelectOptions(
  AppLocalizations l10n,
  List<ClinicalActionCatalogOption> options,
) {
  return clinicalCatalogSelectOptions(
    options,
    iconBuilder: clinicalRadiologyCatalogIcon,
    extraSearchValues: (ClinicalActionCatalogOption option) => <String?>[
      clinicalRadiologyOptionModality(option),
      clinicalRadiologyOptionBodyRegion(option),
      clinicalRadiologyOptionLaterality(option),
      clinicalRadiologyOptionPriority(option),
    ],
    labelBuilder: (ClinicalActionCatalogOption option) =>
        ClinicalRadiologyCatalogOptionLabel(l10n: l10n, option: option),
  );
}

List<ClinicalActionCatalogOption> orderClinicalRadiologyRequestCatalogItems(
  List<ClinicalActionCatalogOption> catalog, {
  required bool Function(ClinicalActionCatalogOption option) includeOption,
  required bool Function(ClinicalActionCatalogOption option) isSelected,
}) {
  final List<ClinicalActionCatalogOption> selected =
      <ClinicalActionCatalogOption>[];
  final List<ClinicalActionCatalogOption> unselected =
      <ClinicalActionCatalogOption>[];
  for (final ClinicalActionCatalogOption option in catalog) {
    if (!includeOption(option)) {
      continue;
    }
    if (isSelected(option)) {
      selected.add(option);
    } else {
      unselected.add(option);
    }
  }
  return <ClinicalActionCatalogOption>[...selected, ...unselected];
}

class ClinicalRadiologyCatalogOptionLabel extends StatelessWidget {
  const ClinicalRadiologyCatalogOptionLabel({
    required this.l10n,
    required this.option,
    super.key,
  });

  final AppLocalizations l10n;
  final ClinicalActionCatalogOption option;

  @override
  Widget build(BuildContext context) {
    return ClinicalCatalogOptionLabel(
      option: option,
      subtitle: clinicalActionJoinDisplay(<String?>[
        clinicalRadiologyModalityDisplayLabel(
          l10n,
          clinicalRadiologyOptionModality(option),
        ),
        clinicalRadiologyOptionBodyRegion(option),
        clinicalRadiologyOptionLaterality(option),
        clinicalRadiologyOptionPriority(option),
        option.status,
        option.displaySubtitle,
      ]),
    );
  }
}
